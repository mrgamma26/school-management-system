-- 0029_seed_role_permissions.sql
-- Seeds role-to-permission mappings with role hierarchy.
-- SUPER_ADMIN inherits all permissions. ADMIN inherits most. MANAGER inherits common permissions. etc.
-- Run AFTER all roles are created (0021_consolidate_super_user_role.sql).

DO $$
DECLARE
  super_admin_role UUID;
  admin_role UUID;
  manager_role UUID;
  staff_role UUID;
  teacher_role UUID;
  customer_role UUID;
  guest_role UUID;
BEGIN
  -- Get all role IDs
  SELECT roleid INTO super_admin_role FROM public.role WHERE rolename = 'SUPER_ADMIN' LIMIT 1;
  SELECT roleid INTO admin_role FROM public.role WHERE rolename = 'ADMIN' LIMIT 1;
  SELECT roleid INTO manager_role FROM public.role WHERE rolename = 'MANAGER' LIMIT 1;
  SELECT roleid INTO staff_role FROM public.role WHERE rolename = 'STAFF' LIMIT 1;
  SELECT roleid INTO teacher_role FROM public.role WHERE rolename = 'TEACHER' LIMIT 1;
  SELECT roleid INTO customer_role FROM public.role WHERE rolename = 'CUSTOMER' LIMIT 1;
  SELECT roleid INTO guest_role FROM public.role WHERE rolename = 'GUEST' LIMIT 1;

  -- ──────────────────────────────────────────────────────────────────
  -- SUPER_ADMIN: All permissions (platform-wide control)
  -- ──────────────────────────────────────────────────────────────────
  IF super_admin_role IS NOT NULL THEN
    INSERT INTO public.rolepermission (roleid, permissionname)
    VALUES
      (super_admin_role, 'users:create'),
      (super_admin_role, 'users:read'),
      (super_admin_role, 'users:write'),
      (super_admin_role, 'users:deactivate'),
      (super_admin_role, 'users:reset_password'),
      (super_admin_role, 'permissions:manage'),
      (super_admin_role, 'staff:write'),
      (super_admin_role, 'staff:read'),
      (super_admin_role, 'guardians:write'),
      (super_admin_role, 'guardians:read'),
      (super_admin_role, 'students:enrol'),
      (super_admin_role, 'students:write'),
      (super_admin_role, 'students:read'),
      (super_admin_role, 'academics:write'),
      (super_admin_role, 'academics:read'),
      (super_admin_role, 'assessments:write'),
      (super_admin_role, 'assessments:read'),
      (super_admin_role, 'grades:write'),
      (super_admin_role, 'grades:read'),
      (super_admin_role, 'finance:write'),
      (super_admin_role, 'finance:manage_structures'),
      (super_admin_role, 'finance:read'),
      (super_admin_role, 'payments:write'),
      (super_admin_role, 'weeding:write'),
      (super_admin_role, 'weeding:read'),
      (super_admin_role, 'progression:write'),
      (super_admin_role, 'progression:decide'),
      (super_admin_role, 'progression:read'),
      (super_admin_role, 'comments:write'),
      (super_admin_role, 'comments:read'),
      (super_admin_role, 'communications:write'),
      (super_admin_role, 'communications:read'),
      (super_admin_role, 'export:write'),
      (super_admin_role, 'notifications:view_own')
    ON CONFLICT DO NOTHING;
  END IF;

  -- ──────────────────────────────────────────────────────────────────
  -- ADMIN: Most permissions except some user management details
  -- ──────────────────────────────────────────────────────────────────
  IF admin_role IS NOT NULL THEN
    INSERT INTO public.rolepermission (roleid, permissionname)
    VALUES
      (admin_role, 'users:read'),
      (admin_role, 'users:write'),
      (admin_role, 'staff:write'),
      (admin_role, 'staff:read'),
      (admin_role, 'guardians:write'),
      (admin_role, 'guardians:read'),
      (admin_role, 'students:enrol'),
      (admin_role, 'students:write'),
      (admin_role, 'students:read'),
      (admin_role, 'academics:write'),
      (admin_role, 'academics:read'),
      (admin_role, 'assessments:write'),
      (admin_role, 'assessments:read'),
      (admin_role, 'grades:write'),
      (admin_role, 'grades:read'),
      (admin_role, 'finance:write'),
      (admin_role, 'finance:manage_structures'),
      (admin_role, 'finance:read'),
      (admin_role, 'payments:write'),
      (admin_role, 'weeding:write'),
      (admin_role, 'weeding:read'),
      (admin_role, 'progression:write'),
      (admin_role, 'progression:decide'),
      (admin_role, 'progression:read'),
      (admin_role, 'comments:read'),
      (admin_role, 'communications:write'),
      (admin_role, 'communications:read'),
      (admin_role, 'export:write'),
      (admin_role, 'notifications:view_own')
    ON CONFLICT DO NOTHING;
  END IF;

  -- ──────────────────────────────────────────────────────────────────
  -- MANAGER: Can approve weeding/progression, manage assessments, finance
  -- ──────────────────────────────────────────────────────────────────
  IF manager_role IS NOT NULL THEN
    INSERT INTO public.rolepermission (roleid, permissionname)
    VALUES
      (manager_role, 'students:write'),
      (manager_role, 'students:read'),
      (manager_role, 'assessments:write'),
      (manager_role, 'assessments:read'),
      (manager_role, 'grades:read'),
      (manager_role, 'finance:write'),
      (manager_role, 'finance:manage_structures'),
      (manager_role, 'finance:read'),
      (manager_role, 'payments:write'),
      (manager_role, 'weeding:write'),
      (manager_role, 'weeding:read'),
      (manager_role, 'progression:write'),
      (manager_role, 'progression:decide'),
      (manager_role, 'progression:read'),
      (manager_role, 'comments:read'),
      (manager_role, 'communications:write'),
      (manager_role, 'communications:read'),
      (manager_role, 'notifications:view_own')
    ON CONFLICT DO NOTHING;
  END IF;

  -- ──────────────────────────────────────────────────────────────────
  -- STAFF: Teachers, accountants, support staff—can read and enter data
  -- ──────────────────────────────────────────────────────────────────
  IF staff_role IS NOT NULL THEN
    INSERT INTO public.rolepermission (roleid, permissionname)
    VALUES
      (staff_role, 'users:read'),
      (staff_role, 'students:read'),
      (staff_role, 'academics:read'),
      (staff_role, 'assessments:read'),
      (staff_role, 'grades:write'),
      (staff_role, 'grades:read'),
      (staff_role, 'finance:read'),
      (staff_role, 'payments:write'),
      (staff_role, 'weeding:read'),
      (staff_role, 'progression:read'),
      (staff_role, 'comments:read'),
      (staff_role, 'communications:read'),
      (staff_role, 'notifications:view_own')
    ON CONFLICT DO NOTHING;
  END IF;

  -- ──────────────────────────────────────────────────────────────────
  -- TEACHER: Can write comments and read/write grades for their classes
  -- ──────────────────────────────────────────────────────────────────
  IF teacher_role IS NOT NULL THEN
    INSERT INTO public.rolepermission (roleid, permissionname)
    VALUES
      (teacher_role, 'students:read'),
      (teacher_role, 'assessments:read'),
      (teacher_role, 'grades:write'),
      (teacher_role, 'grades:read'),
      (teacher_role, 'comments:write'),
      (teacher_role, 'comments:read'),
      (teacher_role, 'notifications:view_own')
    ON CONFLICT DO NOTHING;
  END IF;

  -- ──────────────────────────────────────────────────────────────────
  -- CUSTOMER: Parents/Guardians—can read their child's assessments, grades, notifications
  -- ──────────────────────────────────────────────────────────────────
  IF customer_role IS NOT NULL THEN
    INSERT INTO public.rolepermission (roleid, permissionname)
    VALUES
      (customer_role, 'students:read'),
      (customer_role, 'assessments:read'),
      (customer_role, 'grades:read'),
      (customer_role, 'finance:read'),
      (customer_role, 'comments:read'),
      (customer_role, 'notifications:view_own')
    ON CONFLICT DO NOTHING;
  END IF;

  -- ──────────────────────────────────────────────────────────────────
  -- GUEST: Minimal permissions (read-only public data if any)
  -- ──────────────────────────────────────────────────────────────────
  -- GUEST has no explicit permissions; access is controlled at the RLS level.

END $$;
-- Verify permissions were seeded
SELECT
  r.rolename,
  COUNT(rp.permissionid) as permission_count,
  STRING_AGG(rp.permissionname, ', ' ORDER BY rp.permissionname) as permissions
FROM public.role r
LEFT JOIN public.rolepermission rp ON rp.roleid = r.roleid
GROUP BY r.roleid, r.rolename
ORDER BY
  CASE r.rolename
    WHEN 'SUPER_ADMIN' THEN 1
    WHEN 'ADMIN' THEN 2
    WHEN 'MANAGER' THEN 3
    WHEN 'STAFF' THEN 4
    WHEN 'TEACHER' THEN 5
    WHEN 'CUSTOMER' THEN 6
    WHEN 'GUEST' THEN 7
    ELSE 8
  END;
