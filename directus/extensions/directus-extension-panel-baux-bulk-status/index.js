import { definePanel } from '@directus/extensions-sdk';

export default definePanel({
  id: 'baux-bulk-status-tool',
  name: 'Baux: Statut en masse',
  icon: 'rule_settings',
  description: 'Prévisualiser puis appliquer un changement de statut en masse.',
  minWidth: 16,
  minHeight: 14,
  component: {
    data() {
      return {
        loading: false,

        listSearch: '',
        listLoading: false,
        listRows: [],
        listSelectedIds: [],

        targetStatus: 'CLOS',
        conflictMode: 'block',

        previewDone: false,
        previewSignature: '',
        lastPreviewPayload: null,
        previewAt: '',
        changeTick: 0,
        previewTick: null,
        previewSummary: null,
        previewConflicts: [],

        sampleRows: [],
        sampleCount: 0,

        message: '',
        error: '',
      };
    },
    computed: {
      isActifTarget() {
        return this.targetStatus === 'ACTIF';
      },
      canPreview() {
        return this.listSelectedIds.length > 0;
      },
      currentSignature() {
        return JSON.stringify(this.buildPayload(false));
      },
      canApply() {
        return this.previewDone && this.previewSignature === this.currentSignature && this.previewTick === this.changeTick && !this.loading;
      },
      hasPreviewResult() {
        return this.previewDone && !!this.previewSummary;
      },
      applyDisabledReason() {
        if (this.loading) return 'Traitement en cours...';
        if (!this.previewDone) return 'Prévisualisation obligatoire avant application.';
        if (this.previewSignature !== this.currentSignature || this.previewTick !== this.changeTick) {
          return 'Le périmètre a changé. Clique à nouveau sur "Prévisualiser".';
        }
        return '';
      },
      stepBanner() {
        if (this.canApply) {
          return {
            text: 'Étape 2/2: prévisualisation valide. Tu peux appliquer.',
            style: 'font-size:12px;color:#1f7a3f;background:#ecfdf3;border:1px solid #abefc6;border-radius:6px;padding:8px;',
          };
        }
        return {
          text: 'Étape 1/2: clique sur "Prévisualiser" avant de pouvoir appliquer.',
          style: 'font-size:12px;color:#b42318;background:#fef3f2;border:1px solid #fecdca;border-radius:6px;padding:8px;',
        };
      },
    },
    methods: {
      markChanged() {
        this.changeTick += 1;
        this.resetPreview();
      },
      resetPreview() {
        this.previewDone = false;
        this.previewSignature = '';
        this.lastPreviewPayload = null;
        this.previewAt = '';
        this.previewTick = null;
        this.previewSummary = null;
        this.previewConflicts = [];
        this.sampleRows = [];
        this.sampleCount = 0;
      },
      async loadListRows() {
        this.listLoading = true;
        this.listRows = [];
        try {
          const fields = 'id,code,statut,societe_interne_id.id,societe_interne_id.code';
          const allRows = [];
          if (this.listSearch && this.listSearch.trim()) {
            const paramsSearch = new URLSearchParams({
              fields,
              limit: '100',
              sort: 'code',
              search: this.listSearch.trim(),
            });
            const resSearch = await fetch(`/items/baux?${paramsSearch.toString()}`, {
              method: 'GET',
              credentials: 'include',
              headers: { Accept: 'application/json' },
            });
            const payloadSearch = await resSearch.json();
            if (!resSearch.ok) throw new Error(payloadSearch?.errors?.[0]?.message || 'Impossible de charger la recherche.');
            allRows.push(...(Array.isArray(payloadSearch?.data) ? payloadSearch.data : []));
          }
          if (!(this.listSearch && this.listSearch.trim())) {
            const paramsDefault = new URLSearchParams({
              fields,
              limit: '100',
              sort: 'code',
            });
            const resDefault = await fetch(`/items/baux?${paramsDefault.toString()}`, {
              method: 'GET',
              credentials: 'include',
              headers: { Accept: 'application/json' },
            });
            const payloadDefault = await resDefault.json();
            if (!resDefault.ok) throw new Error(payloadDefault?.errors?.[0]?.message || 'Impossible de charger les baux accessibles.');
            allRows.push(...(Array.isArray(payloadDefault?.data) ? payloadDefault.data : []));
          }
          const dedup = new Map();
          for (const r of allRows) dedup.set(r.id, r);
          this.listRows = Array.from(dedup.values()).slice(0, 100);
          this.listSelectedIds = this.listSelectedIds.filter((id) => this.listRows.some((r) => r.id === id));
        } finally {
          this.listLoading = false;
        }
      },
      async refreshDisplayedListStatuses() {
        const ids = Array.isArray(this.listRows) ? this.listRows.map((r) => r.id).filter(Boolean) : [];
        if (ids.length === 0) return;
        const params = new URLSearchParams({
          fields: 'id,code,statut,societe_interne_id.id,societe_interne_id.code',
          limit: '-1',
          filter: JSON.stringify({ id: { _in: ids } }),
        });
        const res = await fetch(`/items/baux?${params.toString()}`, {
          method: 'GET',
          credentials: 'include',
          headers: { Accept: 'application/json' },
        });
        const payload = await res.json();
        if (!res.ok) throw new Error(payload?.errors?.[0]?.message || 'Impossible de rafraîchir la liste.');
        const byId = new Map((Array.isArray(payload?.data) ? payload.data : []).map((r) => [r.id, r]));
        this.listRows = this.listRows.map((r) => byId.get(r.id) || r);
      },
      selectAllVisibleRows() {
        this.listSelectedIds = this.listRows.map((r) => r.id);
      },
      clearAllVisibleRows() {
        this.listSelectedIds = [];
      },
      buildPayload(dryRun) {
        const sortedSelection = Array.isArray(this.listSelectedIds) ? [...this.listSelectedIds].sort() : [];
        return {
          target_status: this.targetStatus,
          dry_run: Boolean(dryRun),
          activation_conflict_mode: this.conflictMode,
          selection_ids: sortedSelection,
        };
      },
      async preview() {
        this.loading = true;
        this.error = '';
        this.message = '';
        this.resetPreview();

        try {
          if (!this.canPreview) throw new Error('Définis un périmètre avant prévisualisation.');
          if (this.listSelectedIds.length === 0) {
            throw new Error('Coche au moins un bail dans la liste.');
          }
          const selectedMap = new Map(this.listRows.map((r) => [r.id, r]));
          this.sampleRows = this.listSelectedIds.map((id) => selectedMap.get(id)).filter(Boolean).slice(0, 100);
          this.sampleCount = this.listSelectedIds.length;

          const body = this.buildPayload(true);
          const res = await fetch('/baux-bulk-status', {
            method: 'POST',
            credentials: 'include',
            headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
            body: JSON.stringify(body),
          });
          const payload = await res.json();
          if (!res.ok || !payload?.ok) throw new Error(payload?.error || `HTTP ${res.status}`);

          const report = payload.report || {};
          this.previewSummary = {
            targeted: Number(report.candidates || 0) + Number(report.already_target || 0),
            candidates: Number(report.candidates || 0),
            conflicts: Number(report.conflicts || 0),
            will_update: Number(report.updatable || 0),
            skipped: Number(report.skipped_conflicts || 0),
          };
          this.previewConflicts = Array.isArray(report.conflicts_detail) ? report.conflicts_detail : [];

          this.previewDone = true;
          this.previewSignature = this.currentSignature;
          this.lastPreviewPayload = body;
          this.previewAt = new Date().toLocaleString('fr-FR');
          this.previewTick = this.changeTick;
          this.message = 'Prévisualisation prête. Vérifie le résumé puis applique.';
        } catch (e) {
          this.error = e?.message || 'Prévisualisation impossible.';
        } finally {
          this.loading = false;
        }
      },
      async apply() {
        this.loading = true;
        this.error = '';
        this.message = '';

        try {
          if (!this.previewDone || !this.lastPreviewPayload) {
            throw new Error('Fais d\'abord une prévisualisation.');
          }
          if (this.previewSignature !== this.currentSignature) {
            throw new Error('Le périmètre a changé depuis la prévisualisation. Refaire "Prévisualiser".');
          }

          const body = this.buildPayload(false);
          const res = await fetch('/baux-bulk-status', {
            method: 'POST',
            credentials: 'include',
            headers: { 'Content-Type': 'application/json', Accept: 'application/json' },
            body: JSON.stringify(body),
          });
          const payload = await res.json();
          if (!res.ok || !payload?.ok) throw new Error(payload?.error || `HTTP ${res.status}`);

          const report = payload.report || {};
          this.message = `Appliqué: ${Number(report.updated || 0)} mise(s) à jour. Voir Journal actions (action = BULK_STATUT_BAUX).`;
          if (this.listRows.length > 0) {
            await this.refreshDisplayedListStatuses();
          }
          this.resetPreview();
        } catch (e) {
          this.error = e?.message || 'Application impossible.';
        } finally {
          this.loading = false;
        }
      },
    },
    watch: {
      targetStatus() { this.markChanged(); },
      conflictMode() { this.markChanged(); },
      listSearch() { this.markChanged(); },
      listSelectedIds() { this.markChanged(); },
    },
    mounted() {
      this.loadListRows().catch((e) => {
        this.error = e?.message || 'Impossible de charger la liste.';
      });
    },
    template: `
      <div style="display:grid;gap:12px;padding:10px;">

        <div style="border:1px solid #e5e7eb;border-radius:8px;padding:10px;display:grid;gap:8px;">
          <div style="font-weight:700;font-size:13px;">1) Périmètre</div>
          <div style="display:grid;gap:8px;">
            <label style="font-size:12px;">Recherche (optionnel) pour faciliter la sélection</label>
            <input v-model="listSearch" :disabled="loading" placeholder="ex: B-SOCIMMO1" style="padding:8px;border:1px solid #cfd4dc;border-radius:6px;" />
            <div style="display:flex;gap:8px;align-items:center;flex-wrap:wrap;">
              <button type="button" @click="loadListRows" :disabled="loading || listLoading" style="padding:8px 10px;border:1px solid #cfd4dc;border-radius:6px;font-weight:600;">Charger la liste</button>
              <button type="button" @click="selectAllVisibleRows" :disabled="loading || listLoading || listRows.length===0" style="padding:8px 10px;border:1px solid #cfd4dc;border-radius:6px;font-weight:600;">Tout cocher</button>
              <button type="button" @click="clearAllVisibleRows" :disabled="loading || listLoading || listSelectedIds.length===0" style="padding:8px 10px;border:1px solid #cfd4dc;border-radius:6px;font-weight:600;">Tout décocher</button>
              <span style="font-size:12px;color:#344054;">{{ listRows.length }} ligne(s) affichées (max 100)</span>
              <span style="font-size:12px;color:#344054;">{{ listSelectedIds.length }} coché(s)</span>
            </div>
            <div v-if="listRows.length > 0" style="max-height:220px;overflow:auto;border:1px solid #e5e7eb;border-radius:6px;">
              <table style="width:100%;border-collapse:collapse;font-size:12px;">
                <thead>
                  <tr>
                    <th style="text-align:left;padding:6px;border-bottom:1px solid #e5e7eb;">Choix</th>
                    <th style="text-align:left;padding:6px;border-bottom:1px solid #e5e7eb;">Code</th>
                    <th style="text-align:left;padding:6px;border-bottom:1px solid #e5e7eb;">Statut</th>
                    <th style="text-align:left;padding:6px;border-bottom:1px solid #e5e7eb;">Société</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="r in listRows" :key="r.id">
                    <td style="padding:6px;border-bottom:1px solid #f2f4f7;"><input type="checkbox" :value="r.id" v-model="listSelectedIds" /></td>
                    <td style="padding:6px;border-bottom:1px solid #f2f4f7;">{{ r.code }}</td>
                    <td style="padding:6px;border-bottom:1px solid #f2f4f7;">{{ r.statut }}</td>
                    <td style="padding:6px;border-bottom:1px solid #f2f4f7;">{{ (r.societe_interne_id && r.societe_interne_id.code) ? r.societe_interne_id.code : '' }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        </div>

        <div style="border:1px solid #e5e7eb;border-radius:8px;padding:10px;display:grid;gap:8px;">
          <div style="font-weight:700;font-size:13px;">2) Action</div>
          <div style="display:flex;gap:10px;align-items:center;flex-wrap:wrap;">
            <label style="font-size:12px;">Statut cible</label>
            <select v-model="targetStatus" :disabled="loading" style="padding:6px;border:1px solid #cfd4dc;border-radius:6px;">
              <option>BROUILLON</option>
              <option>ACTIF</option>
              <option>CLOS</option>
              <option>LITIGE</option>
            </select>

            <label style="font-size:12px;">Conflit -> ACTIF</label>
            <select v-model="conflictMode" :disabled="loading" style="padding:6px;border:1px solid #cfd4dc;border-radius:6px;">
              <option value="block">Bloquer la mise à jour</option>
              <option value="skip">Ignorer les baux en conflit</option>
            </select>
          </div>
          <div v-if="isActifTarget" style="font-size:12px;color:#b54708;">Attention: le passage vers ACTIF peut créer des conflits de chevauchement. Choisis un mode de gestion des conflits.</div>
        </div>

        <div style="border:1px solid #e5e7eb;border-radius:8px;padding:10px;display:grid;gap:8px;">
          <div style="font-weight:700;font-size:13px;">3) Prévisualiser / Appliquer</div>

          <div style="display:flex;gap:8px;flex-wrap:wrap;">
            <button type="button" @click="preview" :disabled="loading || !canPreview" style="padding:8px 10px;border:1px solid #cfd4dc;border-radius:6px;font-weight:600;">Prévisualiser</button>
            <button
              type="button"
              @click="apply"
              :disabled="!canApply"
              :title="canApply ? 'Appliquer le changement de statut' : applyDisabledReason"
              :style="'padding:8px 10px;border-radius:6px;font-weight:700;border:1px solid ' + (canApply ? '#1d4ed8' : '#cfd4dc') + ';background:' + (canApply ? '#1d4ed8' : '#f2f4f7') + ';color:' + (canApply ? '#ffffff' : '#667085') + ';cursor:' + (canApply ? 'pointer' : 'not-allowed') + ';'"
            >Appliquer</button>
          </div>

          <div :style="stepBanner.style">
            {{ stepBanner.text }}
          </div>

          <div v-if="!canApply" style="font-size:12px;color:#b42318;">
            {{ applyDisabledReason }}
          </div>

          <div v-if="hasPreviewResult && sampleCount>0" style="font-size:12px;color:#344054;">Aperçu périmètre: {{ sampleCount }} bail(x) ciblé(s) (affichage limité à {{ sampleRows.length }} lignes).</div>

          <div v-if="hasPreviewResult" style="font-size:12px;color:#1f7a3f;background:#ecfdf3;border:1px solid #abefc6;border-radius:6px;padding:8px;">
            Prévisualisation générée le {{ previewAt }}.
          </div>

          <div v-if="hasPreviewResult" style="display:grid;grid-template-columns:repeat(5,minmax(120px,1fr));gap:8px;font-size:12px;">
            <div><strong>Ciblés</strong><br/>{{ previewSummary.targeted }}</div>
            <div><strong>À traiter</strong><br/>{{ previewSummary.candidates }}</div>
            <div><strong>Conflits</strong><br/>{{ previewSummary.conflicts }}</div>
            <div><strong>Seront mis à jour</strong><br/>{{ previewSummary.will_update }}</div>
            <div><strong>Ignorés</strong><br/>{{ previewSummary.skipped }}</div>
          </div>

          <div v-if="hasPreviewResult && previewConflicts && previewConflicts.length>0" style="display:grid;gap:6px;">
            <div style="font-size:12px;font-weight:600;">Conflits détectés</div>
            <div style="max-height:220px;overflow:auto;border:1px solid #e5e7eb;border-radius:6px;">
              <table style="width:100%;border-collapse:collapse;font-size:12px;">
                <thead>
                  <tr>
                    <th style="text-align:left;padding:6px;border-bottom:1px solid #e5e7eb;">Bail</th>
                    <th style="text-align:left;padding:6px;border-bottom:1px solid #e5e7eb;">Lot</th>
                    <th style="text-align:left;padding:6px;border-bottom:1px solid #e5e7eb;">Détail</th>
                  </tr>
                </thead>
                <tbody>
                  <tr v-for="c in previewConflicts" :key="c.bail_id">
                    <td style="padding:6px;border-bottom:1px solid #f2f4f7;">{{ c.code || c.bail_id }}</td>
                    <td style="padding:6px;border-bottom:1px solid #f2f4f7;">{{ c.bien_id }}</td>
                    <td style="padding:6px;border-bottom:1px solid #f2f4f7;">{{ JSON.stringify(c.conflicts || []) }}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>

          <div v-if="listRows.length>0" style="font-size:12px;color:#344054;">Liste prête: {{ listSelectedIds.length }} sélectionné(s).</div>

          <div v-if="message" style="font-size:12px;color:#1f7a3f;">{{ message }}</div>
          <div v-if="error" style="font-size:12px;color:#b42318;">{{ error }}</div>
        </div>
      </div>
    `,
  },
});
