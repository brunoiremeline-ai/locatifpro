-- Fix idempotent: avoid Directus crash "parentItem[parentRelationField].push is not a function".
-- Cause: directus_relations.one_field points to a real scalar DB column on one_collection
-- (commonly "id"), while Directus expects a virtual O2M alias or NULL.

with collisions as (
  select dr.id
  from directus_relations dr
  join information_schema.columns c
    on c.table_schema = 'public'
   and c.table_name = dr.one_collection
   and c.column_name = dr.one_field
  where dr.one_field is not null
),
patched as (
  update directus_relations dr
     set one_field = null
   where dr.id in (select id from collisions)
  returning 1
)
select count(*)::int as relations_patchees from patched;
