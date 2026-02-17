-- LocatifPro - RBAC Setup (Role-Based Access Control)
-- Creates "Agent" role with policy and permissions scoped by societe_interne_id
-- Directus 11.15.1 structure: directus_roles -> directus_access -> directus_policies -> directus_permissions
-- Idempotent: checks for existing roles/policies/permissions before inserting

-- ================================================================================
-- 1. CREATE/UPDATE ROLE "Agent" (if not exists)
-- ================================================================================
DO $$
DECLARE
  agent_role_id UUID;
BEGIN
  -- Check if role exists
  SELECT id INTO agent_role_id FROM directus_roles
  WHERE name = 'Agent' LIMIT 1;

  -- If not exists, create it
  IF agent_role_id IS NULL THEN
    INSERT INTO directus_roles (id, name, icon, description)
    VALUES (gen_random_uuid(), 'Agent', 'person', 'User with access scoped by societe_interne')
    RETURNING id INTO agent_role_id;
  END IF;

  -- Store the role ID for use in next sections
  EXECUTE format('SET app.agent_role_id = %L', agent_role_id);
END $$;

-- ================================================================================
-- 2. CREATE/UPDATE POLICY "Agent" (if not exists)
-- ================================================================================
DO $$
DECLARE
  agent_policy_id UUID;
  agent_role_id UUID;
BEGIN
  -- Check if policy exists
  SELECT id INTO agent_policy_id FROM directus_policies
  WHERE name = 'Agent' LIMIT 1;

  -- If not exists, create it
  IF agent_policy_id IS NULL THEN
    INSERT INTO directus_policies (id, name, icon, description, admin_access, app_access)
    VALUES (gen_random_uuid(), 'Agent', 'badge', 'Permissions for Agent role (societe_interne scoped)', false, true)
    RETURNING id INTO agent_policy_id;
  END IF;

  -- Store the policy ID for use in next sections
  EXECUTE format('SET app.agent_policy_id = %L', agent_policy_id);

  -- Link policy to role via directus_access (if not already linked)
  SELECT id INTO agent_role_id FROM directus_roles WHERE name = 'Agent';

  IF NOT EXISTS (
    SELECT 1 FROM directus_access
    WHERE role = agent_role_id AND policy = agent_policy_id
  ) THEN
    INSERT INTO directus_access (id, role, policy)
    VALUES (gen_random_uuid(), agent_role_id, agent_policy_id);
  END IF;

END $$;

-- ================================================================================
-- 3. CREATE PERMISSIONS FOR DIRECTUS SYSTEM COLLECTIONS (minimal)
-- ================================================================================
-- Users need basic access to:
-- - directus_users (read own, update own profile)
-- - directus_roles (read)
-- - directus_files (read, create)

DO $$
DECLARE
  agent_policy_id UUID;
BEGIN
  SELECT current_setting('app.agent_policy_id')::UUID INTO agent_policy_id;

  -- directus_users: read only own profile
  IF NOT EXISTS (
    SELECT 1 FROM directus_permissions
    WHERE policy = agent_policy_id AND collection = 'directus_users'
      AND action = 'read'
  ) THEN
    INSERT INTO directus_permissions (policy, collection, action, fields, permissions)
    VALUES (
      agent_policy_id,
      'directus_users',
      'read',
      '*',
      '{"_and": [{"id": {"_eq": "$CURRENT_USER"}}]}'::JSON
    );
  END IF;

  -- directus_users: update own profile
  IF NOT EXISTS (
    SELECT 1 FROM directus_permissions
    WHERE policy = agent_policy_id AND collection = 'directus_users'
      AND action = 'update'
  ) THEN
    INSERT INTO directus_permissions (policy, collection, action, fields, permissions)
    VALUES (
      agent_policy_id,
      'directus_users',
      'update',
      'email,password,first_name,last_name,avatar',
      '{"_and": [{"id": {"_eq": "$CURRENT_USER"}}]}'::JSON
    );
  END IF;

  -- directus_roles: read all
  IF NOT EXISTS (
    SELECT 1 FROM directus_permissions
    WHERE policy = agent_policy_id AND collection = 'directus_roles'
      AND action = 'read'
  ) THEN
    INSERT INTO directus_permissions (policy, collection, action, fields)
    VALUES (
      agent_policy_id,
      'directus_roles',
      'read',
      '*'
    );
  END IF;

  -- directus_files: read, create
  IF NOT EXISTS (
    SELECT 1 FROM directus_permissions
    WHERE policy = agent_policy_id AND collection = 'directus_files'
      AND action = 'read'
  ) THEN
    INSERT INTO directus_permissions (policy, collection, action, fields)
    VALUES (
      agent_policy_id,
      'directus_files',
      'read',
      '*'
    );
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM directus_permissions
    WHERE policy = agent_policy_id AND collection = 'directus_files'
      AND action = 'create'
  ) THEN
    INSERT INTO directus_permissions (policy, collection, action, fields)
    VALUES (
      agent_policy_id,
      'directus_files',
      'create',
      '*'
    );
  END IF;

END $$;

-- ================================================================================
-- 4. CREATE PERMISSIONS FOR BUSINESS COLLECTIONS (societe_interne filtered)
-- Collections with direct societe_interne_id:
--   - baux, echeances, paiements, paiement_allocations, budgets
--   - charges_refacturables, alertes_conformite, documents, user_societes
--   - relances, plans_apurement, plan_apurement_lignes, indexations_soumises
--   - loyers_variables_ca, provisions_indexation
-- ================================================================================
DO $$
DECLARE
  agent_policy_id UUID;
  collections_to_filter TEXT[] := ARRAY[
    'baux', 'echeances', 'paiements', 'paiement_allocations', 'budgets',
    'charges_refacturables', 'alertes_conformite', 'documents', 'user_societes',
    'relances', 'plans_apurement', 'plan_apurement_lignes',
    'indexations_soumises', 'loyers_variables_ca', 'provisions_indexation'
  ];
  collection_name TEXT;
  permission_filter JSON;
BEGIN
  SELECT current_setting('app.agent_policy_id')::UUID INTO agent_policy_id;

  FOREACH collection_name IN ARRAY collections_to_filter LOOP
    permission_filter := json_build_object(
      '_and', json_build_array(
        json_build_object(
          'societe_interne_id', json_build_object(
            '_in', '(SELECT societe_interne_id FROM public.user_societes WHERE directus_user_id = $CURRENT_USER)'
          )
        )
      )
    );

    -- READ
    IF NOT EXISTS (
      SELECT 1 FROM directus_permissions
      WHERE policy = agent_policy_id AND collection = collection_name AND action = 'read'
    ) THEN
      INSERT INTO directus_permissions (policy, collection, action, fields, permissions)
      VALUES (agent_policy_id, collection_name, 'read', '*', permission_filter);
    END IF;

    -- CREATE
    IF NOT EXISTS (
      SELECT 1 FROM directus_permissions
      WHERE policy = agent_policy_id AND collection = collection_name AND action = 'create'
    ) THEN
      INSERT INTO directus_permissions (policy, collection, action, fields, permissions)
      VALUES (agent_policy_id, collection_name, 'create', '*', permission_filter);
    END IF;

    -- UPDATE
    IF NOT EXISTS (
      SELECT 1 FROM directus_permissions
      WHERE policy = agent_policy_id AND collection = collection_name AND action = 'update'
    ) THEN
      INSERT INTO directus_permissions (policy, collection, action, fields, permissions)
      VALUES (agent_policy_id, collection_name, 'update', '*', permission_filter);
    END IF;

    -- DELETE
    IF NOT EXISTS (
      SELECT 1 FROM directus_permissions
      WHERE policy = agent_policy_id AND collection = collection_name AND action = 'delete'
    ) THEN
      INSERT INTO directus_permissions (policy, collection, action, permissions)
      VALUES (agent_policy_id, collection_name, 'delete', permission_filter);
    END IF;

  END LOOP;

END $$;

-- ================================================================================
-- 5. CREATE PERMISSIONS FOR RELATED COLLECTIONS (read-only)
-- Collections without direct societe_interne_id:
--   - societes_internes (read own only), entites, proprietes, biens, config_index
--   - indices, propriete_societes, journal_actions
-- ================================================================================
DO $$
DECLARE
  agent_policy_id UUID;
  collection_name TEXT;
BEGIN
  SELECT current_setting('app.agent_policy_id')::UUID INTO agent_policy_id;

  -- societes_internes: read only own assigned societes
  IF NOT EXISTS (
    SELECT 1 FROM directus_permissions
    WHERE policy = agent_policy_id AND collection = 'societes_internes' AND action = 'read'
  ) THEN
    INSERT INTO directus_permissions (policy, collection, action, fields, permissions)
    VALUES (
      agent_policy_id,
      'societes_internes',
      'read',
      '*',
      json_build_object(
        '_and', json_build_array(
          json_build_object(
            'id', json_build_object(
              '_in', '(SELECT DISTINCT societe_interne_id FROM public.user_societes WHERE directus_user_id = $CURRENT_USER)'
            )
          )
        )
      )
    );
  END IF;

  -- Read-only collections: entites, proprietes, biens, config_index, indices, propriete_societes, journal_actions
  FOREACH collection_name IN ARRAY ARRAY['entites', 'proprietes', 'biens', 'config_index', 'indices', 'propriete_societes', 'journal_actions'] LOOP
    IF NOT EXISTS (
      SELECT 1 FROM directus_permissions
      WHERE policy = agent_policy_id AND collection = collection_name AND action = 'read'
    ) THEN
      INSERT INTO directus_permissions (policy, collection, action, fields)
      VALUES (agent_policy_id, collection_name, 'read', '*');
    END IF;
  END LOOP;

END $$;

-- ================================================================================
-- Summary: Display created objects
-- ================================================================================
SELECT 'directus_roles (Agent)' AS item_type, COUNT(*) AS count
FROM directus_roles WHERE name = 'Agent'
UNION ALL
SELECT 'directus_policies (Agent)' AS item_type, COUNT(*) AS count
FROM directus_policies WHERE name = 'Agent'
UNION ALL
SELECT 'directus_permissions (Agent)' AS item_type, COUNT(*) AS count
FROM directus_permissions
WHERE policy IN (SELECT id FROM directus_policies WHERE name = 'Agent')
UNION ALL
SELECT 'directus_access (Agent->policy)' AS item_type, COUNT(*) AS count
FROM directus_access
WHERE role IN (SELECT id FROM directus_roles WHERE name = 'Agent')
  AND policy IN (SELECT id FROM directus_policies WHERE name = 'Agent');
