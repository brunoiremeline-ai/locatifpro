create or replace view v_relances_a_faire as
select
  e.echeance_id,
  e.societe_interne_id,
  e.bail_id,
  e.periode,
  e.date_echeance,
  e.statut,
  e.montant_total,
  e.total_alloue,
  e.reste_a_payer
from v_echeances_reste_a_payer e
where e.statut = 'FACTURE'
  and e.reste_a_payer > 0
  and e.date_echeance < current_date
order by e.date_echeance, e.periode;
