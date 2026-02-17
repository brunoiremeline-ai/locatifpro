create or replace view v_kpi_societe as
with base_soc as (
  select distinct societe_interne_id from echeances
  union
  select distinct societe_interne_id from paiements
),
kpi_list as (
  select * from (
    values
      ('RESTE_A_PAYER_FACTURE'),
      ('RELANCES_A_FAIRE'),
      ('RELANCES_BIENTOT'),
      ('PAIEMENTS_EN_AVANCE')
  ) as t(kpi)
),
agg_reste_a_payer as (
  select
    societe_interne_id,
    count(*) as nb,
    coalesce(sum(reste_a_payer),0) as montant
  from v_echeances_reste_a_payer
  where statut = 'FACTURE'
    and reste_a_payer > 0
  group by societe_interne_id
),
agg_relances as (
  select
    societe_interne_id,
    count(*) as nb,
    coalesce(sum(reste_a_payer),0) as montant
  from v_relances_a_faire
  group by societe_interne_id
),
agg_relances_bientot as (
  select
    societe_interne_id,
    count(*) as nb,
    coalesce(sum(reste_a_payer),0) as montant
  from v_relances_bientot
  group by societe_interne_id
),
agg_paiements_en_avance as (
  select
    societe_interne_id,
    count(*) as nb,
    coalesce(sum(reste_a_allouer),0) as montant
  from v_paiements_en_avance
  group by societe_interne_id
)
select
  b.societe_interne_id,
  k.kpi,
  coalesce(ar.nb, al.nb, ab.nb, ap.nb, 0) as nb,
  coalesce(ar.montant, al.montant, ab.montant, ap.montant, 0) as montant,
  md5(coalesce(b.societe_interne_id::text,'') || '|' || coalesce(k.kpi::text,'')) as id
from base_soc b
cross join kpi_list k
left join agg_reste_a_payer ar
  on ar.societe_interne_id = b.societe_interne_id
  and k.kpi = 'RESTE_A_PAYER_FACTURE'
left join agg_relances al
  on al.societe_interne_id = b.societe_interne_id
  and k.kpi = 'RELANCES_A_FAIRE'
left join agg_relances_bientot ab
  on ab.societe_interne_id = b.societe_interne_id
  and k.kpi = 'RELANCES_BIENTOT'
left join agg_paiements_en_avance ap
  on ap.societe_interne_id = b.societe_interne_id
  and k.kpi = 'PAIEMENTS_EN_AVANCE';
