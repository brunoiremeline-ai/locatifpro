-- Source of truth: fonction SQL unique pour generation idempotente des echeances
-- Retourne un rapport created/skipped.

CREATE OR REPLACE FUNCTION public.workflow_generate_echeances(
  p_bail_id uuid DEFAULT NULL,
  p_start_date date DEFAULT NULL,
  p_end_date date DEFAULT NULL,
  p_start_period text DEFAULT NULL,
  p_periods int DEFAULT 12,
  p_include_start text DEFAULT 'true',
  p_mode text DEFAULT 'skip'
)
RETURNS TABLE (
  bail_id uuid,
  mode text,
  include_start boolean,
  candidates int,
  created int,
  skipped_existing int
)
LANGUAGE sql
AS $$
WITH params AS (
  SELECT
    p_bail_id AS bail_id,
    COALESCE(p_start_date, date_trunc('month', current_date)::date) AS start_date,
    COALESCE(p_end_date, (date_trunc('month', current_date)::date + interval '12 months' - interval '1 day')::date) AS end_date,
    CASE
      WHEN p_start_period IS NULL OR btrim(p_start_period) = '' THEN NULL::date
      WHEN p_start_period ~ '^\\d{4}-\\d{2}$' THEN to_date(p_start_period || '-01', 'YYYY-MM-DD')
      ELSE NULL::date
    END AS start_period_date,
    LEAST(GREATEST(COALESCE(p_periods, 12), 1), 60) AS periods,
    CASE
      WHEN lower(COALESCE(NULLIF(btrim(p_include_start), ''), 'true')) IN ('1','true','t','yes','y','oui','o') THEN true
      ELSE false
    END AS include_start,
    COALESCE(NULLIF(btrim(p_mode), ''), 'skip') AS mode
),
target_baux AS (
  SELECT
    b.*,
    CASE b.periodicite
      WHEN 'MENSUEL' THEN interval '1 month'
      WHEN 'TRIMESTRIEL' THEN interval '3 months'
      WHEN 'ANNUEL' THEN interval '12 months'
      ELSE interval '1 month'
    END AS periode_interval
  FROM baux b
  CROSS JOIN params p
  WHERE b.statut = 'ACTIF'
    AND (p.bail_id IS NULL OR b.id = p.bail_id)
),
global_window AS (
  SELECT
    date_trunc('month', start_date)::date AS window_start,
    date_trunc('month', end_date)::date AS window_end
  FROM params
),
series_global AS (
  SELECT
    b.id AS bail_id,
    b.societe_interne_id,
    b.date_effet,
    b.date_fin_contractuelle,
    b.date_exigibilite_jour,
    b.loyer_base,
    b.charges_mode,
    b.charges_provision,
    b.tf_refacturable,
    b.tf_provision,
    b.periode_interval,
    gs::date AS periode_start
  FROM target_baux b
  CROSS JOIN global_window w
  CROSS JOIN params p
  CROSS JOIN LATERAL generate_series(
    date_trunc('month', b.date_effet)::date,
    LEAST(COALESCE(b.date_fin_contractuelle, w.window_end), w.window_end),
    b.periode_interval
  ) AS gs
  WHERE p.bail_id IS NULL
    AND gs::date BETWEEN w.window_start AND w.window_end
),
series_bail AS (
  SELECT
    b.id AS bail_id,
    b.societe_interne_id,
    b.date_effet,
    b.date_fin_contractuelle,
    b.date_exigibilite_jour,
    b.loyer_base,
    b.charges_mode,
    b.charges_provision,
    b.tf_refacturable,
    b.tf_provision,
    b.periode_interval,
    (
      date_trunc('month', COALESCE(p.start_period_date, b.date_effet))::date
      + (n.n * b.periode_interval)
    )::date AS periode_start
  FROM target_baux b
  CROSS JOIN params p
  CROSS JOIN LATERAL generate_series(
    CASE WHEN p.include_start THEN 0 ELSE 1 END,
    CASE WHEN p.include_start THEN p.periods - 1 ELSE p.periods END
  ) AS n(n)
  WHERE p.bail_id IS NOT NULL
),
series AS (
  SELECT * FROM series_global
  UNION ALL
  SELECT * FROM series_bail
),
computed AS (
  SELECT
    s.bail_id,
    s.societe_interne_id,
    to_char(s.periode_start, 'YYYY-MM') AS periode,
    s.periode_start AS date_debut_periode,
    (s.periode_start + s.periode_interval - interval '1 day')::date AS date_fin_periode,
    (
      date_trunc('month', s.periode_start)::date
      + (
          LEAST(
            COALESCE(s.date_exigibilite_jour, EXTRACT(day FROM s.date_effet)::int),
            EXTRACT(day FROM (date_trunc('month', s.periode_start) + interval '1 month - 1 day'))::int
          ) - 1
        ) * interval '1 day'
    )::date AS date_echeance,
    s.loyer_base AS montant_loyer,
    CASE
      WHEN s.charges_mode IS NULL OR s.charges_mode = 'AUCUNE' THEN 0
      ELSE COALESCE(s.charges_provision, 0)
    END AS montant_charges,
    CASE
      WHEN s.tf_refacturable THEN COALESCE(s.tf_provision, 0)
      ELSE 0
    END AS montant_taxe_fonciere_refacturee
  FROM series s
),
filtered AS (
  SELECT c.*
  FROM computed c
  CROSS JOIN params p
  WHERE
    (p.bail_id IS NOT NULL OR (
      c.date_fin_periode >= p.start_date
      AND c.date_debut_periode <= p.end_date
    ))
    AND (c.date_debut_periode >= (SELECT date_trunc('month', date_effet)::date FROM baux WHERE id = c.bail_id))
    AND (
      (SELECT date_fin_contractuelle FROM baux WHERE id = c.bail_id) IS NULL
      OR c.date_debut_periode <= (SELECT date_fin_contractuelle FROM baux WHERE id = c.bail_id)
    )
),
to_insert AS (
  SELECT DISTINCT
    f.bail_id,
    f.societe_interne_id,
    f.periode,
    f.date_debut_periode,
    f.date_fin_periode,
    f.date_echeance,
    f.montant_loyer,
    f.montant_charges,
    f.montant_taxe_fonciere_refacturee,
    'PREVISIONNEL'::echeance_statut_enum AS statut
  FROM filtered f
),
inserted AS (
  INSERT INTO echeances (
    bail_id,
    societe_interne_id,
    periode,
    date_debut_periode,
    date_fin_periode,
    date_echeance,
    montant_loyer,
    montant_charges,
    montant_taxe_fonciere_refacturee,
    statut
  )
  SELECT
    t.bail_id,
    t.societe_interne_id,
    t.periode,
    t.date_debut_periode,
    t.date_fin_periode,
    t.date_echeance,
    t.montant_loyer,
    t.montant_charges,
    t.montant_taxe_fonciere_refacturee,
    t.statut
  FROM to_insert t
  ON CONFLICT (bail_id, periode) DO NOTHING
  RETURNING bail_id, periode
)
SELECT
  p.bail_id,
  p.mode,
  p.include_start,
  COUNT(*) FILTER (WHERE ti.bail_id IS NOT NULL)::int AS candidates,
  (SELECT COUNT(*)::int FROM inserted) AS created,
  (COUNT(*) FILTER (WHERE ti.bail_id IS NOT NULL)::int - (SELECT COUNT(*)::int FROM inserted)) AS skipped_existing
FROM params p
LEFT JOIN to_insert ti ON TRUE
GROUP BY p.bail_id, p.mode, p.include_start;
$$;
