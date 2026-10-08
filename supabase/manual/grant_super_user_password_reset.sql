-- Run once in Supabase SQL Editor, then sign out and sign back in.
-- Restores the User Details > Reset Password button for the SUPER_USER role.

INSERT INTO public.rolepermission (roleid, permissionname)
SELECT r.roleid, 'users:reset_password'
FROM public.role AS r
WHERE r.rolename = 'SUPER_USER'
ON CONFLICT DO NOTHING;

SELECT r.rolename, rp.permissionname
FROM public.rolepermission AS rp
JOIN public.role AS r ON r.roleid = rp.roleid
WHERE r.rolename = 'SUPER_USER'
  AND rp.permissionname = 'users:reset_password';
