-- LocatifPro - Populate Directus metadata from Postgres schema
-- Adds collections, fields, and relations for all public business tables
-- Idempotent: uses NOT EXISTS to avoid re-inserting

-- ================================================================================
-- 1. DIRECTUS COLLECTIONS (public.* tables, excluding directus_%)
-- ================================================================================
INSERT INTO directus_collections (collection)
SELECT t.table_name
FROM information_schema.tables t
WHERE
  t.table_schema = 'public'
  AND t.table_type IN ('BASE TABLE', 'VIEW')
  AND t.table_name NOT LIKE 'directus_%'
  AND NOT EXISTS (
    SELECT 1 FROM directus_collections dc
    WHERE dc.collection = t.table_name
  )
ORDER BY t.table_name;

-- ================================================================================
-- 2. DIRECTUS FIELDS (all columns from public.* tables, excluding directus_%)
-- ================================================================================
INSERT INTO directus_fields (collection, field)
SELECT c.table_name, c.column_name
FROM information_schema.columns c
WHERE
  c.table_schema = 'public'
  AND c.table_name NOT LIKE 'directus_%'
  AND NOT EXISTS (
    SELECT 1 FROM directus_fields df
    WHERE df.collection = c.table_name
      AND df.field = c.column_name
  )
ORDER BY c.table_name, c.ordinal_position;

-- ================================================================================
-- 3. DIRECTUS RELATIONS (from Postgres FK constraints, simple FKs only)
-- Only 1-column FKs (no composite keys)
-- ================================================================================
INSERT INTO directus_relations (
  many_collection,
  many_field,
  one_collection,
  one_field,
  one_deselect_action
)
SELECT
  kcu_fk.table_name,
  kcu_fk.column_name,
  kcu_pk.table_name,
  NULL,
  -- Map Postgres constraint type to Directus delete action
  CASE
    WHEN c.confdeltype = 'c' THEN 'delete'      -- CASCADE
    WHEN c.confdeltype = 'n' THEN 'nullify'     -- SET NULL
    WHEN c.confdeltype = 'r' THEN 'restrict'    -- RESTRICT
    WHEN c.confdeltype = 'a' THEN 'restrict'    -- NO ACTION
    ELSE 'restrict'
  END
FROM
  information_schema.table_constraints tc
  JOIN information_schema.key_column_usage kcu_fk
    ON tc.constraint_name = kcu_fk.constraint_name
    AND tc.table_schema = kcu_fk.table_schema
  JOIN information_schema.constraint_column_usage kcu_pk
    ON kcu_fk.constraint_name = kcu_pk.constraint_name
    AND kcu_fk.table_schema = kcu_pk.table_schema
  JOIN pg_constraint c
    ON c.conname = tc.constraint_name
WHERE
  tc.constraint_type = 'FOREIGN KEY'
  AND tc.table_schema = 'public'
  AND kcu_fk.table_name NOT LIKE 'directus_%'
  AND kcu_pk.table_name NOT LIKE 'directus_%'
  -- Only simple FKs (1 column)
  AND (SELECT COUNT(*) FROM information_schema.key_column_usage kcu
       WHERE kcu.constraint_name = tc.constraint_name) = 1
  AND NOT EXISTS (
    SELECT 1 FROM directus_relations dr
    WHERE dr.many_collection = kcu_fk.table_name
      AND dr.many_field = kcu_fk.column_name
      AND dr.one_collection = kcu_pk.table_name
      AND ((dr.one_field IS NULL) OR (dr.one_field = kcu_pk.column_name))
  );

-- ================================================================================
-- Summary: Display counts
-- ================================================================================
SELECT 'directus_collections' AS metadata_type, COUNT(*) AS count
FROM directus_collections
WHERE collection NOT LIKE 'directus_%'
UNION ALL
SELECT 'directus_fields' AS metadata_type, COUNT(*) AS count
FROM directus_fields
WHERE collection NOT LIKE 'directus_%'
UNION ALL
SELECT 'directus_relations' AS metadata_type, COUNT(*) AS count
FROM directus_relations;

-- -----------------------------------------------------------------------------
-- Special-case: system relation for user_societes.directus_user_id -> directus_users.id
-- Needed because generic FK import excludes directus_% tables.
-- -----------------------------------------------------------------------------
INSERT INTO directus_relations (many_collection, many_field, one_collection, one_field, one_deselect_action)
SELECT 'user_societes', 'directus_user_id', 'directus_users', NULL, 'delete'
WHERE NOT EXISTS (
  SELECT 1 FROM directus_relations
  WHERE many_collection='user_societes' AND many_field='directus_user_id'
);
