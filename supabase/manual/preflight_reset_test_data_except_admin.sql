-- READ ONLY. Safe preflight for reset_all_test_data_except_admin_school_com.sql.
-- This file does not update or delete anything.

SELECT
  (SELECT count(*) FROM auth.users WHERE lower(email) = 'admin@school.com')
    AS preserved_admin_auth_rows,
  (SELECT count(*)
   FROM auth.users au
   JOIN public.systemuser su ON su.userid = au.id
   WHERE lower(au.email) = 'admin@school.com')
    AS preserved_admin_linked_rows,
  (SELECT count(*) FROM auth.users WHERE lower(coalesce(email, '')) <> 'admin@school.com')
    AS auth_users_to_remove,
  (SELECT count(*) FROM public.systemuser
   WHERE userid <> (SELECT id FROM auth.users WHERE lower(email) = 'admin@school.com'))
    AS system_users_to_remove,
  (SELECT count(*) FROM public.student) AS students_to_remove,
  (SELECT count(*) FROM public.staff) AS staff_profiles_to_remove,
  (SELECT count(*) FROM public.guardian) AS guardians_to_remove,
  (SELECT count(*) FROM public.payment) AS payments_to_remove,
  (SELECT count(*) FROM public.deposit_slips) AS deposit_slips_to_remove,
  (SELECT count(*) FROM public.payment_arrangements) AS arrangements_to_remove,
  (SELECT count(*) FROM public.assessment) AS assessments_to_remove,
  (SELECT count(*) FROM public.grade) AS grades_to_remove,
  (SELECT count(*) FROM public.school_academic_years) AS academic_years_to_remove,
  (SELECT count(*) FROM storage.objects
   WHERE bucket_id IN ('deposit-slips', 'staff-profiles', 'school-branding'))
    AS storage_objects_to_remove_via_api;

SELECT bucket_id, count(*) AS objects_to_remove_via_api
FROM storage.objects
WHERE bucket_id IN ('deposit-slips', 'staff-profiles', 'school-branding')
GROUP BY bucket_id
ORDER BY bucket_id;
