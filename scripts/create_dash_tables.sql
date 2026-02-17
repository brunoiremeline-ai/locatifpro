-- Ensure dashboard cache tables exist for the Directus refresh-dash endpoint.
-- Safe to run multiple times.

CREATE TABLE IF NOT EXISTS dash_kpi_societe (
  societe_interne_id uuid,
  kpi text NOT NULL,
  nb bigint NOT NULL DEFAULT 0,
  montant numeric NOT NULL DEFAULT 0,
  id text PRIMARY KEY
);
CREATE INDEX IF NOT EXISTS ix_dash_kpi_societe_societe ON dash_kpi_societe(societe_interne_id);
CREATE INDEX IF NOT EXISTS ix_dash_kpi_societe_kpi ON dash_kpi_societe(kpi);

CREATE TABLE IF NOT EXISTS dash_relances_a_faire (
  echeance_id uuid PRIMARY KEY,
  societe_interne_id uuid,
  bail_id uuid,
  periode text,
  date_echeance date,
  statut echeance_statut_enum,
  montant_total numeric,
  total_alloue numeric,
  reste_a_payer numeric
);
CREATE INDEX IF NOT EXISTS ix_dash_relances_a_faire_societe ON dash_relances_a_faire(societe_interne_id);
CREATE INDEX IF NOT EXISTS ix_dash_relances_a_faire_date ON dash_relances_a_faire(date_echeance);

CREATE TABLE IF NOT EXISTS dash_relances_bientot (
  echeance_id uuid PRIMARY KEY,
  societe_interne_id uuid,
  bail_id uuid,
  periode text,
  date_echeance date,
  statut echeance_statut_enum,
  montant_total numeric,
  total_alloue numeric,
  reste_a_payer numeric,
  jours_avant_echeance integer
);
CREATE INDEX IF NOT EXISTS ix_dash_relances_bientot_societe ON dash_relances_bientot(societe_interne_id);
CREATE INDEX IF NOT EXISTS ix_dash_relances_bientot_date ON dash_relances_bientot(date_echeance);
