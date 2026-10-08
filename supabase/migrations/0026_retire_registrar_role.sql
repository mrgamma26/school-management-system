-- Remove the legacy REGISTRAR alias from active RLS policies while preserving
-- each policy's table, command, roles, and remaining expressions.
DO $$
DECLARE
  policy_row RECORD;
  role_list TEXT;
  new_qual TEXT;
  new_with_check TEXT;
  policy_sql TEXT;
BEGIN
  FOR policy_row IN
    SELECT *
    FROM pg_policies
    WHERE schemaname = 'public'
      AND (qual ILIKE '%REGISTRAR%' OR with_check ILIKE '%REGISTRAR%')
  LOOP
    new_qual := policy_row.qual;
    new_with_check := policy_row.with_check;

    new_qual := replace(new_qual, ', ''REGISTRAR''', '');
    new_qual := replace(new_qual, '''REGISTRAR'', ', '');
    new_with_check := replace(new_with_check, ', ''REGISTRAR''', '');
    new_with_check := replace(new_with_check, '''REGISTRAR'', ', '');

    SELECT string_agg(format('%I', role_name), ', ' ORDER BY role_name)
    INTO role_list
    FROM unnest(policy_row.roles) AS role_name;

    EXECUTE format(
      'DROP POLICY %I ON %I.%I',
      policy_row.policyname,
      policy_row.schemaname,
      policy_row.tablename
    );

    -- Policies that existed only for REGISTRAR are intentionally retired.
    IF (new_qual IS NULL OR new_qual NOT ILIKE '%REGISTRAR%')
       AND (new_with_check IS NULL OR new_with_check NOT ILIKE '%REGISTRAR%')
       AND (new_qual IS NULL OR new_qual NOT LIKE '%IN ()%')
       AND (new_with_check IS NULL OR new_with_check NOT LIKE '%IN ()%') THEN
      policy_sql := format(
        'CREATE POLICY %I ON %I.%I %s FOR %s TO %s',
        policy_row.policyname,
        policy_row.schemaname,
        policy_row.tablename,
        CASE WHEN policy_row.permissive = 'PERMISSIVE' THEN '' ELSE 'AS RESTRICTIVE' END,
        policy_row.cmd,
        role_list
      );

      IF new_qual IS NOT NULL THEN
        policy_sql := policy_sql || format(' USING (%s)', new_qual);
      END IF;
      IF new_with_check IS NOT NULL THEN
        policy_sql := policy_sql || format(' WITH CHECK (%s)', new_with_check);
      END IF;

      EXECUTE policy_sql;
    END IF;
  END LOOP;
END $$;

-- The legacy role has no live users. Remove any leftover role permissions and
-- the role row itself so it cannot be assigned again.
DELETE FROM public.rolepermission
WHERE roleid IN (
  SELECT roleid FROM public.role WHERE upper(rolename) = 'REGISTRAR'
);

DELETE FROM public.role
WHERE upper(rolename) = 'REGISTRAR'
  AND NOT EXISTS (
    SELECT 1
    FROM public.systemuser
    WHERE systemuser.roleid = role.roleid
  );