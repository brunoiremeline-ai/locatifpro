-- Durable guardrail: provide explicit conflict error before exclusion constraint.
-- Keeps the exclusion constraint as the final integrity lock.

CREATE OR REPLACE FUNCTION public.fn_baux_actif_conflict_message()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_conflict RECORD;
  v_new_period text;
  v_conflict_period text;
BEGIN
  IF NEW.statut <> 'ACTIF' THEN
    RETURN NEW;
  END IF;

  SELECT
    b.id,
    b.code,
    b.bien_id,
    b.date_effet,
    b.date_fin_contractuelle
  INTO v_conflict
  FROM baux b
  WHERE b.statut = 'ACTIF'
    AND b.id <> COALESCE(NEW.id, '00000000-0000-0000-0000-000000000000'::uuid)
    AND b.bien_id = NEW.bien_id
    AND daterange(b.date_effet, COALESCE(b.date_fin_contractuelle, 'infinity'::date), '[]')
        && daterange(NEW.date_effet, COALESCE(NEW.date_fin_contractuelle, 'infinity'::date), '[]')
  ORDER BY b.date_effet
  LIMIT 1;

  IF FOUND THEN
    v_new_period := to_char(NEW.date_effet, 'YYYY-MM-DD') || ' -> ' || COALESCE(to_char(NEW.date_fin_contractuelle, 'YYYY-MM-DD'), 'infini');
    v_conflict_period := to_char(v_conflict.date_effet, 'YYYY-MM-DD') || ' -> ' || COALESCE(to_char(v_conflict.date_fin_contractuelle, 'YYYY-MM-DD'), 'infini');

    RAISE EXCEPTION USING
      ERRCODE = 'P0001',
      MESSAGE = format(
        'Conflit ACTIF sur lot %s: bail cible %s [%s] chevauche bail existant %s [%s].',
        NEW.bien_id,
        COALESCE(NEW.code, NEW.id::text),
        v_new_period,
        COALESCE(v_conflict.code, v_conflict.id::text),
        v_conflict_period
      ),
      DETAIL = format(
        'lot=%s; bail_cible_id=%s; bail_conflit_id=%s',
        NEW.bien_id,
        COALESCE(NEW.id::text, 'null'),
        v_conflict.id
      ),
      HINT = 'Passez le bail en conflit a CLOS/LITIGE ou ajustez les dates avant de mettre ce bail en ACTIF.';
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_baux_actif_conflict_message ON baux;

CREATE TRIGGER trg_baux_actif_conflict_message
BEFORE INSERT OR UPDATE OF statut, bien_id, date_effet, date_fin_contractuelle
ON baux
FOR EACH ROW
EXECUTE FUNCTION public.fn_baux_actif_conflict_message();

