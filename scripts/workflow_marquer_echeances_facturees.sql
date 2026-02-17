-- Workflow: marquer les echeances en FACTURE (idempotent)
-- Usage (psql): -v as_of_date=YYYY-MM-DD -v bail_id=UUID -v societe_interne_id=UUID

\if :{?as_of_date}
\else
\set as_of_date ''
\endif
\if :{?bail_id}
\else
\set bail_id ''
\endif
\if :{?societe_interne_id}
\else
\set societe_interne_id ''
\endif

WITH params AS (
  SELECT
    COALESCE(NULLIF(:'as_of_date','')::date, current_date) AS as_of_date,
    NULLIF(:'bail_id','')::uuid AS bail_id,
    NULLIF(:'societe_interne_id','')::uuid AS societe_interne_id
),
updated AS (
  UPDATE echeances e
  SET statut = 'FACTURE'::echeance_statut_enum
  FROM params p
  WHERE e.statut = 'PREVISIONNEL'::echeance_statut_enum
    AND e.date_echeance <= p.as_of_date
    AND (p.bail_id IS NULL OR e.bail_id = p.bail_id)
    AND (p.societe_interne_id IS NULL OR e.societe_interne_id = p.societe_interne_id)
  RETURNING e.id
)
SELECT count(*) AS updated_count FROM updated;
