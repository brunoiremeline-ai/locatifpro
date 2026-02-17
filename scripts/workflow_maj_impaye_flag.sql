-- Workflow: maj impaye_flag sur echeances FACTURE (idempotent)

WITH reste AS (
  SELECT
    e.id AS echeance_id,
    (e.montant_total - COALESCE(sum(pa.montant_alloue), 0)) AS reste_a_payer
  FROM echeances e
  LEFT JOIN paiement_allocations pa ON pa.echeance_id = e.id
  GROUP BY e.id
),
updated AS (
  UPDATE echeances e
  SET impaye_flag = (
    e.statut = 'FACTURE'::echeance_statut_enum
    AND e.date_echeance < current_date
    AND COALESCE(r.reste_a_payer, e.montant_total) > 0
  )
  FROM reste r
  WHERE r.echeance_id = e.id
  RETURNING e.id, e.statut, e.date_echeance, r.reste_a_payer, e.impaye_flag
)
SELECT
  count(*) FILTER (WHERE u.statut = 'FACTURE'::echeance_statut_enum) AS total_facture,
  count(*) FILTER (WHERE u.impaye_flag) AS impayes
FROM updated u;
