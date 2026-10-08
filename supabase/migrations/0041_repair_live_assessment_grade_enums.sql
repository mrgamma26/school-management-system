-- Keep assessment and grade enums compatible with both the canonical schema
-- and the older deployed schema, whose enum type names end in `_enum`.

DO $$
DECLARE
  enum_name text;
  enum_value text;
BEGIN
  FOREACH enum_name IN ARRAY ARRAY['assessment_type', 'assessment_type_enum']
  LOOP
    IF to_regtype(format('public.%I', enum_name)) IS NOT NULL THEN
      EXECUTE format(
        'ALTER TYPE public.%I ADD VALUE IF NOT EXISTS %L',
        enum_name,
        'END_OF_TERM'
      );
    END IF;
  END LOOP;

  FOREACH enum_name IN ARRAY ARRAY['grade_status', 'grade_status_enum']
  LOOP
    IF to_regtype(format('public.%I', enum_name)) IS NOT NULL THEN
      FOREACH enum_value IN ARRAY ARRAY[
        'PENDING',
        'PRESENT',
        'ABSENT',
        'MISSING',
        'INCOMPLETE',
        'FINAL'
      ]
      LOOP
        EXECUTE format(
          'ALTER TYPE public.%I ADD VALUE IF NOT EXISTS %L',
          enum_name,
          enum_value
        );
      END LOOP;
    END IF;
  END LOOP;

  FOREACH enum_name IN ARRAY ARRAY[
    'grade_submission_status',
    'grade_submission_status_enum'
  ]
  LOOP
    IF to_regtype(format('public.%I', enum_name)) IS NOT NULL THEN
      FOREACH enum_value IN ARRAY ARRAY['DRAFT', 'SUBMITTED']
      LOOP
        EXECUTE format(
          'ALTER TYPE public.%I ADD VALUE IF NOT EXISTS %L',
          enum_name,
          enum_value
        );
      END LOOP;
    END IF;
  END LOOP;
END
$$;

NOTIFY pgrst, 'reload schema';
