-- Force Directus locale defaults to French (idempotent)

-- Instance default language
UPDATE directus_settings
SET default_language = 'fr-FR'
WHERE id = 1
  AND (default_language IS DISTINCT FROM 'fr-FR');

-- User locale defaults (avoid manual setting after reset/recreate)
UPDATE directus_users
SET language = 'fr-FR'
WHERE language IS DISTINCT FROM 'fr-FR';

-- Optional: keep left-to-right explicit
UPDATE directus_users
SET text_direction = 'ltr'
WHERE text_direction IS DISTINCT FROM 'ltr';

SELECT 'ux_set_french_applied' AS status;
