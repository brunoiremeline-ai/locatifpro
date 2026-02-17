-- Workflow: rapprocher un paiement sur des echeances FACTURE (idempotent)
-- Usage (psql): -v paiement_id=UUID -v societe_id=UUID -v tolerance=1


WITH params AS (
  SELECT
    NULLIF(:'paiement_id','')::uuid AS paiement_id,
    NULLIF(:'societe_id','')::uuid AS societe_id,
    COALESCE(NULLIF(:'tolerance','')::numeric, 1) AS tolerance
),
paie AS (
  SELECT
    p.*, COALESCE(prm.societe_id, p.societe_interne_id) AS target_societe
  FROM paiements p
  JOIN params prm ON prm.paiement_id = p.id
),
allocated_before AS (
  SELECT COALESCE(sum(pa.montant_alloue), 0) AS allocated
  FROM paiement_allocations pa
  JOIN params prm ON prm.paiement_id = pa.paiement_id
),
payment_remaining AS (
  SELECT (p.montant - a.allocated) AS remaining, p.id AS paiement_id, p.target_societe
  FROM paie p
  CROSS JOIN allocated_before a
),
eligible AS (
  SELECT
    e.id,
    e.date_echeance,
    e.montant_total,
    e.societe_interne_id,
    (e.montant_total - COALESCE(sum(pa2.montant_alloue), 0)) AS remaining_due
  FROM echeances e
  JOIN paie p ON p.target_societe = e.societe_interne_id
  LEFT JOIN paiement_allocations pa2 ON pa2.echeance_id = e.id
  WHERE e.statut = 'FACTURE'::echeance_statut_enum
  GROUP BY e.id
  HAVING (e.montant_total - COALESCE(sum(pa2.montant_alloue), 0)) > 0
),
ordered AS (
  SELECT
    e.*, pr.remaining AS payment_remaining,
    sum(e.remaining_due) OVER (ORDER BY e.date_echeance, e.id) AS cum_due
  FROM eligible e
  CROSS JOIN payment_remaining pr
),
allocations_to_apply AS (
  SELECT
    o.id AS echeance_id,
    o.payment_remaining,
    GREATEST(
      LEAST(
        o.remaining_due,
        o.payment_remaining - (o.cum_due - o.remaining_due)
      ),
      0
    ) AS allocation_amount
  FROM ordered o
),
upserted AS MATERIALIZED (
  INSERT INTO paiement_allocations (paiement_id, echeance_id, montant_alloue)
  SELECT
    pr.paiement_id,
    a.echeance_id,
    a.allocation_amount
  FROM allocations_to_apply a
  CROSS JOIN payment_remaining pr
  WHERE a.allocation_amount > 0
  ON CONFLICT (paiement_id, echeance_id)
  DO UPDATE SET montant_alloue = paiement_allocations.montant_alloue + EXCLUDED.montant_alloue
  RETURNING 1
),
allocations_added AS (
  SELECT a.echeance_id, sum(a.allocation_amount) AS allocated_now
  FROM allocations_to_apply a
  WHERE a.allocation_amount > 0
  GROUP BY a.echeance_id
),
updated_payees AS (
  UPDATE echeances e
  SET statut = 'PAYE'::echeance_statut_enum
  WHERE e.statut = 'FACTURE'::echeance_statut_enum
    AND e.societe_interne_id = (SELECT target_societe FROM paie)
    AND e.id IN (
      SELECT e2.id
      FROM echeances e2
      LEFT JOIN paiement_allocations pa ON pa.echeance_id = e2.id
      LEFT JOIN allocations_added aa ON aa.echeance_id = e2.id
      GROUP BY e2.id
      HAVING COALESCE(sum(pa.montant_alloue), 0) + COALESCE(max(aa.allocated_now), 0) >= e2.montant_total - (SELECT tolerance FROM params)
    )
  RETURNING 1
),
remaining_after AS (
  SELECT (pr.remaining - COALESCE(sum(a.allocation_amount), 0)) AS remaining
  FROM payment_remaining pr
  LEFT JOIN allocations_to_apply a ON a.allocation_amount > 0
  GROUP BY pr.remaining
)
SELECT
  (SELECT remaining FROM remaining_after) AS paiement_restant,
  (SELECT count(*) FROM upserted) AS allocations_upserted,
  (SELECT count(*) FROM updated_payees) AS echeances_passees_payees;
