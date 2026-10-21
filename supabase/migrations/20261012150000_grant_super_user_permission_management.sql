DO $$
DECLARE
  super_user_role_id UUID;
BEGIN
  SELECT roleid
  INTO super_user_role_id
  FROM public.role
  WHERE rolename = 'SUPER_USER';

  IF super_user_role_id IS NULL THEN
    RAISE EXCEPTION 'Cannot grant permissions:manage: SUPER_USER role is missing.';
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.rolepermission
    WHERE roleid = super_user_role_id
      AND permissionname = 'permissions:manage'
  ) THEN
    IF EXISTS (
      SELECT 1
      FROM information_schema.columns
      WHERE table_schema = 'public'
        AND table_name = 'rolepermission'
        AND column_name = 'permission'
    ) THEN
      EXECUTE
        'INSERT INTO public.rolepermission (roleid, permission, permissionname)
         VALUES ($1, $2, $2)'
        USING super_user_role_id, 'permissions:manage';
    ELSE
      INSERT INTO public.rolepermission (roleid, permissionname)
      VALUES (super_user_role_id, 'permissions:manage');
    END IF;
  END IF;
END
$$;
