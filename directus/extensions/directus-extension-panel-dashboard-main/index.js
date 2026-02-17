import { definePanel } from '@directus/extensions-sdk';

export default definePanel({
  id: 'dashboard-main-overview',
  name: 'Dashboard Main Overview',
  icon: 'dashboard',
  description: 'Display KPI and relance tables from dash_* collections.',
  minWidth: 16,
  minHeight: 12,
  component: {
    data() {
      return {
        loading: false,
        error: '',
        kpi: [],
        relancesFaire: [],
        relancesBientot: [],
      };
    },
    mounted() {
      this.load();
    },
    methods: {
      async fetchItems(collection, limit = 10, sort = '') {
        const url = new URL(`/items/${collection}`, window.location.origin);
        url.searchParams.set('limit', String(limit));
        if (sort) url.searchParams.set('sort', sort);

        const response = await fetch(url.toString(), {
          method: 'GET',
          credentials: 'include',
          headers: { Accept: 'application/json' },
        });

        const payload = await response.json();
        if (!response.ok) {
          throw new Error(payload?.errors?.[0]?.message || payload?.error || `HTTP ${response.status}`);
        }

        return payload?.data || [];
      },
      async load() {
        this.loading = true;
        this.error = '';
        try {
          const [kpi, relancesFaire, relancesBientot] = await Promise.all([
            this.fetchItems('dash_kpi_societe', 100, 'kpi'),
            this.fetchItems('dash_relances_a_faire', 10, '-date_echeance'),
            this.fetchItems('dash_relances_bientot', 10, 'date_echeance'),
          ]);

          this.kpi = kpi;
          this.relancesFaire = relancesFaire;
          this.relancesBientot = relancesBientot;
        } catch (error) {
          this.error = error?.message || String(error);
        } finally {
          this.loading = false;
        }
      },
      fmt(v) {
        return v == null ? '-' : String(v);
      },
    },
    template: `
      <div style="padding: 12px; display: grid; gap: 12px;">
        <div style="display: flex; justify-content: space-between; align-items: center;">
          <strong>Dashboard Principal</strong>
          <button type="button" @click="load" :disabled="loading" style="padding: 6px 10px; border: 1px solid #cfd4dc; border-radius: 6px; cursor: pointer;">
            {{ loading ? 'Chargement...' : 'Rafraîchir la vue' }}
          </button>
        </div>

        <div v-if="error" style="color: #b42318; font-size: 13px;">Erreur: {{ error }}</div>

        <div>
          <div style="font-weight: 600; margin-bottom: 6px;">KPI (dash_kpi_societe)</div>
          <table style="width: 100%; border-collapse: collapse; font-size: 12px;">
            <thead>
              <tr>
                <th style="text-align: left; border-bottom: 1px solid #e5e7eb; padding: 4px;">KPI</th>
                <th style="text-align: right; border-bottom: 1px solid #e5e7eb; padding: 4px;">NB</th>
                <th style="text-align: right; border-bottom: 1px solid #e5e7eb; padding: 4px;">Montant</th>
              </tr>
            </thead>
            <tbody>
              <tr v-for="row in kpi" :key="row.id">
                <td style="padding: 4px; border-bottom: 1px solid #f1f3f5;">{{ fmt(row.kpi) }}</td>
                <td style="padding: 4px; text-align: right; border-bottom: 1px solid #f1f3f5;">{{ fmt(row.nb) }}</td>
                <td style="padding: 4px; text-align: right; border-bottom: 1px solid #f1f3f5;">{{ fmt(row.montant) }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div>
          <div style="font-weight: 600; margin-bottom: 6px;">Relances à faire (dash_relances_a_faire)</div>
          <div style="font-size: 12px;">{{ relancesFaire.length }} ligne(s)</div>
        </div>

        <div>
          <div style="font-weight: 600; margin-bottom: 6px;">Relances bientôt (dash_relances_bientot)</div>
          <div style="font-size: 12px;">{{ relancesBientot.length }} ligne(s)</div>
        </div>
      </div>
    `,
  },
});
