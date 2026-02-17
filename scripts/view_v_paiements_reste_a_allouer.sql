create or replace view v_paiements_reste_a_allouer as
select
  p.id as paiement_id,
  p.societe_interne_id,
  p.reference_paiement,
  p.date_paiement,
  p.montant,
  coalesce(sum(pa.montant_alloue),0) as total_alloue,
  (p.montant - coalesce(sum(pa.montant_alloue),0)) as reste_a_allouer
from paiements p
left join paiement_allocations pa on pa.paiement_id = p.id
group by p.id;
