BEGIN;

-- During an UPDATE, exclude the row being replaced when validating the
-- resulting role set. This permits a primary role to be changed in place,
-- while still rejecting any combination other than Teacher + Head Teacher.
CREATE OR REPLACE FUNCTION public.validate_user_role_pair()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public, pg_catalog
AS $$
DECLARE v_roles text[];
BEGIN
  IF TG_OP = 'UPDATE' THEN
    SELECT array_agg(upper(r.rolename) ORDER BY upper(r.rolename)) INTO v_roles
    FROM (
      SELECT role_id FROM public.user_roles
      WHERE user_id = NEW.user_id AND role_id <> OLD.role_id
      UNION
      SELECT NEW.role_id
    ) chosen
    JOIN public.role r ON r.roleid = chosen.role_id;
  ELSE
    SELECT array_agg(upper(r.rolename) ORDER BY upper(r.rolename)) INTO v_roles
    FROM (
      SELECT role_id FROM public.user_roles WHERE user_id = NEW.user_id
      UNION
      SELECT NEW.role_id
    ) chosen
    JOIN public.role r ON r.roleid = chosen.role_id;
  END IF;

  IF cardinality(v_roles) > 2 OR
     (cardinality(v_roles) = 2 AND v_roles <> ARRAY['HEAD_TEACHER', 'TEACHER']::text[]) THEN
    RAISE EXCEPTION 'Only the Teacher and Head Teacher dual-role combination is permitted';
  END IF;
  RETURN NEW;
END;
$$;

-- The legacy systemuser.roleid remains the primary-role field used by user
-- management. Mirror it into the normalized role table without deleting any
-- secondary assignments.
CREATE OR REPLACE FUNCTION public.sync_primary_user_role()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_catalog
AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND NEW.roleid IS NOT DISTINCT FROM OLD.roleid THEN
    RETURN NEW;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.user_roles
    WHERE user_id = NEW.userid AND role_id = NEW.roleid
  ) THEN
    UPDATE public.user_roles SET is_primary = false
    WHERE user_id = NEW.userid AND is_primary;
    UPDATE public.user_roles SET is_primary = true
    WHERE user_id = NEW.userid AND role_id = NEW.roleid;
  ELSE
    UPDATE public.user_roles SET role_id = NEW.roleid
    WHERE user_id = NEW.userid AND is_primary;
    IF NOT FOUND THEN
      INSERT INTO public.user_roles (user_id, role_id, is_primary, created_by)
      VALUES (NEW.userid, NEW.roleid, true, auth.uid());
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS sync_primary_user_role_trigger ON public.systemuser;
CREATE TRIGGER sync_primary_user_role_trigger
AFTER INSERT OR UPDATE OF roleid ON public.systemuser
FOR EACH ROW EXECUTE FUNCTION public.sync_primary_user_role();

REVOKE ALL ON FUNCTION public.sync_primary_user_role() FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';
COMMIT;
