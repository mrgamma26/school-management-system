-- Normalize role comparisons and make academic-year inserts explicit.

CREATE OR REPLACE FUNCTION public.current_app_role()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT upper(r.rolename)
  FROM public.systemuser su
  JOIN public.role r ON r.roleid = su.roleid
  WHERE su.userid = auth.uid()
    AND su.isactive = true
$$;

DROP POLICY IF EXISTS "admins manage academic years" ON public.academicyear;
CREATE POLICY "admins manage academic years"
ON public.academicyear FOR ALL TO authenticated
USING (
  upper(coalesce(public.current_app_role(), '')) IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR', 'HEAD_TEACHER'
  )
)
WITH CHECK (
  upper(coalesce(public.current_app_role(), '')) IN (
    'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'REGISTRAR', 'HEAD_TEACHER'
  )
);