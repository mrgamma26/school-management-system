-- Link the manually created Supabase Auth users to application profiles.
-- Safe to re-run: only these three email addresses are changed.

WITH requested_users(email, rolename) AS (
  VALUES
    ('admin@example.com', 'SUPER_USER'),
    ('teacher@example.com', 'TEACHER'),
    ('parent@example.com', 'GUARDIAN')
), resolved AS (
  SELECT
    u.id AS userid,
    lower(u.email) AS username,
    r.roleid
  FROM auth.users u
  JOIN requested_users requested
    ON lower(u.email) = requested.email
  JOIN public.role r
    ON r.rolename = requested.rolename
)
INSERT INTO public.systemuser (
  userid,
  username,
  roleid,
  mustchangepassword,
  isactive
)
SELECT
  userid,
  username,
  roleid,
  false,
  true
FROM resolved
ON CONFLICT (userid) DO UPDATE SET
  username = EXCLUDED.username,
  roleid = EXCLUDED.roleid,
  isactive = true;

-- Verify all requested Auth users now have active application profiles.
SELECT
  u.email,
  su.userid,
  r.rolename,
  su.isactive
FROM auth.users u
JOIN public.systemuser su ON su.userid = u.id
JOIN public.role r ON r.roleid = su.roleid
WHERE lower(u.email) IN (
  'admin@example.com',
  'teacher@example.com',
  'parent@example.com'
)
ORDER BY u.email;
