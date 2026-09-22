-- 0013_schema_fixes.sql
-- Fixes two known column-name mismatches between the migration schema and
-- the Flutter repository code.  Run AFTER 0012_calendar_event_type.sql.
--
-- Mismatch 1: class table
--   Migration 0002 created: classname, formlevel
--   AcademicRepository queries: classroomname, form
--   Fix: add alias columns so both names work, then rename to match repo.
--
-- Mismatch 2: auditlog table
--   Migration 0002 created: usertype (TEXT)
--   AuditService writes to: actorrole
--   Fix: rename column.

-- ─────────────────────────────────────────────
-- 1. class table — rename classname → classroomname, formlevel → form
-- ─────────────────────────────────────────────
DO $$
BEGIN
  -- Only rename if the old column still exists
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'class'
      AND column_name  = 'classname'
  ) THEN
    ALTER TABLE public.class RENAME COLUMN classname  TO classroomname;
  END IF;

  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'class'
      AND column_name  = 'formlevel'
  ) THEN
    ALTER TABLE public.class RENAME COLUMN formlevel TO form;
  END IF;
END $$;

-- Drop the old UNIQUE constraint on classname and add one on classroomname
-- (only if it doesn't already exist under the new name)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.class'::regclass
      AND conname  = 'class_classroomname_key'
  ) THEN
    ALTER TABLE public.class ADD CONSTRAINT class_classroomname_key UNIQUE (classroomname);
  END IF;
END $$;

-- ─────────────────────────────────────────────
-- 2. auditlog table — rename usertype → actorrole
-- ─────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name   = 'auditlog'
      AND column_name  = 'usertype'
  ) THEN
    ALTER TABLE public.auditlog RENAME COLUMN usertype TO actorrole;
  END IF;
END $$;
