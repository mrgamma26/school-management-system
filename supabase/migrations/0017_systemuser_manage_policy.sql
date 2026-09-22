-- 0017_systemuser_manage_policy.sql
-- FIX 1: Update systemuser RLS management policy to allow SUPER_USER, 
-- SYSTEM_ADMIN, and ADMINISTRATOR (not just SYSTEM_ADMIN alone).
--
-- Previously: Only SYSTEM_ADMIN could manage systemuser records.
-- Now: SUPER_USER, SYSTEM_ADMIN, and ADMINISTRATOR can all manage systemuser.
--
-- This ensures that ADMINISTRATOR role can deactivate/reactivate users
-- without hitting RLS violations.

-- Drop the old policy that only allowed SYSTEM_ADMIN
DROP POLICY IF EXISTS "admins can manage system users" ON public.systemuser;

-- Create new policy allowing SUPER_USER, SYSTEM_ADMIN, and ADMINISTRATOR
CREATE POLICY "privileged roles manage systemusers"
ON public.systemuser FOR ALL TO authenticated
USING (
  public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR')
)
WITH CHECK (
  public.current_app_role() IN ('SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR')
);
