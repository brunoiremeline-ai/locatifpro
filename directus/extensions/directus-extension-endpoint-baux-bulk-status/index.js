function parseDate(value) {
  if (!value) return null;
  const d = new Date(value);
  if (Number.isNaN(d.getTime())) return null;
  return value;
}

function rangeOverlaps(aStart, aEnd, bStart, bEnd) {
  const a1 = new Date(aStart).getTime();
  const b1 = new Date(bStart).getTime();
  const a2 = aEnd ? new Date(aEnd).getTime() : Number.POSITIVE_INFINITY;
  const b2 = bEnd ? new Date(bEnd).getTime() : Number.POSITIVE_INFINITY;
  return a1 <= b2 && b1 <= a2;
}

function asArray(v) {
  if (Array.isArray(v)) return v;
  if (v === undefined || v === null || v === '') return [];
  return [v];
}

function parseBoolean(v, defaultValue = false) {
  if (v === undefined || v === null || v === '') return defaultValue;
  if (typeof v === 'boolean') return v;
  if (typeof v === 'number') return v !== 0;
  if (typeof v === 'string') {
    const s = v.trim().toLowerCase();
    if (['1', 'true', 't', 'yes', 'y', 'oui', 'o'].includes(s)) return true;
    if (['0', 'false', 'f', 'no', 'n', 'non'].includes(s)) return false;
  }
  throw new Error('Valeur booléenne invalide');
}

function sanitizeIds(ids) {
  const uuidRe = /^[0-9a-fA-F-]{36}$/;
  return asArray(ids).map(String).map((s) => s.trim()).filter((s) => uuidRe.test(s));
}

function buildBauxFilter({ selectionIds, filter, allowedStatuses }) {
  if (selectionIds.length > 0) {
    return { id: { _in: selectionIds } };
  }

  const and = [];

  if (filter?.societe_interne_id) {
    const societes = asArray(filter.societe_interne_id).map((v) => String(v)).filter(Boolean);
    if (societes.length === 1) and.push({ societe_interne_id: { _eq: societes[0] } });
    if (societes.length > 1) and.push({ societe_interne_id: { _in: societes } });
  }

  if (filter?.current_status) {
    const statuses = asArray(filter.current_status)
      .map((s) => String(s).toUpperCase())
      .filter((s) => allowedStatuses.has(s));
    if (statuses.length === 1) and.push({ statut: { _eq: statuses[0] } });
    if (statuses.length > 1) and.push({ statut: { _in: statuses } });
  }

  if (filter?.date_fin_before) {
    and.push({ date_fin_contractuelle: { _lt: filter.date_fin_before } });
  }

  if (and.length === 0) return {};
  if (and.length === 1) return and[0];
  return { _and: and };
}

function registerBauxBulkStatus(router, { services, getSchema, database, logger }) {
  const { ItemsService } = services;

  router.post('/', async (req, res) => {
    const at = new Date().toISOString();

    if (!req?.accountability?.user && !req?.accountability?.admin) {
      return res.status(401).json({ ok: false, error: 'Non autorisé', at });
    }

    const allowedStatuses = new Set(['BROUILLON', 'ACTIF', 'CLOS', 'LITIGE']);

    try {
      const targetStatus = String(req?.body?.target_status || '').trim().toUpperCase();
      if (!allowedStatuses.has(targetStatus)) {
        return res.status(400).json({ ok: false, error: 'target_status invalide', at });
      }

      const selectionIds = sanitizeIds(req?.body?.selection_ids);
      const filter = req?.body?.filter || {};
      const dryRun = parseBoolean(req?.body?.dry_run, true);
      const activationMode = String(req?.body?.activation_conflict_mode || 'block').toLowerCase() === 'skip' ? 'skip' : 'block';
      const schema = await getSchema();
      const bauxService = new ItemsService('baux', {
        knex: database,
        schema,
        accountability: req.accountability,
      });

      if (selectionIds.length === 0) {
        const hasFilter = Boolean(filter?.societe_interne_id || filter?.current_status || filter?.date_fin_before);
        if (!hasFilter) {
          return res.status(400).json({ ok: false, error: 'selection_ids ou filter est requis', at });
        }
      }

      if (filter?.date_fin_before) {
        const d = parseDate(filter.date_fin_before);
        if (!d) return res.status(400).json({ ok: false, error: 'filter.date_fin_before invalide', at });
        filter.date_fin_before = d;
      }

      const bauxFilter = buildBauxFilter({ selectionIds, filter, allowedStatuses });
      const candidatesAll = await bauxService.readByQuery({
        fields: ['id', 'code', 'bien_id', 'date_effet', 'date_fin_contractuelle', 'statut', 'societe_interne_id'],
        filter: bauxFilter,
        sort: ['code'],
        limit: -1,
      });

      const alreadyTarget = candidatesAll.filter((b) => String(b.statut).toUpperCase() === targetStatus);
      const candidates = candidatesAll.filter((b) => String(b.statut).toUpperCase() !== targetStatus);

      let conflicts = [];
      let updatable = [...candidates];

      if (targetStatus === 'ACTIF' && candidates.length > 0) {
        const candidateIds = candidates.map((b) => b.id);
        const bienIds = [...new Set(candidates.map((b) => b.bien_id).filter(Boolean))];

        const activeExisting = await bauxService.readByQuery({
          fields: ['id', 'code', 'bien_id', 'date_effet', 'date_fin_contractuelle'],
          filter: {
            _and: [
              { statut: { _eq: 'ACTIF' } },
              { bien_id: { _in: bienIds } },
              { id: { _nin: candidateIds } },
            ],
          },
          limit: -1,
        });

        const conflictByCandidate = new Map();

        for (const c of candidates) {
          for (const a of activeExisting) {
            if (c.bien_id === a.bien_id && rangeOverlaps(c.date_effet, c.date_fin_contractuelle, a.date_effet, a.date_fin_contractuelle)) {
              const arr = conflictByCandidate.get(c.id) || [];
              arr.push({ type: 'active_existing', with_bail_id: a.id, with_code: a.code });
              conflictByCandidate.set(c.id, arr);
            }
          }
        }

        const byBien = new Map();
        for (const c of candidates) {
          const key = String(c.bien_id);
          const arr = byBien.get(key) || [];
          arr.push(c);
          byBien.set(key, arr);
        }
        for (const list of byBien.values()) {
          for (let i = 0; i < list.length; i++) {
            for (let j = i + 1; j < list.length; j++) {
              const a = list[i];
              const b = list[j];
              if (rangeOverlaps(a.date_effet, a.date_fin_contractuelle, b.date_effet, b.date_fin_contractuelle)) {
                const ai = conflictByCandidate.get(a.id) || [];
                ai.push({ type: 'candidate_overlap', with_bail_id: b.id, with_code: b.code });
                conflictByCandidate.set(a.id, ai);
                const bi = conflictByCandidate.get(b.id) || [];
                bi.push({ type: 'candidate_overlap', with_bail_id: a.id, with_code: a.code });
                conflictByCandidate.set(b.id, bi);
              }
            }
          }
        }

        conflicts = candidates
          .filter((c) => conflictByCandidate.has(c.id))
          .map((c) => ({
            bail_id: c.id,
            code: c.code,
            bien_id: c.bien_id,
            conflicts: conflictByCandidate.get(c.id),
          }));

        if (activationMode === 'block' && conflicts.length > 0) {
          updatable = [];
        } else if (activationMode === 'skip' && conflicts.length > 0) {
          const blocked = new Set(conflicts.map((c) => c.bail_id));
          updatable = candidates.filter((c) => !blocked.has(c.id));
        }
      }

      const report = {
        target_status: targetStatus,
        dry_run: dryRun,
        mode: selectionIds.length > 0 ? 'selection' : 'filter',
        candidates: candidates.length,
        already_target: alreadyTarget.length,
        conflicts: conflicts.length,
        updatable: updatable.length,
        updated: 0,
        skipped_conflicts: Math.max(candidates.length - updatable.length, 0),
        conflict_mode: targetStatus === 'ACTIF' ? activationMode : null,
        conflicts_detail: conflicts,
      };

      if (!dryRun && updatable.length > 0) {
        const idsToUpdate = updatable.map((b) => b.id);
        const updatedKeys = await bauxService.updateMany(idsToUpdate, { statut: targetStatus });
        report.updated = Array.isArray(updatedKeys) ? updatedKeys.length : idsToUpdate.length;
      }

      const details = {
        source: 'baux-bulk-status-endpoint',
        target_status: targetStatus,
        mode: report.mode,
        dry_run: dryRun,
        conflict_mode: report.conflict_mode,
        selection_count: selectionIds.length,
        filter: selectionIds.length > 0 ? null : filter,
        report: {
          candidates: report.candidates,
          already_target: report.already_target,
          conflicts: report.conflicts,
          updatable: report.updatable,
          updated: report.updated,
          skipped_conflicts: report.skipped_conflicts,
        },
      };

      await database('journal_actions').insert({
        action: 'BULK_STATUT_BAUX',
        utilisateur: req?.accountability?.user || null,
        bail_id: null,
        periode: null,
        details: JSON.stringify(details),
      });

      return res.json({ ok: true, at, report });
    } catch (err) {
      try { logger?.error?.(err); } catch (_) {}
      return res.status(500).json({ ok: false, error: String(err?.message || err), at });
    }
  });
}

module.exports = {
  id: 'baux-bulk-status',
  handler: registerBauxBulkStatus,
};
