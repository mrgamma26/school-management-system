-- 0003_auth_bridge.sql
-- Links systemuser.userid to auth.users(id) via a foreign key.
-- Run AFTER 0002_tables.sql and AFTER the Supabase project is live.
-- Safe to run multiple times.

-- Add the FK only if it doesn't already exist
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.table_constraints
    WHERE constraint_schema = 'public'
      AND table_name        = 'systemuser'
      AND constraint_name   = 'fk_systemuser_authuser'
  ) THEN
    ALTER TABLE public.systemuser
      ADD CONSTRAINT fk_systemuser_authuser
      FOREIGN KEY (userid)
      REFERENCES auth.users(id)
      ON DELETE CASCADE;
  END IF;
END $$;
-- Seed the canonical role set (safe to re-run — ON CONFLICT is a no-op).
INSERT INTO public.role (rolename, description) VALUES
  ('ADMINISTRATOR', 'Manages student and account registration'),
  ('TEACHER',       'Manages assessments and grades'),
  ('HEAD_TEACHER',  'Approves progression and school-level decisions'),
  ('ACCOUNTANT',    'Manages financial workflows'),
  ('GUARDIAN',      'Views linked student information'),
  ('SYSTEM_ADMIN',  'System configuration and administration'),
  ('SUPER_USER',    'Full platform access')
ON CONFLICT (rolename) DO NOTHING;
