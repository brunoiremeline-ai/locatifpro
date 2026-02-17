-- Check paiement by reference
-- Usage (psql): -v ref=REFERENCE_PAIEMENT

\echo '== Paiement summary =='
WITH params AS (
  SELECT :'ref'::text AS ref
),
paie AS (
  SELECT p.*
  FROM paiements p
  JOIN params prm ON p.reference_paiement = prm.ref
),
allocs AS (
  SELECT pa.paiement_id, COALESCE(sum(pa.montant_alloue), 0) AS total_alloue
  FROM paiement_allocations pa
  GROUP BY pa.paiement_id
)
SELECT
  p.id AS paiement_id,
  p.reference_paiement,
  p.montant,
  COALESCE(a.total_alloue, 0) AS total_alloue,
  (p.montant - COALESCE(a.total_alloue, 0)) AS reste_a_allouer,
  p.societe_interne_id AS societe_id
FROM paie p
LEFT JOIN allocs a ON a.paiement_id = p.id
ORDER BY p.date_paiement, p.id;

\echo '== Allocations detail =='
WITH params AS (
  SELECT :'ref'::text AS ref
),
paie AS (
  SELECT p.*
  FROM paiements p
  JOIN params prm ON p.reference_paiement = prm.ref
)
SELECT
  p.id AS paiement_id,
  p.reference_paiement,
  p.societe_interne_id AS paiement_societe_id,
  pa.echeance_id,
  e.societe_interne_id AS echeance_societe_id,
  CASE WHEN p.societe_interne_id <> e.societe_interne_id THEN 'MISMATCH' ELSE '' END AS check_soc,
  e.periode,
  e.date_echeance,
  e.montant_total,
  pa.montant_alloue
FROM paie p
JOIN paiement_allocations pa ON pa.paiement_id = p.id
JOIN echeances e ON e.id = pa.echeance_id
ORDER BY p.id, e.date_echeance, e.id;

\echo '== Echeances societe =='
WITH params AS (
  SELECT :'ref'::text AS ref
),
paie_soc AS (
  SELECT DISTINCT p.societe_interne_id
  FROM paiements p
  JOIN params prm ON p.reference_paiement = prm.ref
),
allocs AS (
  SELECT pa.echeance_id, COALESCE(sum(pa.montant_alloue), 0) AS total_alloue
  FROM paiement_allocations pa
  GROUP BY pa.echeance_id
)
SELECT
  e.societe_interne_id AS societe_id,
  e.id AS echeance_id,
  e.periode,
  e.date_echeance,
  e.statut,
  e.montant_total,
  (e.montant_total - COALESCE(a.total_alloue, 0)) AS reste_a_payer
FROM echeances e
JOIN paie_soc ps ON ps.societe_interne_id = e.societe_interne_id
LEFT JOIN allocs a ON a.echeance_id = e.id
ORDER BY e.societe_interne_id, e.date_echeance, e.id;

\echo '== Vue reste à payer (FACTURE seulement) =='
select periode, date_echeance, statut, montant_total, total_alloue, reste_a_payer
from v_echeances_reste_a_payer
where societe_interne_id = (select societe_interne_id from paiements where reference_paiement = :'ref' order by date_paiement desc limit 1)
  and statut = 'FACTURE'
order by date_echeance;
