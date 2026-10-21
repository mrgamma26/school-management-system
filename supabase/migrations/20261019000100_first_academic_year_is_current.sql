-- Ensure a school cannot finish initial academic setup without a current year.
-- The advisory lock makes simultaneous first-year inserts deterministic, while
-- the existing partial unique index remains the final one-current invariant.
CREATE OR REPLACE FUNCTION public.default_first_academic_year_current()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  PERFORM pg_advisory_xact_lock(hashtextextended('school_academic_years:first-current', 0));
  IF NOT EXISTS (SELECT 1 FROM public.school_academic_years WHERE is_current) THEN
    NEW.is_current := true;
    NEW.status := 'ACTIVE';
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS default_first_academic_year_current
  ON public.school_academic_years;
CREATE TRIGGER default_first_academic_year_current
BEFORE INSERT ON public.school_academic_years
FOR EACH ROW EXECUTE FUNCTION public.default_first_academic_year_current();

-- Repair installations where the first year was saved before this rule.
DO $$
DECLARE
  first_year_id uuid;
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.school_academic_years WHERE is_current) THEN
    SELECT year.academic_year_id
    INTO first_year_id
    FROM public.school_academic_years year
    WHERE (
      SELECT count(*)
      FROM public.academic_year_terms term
      WHERE term.academic_year_id = year.academic_year_id
    ) = 3
    ORDER BY year.start_date, year.created_at, year.academic_year_id
    LIMIT 1;

    IF first_year_id IS NOT NULL THEN
      UPDATE public.school_academic_years
      SET is_current = true, status = 'ACTIVE'
      WHERE academic_year_id = first_year_id;
    END IF;
  END IF;
END;
$$;
