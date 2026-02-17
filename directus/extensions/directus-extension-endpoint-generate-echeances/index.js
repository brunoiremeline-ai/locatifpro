function registerGenerateEcheances(router, { database, logger }) {
  function parseBooleanInput(value, defaultValue = true) {
    if (value === undefined || value === null || value === '') return defaultValue;
    if (typeof value === 'boolean') return value;
    if (typeof value === 'number') return value !== 0;
    if (typeof value === 'string') {
      const v = value.trim().toLowerCase();
      if (['1', 'true', 't', 'yes', 'y', 'oui', 'o'].includes(v)) return true;
      if (['0', 'false', 'f', 'no', 'n', 'non'].includes(v)) return false;
    }
    throw new Error('include_start must be a boolean-compatible value');
  }

  router.post('/', async (req, res) => {
    const at = new Date().toISOString();

    if (!req?.accountability?.user && !req?.accountability?.admin) {
      return res.status(401).json({ ok: false, error: 'Unauthorized', at });
    }

    const bailId = req?.body?.bail_id || null;
    const startPeriod = req?.body?.start_period || null; // YYYY-MM
    const periodsRaw = req?.body?.periods;
    const periods = Number.isFinite(Number(periodsRaw)) ? Number(periodsRaw) : 12;
    let includeStart = true;
    try {
      includeStart = parseBooleanInput(req?.body?.include_start, true);
    } catch (e) {
      return res.status(400).json({ ok: false, error: e.message, at });
    }
    const mode = String(req?.body?.mode || 'skip');

    if (!bailId) {
      return res.status(400).json({ ok: false, error: 'bail_id is required', at });
    }

    if (startPeriod && !/^\d{4}-\d{2}$/.test(startPeriod)) {
      return res.status(400).json({ ok: false, error: 'start_period must be YYYY-MM', at });
    }

    if (!Number.isInteger(periods) || periods < 1 || periods > 60) {
      return res.status(400).json({ ok: false, error: 'periods must be an integer between 1 and 60', at });
    }

    try {
      const sql = `
SELECT *
FROM public.workflow_generate_echeances(
  ?::uuid,
  NULL::date,
  NULL::date,
  ?::text,
  ?::int,
  ?::text,
  ?::text
);
`;

      const bindings = [bailId, startPeriod || '', periods, includeStart ? 'true' : 'false', mode];
      const result = await database.raw(sql, bindings);
      const row = result?.rows?.[0] || result?.[0]?.[0] || null;

      res.json({ ok: true, at, report: row || { bail_id: bailId, mode, include_start: includeStart, candidates: 0, created: 0, skipped_existing: 0 } });
    } catch (err) {
      try { logger?.error?.(err); } catch (_) {}
      res.status(500).json({ ok: false, error: String(err?.message || err), at });
    }
  });
}

module.exports = {
  id: 'generate-echeances',
  handler: registerGenerateEcheances,
};
