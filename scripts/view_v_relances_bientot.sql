create or replace view v_relances_bientot as
select
  e.echeance_id,
  e.societe_interne_id,
  e.bail_id,
  e.periode,
  e.date_echeance,
  e.statut,
  e.montant_total,
  e.total_alloue,
  e.reste_a_payer,
  (e.date_echeance - current_date) as jours_avant_echeance
from v_echeances_reste_a_payer e
where e.statut = 'FACTURE'::echeance_statut_enum
  and e.reste_a_payer > 0
  and e.date_echeance >= current_date
  and e.date_echeance < (current_date + 30);
