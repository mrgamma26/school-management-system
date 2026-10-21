-- Consolidate SYSTEM_ADMIN into the canonical SUPER_USER role.
-- Existing users keep their access, but only SUPER_USER remains selectable.

DO $$
DECLARE
  super_role_id UUID;
  system_role_id UUID;
BEGIN
  SELECT roleid INTO super_role_id
  FROM public.role
  WHERE rolename = 'SUPER_USER';

  IF super_role_id IS NULL THEN
    INSERT INTO public.role (rolename, description)
    VALUES ('SUPER_USER', 'Full platform access')
    RETURNING roleid INTO super_role_id;
  END IF;

  SELECT roleid INTO system_role_id
  FROM public.role
  WHERE rolename = 'SYSTEM_ADMIN';

  IF system_role_id IS NOT NULL THEN
    UPDATE public.systemuser
    SET roleid = super_role_id,
        updatedat = now()
    WHERE roleid = system_role_id;

    UPDATE public.rolepermission
    SET roleid = super_role_id
    WHERE roleid = system_role_id;

    DELETE FROM public.role
    WHERE roleid = system_role_id;
  END IF;
END $$;
