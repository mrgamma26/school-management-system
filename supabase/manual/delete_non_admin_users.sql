-- DESTRUCTIVE TEST RESET. Back up the database first.
-- Keeps SUPER_USER, SYSTEM_ADMIN, and ADMINISTRATOR accounts only.
BEGIN;

CREATE TEMP TABLE users_to_remove AS
SELECT su.userid
FROM public.systemuser su
JOIN public.role r ON r.roleid = su.roleid
WHERE upper(r.rolename) NOT IN (
  'SUPER_USER', 'SYSTEM_ADMIN', 'ADMINISTRATOR', 'ADMIN'
);

DELETE FROM public.studentguardian sg
USING public.guardian g
WHERE sg.guardianid = g.guardianid
  AND g.userid IN (SELECT userid FROM users_to_remove);

DELETE FROM public.classsubject cs
USING public.staff s
WHERE cs.staffid = s.staffid
  AND s.userid IN (SELECT userid FROM users_to_remove);

DELETE FROM public.teachercomment tc
USING public.staff s
WHERE tc.staffid = s.staffid
  AND s.userid IN (SELECT userid FROM users_to_remove);

DELETE FROM public.notification n
USING public.staff s
WHERE n.sentby = s.staffid
  AND s.userid IN (SELECT userid FROM users_to_remove);

UPDATE public.calendarevent
SET createdby = NULL, createdbyuser = NULL
WHERE createdbyuser IN (SELECT userid FROM users_to_remove)
   OR createdby IN (
     SELECT staffid FROM public.staff
     WHERE userid IN (SELECT userid FROM users_to_remove)
   );

DELETE FROM public.systemuser
WHERE userid IN (SELECT userid FROM users_to_remove);

DELETE FROM auth.users
WHERE id IN (SELECT userid FROM users_to_remove);

COMMIT;
