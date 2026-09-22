-- 0005_functions.sql
-- Utility database functions used by RLS policies and business logic.

-- ─────────────────────────────────────────────
-- current_app_role()
-- Returns the rolename of the currently authenticated user.
-- SECURITY DEFINER so it can read systemuser/role regardless of RLS.
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.current_app_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT r.rolename
  FROM public.systemuser su
  JOIN public.role r ON r.roleid = su.roleid
  WHERE su.userid = auth.uid()
    AND su.isactive = true
$$;

-- ─────────────────────────────────────────────
-- is_app_role(expected text)
-- Returns true when the authenticated user has the given role.
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.is_app_role(expected text)
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT upper(coalesce(public.current_app_role(), '')) = upper(expected)
$$;

-- ─────────────────────────────────────────────
-- close_current_class_placement(student_id uuid)
-- Sets enddate = CURRENT_DATE on the active studentclasshistory row.
-- Call this before inserting a new placement.
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.close_current_class_placement(student_id uuid)
RETURNS void
LANGUAGE sql
AS $$
  UPDATE public.studentclasshistory
  SET enddate   = CURRENT_DATE,
      updatedat = now()
  WHERE studentid = student_id
    AND enddate IS NULL;
$$;

-- ─────────────────────────────────────────────
-- updated_at trigger function
-- Automatically keeps updatedat current on any UPDATE.
-- ─────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updatedat = now();
  RETURN NEW;
END;
$$;

-- Attach the trigger to all tables that have updatedat
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOREACH tbl IN ARRAY ARRAY[
    'role', 'systemuser', 'staff', 'guardian',
    'academicyear', 'class', 'subject', 'classsubject',
    'student', 'studentclasshistory',
    'assessment', 'grade',
    'progressionreview', 'weedingreview'
  ]
  LOOP
    EXECUTE format(
      'DROP TRIGGER IF EXISTS trg_set_updated_at ON public.%I;
       CREATE TRIGGER trg_set_updated_at
         BEFORE UPDATE ON public.%I
         FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();',
      tbl, tbl
    );
  END LOOP;
END;
$$;
