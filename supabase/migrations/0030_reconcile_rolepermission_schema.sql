-- Reconcile installations that created rolepermission from the legacy
-- permission-junction schema before the direct permissionname model.

ALTER TABLE public.rolepermission
  ADD COLUMN IF NOT EXISTS permissionname TEXT;

DO $$
BEGIN
  IF to_regclass('public.permissions') IS NOT NULL
     AND EXISTS (
       SELECT 1
       FROM information_schema.columns
       WHERE table_schema = 'public'
         AND table_name = 'permissions'
         AND column_name = 'code'
     )
     AND EXISTS (
       SELECT 1
       FROM information_schema.columns
       WHERE table_schema = 'public'
         AND table_name = 'rolepermission'
         AND column_name = 'permissionid'
     ) THEN
    EXECUTE '
      UPDATE public.rolepermission AS rp
      SET permissionname = p.code
      FROM public.permissions AS p
      WHERE rp.permissionid = p.id
        AND rp.permissionname IS NULL';
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS rolepermission_roleid_idx
  ON public.rolepermission (roleid);
