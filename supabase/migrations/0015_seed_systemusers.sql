-- 0015_seed_systemusers.sql
-- Run this ONCE in the Supabase SQL Editor to create systemuser rows
-- for every auth.users account that doesn't already have one.
--
-- BEFORE running:
--   1. Make sure your roles exist in the role table.
--   2. Check which roles you have: SELECT roleid, rolename FROM role;
--   3. Replace the email→rolename mappings in the VALUES block below
--      to match the actual emails you created in Auth > Users.
--
-- STEP 1 — See what roles exist
SELECT roleid, rolename FROM public.role ORDER BY rolename;
-- STEP 2 — See which auth users already have a systemuser row
SELECT
    u.id            AS auth_user_id,
    u.email,
    u.created_at,
    su.userid       AS systemuser_exists
FROM auth.users u
LEFT JOIN public.systemuser su ON su.userid = u.id
ORDER BY u.created_at;
-- STEP 3 — Insert missing systemuser rows
-- Edit the email → rolename pairs to match your actual test accounts.
INSERT INTO public.systemuser (userid, username, roleid, mustchangepassword, isactive)
SELECT
    u.id                                AS userid,
    split_part(u.email, '@', 1)         AS username,
    r.roleid,
    false                               AS mustchangepassword,
    true                                AS isactive
FROM auth.users u
JOIN (
    VALUES
        -- email                     rolename
        ('admin@school.com',        'SUPER_USER'),
        ('registrar@school.com',    'ADMINISTRATOR'),
        ('teacher@school.com',      'TEACHER'),
        ('headteacher@school.com',  'HEAD_TEACHER'),
        ('accountant@school.com',   'ACCOUNTANT'),
        ('parent@school.com',       'GUARDIAN')
        -- Add or change rows above to match the emails you created
) AS mapping(email, rolename) ON u.email = mapping.email
JOIN public.role r ON r.rolename = mapping.rolename
-- Skip any user that already has a systemuser row
WHERE NOT EXISTS (
    SELECT 1 FROM public.systemuser su WHERE su.userid = u.id
);
-- STEP 4 — Verify the result
SELECT
    su.userid,
    su.username,
    r.rolename,
    su.isactive,
    su.mustchangepassword
FROM public.systemuser su
JOIN public.role r ON r.roleid = su.roleid
ORDER BY r.rolename;
