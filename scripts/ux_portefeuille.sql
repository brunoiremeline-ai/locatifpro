-- LocatifPro - UX Portefeuille (Directus v11)
-- Idempotent setup for menu group, readable relations, form organization, and list presets.

-- 1) Create/normalize a folder collection for the menu group
INSERT INTO directus_collections (collection, icon, note, hidden, singleton, sort)
SELECT 'portefeuille', 'workspaces', 'Navigation portefeuille (groupe UI).', false, false, 5
WHERE NOT EXISTS (
  SELECT 1 FROM directus_collections WHERE collection = 'portefeuille'
);

UPDATE directus_collections
SET
  icon = COALESCE(icon, 'workspaces'),
  note = COALESCE(note, 'Navigation portefeuille (groupe UI).'),
  hidden = false,
  singleton = false,
  accountability = NULL,
  collapse = 'open',
  sort = COALESCE(sort, 5)
WHERE collection = 'portefeuille';

-- 2) Place business collections under "Portefeuille"
UPDATE directus_collections SET "group" = 'portefeuille', sort = 10 WHERE collection = 'societes_internes';
UPDATE directus_collections SET "group" = 'portefeuille', sort = 11 WHERE collection = 'proprietes';
UPDATE directus_collections SET "group" = 'portefeuille', sort = 12 WHERE collection = 'biens';
UPDATE directus_collections SET "group" = 'portefeuille', sort = 13, hidden = true WHERE collection = 'propriete_societes';

-- 3) Human-readable titles in list/form references
UPDATE directus_collections
SET display_template = '[{{code}}] - {{groupe_interne}}/{{sous_groupe}}'
WHERE collection = 'societes_internes';

UPDATE directus_collections
SET display_template = '[{{code}}] - {{nom}}'
WHERE collection = 'proprietes';

UPDATE directus_collections
SET display_template = '[{{code}}] - {{ref_unite}}'
WHERE collection = 'biens';

UPDATE directus_collections
SET display_template = '[{{propriete_id.code}}] - [{{societe_interne_id.code}}]'
WHERE collection = 'propriete_societes';

-- 4) Relations metadata (M2O UI)
UPDATE directus_relations
SET
  one_field = 'propriete_societes',
  one_collection_field = NULL,
  junction_field = NULL
WHERE many_collection = 'propriete_societes'
  AND many_field = 'propriete_id'
  AND one_collection = 'proprietes';

UPDATE directus_relations
SET
  one_field = NULL,
  one_collection_field = NULL,
  junction_field = NULL
WHERE many_collection = 'propriete_societes'
  AND many_field = 'societe_interne_id'
  AND one_collection = 'societes_internes';

UPDATE directus_relations
SET one_field = NULL,
    one_collection_field = NULL
WHERE many_collection = 'biens'
  AND many_field = 'propriete_id'
  AND one_collection = 'proprietes';

-- Enable reverse relation on biens for occupancy filters (biens -> baux)
UPDATE directus_relations
SET one_field = 'baux',
    one_collection_field = 'baux'
WHERE many_collection = 'baux'
  AND many_field = 'bien_id'
  AND one_collection = 'biens';

-- Keep relation dropdowns readable for association table and lot->property relation
UPDATE directus_fields
SET
  interface = 'select-dropdown-m2o',
  display = 'related-values',
  display_options = '{"template":"[{{code}}] - {{nom}}"}'::json
WHERE collection = 'propriete_societes' AND field = 'propriete_id';

UPDATE directus_fields
SET
  interface = 'select-dropdown-m2o',
  display = 'related-values',
  display_options = '{"template":"[{{code}}] - {{groupe_interne}}/{{sous_groupe}}"}'::json
WHERE collection = 'propriete_societes' AND field = 'societe_interne_id';

UPDATE directus_fields
SET
  interface = 'select-dropdown-m2o',
  display = 'related-values',
  display_options = '{"template":"[{{code}}] - {{nom}}"}'::json
WHERE collection = 'biens' AND field = 'propriete_id';

-- Remove non-DB alias fields if previously injected by older UX attempts.
DELETE FROM directus_fields WHERE collection='societes_internes' AND field='proprietes';
DELETE FROM directus_fields WHERE collection='proprietes' AND field IN ('societes', 'lots');

INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, note)
SELECT 'proprietes', 'propriete_societes', 'alias,o2m', 'list-o2m', '{"template":"{{societe_interne_id.code}} (actif={{is_active}})"}'::json, 205, 'full', 'Affectations société liées à la propriété.'
WHERE NOT EXISTS (
  SELECT 1 FROM directus_fields WHERE collection='proprietes' AND field='propriete_societes'
);

UPDATE directus_fields
SET special='alias,o2m', interface='list-o2m', options='{"template":"{{societe_interne_id.code}} (actif={{is_active}})"}'::json, sort=205, width='full'
WHERE collection='proprietes' AND field='propriete_societes';

INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, note)
SELECT 'biens', 'baux', 'alias,o2m', 'list-o2m', '{"template":"{{code}} — {{statut}}"}'::json, 200, 'full', 'Baux liés au lot (utilisé par les filtres occupés/vacants).'
WHERE NOT EXISTS (
  SELECT 1 FROM directus_fields WHERE collection='biens' AND field='baux'
);

UPDATE directus_fields
SET special='alias,o2m', interface='list-o2m', options='{"template":"{{code}} — {{statut}}"}'::json, sort=200, width='full'
WHERE collection='biens' AND field='baux';

-- 5) Input interfaces (data entry)
UPDATE directus_fields SET interface='boolean' WHERE (collection, field) IN (
  ('societes_internes','is_active'),
  ('proprietes','is_active'),
  ('biens','is_active'),
  ('propriete_societes','is_active'),
  ('propriete_societes','par_defaut')
);

UPDATE directus_fields SET interface='input-multiline' WHERE (collection, field) IN (
  ('proprietes','commentaire'),
  ('biens','commentaire')
);

UPDATE directus_fields
SET options='{"placeholder":"RAS ou information utile de qualification."}'::json
WHERE collection='proprietes' AND field='commentaire';

UPDATE directus_fields
SET options='{"placeholder":"RAS ou précision utile sur le lot."}'::json
WHERE collection='biens' AND field='commentaire';

UPDATE directus_fields
SET interface='select-dropdown', options='{"choices":[{"text":"Immeuble","value":"Immeuble"},{"text":"Terrain","value":"Terrain"},{"text":"Local","value":"Local"},{"text":"Autre","value":"Autre"}]}'::json
WHERE collection='proprietes' AND field='type_propriete';

UPDATE directus_fields
SET interface='select-dropdown', options='{"choices":[{"text":"Lot","value":"Lot"},{"text":"Parking","value":"Parking"},{"text":"Local","value":"Local"},{"text":"Autre","value":"Autre"}]}'::json
WHERE collection='biens' AND field='type_bien';

UPDATE directus_fields SET interface='datetime' WHERE collection='propriete_societes' AND field IN ('date_debut','date_fin');

-- 6) Form sections/dividers
INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, readonly)
SELECT 'societes_internes', 'sec_infos', 'alias,no-data', 'presentation-divider', '{"title":"Infos"}'::json, 1, 'full', true
WHERE NOT EXISTS (SELECT 1 FROM directus_fields WHERE collection='societes_internes' AND field='sec_infos');

INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, readonly)
SELECT 'societes_internes', 'sec_affectations', 'alias,no-data', 'presentation-divider', '{"title":"Affectations"}'::json, 200, 'full', true
WHERE NOT EXISTS (SELECT 1 FROM directus_fields WHERE collection='societes_internes' AND field='sec_affectations');

INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, readonly)
SELECT 'proprietes', 'sec_infos', 'alias,no-data', 'presentation-divider', '{"title":"Infos"}'::json, 1, 'full', true
WHERE NOT EXISTS (SELECT 1 FROM directus_fields WHERE collection='proprietes' AND field='sec_infos');

INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, readonly)
SELECT 'proprietes', 'sec_adresse', 'alias,no-data', 'presentation-divider', '{"title":"Adresse"}'::json, 45, 'full', true
WHERE NOT EXISTS (SELECT 1 FROM directus_fields WHERE collection='proprietes' AND field='sec_adresse');

INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, readonly)
SELECT 'proprietes', 'sec_affectations', 'alias,no-data', 'presentation-divider', '{"title":"Affectations"}'::json, 200, 'full', true
WHERE NOT EXISTS (SELECT 1 FROM directus_fields WHERE collection='proprietes' AND field='sec_affectations');

INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, readonly)
SELECT 'biens', 'sec_infos', 'alias,no-data', 'presentation-divider', '{"title":"Infos"}'::json, 1, 'full', true
WHERE NOT EXISTS (SELECT 1 FROM directus_fields WHERE collection='biens' AND field='sec_infos');

INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, readonly)
SELECT 'biens', 'sec_affectations', 'alias,no-data', 'presentation-divider', '{"title":"Affectations"}'::json, 25, 'full', true
WHERE NOT EXISTS (SELECT 1 FROM directus_fields WHERE collection='biens' AND field='sec_affectations');

UPDATE directus_fields
SET special='alias,no-data', interface='presentation-divider', options='{"title":"Infos"}'::json, sort=1, width='full', readonly=true
WHERE collection='societes_internes' AND field='sec_infos';

UPDATE directus_fields
SET special='alias,no-data', interface='presentation-divider', options='{"title":"Affectations"}'::json, sort=200, width='full', readonly=true
WHERE collection='societes_internes' AND field='sec_affectations';

UPDATE directus_fields
SET special='alias,no-data', interface='presentation-divider', options='{"title":"Infos"}'::json, sort=1, width='full', readonly=true
WHERE collection='proprietes' AND field='sec_infos';

UPDATE directus_fields
SET special='alias,no-data', interface='presentation-divider', options='{"title":"Adresse"}'::json, sort=45, width='full', readonly=true
WHERE collection='proprietes' AND field='sec_adresse';

UPDATE directus_fields
SET special='alias,no-data', interface='presentation-divider', options='{"title":"Affectations"}'::json, sort=200, width='full', readonly=true
WHERE collection='proprietes' AND field='sec_affectations';

UPDATE directus_fields
SET special='alias,no-data', interface='presentation-divider', options='{"title":"Infos"}'::json, sort=1, width='full', readonly=true
WHERE collection='biens' AND field='sec_infos';

UPDATE directus_fields
SET special='alias,no-data', interface='presentation-divider', options='{"title":"Affectations"}'::json, sort=25, width='full', readonly=true
WHERE collection='biens' AND field='sec_affectations';

-- 7) Put required fields first; technical fields last
-- societes_internes
UPDATE directus_fields SET required = true, sort = 10, width = 'half' WHERE collection='societes_internes' AND field='code';
UPDATE directus_fields SET required = true, sort = 20, width = 'half' WHERE collection='societes_internes' AND field='entite_id';
UPDATE directus_fields SET required = true, sort = 30, width = 'half' WHERE collection='societes_internes' AND field='groupe_interne';
UPDATE directus_fields SET required = true, sort = 40, width = 'half' WHERE collection='societes_internes' AND field='sous_groupe';
UPDATE directus_fields SET required = true, sort = 50, width = 'full' WHERE collection='societes_internes' AND field='is_active';
UPDATE directus_fields SET hidden = true, sort = 999 WHERE collection='societes_internes' AND field='id';

-- proprietes
UPDATE directus_fields SET required = true, sort = 10, width = 'half' WHERE collection='proprietes' AND field='code';
UPDATE directus_fields SET required = true, sort = 20, width = 'half' WHERE collection='proprietes' AND field='nom';
UPDATE directus_fields SET required = true, sort = 30, width = 'half' WHERE collection='proprietes' AND field='type_propriete';
UPDATE directus_fields SET required = true, sort = 40, width = 'full' WHERE collection='proprietes' AND field='is_active';
UPDATE directus_fields SET required = true, sort = 50, width = 'full' WHERE collection='proprietes' AND field='adresse_ligne1';
UPDATE directus_fields SET sort = 60, width = 'full' WHERE collection='proprietes' AND field='adresse_ligne2';
UPDATE directus_fields SET required = true, sort = 70, width = 'half' WHERE collection='proprietes' AND field='code_postal';
UPDATE directus_fields SET required = true, sort = 80, width = 'half' WHERE collection='proprietes' AND field='ville';
UPDATE directus_fields SET required = true, sort = 90, width = 'half' WHERE collection='proprietes' AND field='pays';
UPDATE directus_fields SET required = true, sort = 100, width = 'half', note = 'Champ obligatoire (MLD): préciser la nature du bien.' WHERE collection='proprietes' AND field='nature';
UPDATE directus_fields SET required = true, sort = 110, width = 'half', note = 'Champ obligatoire (MLD): surface totale de référence.' WHERE collection='proprietes' AND field='surface_totale';
UPDATE directus_fields SET required = true, sort = 120, width = 'full', note = 'Champ obligatoire (MLD): indiquer \"RAS\" si aucune précision.' WHERE collection='proprietes' AND field='commentaire';
UPDATE directus_fields SET hidden = true, sort = 999 WHERE collection='proprietes' AND field='id';

-- biens
UPDATE directus_fields SET required = true, sort = 10, width = 'half' WHERE collection='biens' AND field='code';
UPDATE directus_fields SET required = true, sort = 20, width = 'half' WHERE collection='biens' AND field='ref_unite';
UPDATE directus_fields SET required = true, sort = 30, width = 'full' WHERE collection='biens' AND field='propriete_id';
UPDATE directus_fields SET required = true, sort = 40, width = 'half' WHERE collection='biens' AND field='type_bien';
UPDATE directus_fields SET required = true, sort = 50, width = 'half' WHERE collection='biens' AND field='is_active';
UPDATE directus_fields SET required = true, sort = 60, width = 'half' WHERE collection='biens' AND field='surface';
UPDATE directus_fields SET required = true, sort = 70, width = 'half' WHERE collection='biens' AND field='etage';
UPDATE directus_fields SET required = true, sort = 80, width = 'full' WHERE collection='biens' AND field='commentaire';
UPDATE directus_fields SET hidden = true, sort = 999 WHERE collection='biens' AND field='id';

-- propriete_societes (form usability)
UPDATE directus_fields SET required = true, sort = 10, width = 'half' WHERE collection='propriete_societes' AND field='propriete_id';
UPDATE directus_fields SET required = true, sort = 20, width = 'half' WHERE collection='propriete_societes' AND field='societe_interne_id';
UPDATE directus_fields SET required = true, sort = 30, width = 'half' WHERE collection='propriete_societes' AND field='quote_part_pct';
UPDATE directus_fields SET required = true, sort = 40, width = 'half' WHERE collection='propriete_societes' AND field='par_defaut';
UPDATE directus_fields SET required = true, sort = 50, width = 'half' WHERE collection='propriete_societes' AND field='date_debut';
UPDATE directus_fields SET sort = 60, width = 'half' WHERE collection='propriete_societes' AND field='date_fin';
UPDATE directus_fields SET required = true, sort = 70, width = 'full' WHERE collection='propriete_societes' AND field='is_active';
UPDATE directus_fields SET hidden = true, sort = 999 WHERE collection='propriete_societes' AND field='id';

-- 8) Useful list presets (global, user/role NULL)
-- Societes internes actives
WITH up AS (
  UPDATE directus_presets
  SET
    layout = 'tabular',
    icon = 'domain',
    color = 'primary',
    filter = '{"is_active":{"_eq":true}}'::json,
    layout_query = '{"sort":["code"]}'::json
  WHERE bookmark = 'societes-actives'
    AND collection = 'societes_internes'
    AND "user" IS NULL
    AND role IS NULL
  RETURNING 1
)
INSERT INTO directus_presets (bookmark, "user", role, collection, layout, layout_query, filter, icon, color)
SELECT 'societes-actives', NULL, NULL, 'societes_internes', 'tabular', '{"sort":["code"]}'::json, '{"is_active":{"_eq":true}}'::json, 'domain', 'primary'
WHERE NOT EXISTS (SELECT 1 FROM up);

-- Proprietes actives
WITH up AS (
  UPDATE directus_presets
  SET
    layout = 'tabular',
    icon = 'apartment',
    color = 'primary',
    filter = '{"is_active":{"_eq":true}}'::json,
    layout_query = '{"sort":["code"]}'::json
  WHERE bookmark = 'proprietes-actives'
    AND collection = 'proprietes'
    AND "user" IS NULL
    AND role IS NULL
  RETURNING 1
)
INSERT INTO directus_presets (bookmark, "user", role, collection, layout, layout_query, filter, icon, color)
SELECT 'proprietes-actives', NULL, NULL, 'proprietes', 'tabular', '{"sort":["code"]}'::json, '{"is_active":{"_eq":true}}'::json, 'apartment', 'primary'
WHERE NOT EXISTS (SELECT 1 FROM up);

-- Proprietes par societe (au moins une affectation active)
WITH up AS (
  UPDATE directus_presets
  SET
    layout = 'tabular',
    icon = 'share',
    color = 'warning',
    filter = '{"propriete_societes":{"_some":{"is_active":{"_eq":true}}}}'::json,
    layout_query = '{"sort":["code"]}'::json
  WHERE bookmark = 'proprietes-par-societe'
    AND collection = 'proprietes'
    AND "user" IS NULL
    AND role IS NULL
  RETURNING 1
)
INSERT INTO directus_presets (bookmark, "user", role, collection, layout, layout_query, filter, icon, color)
SELECT 'proprietes-par-societe', NULL, NULL, 'proprietes', 'tabular', '{"sort":["code"]}'::json, '{"propriete_societes":{"_some":{"is_active":{"_eq":true}}}}'::json, 'share', 'warning'
WHERE NOT EXISTS (SELECT 1 FROM up);

-- Lots/Biens actifs
WITH up AS (
  UPDATE directus_presets
  SET
    layout = 'tabular',
    icon = 'home',
    color = 'primary',
    filter = '{"is_active":{"_eq":true}}'::json,
    layout_query = '{"sort":["code"]}'::json
  WHERE bookmark = 'biens-actifs'
    AND collection = 'biens'
    AND "user" IS NULL
    AND role IS NULL
  RETURNING 1
)
INSERT INTO directus_presets (bookmark, "user", role, collection, layout, layout_query, filter, icon, color)
SELECT 'biens-actifs', NULL, NULL, 'biens', 'tabular', '{"sort":["code"]}'::json, '{"is_active":{"_eq":true}}'::json, 'home', 'primary'
WHERE NOT EXISTS (SELECT 1 FROM up);

-- Lots/Biens par propriete
WITH up AS (
  UPDATE directus_presets
  SET
    layout = 'tabular',
    icon = 'filter_alt',
    color = 'warning',
    filter = '{"propriete_id":{"_nnull":true}}'::json,
    layout_query = '{"sort":["propriete_id","code"]}'::json
  WHERE bookmark = 'biens-par-propriete'
    AND collection = 'biens'
    AND "user" IS NULL
    AND role IS NULL
  RETURNING 1
)
INSERT INTO directus_presets (bookmark, "user", role, collection, layout, layout_query, filter, icon, color)
SELECT 'biens-par-propriete', NULL, NULL, 'biens', 'tabular', '{"sort":["propriete_id","code"]}'::json, '{"propriete_id":{"_nnull":true}}'::json, 'filter_alt', 'warning'
WHERE NOT EXISTS (SELECT 1 FROM up);

-- Lots/Biens vacants (aucun bail ACTIF)
WITH up AS (
  UPDATE directus_presets
  SET
    layout = 'tabular',
    icon = 'meeting_room',
    color = 'warning',
    filter = '{"baux":{"_none":{"statut":{"_eq":"ACTIF"}}}}'::json,
    layout_query = '{"sort":["code"]}'::json
  WHERE bookmark = 'biens-vacants'
    AND collection = 'biens'
    AND "user" IS NULL
    AND role IS NULL
  RETURNING 1
)
INSERT INTO directus_presets (bookmark, "user", role, collection, layout, layout_query, filter, icon, color)
SELECT 'biens-vacants', NULL, NULL, 'biens', 'tabular', '{"sort":["code"]}'::json, '{"baux":{"_none":{"statut":{"_eq":"ACTIF"}}}}'::json, 'meeting_room', 'warning'
WHERE NOT EXISTS (SELECT 1 FROM up);

-- Lots/Biens occupes (au moins un bail ACTIF)
WITH up AS (
  UPDATE directus_presets
  SET
    layout = 'tabular',
    icon = 'key',
    color = 'success',
    filter = '{"baux":{"_some":{"statut":{"_eq":"ACTIF"}}}}'::json,
    layout_query = '{"sort":["code"]}'::json
  WHERE bookmark = 'biens-occupes'
    AND collection = 'biens'
    AND "user" IS NULL
    AND role IS NULL
  RETURNING 1
)
INSERT INTO directus_presets (bookmark, "user", role, collection, layout, layout_query, filter, icon, color)
SELECT 'biens-occupes', NULL, NULL, 'biens', 'tabular', '{"sort":["code"]}'::json, '{"baux":{"_some":{"statut":{"_eq":"ACTIF"}}}}'::json, 'key', 'success'
WHERE NOT EXISTS (SELECT 1 FROM up);

SELECT 'ux_portefeuille_applied' AS status;
