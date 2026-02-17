function registerRefreshDash(router, { database, logger }) {
  const TABLES = [
    'dash_kpi_societe',
    'dash_relances_a_faire',
    'dash_relances_bientot',
  ];

  async function countTable(knex, table) {
    const row = await knex
      .withSchema('public')
      .from(table)
      .count('* as c')
      .first();
    const c = row && (row.c ?? row.count);
    const n = Number(c);
    return Number.isFinite(n) ? n : 0;
  }

  router.get('/', async (req, res) => {
    const at = new Date().toISOString();

    if (!req?.accountability?.user && !req?.accountability?.admin) {
      return res.status(401).json({ ok: false, error: 'Unauthorized', at });
    }

    try {
      const before = {};
      for (const t of TABLES) before[t] = await countTable(database, t);

      await database.transaction(async (trx) => {
        await trx.raw(
          'TRUNCATE TABLE public.dash_kpi_societe, public.dash_relances_a_faire, public.dash_relances_bientot;'
        );
        await trx.raw('INSERT INTO public.dash_kpi_societe SELECT * FROM public.v_kpi_societe;');
        await trx.raw('INSERT INTO public.dash_relances_a_faire SELECT * FROM public.v_relances_a_faire;');
        await trx.raw('INSERT INTO public.dash_relances_bientot SELECT * FROM public.v_relances_bientot;');
      });

      const after = {};
      for (const t of TABLES) after[t] = await countTable(database, t);

      res.json({ ok: true, before, after, at });
    } catch (err) {
      try { logger?.error?.(err); } catch (_) {}
      res.status(500).json({ ok: false, error: String(err?.message || err), at });
    }
  });
}

module.exports = {
  id: 'refresh-dash',
  handler: registerRefreshDash,
};
