-- Fix idempotent: évite le crash Directus "parentItem[parentRelationField].push is not a function"
-- Cause: directus_relations.one_field pointe sur un vrai champ SCALAIRE de directus_users -> Directus croit que c'est une liste et fait .push()

with collisions as (
  select dr.id
  from directus_relations dr
  join information_schema.columns c
    on c.table_schema = 'public'
   and c.table_name   = 'directus_users'
   and c.column_name  = dr.one_field
  where dr.one_collection = 'directus_users'
    and dr.one_field is not null
),
patched as (
  update directus_relations dr
     set one_field = null
   where dr.id in (select id from collisions)
  returning 1
)
select count(*)::int as relations_patchees from patched;
