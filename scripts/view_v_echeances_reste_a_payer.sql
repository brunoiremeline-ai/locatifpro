create or replace view v_echeances_reste_a_payer as
select
  e.id as echeance_id,
  e.societe_interne_id,
  e.bail_id,
  e.periode,
  e.date_echeance,
  e.statut,
  e.montant_total,
  coalesce(sum(pa.montant_alloue),0) as total_alloue,
  (e.montant_total - coalesce(sum(pa.montant_alloue),0)) as reste_a_payer
from echeances e
left join paiement_allocations pa on pa.echeance_id = e.id
group by e.id;
