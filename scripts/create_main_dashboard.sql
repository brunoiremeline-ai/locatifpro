-- Create/update a primary dashboard in Directus (idempotent)

DO $$
DECLARE
  dash_id uuid := '8a8a8a8a-1111-4444-8888-111111111111';
  panel_refresh_id uuid := '8a8a8a8a-2222-4444-8888-222222222222';
  panel_main_id uuid := '8a8a8a8a-3333-4444-8888-333333333333';
  creator_id uuid;
BEGIN
  SELECT id INTO creator_id
  FROM directus_users
  WHERE email = 'ebrunoir@groupecreo.com'
  LIMIT 1;

  IF creator_id IS NULL THEN
    SELECT id INTO creator_id FROM directus_users ORDER BY date_created ASC LIMIT 1;
  END IF;

  INSERT INTO directus_dashboards (id, name, icon, color, user_created)
  VALUES (dash_id, 'Dashboard Principal', 'space_dashboard', NULL, creator_id)
  ON CONFLICT (id)
  DO UPDATE SET name = EXCLUDED.name, icon = EXCLUDED.icon;

  INSERT INTO directus_panels (
    id, dashboard, name, icon, color, show_header, note, type,
    position_x, position_y, width, height, options, user_created
  )
  VALUES (
    panel_refresh_id, dash_id, 'Actualiser', 'sync', NULL, true,
    'Lancer la synchronisation des tables dash_* depuis les vues v_*',
    'refresh-dash-button',
    1, 1, 8, 8, '{}'::json, creator_id
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

  INSERT INTO directus_panels (
    id, dashboard, name, icon, color, show_header, note, type,
    position_x, position_y, width, height, options, user_created
  )
  VALUES (
    panel_main_id, dash_id, 'Vue Principale', 'dashboard', NULL, true,
    'Synthèse KPI et relances',
    'dashboard-main-overview',
    9, 1, 16, 16, '{}'::json, creator_id
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
