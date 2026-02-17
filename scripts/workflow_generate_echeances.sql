-- Wrapper psql pour la fonction source de verite: public.workflow_generate_echeances
-- Modes supportes:
-- 1) Global: -v start_date=YYYY-MM-DD -v end_date=YYYY-MM-DD
-- 2) Par bail: -v bail_id=UUID [-v start_period=YYYY-MM] [-v periods=12] [-v include_start=true|false]

\if :{?start_date}
\else
\set start_date ''
\endif
\if :{?end_date}
\else
\set end_date ''
\endif
\if :{?bail_id}
\else
\set bail_id ''
\endif
\if :{?start_period}
\else
\set start_period ''
\endif
\if :{?periods}
\else
\set periods '12'
\endif
\if :{?include_start}
\else
\set include_start 'true'
\endif
\if :{?mode}
\else
\set mode 'skip'
\endif

SELECT *
FROM public.workflow_generate_echeances(
  NULLIF(:'bail_id','')::uuid,
  NULLIF(:'start_date','')::date,
  NULLIF(:'end_date','')::date,
  NULLIF(:'start_period',''),
  COALESCE(NULLIF(:'periods','')::int, 12),
  NULLIF(:'include_start',''),
  COALESCE(NULLIF(:'mode',''), 'skip')
);
