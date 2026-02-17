-- LocatifPro - UX Defaults Setup
-- Injects display_templates for collections and configures relation displays
-- Idempotent: only updates empty/null display_template values

-- ================================================================================
-- 1. UPDATE DIRECTUS_COLLECTIONS with display_template based on column heuristics
-- ================================================================================
-- For each collection, find the best candidate column(s) for display and set template
-- Heuristic: prefer columns in this order: nom, name, libelle, label, titre, title,
-- code, reference, ref, numero, num, slug

DO $$
DECLARE
  collection_name TEXT;
  template_cols TEXT[];
  col_name TEXT;
  display_tmpl TEXT;
BEGIN
  -- Iterate over all non-directus collections
  FOR collection_name IN
    SELECT collection FROM directus_collections
    WHERE collection NOT LIKE 'directus_%'
      AND display_template IS NULL
    ORDER BY collection
  LOOP
    -- Collect matching columns in order of preference
    template_cols := ARRAY[]::TEXT[];

    -- Check for preferred column names (longest match list first)
    FOREACH col_name IN ARRAY ARRAY['nom', 'name', 'libelle', 'label', 'titre', 'title', 
                                      'code', 'reference', 'ref', 'numero', 'num', 'slug'] LOOP
      IF EXISTS (
        SELECT 1 FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = collection_name
          AND column_name = col_name
      ) THEN
        template_cols := array_append(template_cols, col_name);
      END IF;
    END LOOP;

    -- Build display template
    IF array_length(template_cols, 1) > 0 THEN
      -- If only one column, use {{col}}
      -- If multiple, combine with " - " separator
      IF array_length(template_cols, 1) = 1 THEN
        display_tmpl := format('{{%I}}', template_cols[1]);
      ELSE
        display_tmpl := (
          SELECT string_agg(format('{{%I}}', col), ' - ')
          FROM unnest(template_cols) AS col
        );
      END IF;

      -- Update collection with new template
      UPDATE directus_collections
      SET display_template = display_tmpl
      WHERE collection = collection_name;
    END IF;

  END LOOP;

END $$;

-- ================================================================================
-- 2. UPDATE DIRECTUS_FIELDS for M2O relationships (select-dropdown-m2o interface)
-- ================================================================================
-- For each FK field (exists in directus_relations as many_field),
-- update its interface to 'select-dropdown-m2o' if not already set

DO $$
DECLARE
  fk_collection TEXT;
  fk_field TEXT;
BEGIN
  -- Find all FK fields from directus_relations
  FOR fk_collection, fk_field IN
    SELECT DISTINCT many_collection, many_field
    FROM directus_relations
    WHERE many_collection NOT LIKE 'directus_%'
  LOOP
    -- Update field interface to dropdown M2O if not already set to something meaningful
    UPDATE directus_fields
    SET interface = 'select-dropdown-m2o'
    WHERE collection = fk_collection
      AND field = fk_field
      AND (interface IS NULL OR interface = 'input');
  END LOOP;

END $$;

-- ================================================================================
-- 3. Summary: Display updated collections and fields
-- ================================================================================
SELECT 'directus_collections with display_template' AS item_type, COUNT(*) AS count
FROM directus_collections
WHERE collection NOT LIKE 'directus_%' AND display_template IS NOT NULL
UNION ALL
SELECT 'directus_fields with select-dropdown-m2o' AS item_type, COUNT(*) AS count
FROM directus_fields
WHERE interface = 'select-dropdown-m2o'
  AND collection NOT LIKE 'directus_%';

-- -----------------------------------------------------------------------------
-- Special-case UX: force user_societes.directus_user_id as M2O dropdown (UUID)
-- -----------------------------------------------------------------------------
UPDATE directus_fields
SET interface='select-dropdown-m2o'
WHERE collection='user_societes'
  AND field='directus_user_id'
  AND (interface IS DISTINCT FROM 'select-dropdown-m2o');

