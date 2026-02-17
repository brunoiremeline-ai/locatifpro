-- MCD consistency patch (idempotent)
-- Aligns logical constraints with practical data integrity rules.

-- 1) Normalize text categories before CHECK constraints
UPDATE proprietes
SET type_propriete = 'Autre'
WHERE type_propriete IS NULL
   OR type_propriete NOT IN ('Immeuble','Terrain','Local','Autre');

UPDATE biens
SET type_bien = 'Autre'
WHERE type_bien IS NULL
   OR type_bien NOT IN ('Lot','Parking','Local','Autre');

-- 2) Prevent orphan document references before FK creation
UPDATE indexations_soumises i
SET piece_justificative_document_id = NULL
WHERE piece_justificative_document_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM documents d WHERE d.id = i.piece_justificative_document_id
  );

UPDATE charges_refacturables c
SET document_id = NULL
WHERE document_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM documents d WHERE d.id = c.document_id
  );

UPDATE relances r
SET document_id = NULL
WHERE document_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM documents d WHERE d.id = r.document_id
  );

-- 3) Add missing table CHECK constraints
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_proprietes_type_propriete') THEN
    ALTER TABLE proprietes
      ADD CONSTRAINT chk_proprietes_type_propriete
      CHECK (type_propriete IN ('Immeuble','Terrain','Local','Autre'));
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_biens_type_bien') THEN
    ALTER TABLE biens
      ADD CONSTRAINT chk_biens_type_bien
      CHECK (type_bien IN ('Lot','Parking','Local','Autre'));
  END IF;
END $$;

-- 4) Add missing document FKs
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

-- 5) Enforce one-to-one mirror for internal baux
CREATE UNIQUE INDEX IF NOT EXISTS ux_baux_miroir_unique
  ON baux(bail_miroir_id)
  WHERE bail_miroir_id IS NOT NULL;

-- 6) Enforce budget and repayment line uniqueness at business grain
CREATE UNIQUE INDEX IF NOT EXISTS ux_budgets_unique
  ON budgets(societe_interne_id, bien_id, periode, nature_flux);

CREATE UNIQUE INDEX IF NOT EXISTS ux_plan_apurement_lignes_unique
  ON plan_apurement_lignes(plan_id, periode);
