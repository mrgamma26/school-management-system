-- Repair deployments where the enum normalization migration was recorded as
-- applied but the original uppercase labels remained in the live schema.

DO $$
DECLARE
  status_name TEXT;
BEGIN
  FOREACH status_name IN ARRAY ARRAY[
    'ENROLLED', 'WITHDRAWN', 'GRADUATED', 'TRANSFERRED', 'SUSPENDED'
  ] LOOP
    IF EXISTS (
      SELECT 1
      FROM pg_enum e
      JOIN pg_type t ON t.oid = e.enumtypid
      WHERE t.typnamespace = 'public'::regnamespace
        AND t.typname = 'student_status_enum'
        AND e.enumlabel = status_name
    ) THEN
      EXECUTE format(
        'ALTER TYPE public.student_status_enum RENAME VALUE %L TO %L',
        status_name,
        lower(status_name)
      );
    END IF;
  END LOOP;
END $$;
DO $$
DECLARE
  enrolled_label TEXT;
BEGIN
  SELECT e.enumlabel
  INTO enrolled_label
  FROM pg_enum e
  JOIN pg_type t ON t.oid = e.enumtypid
  WHERE t.typnamespace = 'public'::regnamespace
    AND t.typname = 'student_status_enum'
    AND lower(e.enumlabel) = 'enrolled'
  ORDER BY e.enumsortorder
  LIMIT 1;

  IF enrolled_label IS NULL THEN
    SELECT e.enumlabel
    INTO enrolled_label
    FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typnamespace = 'public'::regnamespace
      AND t.typname = 'student_status_enum'
    ORDER BY e.enumsortorder
    LIMIT 1;
  END IF;

  IF enrolled_label IS NOT NULL THEN
    EXECUTE format(
      'ALTER TABLE public.student ALTER COLUMN enrollmentstatus SET DEFAULT %L::public.student_status_enum',
      enrolled_label
    );
  END IF;
END $$;
