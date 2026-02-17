-- LocatifPro - UX Baux (Directus v11)
-- Idempotent setup for Baux navigation, form usability, and list presets.

-- 1) Sidebar group/folder for Baux
INSERT INTO directus_collections (collection, icon, note, hidden, singleton, sort)
SELECT 'menu_baux', 'description', 'Navigation baux (groupe UI).', false, false, 20
WHERE NOT EXISTS (
  SELECT 1 FROM directus_collections WHERE collection = 'menu_baux'
);

UPDATE directus_collections
SET
  icon = COALESCE(icon, 'description'),
  note = COALESCE(note, 'Navigation baux (groupe UI).'),
  hidden = false,
  singleton = false,
  accountability = NULL,
  translations = COALESCE(
    translations,
    '[{"language":"fr-FR","translation":"Baux"},{"language":"en-US","translation":"Leases"}]'::json
  ),
  collapse = 'open',
  sort = COALESCE(sort, 20)
WHERE collection = 'menu_baux';

-- 2) Place useful collections under Baux group
UPDATE directus_collections
SET "group" = 'menu_baux', sort = 21, hidden = false
WHERE collection = 'baux';

-- Keep advanced step-2 collections available but hidden by default
UPDATE directus_collections
SET "group" = 'menu_baux', sort = 22, hidden = true
WHERE collection = 'indexations_soumises';

UPDATE directus_collections
SET "group" = 'menu_baux', sort = 23, hidden = true
WHERE collection = 'loyers_variables_ca';

-- 3) Human-readable titles
UPDATE directus_collections
SET display_template = '[{{code}}] - {{statut}} - {{bien_id.code}}'
WHERE collection = 'baux';

-- 4) Relation dropdowns readable
UPDATE directus_fields
SET
  interface = 'select-dropdown-m2o',
  display = 'related-values',
  display_options = '{"template":"[{{code}}] - {{groupe_interne}}/{{sous_groupe}}"}'::json
WHERE collection = 'baux' AND field = 'societe_interne_id';

UPDATE directus_fields
SET
  interface = 'select-dropdown-m2o',
  display = 'related-values',
  display_options = '{"template":"[{{code}}] - {{ref_unite}}"}'::json
WHERE collection = 'baux' AND field = 'bien_id';

UPDATE directus_fields
SET
  interface = 'select-dropdown-m2o',
  display = 'related-values',
  display_options = '{"template":"[{{code}}] - {{nom_affichage}}"}'::json
WHERE collection = 'baux' AND field IN ('bailleur_entite_id', 'preneur_entite_id');

UPDATE directus_fields
SET
  interface = 'select-dropdown-m2o',
  display = 'related-values',
  display_options = '{"template":"[{{code}}] - {{statut}}"}'::json
WHERE collection = 'baux' AND field = 'bail_miroir_id';

-- 5) Input interfaces (guided V1)
UPDATE directus_fields
SET interface='select-dropdown', options='{"choices":[{"text":"FUTUR (Brouillon)","value":"BROUILLON"},{"text":"ACTIF","value":"ACTIF"},{"text":"TERMINE","value":"CLOS"},{"text":"RESILIE/LITIGE","value":"LITIGE"}]}'::json
WHERE collection='baux' AND field='statut';

UPDATE directus_fields
SET interface='select-dropdown', options='{"choices":[{"text":"Entrant","value":"ENTRANT"},{"text":"Sortant","value":"SORTANT"}]}'::json,
    note='Sens opérationnel (entrant/sortant).'
WHERE collection='baux' AND field='sens';

UPDATE directus_fields
SET interface='select-dropdown', options='{"choices":[{"text":"Direct","value":"DIRECT"},{"text":"Sous-location","value":"SOUS_LOCATION"}]}'::json,
    note='Relation au bien (direct/sous-location).'
WHERE collection='baux' AND field='relation';

UPDATE directus_fields
SET interface='select-dropdown', options='{"choices":[{"text":"Habitation","value":"HABITATION"},{"text":"Commercial","value":"COMMERCIAL"},{"text":"Professionnel","value":"PROFESSIONNEL"},{"text":"Autre","value":"AUTRE"}]}'::json
WHERE collection='baux' AND field='type_bail';

UPDATE directus_fields
SET interface='select-dropdown', options='{"choices":[{"text":"Aucune","value":"AUCUNE"},{"text":"Tacite","value":"TACITE"},{"text":"Expresse","value":"EXPRESSE"}]}'::json
WHERE collection='baux' AND field='reconduction';

UPDATE directus_fields
SET interface='select-dropdown', options='{"choices":[{"text":"Mensuel","value":"MENSUEL"},{"text":"Trimestriel","value":"TRIMESTRIEL"},{"text":"Annuel","value":"ANNUEL"}]}'::json
WHERE collection='baux' AND field='periodicite';

UPDATE directus_fields
SET interface='select-dropdown', options='{"choices":[{"text":"Aucune","value":"AUCUNE"},{"text":"Forfait","value":"FORFAIT"},{"text":"Provisions","value":"PROVISIONS"}]}'::json
WHERE collection='baux' AND field='charges_mode';

UPDATE directus_fields SET interface='datetime' WHERE collection='baux' AND field IN ('date_effet','date_fin_contractuelle');
UPDATE directus_fields SET interface='boolean' WHERE collection='baux' AND field IN ('tf_refacturable','indexation_clause_prevue','indexation_active');
UPDATE directus_fields SET interface='input' WHERE collection='baux' AND field IN ('loyer_base','charges_provision','tf_provision','loyer_variable_pct_ca','loyer_variable_plancher_valeur_base','loyer_variable_plafond_valeur_base');
UPDATE directus_fields SET interface='input-multiline', options='{"placeholder":"Informations complémentaires (optionnel)."}'::json WHERE collection='baux' AND field='code_analytique';

-- 6) Form sections
INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, readonly)
SELECT 'baux', 'sec_contexte', 'alias,no-data', 'presentation-divider', '{"title":"Contexte"}'::json, 1, 'full', true
WHERE NOT EXISTS (SELECT 1 FROM directus_fields WHERE collection='baux' AND field='sec_contexte');

INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, readonly)
SELECT 'baux', 'sec_dates', 'alias,no-data', 'presentation-divider', '{"title":"Dates"}'::json, 100, 'full', true
WHERE NOT EXISTS (SELECT 1 FROM directus_fields WHERE collection='baux' AND field='sec_dates');

INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, readonly)
SELECT 'baux', 'sec_financier', 'alias,no-data', 'presentation-divider', '{"title":"Financier"}'::json, 200, 'full', true
WHERE NOT EXISTS (SELECT 1 FROM directus_fields WHERE collection='baux' AND field='sec_financier');

INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, readonly)
SELECT 'baux', 'sec_indexation', 'alias,no-data', 'presentation-divider', '{"title":"Indexation"}'::json, 300, 'full', true
WHERE NOT EXISTS (SELECT 1 FROM directus_fields WHERE collection='baux' AND field='sec_indexation');

INSERT INTO directus_fields (collection, field, special, interface, options, sort, width, readonly)
SELECT 'baux', 'sec_notes', 'alias,no-data', 'presentation-divider', '{"title":"Notes / Pieces"}'::json, 400, 'full', true
WHERE NOT EXISTS (SELECT 1 FROM directus_fields WHERE collection='baux' AND field='sec_notes');

INSERT INTO directus_fields (collection, field, special, interface, sort, width, readonly, note)
SELECT 'baux', 'action_generer_echeances', 'alias,no-data', 'generate-echeances-action', 430, 'full', true, 'Action: generer les echeances previsionnelles (anti-doublon).'
WHERE NOT EXISTS (SELECT 1 FROM directus_fields WHERE collection='baux' AND field='action_generer_echeances');

UPDATE directus_fields SET special='alias,no-data', interface='presentation-divider', options='{"title":"Contexte"}'::json, sort=1, width='full', readonly=true WHERE collection='baux' AND field='sec_contexte';
UPDATE directus_fields SET special='alias,no-data', interface='presentation-divider', options='{"title":"Dates"}'::json, sort=100, width='full', readonly=true WHERE collection='baux' AND field='sec_dates';
UPDATE directus_fields SET special='alias,no-data', interface='presentation-divider', options='{"title":"Financier"}'::json, sort=200, width='full', readonly=true WHERE collection='baux' AND field='sec_financier';
UPDATE directus_fields SET special='alias,no-data', interface='presentation-divider', options='{"title":"Indexation"}'::json, sort=300, width='full', readonly=true WHERE collection='baux' AND field='sec_indexation';
UPDATE directus_fields SET special='alias,no-data', interface='presentation-divider', options='{"title":"Notes / Pieces"}'::json, sort=400, width='full', readonly=true WHERE collection='baux' AND field='sec_notes';
UPDATE directus_fields SET special='alias,no-data', interface='generate-echeances-action', sort=430, width='full', readonly=true WHERE collection='baux' AND field='action_generer_echeances';

-- 7) Field order and required flags (aligned with DB constraints)
UPDATE directus_fields SET hidden=true, sort=999 WHERE collection='baux' AND field='id';

-- Contexte
UPDATE directus_fields SET required=true, sort=10, width='half', note='Identifiant bail (obligatoire).' WHERE collection='baux' AND field='code';
UPDATE directus_fields SET required=true, sort=20, width='half' WHERE collection='baux' AND field='societe_interne_id';
UPDATE directus_fields SET required=true, sort=30, width='half' WHERE collection='baux' AND field='bien_id';
UPDATE directus_fields SET required=true, sort=40, width='half' WHERE collection='baux' AND field='sens';
UPDATE directus_fields SET required=true, sort=50, width='half' WHERE collection='baux' AND field='relation';
UPDATE directus_fields SET required=true, sort=60, width='half' WHERE collection='baux' AND field='type_bail';
UPDATE directus_fields SET required=true, sort=70, width='half' WHERE collection='baux' AND field='statut';
UPDATE directus_fields SET required=true, sort=80, width='half', note='Obligatoire MLD: entité bailleur.' WHERE collection='baux' AND field='bailleur_entite_id';
UPDATE directus_fields SET required=true, sort=90, width='half', note='Obligatoire MLD: entité preneur.' WHERE collection='baux' AND field='preneur_entite_id';

-- Dates
UPDATE directus_fields SET required=true, sort=110, width='half', note='Date de prise d''effet (obligatoire).' WHERE collection='baux' AND field='date_effet';
UPDATE directus_fields SET sort=120, width='half' WHERE collection='baux' AND field='date_fin_contractuelle';
UPDATE directus_fields SET required=true, sort=130, width='half' WHERE collection='baux' AND field='reconduction';
UPDATE directus_fields SET sort=140, width='half' WHERE collection='baux' AND field='date_exigibilite_jour';

-- Financier (echeances)
UPDATE directus_fields SET required=true, sort=210, width='half' WHERE collection='baux' AND field='periodicite';
UPDATE directus_fields SET required=true, sort=220, width='half' WHERE collection='baux' AND field='loyer_base';
UPDATE directus_fields SET sort=230, width='half' WHERE collection='baux' AND field='charges_mode';
UPDATE directus_fields SET sort=240, width='half' WHERE collection='baux' AND field='charges_provision';
UPDATE directus_fields SET sort=250, width='half' WHERE collection='baux' AND field='tf_refacturable';
UPDATE directus_fields SET sort=260, width='half' WHERE collection='baux' AND field='tf_provision';

-- Indexation
UPDATE directus_fields SET sort=310, width='half' WHERE collection='baux' AND field='indexation_clause_prevue';
UPDATE directus_fields SET sort=320, width='half' WHERE collection='baux' AND field='indexation_active';
UPDATE directus_fields SET sort=330, width='half' WHERE collection='baux' AND field='loyer_variable_pct_ca';
UPDATE directus_fields SET sort=340, width='half' WHERE collection='baux' AND field='loyer_variable_plancher_mode';
UPDATE directus_fields SET sort=350, width='half' WHERE collection='baux' AND field='loyer_variable_plancher_valeur_base';
UPDATE directus_fields SET sort=360, width='half' WHERE collection='baux' AND field='loyer_variable_plancher_indice_type';
UPDATE directus_fields SET sort=370, width='half' WHERE collection='baux' AND field='loyer_variable_plancher_indice_ref_periode';
UPDATE directus_fields SET sort=380, width='half' WHERE collection='baux' AND field='loyer_variable_plafond_mode';
UPDATE directus_fields SET sort=390, width='half' WHERE collection='baux' AND field='loyer_variable_plafond_valeur_base';
UPDATE directus_fields SET sort=391, width='half' WHERE collection='baux' AND field='loyer_variable_plafond_indice_type';
UPDATE directus_fields SET sort=392, width='half' WHERE collection='baux' AND field='loyer_variable_plafond_indice_ref_periode';

-- Notes / pièces / technique
UPDATE directus_fields SET sort=410, width='half' WHERE collection='baux' AND field='code_analytique';
UPDATE directus_fields SET sort=420, width='half' WHERE collection='baux' AND field='interne_reciprocite_requise';
UPDATE directus_fields SET sort=425, width='half' WHERE collection='baux' AND field='bail_miroir_id';

-- 8) Useful list presets
WITH up AS (
  UPDATE directus_presets
  SET layout='tabular', icon='check_circle', color='success',
      filter='{"statut":{"_eq":"ACTIF"}}'::json,
      layout_query='{"sort":["-date_effet","code"]}'::json
  WHERE bookmark='baux-actifs' AND collection='baux' AND "user" IS NULL AND role IS NULL
  RETURNING 1
)
INSERT INTO directus_presets (bookmark,"user",role,collection,layout,layout_query,filter,icon,color)
SELECT 'baux-actifs',NULL,NULL,'baux','tabular','{"sort":["-date_effet","code"]}'::json,'{"statut":{"_eq":"ACTIF"}}'::json,'check_circle','success'
WHERE NOT EXISTS (SELECT 1 FROM up);

WITH up AS (
  UPDATE directus_presets
  SET layout='tabular', icon='schedule', color='warning',
      filter='{"_or":[{"statut":{"_eq":"BROUILLON"}},{"date_effet":{"_gt":"$NOW"}}]}'::json,
      layout_query='{"sort":["date_effet","code"]}'::json
  WHERE bookmark='baux-futurs' AND collection='baux' AND "user" IS NULL AND role IS NULL
  RETURNING 1
)
INSERT INTO directus_presets (bookmark,"user",role,collection,layout,layout_query,filter,icon,color)
SELECT 'baux-futurs',NULL,NULL,'baux','tabular','{"sort":["date_effet","code"]}'::json,'{"_or":[{"statut":{"_eq":"BROUILLON"}},{"date_effet":{"_gt":"$NOW"}}]}'::json,'schedule','warning'
WHERE NOT EXISTS (SELECT 1 FROM up);

WITH up AS (
  UPDATE directus_presets
  SET layout='tabular', icon='inventory_2', color='primary',
      filter='{"statut":{"_in":["CLOS","LITIGE"]}}'::json,
      layout_query='{"sort":["-date_effet","code"]}'::json
  WHERE bookmark='baux-termines-resilies' AND collection='baux' AND "user" IS NULL AND role IS NULL
  RETURNING 1
)
INSERT INTO directus_presets (bookmark,"user",role,collection,layout,layout_query,filter,icon,color)
SELECT 'baux-termines-resilies',NULL,NULL,'baux','tabular','{"sort":["-date_effet","code"]}'::json,'{"statut":{"_in":["CLOS","LITIGE"]}}'::json,'inventory_2','primary'
WHERE NOT EXISTS (SELECT 1 FROM up);

WITH up AS (
  UPDATE directus_presets
  SET layout='tabular', icon='domain', color='primary',
      filter='{"societe_interne_id":{"_nnull":true}}'::json,
      layout_query='{"sort":["societe_interne_id","-date_effet","code"]}'::json
  WHERE bookmark='baux-par-societe' AND collection='baux' AND "user" IS NULL AND role IS NULL
  RETURNING 1
)
INSERT INTO directus_presets (bookmark,"user",role,collection,layout,layout_query,filter,icon,color)
SELECT 'baux-par-societe',NULL,NULL,'baux','tabular','{"sort":["societe_interne_id","-date_effet","code"]}'::json,'{"societe_interne_id":{"_nnull":true}}'::json,'domain','primary'
WHERE NOT EXISTS (SELECT 1 FROM up);

SELECT 'ux_baux_applied' AS status;
