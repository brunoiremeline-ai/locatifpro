-- Ajoute la FK user_societes.directus_user_id -> directus_users.id (si Directus est déjà initialisé)
ALTER TABLE user_societes
  ADD COLUMN IF NOT EXISTS directus_user_id uuid;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema='public' AND table_name='directus_users') THEN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='fk_user_societes_directus_user') THEN
      ALTER TABLE user_societes
        ADD CONSTRAINT fk_user_societes_directus_user
        FOREIGN KEY (directus_user_id) REFERENCES directus_users(id)
        ON DELETE CASCADE;
    END IF;
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema='public' AND table_name='user_societes' AND column_name='directus_user_id') THEN
    IF NOT EXISTS (SELECT 1 FROM user_societes WHERE directus_user_id IS NULL) THEN
      ALTER TABLE user_societes
        ALTER COLUMN directus_user_id SET NOT NULL;
    END IF;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_user_societes_user ON user_societes(directus_user_id);
