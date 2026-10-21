-- Keep enrollment_status compatible with the deployed database.
-- Existing deployments use lowercase labels; rename uppercase labels only
-- when they exist on a database created from the original migrations.

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typnamespace = 'public'::regnamespace
      AND t.typname = 'enrollment_status'
      AND e.enumlabel = 'ENROLLED'
  ) THEN
    ALTER TYPE public.enrollment_status RENAME VALUE 'ENROLLED' TO 'enrolled';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typnamespace = 'public'::regnamespace
      AND t.typname = 'enrollment_status'
      AND e.enumlabel = 'WITHDRAWN'
  ) THEN
    ALTER TYPE public.enrollment_status RENAME VALUE 'WITHDRAWN' TO 'withdrawn';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typnamespace = 'public'::regnamespace
      AND t.typname = 'enrollment_status'
      AND e.enumlabel = 'GRADUATED'
  ) THEN
    ALTER TYPE public.enrollment_status RENAME VALUE 'GRADUATED' TO 'graduated';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typnamespace = 'public'::regnamespace
      AND t.typname = 'enrollment_status'
      AND e.enumlabel = 'TRANSFERRED'
  ) THEN
    ALTER TYPE public.enrollment_status RENAME VALUE 'TRANSFERRED' TO 'transferred';
  END IF;

  IF EXISTS (
    SELECT 1 FROM pg_enum e
    JOIN pg_type t ON t.oid = e.enumtypid
    WHERE t.typnamespace = 'public'::regnamespace
      AND t.typname = 'enrollment_status'
      AND e.enumlabel = 'SUSPENDED'
  ) THEN
    ALTER TYPE public.enrollment_status RENAME VALUE 'SUSPENDED' TO 'suspended';
  END IF;
END $$;
