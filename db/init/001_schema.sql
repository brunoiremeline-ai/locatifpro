-- LocatifPro (V2) - Schema PostgreSQL
-- Basé sur le dictionnaire de données V2 + règles (pas de chevauchement de baux actifs par lot, anti-doublons, etc.)
-- IMPORTANT: valeurs des enums = codes ASCII (pour éviter accents/espaces). L’UI peut afficher des libellés.

CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS btree_gist;

-- ---------- ENUM TYPES ----------
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'entite_type_enum') THEN
    CREATE TYPE entite_type_enum AS ENUM ('PARTICULIER','SOCIETE');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'entite_perimetre_enum') THEN
    CREATE TYPE entite_perimetre_enum AS ENUM ('INTERNE','EXTERNE');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'bail_statut_enum') THEN
    CREATE TYPE bail_statut_enum AS ENUM ('BROUILLON','ACTIF','CLOS','LITIGE');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'bail_sens_enum') THEN
    CREATE TYPE bail_sens_enum AS ENUM ('ENTRANT','SORTANT');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'bail_relation_enum') THEN
    CREATE TYPE bail_relation_enum AS ENUM ('DIRECT','SOUS_LOCATION');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'bail_type_enum') THEN
    CREATE TYPE bail_type_enum AS ENUM ('HABITATION','COMMERCIAL','PROFESSIONNEL','AUTRE');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'bail_reconduction_enum') THEN
    CREATE TYPE bail_reconduction_enum AS ENUM ('AUCUNE','TACITE','EXPRESSE');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'bail_periodicite_enum') THEN
    CREATE TYPE bail_periodicite_enum AS ENUM ('MENSUEL','TRIMESTRIEL','ANNUEL');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'charges_mode_enum') THEN
    CREATE TYPE charges_mode_enum AS ENUM ('AUCUNE','FORFAIT','PROVISIONS');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'indice_type_enum') THEN
    CREATE TYPE indice_type_enum AS ENUM ('IRL','ILC','ICC','ILAT','IRL_OUTREMER');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'index_frequence_enum') THEN
    CREATE TYPE index_frequence_enum AS ENUM ('ANNUELLE','TRIENNALE','JAMAIS');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'index_date_revision_mode_enum') THEN
    CREATE TYPE index_date_revision_mode_enum AS ENUM ('ANNIVERSAIRE','DATE_FIXE','SELON_BAIL');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'echeance_statut_enum') THEN
    CREATE TYPE echeance_statut_enum AS ENUM ('PREVISIONNEL','FACTURE','PAYE','LITIGE');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'paiement_mode_enum') THEN
    CREATE TYPE paiement_mode_enum AS ENUM ('VIREMENT','PRELEVEMENT','CHEQUE','AUTRE');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'indexation_soumise_statut_enum') THEN
    CREATE TYPE indexation_soumise_statut_enum AS ENUM ('RECUE','A_VERIFIER','VALIDEE','CONTESTEE','APPLIQUEE');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'doc_type_enum') THEN
    CREATE TYPE doc_type_enum AS ENUM ('BAIL','AVENANT','EDLE','QUITTANCE','RELANCE','FACTURE_CHARGE','AUTRE');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'doc_traitement_statut_enum') THEN
    CREATE TYPE doc_traitement_statut_enum AS ENUM ('A_TRAITER','TRAITE','REJETE');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'alerte_scope_enum') THEN
    CREATE TYPE alerte_scope_enum AS ENUM ('BAIL','ECHEANCE','PAIEMENT','INDEXATION','DOCUMENT');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'alerte_gravite_enum') THEN
    CREATE TYPE alerte_gravite_enum AS ENUM ('INFO','AVERTISSEMENT','CRITIQUE');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'alerte_statut_enum') THEN
    CREATE TYPE alerte_statut_enum AS ENUM ('OUVERTE','ACCEPTEE','RESOLUE');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'charge_statut_enum') THEN
    CREATE TYPE charge_statut_enum AS ENUM ('A_REFACTURER','REFACTURE','EN_LITIGE','ABANDONNE');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'relance_niveau_enum') THEN
    CREATE TYPE relance_niveau_enum AS ENUM ('RELANCE1','RELANCE2','MISE_EN_DEMEURE');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'relance_canal_enum') THEN
    CREATE TYPE relance_canal_enum AS ENUM ('EMAIL','PDF','MANUEL');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'relance_statut_enum') THEN
    CREATE TYPE relance_statut_enum AS ENUM ('A_ENVOYER','ENVOYEE','ANNULEE');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'plan_apurement_statut_enum') THEN
    CREATE TYPE plan_apurement_statut_enum AS ENUM ('ACTIF','CLOS','ROMPU');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'plan_ligne_statut_enum') THEN
    CREATE TYPE plan_ligne_statut_enum AS ENUM ('PREVU','PARTIEL','PAYE','EN_RETARD');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'budget_flux_enum') THEN
    CREATE TYPE budget_flux_enum AS ENUM ('LOYER','CHARGES','TF','AUTRE');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'provision_statut_enum') THEN
    CREATE TYPE provision_statut_enum AS ENUM ('ESTIME','VALIDE');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'user_role_enum') THEN
    CREATE TYPE user_role_enum AS ENUM ('ADMIN','GESTIONNAIRE','COMPTABLE','LECTURE');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'loyer_plancher_plafond_mode_enum') THEN
    CREATE TYPE loyer_plancher_plafond_mode_enum AS ENUM ('FIXE','INDEXE');
  END IF;
END $$;

-- ---------- DOMAIN ----------
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'periode_mois') THEN
    CREATE DOMAIN periode_mois AS text
      CHECK (VALUE ~ '^[0-9]{4}-(0[1-9]|1[0-2])$');
  END IF;
END $$;

-- ---------- TABLES ----------
-- 5.1 entites
CREATE TABLE IF NOT EXISTS entites (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  nom_affichage text NOT NULL,
  type_entite entite_type_enum NOT NULL,
  perimetre entite_perimetre_enum NOT NULL,
  groupe_interne text,
  sous_groupe_interne text,
  siren text,
  adresse_ligne1 text,
  adresse_ligne2 text,
  code_postal text,
  ville text,
  pays text,
  contact_nom text,
  contact_email text,
  contact_telephone text,
  CONSTRAINT chk_entites_interne_groupes CHECK (
    (perimetre = 'INTERNE' AND groupe_interne IS NOT NULL AND sous_groupe_interne IS NOT NULL)
    OR (perimetre <> 'INTERNE')
  ),
  CONSTRAINT chk_entites_siren_societe CHECK (
    (type_entite = 'SOCIETE' AND siren IS NOT NULL) OR (type_entite <> 'SOCIETE')
  )
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_entites_siren_notnull ON entites(siren) WHERE siren IS NOT NULL;

-- 5.2 societes_internes
CREATE TABLE IF NOT EXISTS societes_internes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  entite_id uuid NOT NULL REFERENCES entites(id),
  groupe_interne text NOT NULL,
  sous_groupe text NOT NULL,
  is_active bool NOT NULL DEFAULT true
);

-- 5.3 proprietes
CREATE TABLE IF NOT EXISTS proprietes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  nom text NOT NULL,
  nature text NOT NULL,
  type_propriete text NOT NULL, -- "Immeuble/Terrain/Local/Autre"
  adresse_ligne1 text NOT NULL,
  adresse_ligne2 text,
  code_postal text NOT NULL,
  ville text NOT NULL,
  pays text NOT NULL,
  surface_totale numeric NOT NULL CHECK (surface_totale >= 0),
  commentaire text NOT NULL,
  is_active bool NOT NULL DEFAULT true,
  CONSTRAINT chk_proprietes_type_propriete CHECK (type_propriete IN ('Immeuble','Terrain','Local','Autre'))
);

-- 5.4 propriete_societes
CREATE TABLE IF NOT EXISTS propriete_societes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  propriete_id uuid NOT NULL REFERENCES proprietes(id),
  societe_interne_id uuid NOT NULL REFERENCES societes_internes(id),
  quote_part_pct numeric NOT NULL CHECK (quote_part_pct >= 0 AND quote_part_pct <= 100),
  date_debut date NOT NULL,
  date_fin date,
  par_defaut bool NOT NULL DEFAULT false,
  is_active bool NOT NULL DEFAULT true,
  CONSTRAINT chk_prop_soc_dates CHECK (date_fin IS NULL OR date_fin >= date_debut)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_prop_soc_unique_defaut
  ON propriete_societes(propriete_id)
  WHERE par_defaut = true AND is_active = true;

-- 5.5 biens
CREATE TABLE IF NOT EXISTS biens (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  ref_unite text NOT NULL,
  propriete_id uuid NOT NULL REFERENCES proprietes(id),
  type_bien text NOT NULL, -- "Lot/Parking/Local/Autre"
  surface numeric NOT NULL CHECK (surface >= 0),
  etage text NOT NULL,
  commentaire text NOT NULL,
  is_active bool NOT NULL DEFAULT true,
  CONSTRAINT chk_biens_type_bien CHECK (type_bien IN ('Lot','Parking','Local','Autre'))
);

-- 5.6 baux
CREATE TABLE IF NOT EXISTS baux (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code text NOT NULL UNIQUE,
  statut bail_statut_enum NOT NULL,
  sens bail_sens_enum NOT NULL,
  relation bail_relation_enum NOT NULL,
  bien_id uuid NOT NULL REFERENCES biens(id),
  societe_interne_id uuid NOT NULL REFERENCES societes_internes(id),
  bailleur_entite_id uuid NOT NULL REFERENCES entites(id),
  preneur_entite_id uuid NOT NULL REFERENCES entites(id),
  type_bail bail_type_enum NOT NULL,
  date_effet date NOT NULL,
  date_fin_contractuelle date,
  reconduction bail_reconduction_enum NOT NULL,
  periodicite bail_periodicite_enum NOT NULL,
  date_exigibilite_jour int CHECK (date_exigibilite_jour BETWEEN 1 AND 31),
  loyer_base numeric NOT NULL CHECK (loyer_base >= 0),
  charges_mode charges_mode_enum,
  charges_provision numeric CHECK (charges_provision IS NULL OR charges_provision >= 0),
  tf_refacturable bool NOT NULL DEFAULT false,
  tf_provision numeric CHECK (tf_provision IS NULL OR tf_provision >= 0),
  indexation_clause_prevue bool NOT NULL DEFAULT false,
  indexation_active bool NOT NULL DEFAULT false,
  code_analytique text,
  loyer_variable_pct_ca numeric CHECK (loyer_variable_pct_ca IS NULL OR (loyer_variable_pct_ca >= 0 AND loyer_variable_pct_ca <= 100)),
  loyer_variable_plancher_mode loyer_plancher_plafond_mode_enum,
  loyer_variable_plancher_valeur_base numeric CHECK (loyer_variable_plancher_valeur_base IS NULL OR loyer_variable_plancher_valeur_base >= 0),
  loyer_variable_plancher_indice_type indice_type_enum,
  loyer_variable_plancher_indice_ref_periode text,
  loyer_variable_plafond_mode loyer_plancher_plafond_mode_enum,
  loyer_variable_plafond_valeur_base numeric CHECK (loyer_variable_plafond_valeur_base IS NULL OR loyer_variable_plafond_valeur_base >= 0),
  loyer_variable_plafond_indice_type indice_type_enum,
  loyer_variable_plafond_indice_ref_periode text,
  interne_reciprocite_requise bool NOT NULL DEFAULT false,
  bail_miroir_id uuid REFERENCES baux(id),
  CONSTRAINT chk_baux_dates CHECK (date_fin_contractuelle IS NULL OR date_fin_contractuelle >= date_effet),
  CONSTRAINT chk_baux_miroir_not_self CHECK (bail_miroir_id IS NULL OR bail_miroir_id <> id),
  CONSTRAINT chk_baux_indexation_coherence CHECK (
    (indexation_active = false) OR (indexation_clause_prevue = true)
  )
);

-- Anti-chevauchement des baux ACTIF sur un même lot
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'excl_baux_actifs_par_lot') THEN
    ALTER TABLE baux
      ADD CONSTRAINT excl_baux_actifs_par_lot
      EXCLUDE USING gist (
        bien_id WITH =,
        daterange(date_effet, COALESCE(date_fin_contractuelle, 'infinity'::date), '[]') WITH &&
      )
      WHERE (statut = 'ACTIF');
  END IF;
END $$;

-- Message clair en cas de conflit ACTIF (avant la contrainte d'exclusion)
CREATE OR REPLACE FUNCTION public.fn_baux_actif_conflict_message()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_conflict RECORD;
  v_new_period text;
  v_conflict_period text;
BEGIN
  IF NEW.statut <> 'ACTIF' THEN
    RETURN NEW;
  END IF;

  SELECT
    b.id,
    b.code,
    b.bien_id,
    b.date_effet,
    b.date_fin_contractuelle
  INTO v_conflict
  FROM baux b
  WHERE b.statut = 'ACTIF'
    AND b.id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
    AND b.bien_id = NEW.bien_id
    AND daterange(b.date_effet, COALESCE(b.date_fin_contractuelle, 'infinity'::date), '[]')
        && daterange(NEW.date_effet, COALESCE(NEW.date_fin_contractuelle, 'infinity'::date), '[]')
  ORDER BY b.date_effet
  LIMIT 1;

  IF FOUND THEN
    v_new_period := to_char(NEW.date_effet, 'YYYY-MM-DD') || ' -> ' || COALESCE(to_char(NEW.date_fin_contractuelle, 'YYYY-MM-DD'), 'infini');
    v_conflict_period := to_char(v_conflict.date_effet, 'YYYY-MM-DD') || ' -> ' || COALESCE(to_char(v_conflict.date_fin_contractuelle, 'YYYY-MM-DD'), 'infini');

    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = format(
        'Conflit ACTIF sur lot %s: bail cible %s [%s] chevauche bail existant %s [%s].',
        NEW.bien_id,
        COALESCE(NEW.code, NEW.id::text),
        v_new_period,
        COALESCE(v_conflict.code, v_conflict.id::text),
        v_conflict_period
      ),
      DETAIL = format(
        'lot=%s; bail_cible_id=%s; bail_conflit_id=%s',
        NEW.bien_id,
        COALESCE(NEW.id::text, 'null'),
        v_conflict.id
      ),
      HINT = 'Passez le bail en conflit a CLOS/LITIGE ou ajustez les dates avant de mettre ce bail en ACTIF.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_baux_actif_conflict_message ON baux;

CREATE TRIGGER trg_baux_actif_conflict_message
BEFORE INSERT OR UPDATE OF statut, bien_id, date_effet, date_fin_contractuelle
ON baux
FOR EACH ROW
EXECUTE FUNCTION public.fn_baux_actif_conflict_message();

CREATE UNIQUE INDEX IF NOT EXISTS ux_baux_miroir_unique
  ON baux(bail_miroir_id)
  WHERE bail_miroir_id IS NOT NULL;

-- 5.7 config_index
CREATE TABLE IF NOT EXISTS config_index (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bail_id uuid NOT NULL REFERENCES baux(id),
  indice indice_type_enum NOT NULL,
  frequence index_frequence_enum NOT NULL,
  date_revision_mode index_date_revision_mode_enum NOT NULL,
  date_revision_fixe date,
  cap_pct numeric CHECK (cap_pct IS NULL OR (cap_pct >= 0 AND cap_pct <= 100)),
  floor_pct numeric CHECK (floor_pct IS NULL OR (floor_pct >= 0 AND floor_pct <= 100)),
  cap_eur numeric CHECK (cap_eur IS NULL OR cap_eur >= 0),
  floor_eur numeric CHECK (floor_eur IS NULL OR floor_eur >= 0),
  min_loyer numeric CHECK (min_loyer IS NULL OR min_loyer >= 0),
  max_loyer numeric CHECK (max_loyer IS NULL OR max_loyer >= 0),
  actif bool NOT NULL DEFAULT true,
  CONSTRAINT chk_config_index_datefixe CHECK (
    (date_revision_mode <> 'DATE_FIXE') OR (date_revision_fixe IS NOT NULL)
  ),
  CONSTRAINT chk_config_index_minmax CHECK (
    max_loyer IS NULL OR min_loyer IS NULL OR max_loyer >= min_loyer
  )
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_config_index_un_actif_par_bail
  ON config_index(bail_id)
  WHERE actif = true;

-- 5.8 indices
CREATE TABLE IF NOT EXISTS indices (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type_indice indice_type_enum NOT NULL,
  periode text NOT NULL,
  annee int,
  valeur_indice numeric NOT NULL CHECK (valeur_indice > 0),
  date_publication date,
  source text,
  CONSTRAINT ux_indices_unique UNIQUE (type_indice, periode)
);

-- 5.9 echeances
CREATE TABLE IF NOT EXISTS echeances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bail_id uuid NOT NULL REFERENCES baux(id),
  societe_interne_id uuid NOT NULL REFERENCES societes_internes(id),
  periode periode_mois NOT NULL,
  date_debut_periode date NOT NULL,
  date_fin_periode date NOT NULL,
  date_echeance date NOT NULL,
  montant_loyer numeric NOT NULL, -- peut être négatif (avoir) -> alerte conformité côté applicatif
  montant_charges numeric NOT NULL DEFAULT 0 CHECK (montant_charges >= 0),
  montant_taxe_fonciere_refacturee numeric NOT NULL DEFAULT 0 CHECK (montant_taxe_fonciere_refacturee >= 0),
  montant_total numeric GENERATED ALWAYS AS (montant_loyer + montant_charges + montant_taxe_fonciere_refacturee) STORED,
  statut echeance_statut_enum NOT NULL,
  indexation_appliquee bool NOT NULL DEFAULT false,
  impaye_flag bool NOT NULL DEFAULT false,
  CONSTRAINT ux_echeances_unique UNIQUE (bail_id, periode),
  CONSTRAINT chk_echeances_dates CHECK (date_fin_periode >= date_debut_periode)
);
CREATE INDEX IF NOT EXISTS ix_echeances_societe_periode ON echeances(societe_interne_id, periode);
CREATE INDEX IF NOT EXISTS ix_echeances_impaye ON echeances(impaye_flag) WHERE impaye_flag = true;

-- 5.10 paiements
CREATE TABLE IF NOT EXISTS paiements (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  reference_paiement text,
  date_paiement date NOT NULL,
  montant numeric NOT NULL CHECK (montant <> 0),
  societe_interne_id uuid NOT NULL REFERENCES societes_internes(id),
  contrepartie_entite_id uuid REFERENCES entites(id),
  mode_paiement paiement_mode_enum NOT NULL,
  source_import text,
  commentaire text
);
CREATE INDEX IF NOT EXISTS ix_paiements_ref ON paiements(reference_paiement);
CREATE INDEX IF NOT EXISTS ix_paiements_societe_date ON paiements(societe_interne_id, date_paiement);

-- 5.11 paiement_allocations
CREATE TABLE IF NOT EXISTS paiement_allocations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  paiement_id uuid NOT NULL REFERENCES paiements(id) ON DELETE CASCADE,
  echeance_id uuid NOT NULL REFERENCES echeances(id) ON DELETE CASCADE,
  montant_alloue numeric NOT NULL CHECK (montant_alloue > 0),
  created_at timestamptz NOT NULL DEFAULT now(),
  created_by text,
  CONSTRAINT ux_alloc_unique UNIQUE (paiement_id, echeance_id)
);

-- 5.12 indexations_soumises
CREATE TABLE IF NOT EXISTS indexations_soumises (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bail_id uuid NOT NULL REFERENCES baux(id),
  date_reception date NOT NULL,
  periode_application periode_mois NOT NULL,
  retroactivite bool NOT NULL DEFAULT false,
  periode_debut_retro periode_mois,
  ancien_loyer numeric NOT NULL CHECK (ancien_loyer >= 0),
  nouveau_loyer_demande numeric NOT NULL CHECK (nouveau_loyer_demande >= 0),
  type_indice indice_type_enum NOT NULL,
  indice_reference_periode text,
  indice_reference_valeur numeric,
  indice_nouveau_periode text,
  indice_nouveau_valeur numeric,
  nouveau_loyer_calcule numeric CHECK (nouveau_loyer_calcule IS NULL OR nouveau_loyer_calcule >= 0),
  ecart_eur numeric,
  ecart_pct numeric,
  piece_justificative_document_id uuid,
  statut indexation_soumise_statut_enum NOT NULL,
  valide_par text,
  date_validation timestamptz,
  commentaire_controle text,
  CONSTRAINT chk_indexations_retro_coherence CHECK (
    (retroactivite = false AND periode_debut_retro IS NULL) OR (retroactivite = true)
  )
);

-- 5.13 loyers_variables_ca
CREATE TABLE IF NOT EXISTS loyers_variables_ca (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bail_id uuid NOT NULL REFERENCES baux(id),
  periode periode_mois NOT NULL,
  date_declaration date,
  chiffre_affaires numeric NOT NULL CHECK (chiffre_affaires >= 0),
  loyer_variable_calcule numeric CHECK (loyer_variable_calcule IS NULL OR loyer_variable_calcule >= 0),
  applique bool NOT NULL DEFAULT false,
  CONSTRAINT ux_loyers_var_unique UNIQUE (bail_id, periode)
);

-- 5.14 budgets
CREATE TABLE IF NOT EXISTS budgets (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  societe_interne_id uuid NOT NULL REFERENCES societes_internes(id),
  bien_id uuid NOT NULL REFERENCES biens(id),
  periode periode_mois NOT NULL,
  nature_flux budget_flux_enum NOT NULL,
  montant_budget numeric NOT NULL CHECK (montant_budget >= 0)
);
CREATE INDEX IF NOT EXISTS ix_budgets_societe_periode ON budgets(societe_interne_id, periode);
CREATE UNIQUE INDEX IF NOT EXISTS ux_budgets_unique
  ON budgets(societe_interne_id, bien_id, periode, nature_flux);

-- 5.15 provisions_indexation
CREATE TABLE IF NOT EXISTS provisions_indexation (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  run_id uuid NOT NULL,
  bail_id uuid NOT NULL REFERENCES baux(id),
  periode periode_mois NOT NULL,
  loyer_facture numeric NOT NULL,
  loyer_reference_utilise numeric NOT NULL,
  indice_reference_utilise numeric NOT NULL,
  indice_nouveau_utilise numeric NOT NULL,
  loyer_theorique_indexe numeric NOT NULL,
  ecart_provision numeric NOT NULL,
  statut provision_statut_enum NOT NULL,
  commentaire text
);
CREATE INDEX IF NOT EXISTS ix_provisions_run ON provisions_indexation(run_id);

-- 5.16 charges_refacturables
CREATE TABLE IF NOT EXISTS charges_refacturables (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  societe_interne_id uuid NOT NULL REFERENCES societes_internes(id),
  propriete_id uuid REFERENCES proprietes(id),
  bien_id uuid REFERENCES biens(id),
  bail_id uuid REFERENCES baux(id),
  periode periode_mois NOT NULL,
  libelle text NOT NULL,
  montant numeric NOT NULL CHECK (montant >= 0),
  document_id uuid,
  statut charge_statut_enum NOT NULL
);

-- 5.17 relances
CREATE TABLE IF NOT EXISTS relances (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  echeance_id uuid NOT NULL REFERENCES echeances(id) ON DELETE CASCADE,
  niveau relance_niveau_enum NOT NULL,
  date_relance date NOT NULL,
  canal relance_canal_enum NOT NULL,
  document_id uuid,
  statut relance_statut_enum NOT NULL,
  note text
);

-- 5.18 plans_apurement
CREATE TABLE IF NOT EXISTS plans_apurement (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  bail_id uuid NOT NULL REFERENCES baux(id) ON DELETE CASCADE,
  date_debut date NOT NULL,
  date_fin date,
  montant_total numeric NOT NULL CHECK (montant_total >= 0),
  mensualite numeric NOT NULL CHECK (mensualite >= 0),
  statut plan_apurement_statut_enum NOT NULL,
  CONSTRAINT chk_plan_dates CHECK (date_fin IS NULL OR date_fin >= date_debut)
);

-- 5.19 plan_apurement_lignes
CREATE TABLE IF NOT EXISTS plan_apurement_lignes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plan_id uuid NOT NULL REFERENCES plans_apurement(id) ON DELETE CASCADE,
  periode periode_mois NOT NULL,
  montant_attendu numeric NOT NULL CHECK (montant_attendu >= 0),
  montant_regle numeric NOT NULL CHECK (montant_regle >= 0),
  statut plan_ligne_statut_enum NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_plan_apurement_lignes_unique
  ON plan_apurement_lignes(plan_id, periode);

-- 5.20 documents
CREATE TABLE IF NOT EXISTS documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  type_document doc_type_enum NOT NULL,
  bail_id uuid REFERENCES baux(id),
  bien_id uuid REFERENCES biens(id),
  societe_interne_id uuid REFERENCES societes_internes(id),
  periode periode_mois,
  nom_fichier text NOT NULL,
  url text NOT NULL,
  statut_traitement doc_traitement_statut_enum NOT NULL,
  notes text
);

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_indexations_soumises_document') THEN
    ALTER TABLE indexations_soumises
      ADD CONSTRAINT fk_indexations_soumises_document
      FOREIGN KEY (piece_justificative_document_id) REFERENCES documents(id)
      ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_charges_refacturables_document') THEN
    ALTER TABLE charges_refacturables
      ADD CONSTRAINT fk_charges_refacturables_document
      FOREIGN KEY (document_id) REFERENCES documents(id)
      ON DELETE SET NULL;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'fk_relances_document') THEN
    ALTER TABLE relances
      ADD CONSTRAINT fk_relances_document
      FOREIGN KEY (document_id) REFERENCES documents(id)
      ON DELETE SET NULL;
  END IF;
END $$;

-- 5.21 alertes_conformite
CREATE TABLE IF NOT EXISTS alertes_conformite (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  scope alerte_scope_enum NOT NULL,
  societe_interne_id uuid REFERENCES societes_internes(id),
  bail_id uuid REFERENCES baux(id),
  echeance_id uuid REFERENCES echeances(id),
  indexation_soumise_id uuid REFERENCES indexations_soumises(id),
  type_alerte text NOT NULL,
  gravite alerte_gravite_enum NOT NULL,
  message text NOT NULL,
  recommandation text,
  statut alerte_statut_enum NOT NULL,
  justification text,
  cree_par text,
  horodatage timestamptz NOT NULL DEFAULT now()
);

-- 5.22 journal_actions
CREATE TABLE IF NOT EXISTS journal_actions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  horodatage timestamptz NOT NULL DEFAULT now(),
  action text NOT NULL,
  utilisateur text,
  bail_id uuid REFERENCES baux(id),
  periode periode_mois,
  details text
);

-- 5.23 user_societes (droits par société interne)
CREATE TABLE IF NOT EXISTS user_societes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  societe_interne_id uuid NOT NULL REFERENCES societes_internes(id) ON DELETE CASCADE,
  directus_user_id uuid NOT NULL, -- FK ajouté plus tard quand directus_users existe
  role user_role_enum NOT NULL DEFAULT 'LECTURE',
  is_active bool NOT NULL DEFAULT true,
  CONSTRAINT ux_user_soc_unique UNIQUE (societe_interne_id, directus_user_id)
);
CREATE INDEX IF NOT EXISTS ix_user_societes_user ON user_societes(directus_user_id);

-- ---------- FKs ajoutés après création des tables Directus (optionnel) ----------
-- Le script scripts/patch_directus_user_fk.sql le fera proprement après init Directus.

-- ---------- Dashboard cache tables (utilisées par l'endpoint /refresh-dash) ----------
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
