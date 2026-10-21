-- Lets an authenticated user complete their own forced-password-change flow
-- without granting them permission to alter any other systemuser field.
BEGIN;
CREATE OR REPLACE FUNCTION public.complete_current_user_password_change()
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
  UPDATE public.systemuser
  SET mustchangepassword = false
  WHERE userid = auth.uid();

  IF NOT FOUND THEN
    RAISE EXCEPTION 'System user profile was not found.' USING ERRCODE = 'P0002';
  END IF;
END;
$$;
REVOKE ALL ON FUNCTION public.complete_current_user_password_change() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.complete_current_user_password_change() TO authenticated;
COMMIT;
