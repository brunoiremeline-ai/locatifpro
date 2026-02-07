-- LocatifPro V1 - Schéma robuste (PostgreSQL)
-- Objectif: base relationnelle pour baux, échéances, paiements, indexations entrantes, alertes, documents, droits.

BEGIN;

-- Extensions utiles
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =========================
-- 1) Référentiels
-- =========================

CREATE TABLE IF NOT EXISTS entites (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code            TEXT NOT NULL UNIQUE,
  nom_affichage   TEXT NOT NULL,
  type_entite     TEXT NOT NULL CHECK (type_entite IN ('PARTICULIER','SOCIETE')),
  perimetre       TEXT NOT NULL CHECK (perimetre IN ('INTERNE','EXTERNE')),
  siren           TEXT,
  adresse_ligne1  TEXT,
  adresse_ligne2  TEXT,
  code_postal     TEXT,
  ville           TEXT,
  pays            TEXT DEFAULT 'FR',
  contact_nom     TEXT,
  contact_email   TEXT,
  contact_tel     TEXT,
  actif           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS societes_internes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code            TEXT NOT NULL UNIQUE,
  entite_id       UUID NOT NULL REFERENCES entites(id),
  groupe_interne  TEXT NOT NULL,
  sous_groupe     TEXT NOT NULL,
  actif           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS proprietes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code            TEXT NOT NULL UNIQUE,
  libelle         TEXT NOT NULL,
  adresse_ligne1  TEXT,
  adresse_ligne2  TEXT,
  code_postal     TEXT,
  ville           TEXT,
  pays            TEXT DEFAULT 'FR',
  actif           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS biens (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code_lot        TEXT NOT NULL UNIQUE,
  propriete_id    UUID NOT NULL REFERENCES proprietes(id),
  type_bien       TEXT NOT NULL CHECK (type_bien IN ('APPART','MAISON','LOCAL_COMMERCIAL','BUREAU','PARKING','AUTRE')),
  surface_m2      NUMERIC(10,2),
  etage           TEXT,
  porte           TEXT,
  actif           BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Lien Propriété ↔ Sociétés internes (utile si plusieurs sociétés impliquées)
CREATE TABLE IF NOT EXISTS propriete_societes (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  propriete_id       UUID NOT NULL REFERENCES proprietes(id) ON DELETE CASCADE,
  societe_interne_id UUID NOT NULL REFERENCES societes_internes(id),
  quote_part         NUMERIC(8,5) NOT NULL DEFAULT 1.0,
  date_debut         DATE,
  date_fin           DATE,
  UNIQUE (propriete_id, societe_interne_id, date_debut)
);

-- =========================
-- 2) Baux
-- =========================

CREATE TABLE IF NOT EXISTS baux (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code_bail           TEXT NOT NULL UNIQUE,

  -- Société interne "porteuse" (obligatoire)
  societe_interne_id  UUID NOT NULL REFERENCES societes_internes(id),

  -- Lot concerné (1 bail = 1 lot)
  bien_id             UUID NOT NULL REFERENCES biens(id),

  -- Sens du bail
  sens                TEXT NOT NULL CHECK (sens IN ('ENTRANT','SORTANT')),

  -- Type (interne vs externe)
  type_bail           TEXT NOT NULL CHECK (type_bail IN ('INTERNE','EXTERNE')),

  -- Contreparties
  bailleur_entite_id  UUID REFERENCES entites(id),
  locataire_entite_id UUID REFERENCES entites(id),

  -- Dates
  date_effet          DATE NOT NULL,
  date_fin            DATE,
  date_signature      DATE,

  -- Statut
  statut              TEXT NOT NULL DEFAULT 'BROUILLON'
                      CHECK (statut IN ('BROUILLON','ACTIF','CLOS','LITIGE')),

  -- Montants de base
  loyer_ht            NUMERIC(12,2) NOT NULL DEFAULT 0,
  charges_prov        NUMERIC(12,2) NOT NULL DEFAULT 0,
  tva_taux            NUMERIC(6,3)  NOT NULL DEFAULT 0,

  -- Indexation param
  indexation_active   BOOLEAN NOT NULL DEFAULT FALSE,
  index_code          TEXT,  -- ex: ILAT/ICC/IRL (référence)
  index_mois_ref      TEXT,  -- ex: "2024-01"
  date_revisable      DATE,  -- prochaine révision

  -- Liens
  bail_miroir_id      UUID REFERENCES baux(id), -- pour bail interne (miroir)

  commentaire         TEXT,

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Empêcher 2 baux ACTIF sur le même lot (approche simple pour V1)
CREATE UNIQUE INDEX IF NOT EXISTS ux_baux_un_actif_par_lot
ON baux (bien_id)
WHERE statut = 'ACTIF';

CREATE INDEX IF NOT EXISTS ix_baux_societe ON baux(societe_interne_id);
CREATE INDEX IF NOT EXISTS ix_baux_bien ON baux(bien_id);
CREATE INDEX IF NOT EXISTS ix_baux_dates ON baux(date_effet, date_fin);

-- =========================
-- 3) Échéances (quittancement)
-- =========================

CREATE TABLE IF NOT EXISTS echeances (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bail_id        UUID NOT NULL REFERENCES baux(id) ON DELETE CASCADE,

  -- Période rattachée (AAAA-MM)
  periode        TEXT NOT NULL CHECK (periode ~ '^\d{4}-\d{2}$'),
  date_echeance  DATE NOT NULL,

  -- Montants
  loyer_ht       NUMERIC(12,2) NOT NULL DEFAULT 0,
  charges        NUMERIC(12,2) NOT NULL DEFAULT 0,
  tva            NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_ttc      NUMERIC(12,2) NOT NULL DEFAULT 0,

  statut         TEXT NOT NULL DEFAULT 'PREVISIONNEL'
                 CHECK (statut IN ('PREVISIONNEL','FACTURE','PAYE','LITIGE')),

  solde_restant  NUMERIC(12,2) NOT NULL DEFAULT 0,

  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now(),

  UNIQUE (bail_id, periode)
);

CREATE INDEX IF NOT EXISTS ix_echeances_bail_periode ON echeances(bail_id, periode);
CREATE INDEX IF NOT EXISTS ix_echeances_statut ON echeances(statut);

-- =========================
-- 4) Paiements + allocations (rapprochement N:N)
-- =========================

CREATE TABLE IF NOT EXISTS paiements (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  societe_interne_id UUID NOT NULL REFERENCES societes_internes(id),
  date_paiement     DATE NOT NULL,
  montant           NUMERIC(12,2) NOT NULL,
  mode_paiement     TEXT NOT NULL DEFAULT 'AUTRE'
                    CHECK (mode_paiement IN ('VIREMENT','CHEQUE','ESPECES','CB','AUTRE')),
  reference         TEXT,
  payeur_entite_id  UUID REFERENCES entites(id),
  commentaire       TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_paiements_societe_date ON paiements(societe_interne_id, date_paiement);

CREATE TABLE IF NOT EXISTS paiement_allocations (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  paiement_id   UUID NOT NULL REFERENCES paiements(id) ON DELETE CASCADE,
  echeance_id   UUID NOT NULL REFERENCES echeances(id) ON DELETE CASCADE,
  montant_alloue NUMERIC(12,2) NOT NULL CHECK (montant_alloue >= 0),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (paiement_id, echeance_id)
);

CREATE INDEX IF NOT EXISTS ix_alloc_echeance ON paiement_allocations(echeance_id);

-- =========================
-- 5) Indexations entrantes (soumissions bailleur)
-- =========================

CREATE TABLE IF NOT EXISTS indexations_soumises (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bail_id         UUID NOT NULL REFERENCES baux(id) ON DELETE CASCADE,

  -- Demande bailleur
  date_demande    DATE NOT NULL,
  periode_effet   TEXT NOT NULL CHECK (periode_effet ~ '^\d{4}-\d{2}$'),
  montant_demande NUMERIC(12,2) NOT NULL,

  -- Calcul interne attendu
  montant_calcule NUMERIC(12,2),
  ecart           NUMERIC(12,2),

  statut          TEXT NOT NULL DEFAULT 'RECUE'
                  CHECK (statut IN ('RECUE','A_VERIFIER','VALIDEE','APPLIQUEE','REFUSEE')),

  commentaire     TEXT,

  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_index_soumises_bail_statut ON indexations_soumises(bail_id, statut);

-- Table indices (IRL/ILAT/ICC etc.)
CREATE TABLE IF NOT EXISTS indices (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code_index   TEXT NOT NULL,           -- ex: IRL
  periode      TEXT NOT NULL CHECK (periode ~ '^\d{4}-\d{2}$'),
  valeur       NUMERIC(12,6) NOT NULL,
  source       TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (code_index, periode)
);

-- =========================
-- 6) Documents, alertes, journal
-- =========================

CREATE TABLE IF NOT EXISTS documents (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  societe_interne_id UUID REFERENCES societes_internes(id),
  bail_id        UUID REFERENCES baux(id) ON DELETE SET NULL,
  bien_id        UUID REFERENCES biens(id) ON DELETE SET NULL,
  categorie      TEXT NOT NULL CHECK (categorie IN ('BAIL','AVENANT','QUITTANCE','RELANCE','INDEXATION','JUSTIFICATIF','AUTRE')),
  titre          TEXT NOT NULL,
  url_stockage   TEXT,   -- pour V1, lien/URL; plus tard on peut lier au module Files Directus
  commentaire    TEXT,
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_docs_bail ON documents(bail_id);

CREATE TABLE IF NOT EXISTS alertes_conformite (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  societe_interne_id UUID REFERENCES societes_internes(id),
  bail_id          UUID REFERENCES baux(id) ON DELETE CASCADE,
  niveau           TEXT NOT NULL CHECK (niveau IN ('INFO','WARNING','CRITIQUE')),
  code             TEXT NOT NULL, -- ex: RETROACTIVITE_HAB_PART
  message          TEXT NOT NULL,
  justification    TEXT,
  acquittee        BOOLEAN NOT NULL DEFAULT FALSE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_alertes_bail ON alertes_conformite(bail_id, acquittee);

CREATE TABLE IF NOT EXISTS journal_actions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  acteur          TEXT, -- email/nom utilisateur (Directus)
  action          TEXT NOT NULL,
  objet_type      TEXT,
  objet_id        UUID,
  details         JSONB,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =========================
-- 7) Droits par société interne (pour Directus Roles)
-- =========================

CREATE TABLE IF NOT EXISTS user_societes (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_email         TEXT NOT NULL,
  societe_interne_id UUID NOT NULL REFERENCES societes_internes(id) ON DELETE CASCADE,
  role_metier        TEXT NOT NULL CHECK (role_metier IN ('ADMIN','GESTIONNAIRE','COMPTABLE','LECTURE')),
  UNIQUE (user_email, societe_interne_id)
);

COMMIT;
