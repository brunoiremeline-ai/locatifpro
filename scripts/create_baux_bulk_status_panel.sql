-- Add/update panel "Statut en masse Baux" in Dashboard Principal (idempotent)

DO $$
DECLARE
  dash_id uuid := '8a8a8a8a-1111-4444-8888-111111111111';
  panel_id uuid := '8a8a8a8a-4444-4444-8888-444444444444';
  creator_id uuid;
BEGIN
  SELECT id INTO creator_id
  FROM directus_users
  WHERE email = 'ebrunoir@groupecreo.com'
  LIMIT 1;

  IF creator_id IS NULL THEN
    SELECT id INTO creator_id FROM directus_users ORDER BY id LIMIT 1;
  END IF;

  INSERT INTO directus_panels (
    id, dashboard, name, icon, color, show_header, note, type,
    position_x, position_y, width, height, options, user_created
  )
  VALUES (
    panel_id, dash_id, 'Statut Baux (masse)', 'rule_settings', NULL, true,
    'Previsualiser puis appliquer un changement de statut en masse (selection ou filtre).',
    'baux-bulk-status-tool',
    1, 9, 8, 8, '{}'::json, creator_id
  )
  ON CONFLICT (id)
  DO UPDATE SET
    dashboard = EXCLUDED.dashboard,
    name = EXCLUDED.name,
    type = EXCLUDED.type,
    position_x = EXCLUDED.position_x,
    position_y = EXCLUDED.position_y,
    width = EXCLUDED.width,
    height = EXCLUDED.height,
    note = EXCLUDED.note;
END $$;
