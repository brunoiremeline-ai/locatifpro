import { definePanel } from '@directus/extensions-sdk';

export default definePanel({
  id: 'refresh-dash-button',
  name: 'Refresh Dashboard',
  icon: 'sync',
  description: 'Run refresh-dash and show the latest counts.',
  minWidth: 12,
  minHeight: 10,
  component: {
    data() {
      return {
        loading: false,
        message: '',
        error: '',
        result: null,
      };
    },
    methods: {
      async runRefresh() {
        this.loading = true;
        this.error = '';
        this.message = '';

        try {
          const response = await fetch('/refresh-dash', {
            method: 'GET',
            credentials: 'include',
            headers: { Accept: 'application/json' },
          });

          let payload = null;
          try {
            payload = await response.json();
          } catch (_) {
            payload = null;
          }

          if (!response.ok) {
            const reason = payload?.error || `HTTP ${response.status}`;
            throw new Error(reason);
          }

          this.result = payload;
          this.message = `Refresh OK at ${payload?.at || 'unknown time'}`;
        } catch (error) {
          this.error = error?.message || String(error);
        } finally {
          this.loading = false;
        }
      },
    },
    template: `
      <div style="padding: 12px; display: grid; gap: 10px;">
        <button
          type="button"
          @click="runRefresh"
          :disabled="loading"
          style="padding: 10px 12px; border: 1px solid #cfd4dc; border-radius: 8px; cursor: pointer; font-weight: 600;"
        >
          {{ loading ? 'Actualisation en cours...' : 'Actualiser maintenant' }}
        </button>

        <div v-if="message" style="color: #1f7a3f; font-size: 13px;">
          {{ message }}
        </div>
        <div v-if="error" style="color: #b42318; font-size: 13px;">
          Erreur: {{ error }}
        </div>

        <pre
          v-if="result"
          style="margin: 0; padding: 10px; border: 1px solid #e5e7eb; border-radius: 8px; max-height: 260px; overflow: auto; font-size: 12px;"
        >{{ JSON.stringify(result, null, 2) }}</pre>
      </div>
    `,
  },
});
