create or replace view v_paiements_en_avance as
with open_factures as (
  select
    societe_interne_id,
    count(*) as nb_factures_ouvertes,
    coalesce(sum(reste_a_payer),0) as total_reste_factures
  from v_echeances_reste_a_payer
  where statut = 'FACTURE'
    and reste_a_payer > 0
  group by societe_interne_id
)
select
  p.paiement_id,
  p.societe_interne_id,
  p.reference_paiement,
  p.date_paiement,
  p.montant,
  p.total_alloue,
  p.reste_a_allouer,
  coalesce(o.nb_factures_ouvertes,0) as nb_factures_ouvertes,
  coalesce(o.total_reste_factures,0) as total_reste_factures
from v_paiements_reste_a_allouer p
left join open_factures o on o.societe_interne_id = p.societe_interne_id
where p.reste_a_allouer > 0
  and coalesce(o.nb_factures_ouvertes,0) = 0;
