import { defineInterface } from '@directus/extensions-sdk';

export default defineInterface({
  id: 'generate-echeances-action',
  name: 'Generer Echeances',
  icon: 'event_repeat',
  description: 'Genere des echeances previsionnelles pour le bail courant.',
  types: ['alias'],
  localTypes: ['presentation'],
  group: 'presentation',
  component: {
    props: {
      primaryKey: {
        type: [String, Number],
        default: null,
      },
      disabled: {
        type: Boolean,
        default: false,
      },
    },
    data() {
      return {
        loading: false,
        startPeriod: '',
        periods: 12,
        includeStart: true,
        message: '',
        error: '',
        report: null,
      };
    },
    methods: {
      async generate() {
        if (!this.primaryKey) {
          this.error = 'Enregistre d\'abord le bail avant de generer.';
          return;
        }

        this.loading = true;
        this.error = '';
        this.message = '';

        try {
          const response = await fetch('/generate-echeances', {
            method: 'POST',
            credentials: 'include',
            headers: {
              'Content-Type': 'application/json',
              Accept: 'application/json',
            },
            body: JSON.stringify({
              bail_id: this.primaryKey,
              start_period: this.startPeriod || undefined,
              periods: Number(this.periods) || 12,
              include_start: Boolean(this.includeStart),
              mode: 'skip',
            }),
          });

          const payload = await response.json();
          if (!response.ok || !payload?.ok) {
            throw new Error(payload?.error || `HTTP ${response.status}`);
          }

          this.report = payload.report || null;
          const created = this.report?.created ?? 0;
          const skipped = this.report?.skipped_existing ?? 0;
          this.message = `Generation OK: ${created} creees, ${skipped} deja existantes.`;
        } catch (err) {
          this.error = err?.message || String(err);
        } finally {
          this.loading = false;
        }
      },
    },
    template: `
      <div style="display:grid;gap:8px;padding:10px;border:1px solid #e5e7eb;border-radius:8px;">
        <div style="font-weight:600;">Generer echeances</div>

        <label style="display:grid;gap:4px;font-size:12px;">
          Periode depart (AAAA-MM, optionnel)
          <input v-model="startPeriod" type="text" placeholder="ex: 2026-03" :disabled="loading || disabled" style="padding:6px 8px;border:1px solid #cfd4dc;border-radius:6px;" />
        </label>

        <label style="display:grid;gap:4px;font-size:12px;">
          Nombre de periodes
          <input v-model.number="periods" type="number" min="1" max="60" :disabled="loading || disabled" style="padding:6px 8px;border:1px solid #cfd4dc;border-radius:6px;" />
        </label>

        <label style="display:flex;gap:8px;align-items:center;font-size:12px;">
          <input v-model="includeStart" type="checkbox" :disabled="loading || disabled" />
          Inclure la periode de depart
        </label>

        <button
          type="button"
          @click="generate"
          :disabled="loading || disabled || !primaryKey"
          style="padding:8px 10px;border:1px solid #cfd4dc;border-radius:8px;cursor:pointer;font-weight:600;"
        >
          {{ loading ? 'Generation...' : 'Generer echeances' }}
        </button>

        <div v-if="message" style="color:#1f7a3f;font-size:12px;">{{ message }}</div>
        <div v-if="error" style="color:#b42318;font-size:12px;">Erreur: {{ error }}</div>

        <pre v-if="report" style="margin:0;padding:8px;border:1px solid #e5e7eb;border-radius:8px;font-size:11px;max-height:160px;overflow:auto;">{{ JSON.stringify(report, null, 2) }}</pre>
      </div>
    `,
  },
});
