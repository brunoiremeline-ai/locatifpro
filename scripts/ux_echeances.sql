-- LocatifPro - UX Echeances (Directus v11)
-- Idempotent setup for Echeances navigation, form usability, and list presets.

-- 1) Sidebar group/folder for Echeances
INSERT INTO directus_collections (collection, icon, note, hidden, singleton, sort)
SELECT 'menu_echeances', 'calendar_month', 'Navigation echeances/quittancement (groupe UI).', false, false, 30
WHERE NOT EXISTS (
  SELECT 1 FROM directus_collections WHERE collection = 'menu_echeances'
);

UPDATE directus_collections
SET
  icon = COALESCE(icon, 'calendar_month'),
  note = COALESCE(note, 'Navigation echeances/quittancement (groupe UI).'),
  hidden = false,
  singleton = false,
  accountability = NULL,
  translations = COALESCE(
    translations,
    '[{"language":"fr-FR","translation":"Echeances"},{"language":"en-US","translation":"Installments"}]'::json
  ),
  collapse = 'open',
  sort = COALESCE(sort, 30)
WHERE collection = 'menu_echeances';

-- 2) Place useful collections under Echeances group
UPDATE directus_collections
SET "group" = 'menu_echeances', sort = 31, hidden = false
WHERE collection = 'echeances';

UPDATE directus_collections
SET "group" = 'menu_echeances', sort = 32, hidden = true
WHERE collection = 'v_echeances_reste_a_payer';

-- 3) Human-readable titles
UPDATE directus_collections
SET display_template = '[{{periode}}] - {{statut}} - {{bail_id.code}}'
WHERE collection = 'echeances';

-- 4) Relations metadata + reverse list on bail
UPDATE directus_relations
SET one_field = 'echeances',
    one_collection_field = 'echeances'
WHERE many_collection = 'echeances'
  AND many_field = 'bail_id'
  AND one_collection = 'baux';

INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, note)
SELECT 'baux', 'echeances', 'alias,o2m', 'list-o2m', '{"template":"{{periode}} — {{statut}} — {{montant_total}}"}'::json, 440, 'full', 'Echeances generees pour ce bail.'
WHERE NOT EXISTS (
  SELECT 1 FROM directus_fields WHERE collection='baux' AND field='echeances'
);

UPDATE directus_fields
SET special='alias,o2m', interface='list-o2m', options='{"template":"{{periode}} — {{statut}} — {{montant_total}}"}'::json, sort=440, width='full'
WHERE collection='baux' AND field='echeances';

-- 5) Relation dropdowns readable
UPDATE directus_fields
SET
  interface = 'select-dropdown-m2o',
  display = 'related-values',
  display_options = '{"template":"[{{code}}] - {{statut}}"}'::json
WHERE collection = 'echeances' AND field = 'bail_id';

UPDATE directus_fields
SET
  interface = 'select-dropdown-m2o',
  display = 'related-values',
  display_options = '{"template":"[{{code}}] - {{groupe_interne}}/{{sous_groupe}}"}'::json
WHERE collection = 'echeances' AND field = 'societe_interne_id';

-- 6) Input interfaces
UPDATE directus_fields
SET interface='select-dropdown', options='{"choices":[{"text":"Previsionnel","value":"PREVISIONNEL"},{"text":"Facture","value":"FACTURE"},{"text":"Paye","value":"PAYE"},{"text":"Litige","value":"LITIGE"}]}'::json
WHERE collection='echeances' AND field='statut';

UPDATE directus_fields SET interface='datetime' WHERE collection='echeances' AND field IN ('date_debut_periode','date_fin_periode','date_echeance');
UPDATE directus_fields SET interface='boolean' WHERE collection='echeances' AND field IN ('indexation_appliquee','impaye_flag');
UPDATE directus_fields SET interface='input' WHERE collection='echeances' AND field IN ('periode','montant_loyer','montant_charges','montant_taxe_fonciere_refacturee','montant_total');

-- 7) Form sections
INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, readonly)
SELECT 'echeances', 'sec_contexte', 'alias,no-data', 'presentation-divider', '{"title":"Contexte"}'::json, 1, 'full', true
WHERE NOT EXISTS (SELECT 1 FROM directus_fields WHERE collection='echeances' AND field='sec_contexte');

INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, readonly)
SELECT 'echeances', 'sec_periode', 'alias,no-data', 'presentation-divider', '{"title":"Periode"}'::json, 100, 'full', true
WHERE NOT EXISTS (SELECT 1 FROM directus_fields WHERE collection='echeances' AND field='sec_periode');

INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, readonly)
SELECT 'echeances', 'sec_montants', 'alias,no-data', 'presentation-divider', '{"title":"Montants"}'::json, 200, 'full', true
WHERE NOT EXISTS (SELECT 1 FROM directus_fields WHERE collection='echeances' AND field='sec_montants');

INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, readonly)
SELECT 'echeances', 'sec_suivi', 'alias,no-data', 'presentation-divider', '{"title":"Suivi"}'::json, 300, 'full', true
WHERE NOT EXISTS (SELECT 1 FROM directus_fields WHERE collection='echeances' AND field='sec_suivi');

UPDATE directus_fields SET special='alias,no-data', interface='presentation-divider', options='{"title":"Contexte"}'::json, sort=1, width='full', readonly=true WHERE collection='echeances' AND field='sec_contexte';
UPDATE directus_fields SET special='alias,no-data', interface='presentation-divider', options='{"title":"Periode"}'::json, sort=100, width='full', readonly=true WHERE collection='echeances' AND field='sec_periode';
UPDATE directus_fields SET special='alias,no-data', interface='presentation-divider', options='{"title":"Montants"}'::json, sort=200, width='full', readonly=true WHERE collection='echeances' AND field='sec_montants';
UPDATE directus_fields SET special='alias,no-data', interface='presentation-divider', options='{"title":"Suivi"}'::json, sort=300, width='full', readonly=true WHERE collection='echeances' AND field='sec_suivi';

-- 8) Field order / required flags
UPDATE directus_fields SET hidden=true, sort=999 WHERE collection='echeances' AND field='id';

-- Contexte
UPDATE directus_fields SET required=true, sort=10, width='half' WHERE collection='echeances' AND field='bail_id';
UPDATE directus_fields SET required=true, sort=20, width='half' WHERE collection='echeances' AND field='societe_interne_id';
UPDATE directus_fields SET required=true, sort=30, width='half', note='Format AAAA-MM, unique par bail.' WHERE collection='echeances' AND field='periode';
UPDATE directus_fields SET required=true, sort=40, width='half' WHERE collection='echeances' AND field='statut';

-- Periode
UPDATE directus_fields SET required=true, sort=110, width='half' WHERE collection='echeances' AND field='date_debut_periode';
UPDATE directus_fields SET required=true, sort=120, width='half' WHERE collection='echeances' AND field='date_fin_periode';
UPDATE directus_fields SET required=true, sort=130, width='half' WHERE collection='echeances' AND field='date_echeance';

-- Montants
UPDATE directus_fields SET required=true, sort=210, width='half' WHERE collection='echeances' AND field='montant_loyer';
UPDATE directus_fields SET required=true, sort=220, width='half' WHERE collection='echeances' AND field='montant_charges';
UPDATE directus_fields SET required=true, sort=230, width='half' WHERE collection='echeances' AND field='montant_taxe_fonciere_refacturee';
UPDATE directus_fields SET sort=240, width='half' WHERE collection='echeances' AND field='montant_total';

-- Suivi
UPDATE directus_fields SET required=true, sort=310, width='half' WHERE collection='echeances' AND field='indexation_appliquee';
UPDATE directus_fields SET required=true, sort=320, width='half' WHERE collection='echeances' AND field='impaye_flag';

-- 9) Useful list presets
WITH up AS (
  UPDATE directus_presets
  SET layout='tabular', icon='today', color='warning',
      filter='{"date_debut_periode":{"_lte":"$NOW"},"date_fin_periode":{"_gte":"$NOW"}}'::json,
      layout_query='{"sort":["date_echeance","bail_id","periode"]}'::json
  WHERE bookmark='echeances-periode-en-cours' AND collection='echeances' AND "user" IS NULL AND role IS NULL
  RETURNING 1
)
INSERT INTO directus_presets (bookmark,"user",role,collection,layout,layout_query,filter,icon,color)
SELECT 'echeances-periode-en-cours',NULL,NULL,'echeances','tabular','{"sort":["date_echeance","bail_id","periode"]}'::json,'{"date_debut_periode":{"_lte":"$NOW"},"date_fin_periode":{"_gte":"$NOW"}}'::json,'today','warning'
WHERE NOT EXISTS (SELECT 1 FROM up);

WITH up AS (
  UPDATE directus_presets
  SET layout='tabular', icon='receipt_long', color='primary',
      filter='{"statut":{"_eq":"PREVISIONNEL"}}'::json,
      layout_query='{"sort":["date_echeance","bail_id"]}'::json
  WHERE bookmark='echeances-a-facturer' AND collection='echeances' AND "user" IS NULL AND role IS NULL
  RETURNING 1
)
INSERT INTO directus_presets (bookmark,"user",role,collection,layout,layout_query,filter,icon,color)
SELECT 'echeances-a-facturer',NULL,NULL,'echeances','tabular','{"sort":["date_echeance","bail_id"]}'::json,'{"statut":{"_eq":"PREVISIONNEL"}}'::json,'receipt_long','primary'
WHERE NOT EXISTS (SELECT 1 FROM up);

WITH up AS (
  UPDATE directus_presets
  SET layout='tabular', icon='payments', color='warning',
      filter='{"statut":{"_eq":"FACTURE"},"impaye_flag":{"_eq":true}}'::json,
      layout_query='{"sort":["date_echeance","bail_id"]}'::json
  WHERE bookmark='echeances-a-encaisser' AND collection='echeances' AND "user" IS NULL AND role IS NULL
  RETURNING 1
)
INSERT INTO directus_presets (bookmark,"user",role,collection,layout,layout_query,filter,icon,color)
SELECT 'echeances-a-encaisser',NULL,NULL,'echeances','tabular','{"sort":["date_echeance","bail_id"]}'::json,'{"statut":{"_eq":"FACTURE"},"impaye_flag":{"_eq":true}}'::json,'payments','warning'
WHERE NOT EXISTS (SELECT 1 FROM up);

WITH up AS (
  UPDATE directus_presets
  SET layout='tabular', icon='gavel', color='danger',
      filter='{"statut":{"_eq":"LITIGE"}}'::json,
      layout_query='{"sort":["-date_echeance","bail_id"]}'::json
  WHERE bookmark='echeances-en-litige' AND collection='echeances' AND "user" IS NULL AND role IS NULL
  RETURNING 1
)
INSERT INTO directus_presets (bookmark,"user",role,collection,layout,layout_query,filter,icon,color)
SELECT 'echeances-en-litige',NULL,NULL,'echeances','tabular','{"sort":["-date_echeance","bail_id"]}'::json,'{"statut":{"_eq":"LITIGE"}}'::json,'gavel','danger'
WHERE NOT EXISTS (SELECT 1 FROM up);

WITH up AS (
  UPDATE directus_presets
  SET layout='tabular', icon='description', color='primary',
      filter='{"bail_id":{"_nnull":true}}'::json,
      layout_query='{"sort":["bail_id","-periode"]}'::json
  WHERE bookmark='echeances-par-bail' AND collection='echeances' AND "user" IS NULL AND role IS NULL
  RETURNING 1
)
INSERT INTO directus_presets (bookmark,"user",role,collection,layout,layout_query,filter,icon,color)
SELECT 'echeances-par-bail',NULL,NULL,'echeances','tabular','{"sort":["bail_id","-periode"]}'::json,'{"bail_id":{"_nnull":true}}'::json,'description','primary'
WHERE NOT EXISTS (SELECT 1 FROM up);

WITH up AS (
  UPDATE directus_presets
  SET layout='tabular', icon='domain', color='primary',
      filter='{"societe_interne_id":{"_nnull":true}}'::json,
      layout_query='{"sort":["societe_interne_id","-periode","bail_id"]}'::json
  WHERE bookmark='echeances-par-societe' AND collection='echeances' AND "user" IS NULL AND role IS NULL
  RETURNING 1
)
INSERT INTO directus_presets (bookmark,"user",role,collection,layout,layout_query,filter,icon,color)
SELECT 'echeances-par-societe',NULL,NULL,'echeances','tabular','{"sort":["societe_interne_id","-periode","bail_id"]}'::json,'{"societe_interne_id":{"_nnull":true}}'::json,'domain','primary'
WHERE NOT EXISTS (SELECT 1 FROM up);

SELECT 'ux_echeances_applied' AS status;
