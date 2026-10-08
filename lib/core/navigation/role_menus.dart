import 'package:flutter/material.dart';

/// A navigation node — either a direct link or a collapsible group.
class MenuNode {
  final String label;
  final IconData icon;
  final String? route; // null ⟹ group header
  final List<MenuNode> children;
  final String? requiredPermission;

  const MenuNode.link(
    this.label,
    this.icon,
    this.route, {
    this.requiredPermission,
  }) : children = const [];

  const MenuNode.group(this.label, this.icon, this.children)
    : route = null,
      requiredPermission = null;

  bool get isGroup => route == null;
}

/// Normalizes a role name to its canonical form.
///
/// This function maps 'SYSTEM_ADMIN' to 'SUPER_USER' — a deliberate consolidation
/// implemented in migration `supabase/migrations/0021_consolidate_super_user_role.sql`.
/// Both roles had identical permissions, so a single canonical role reduces maintenance burden
/// and prevents confusion. Existing SYSTEM_ADMIN users are migrated to SUPER_USER with
/// permissions preserved; the role dropdown pulls dynamically from UserRepository().listRoles(),
/// so SYSTEM_ADMIN no longer appears in the UI after the migration.
///
/// See: supabase/migrations/0021_consolidate_super_user_role.sql
String canonicalRole(String role) {
  final r = role.trim().toUpperCase();
  return r == 'SYSTEM_ADMIN' ? 'SUPER_USER' : r;
}

// ── Shared sub-trees ─────────────────────────────────────────────────────────

const _academics = MenuNode.group('Academics', Icons.school_outlined, [
  MenuNode.link(
    'Academic Years',
    Icons.calendar_today_outlined,
    '/academics/years',
  ),
  MenuNode.link('Classes', Icons.class_outlined, '/academics/classes'),
  MenuNode.link('Subjects', Icons.menu_book_outlined, '/academics/subjects'),
  MenuNode.link(
    'Class Assignments',
    Icons.assignment_ind_outlined,
    '/academics/assignments',
  ),
]);

const _finance = MenuNode.group('Finance', Icons.payments_outlined, [
  MenuNode.link(
    'Payments',
    Icons.payments_outlined,
    '/finance/payments',
    requiredPermission: 'finance:read',
  ),
  MenuNode.link(
    'Fee Structure',
    Icons.receipt_long_outlined,
    '/finance/fees',
    requiredPermission: 'finance:manage_structures',
  ),
  MenuNode.link(
    'Payment Configuration',
    Icons.tune_outlined,
    '/finance/payment-configuration',
  ),
]);

const _commonNodes = [
  MenuNode.link('Calendar', Icons.calendar_month_outlined, '/calendar'),
  MenuNode.link(
    'Notifications',
    Icons.notifications_outlined,
    '/notifications',
  ),
];

const _adminStudents = MenuNode.group('Students', Icons.groups_outlined, [
  MenuNode.link('All Students', Icons.people_outline, '/students'),
  MenuNode.link('Add Student', Icons.person_add_outlined, '/students/new'),
]);

// ── Per-role menus ────────────────────────────────────────────────────────────

final Map<String, List<MenuNode>> roleMenus = {
  'SUPER_USER': [
    const MenuNode.group('User Management', Icons.manage_accounts_outlined, [
      MenuNode.link(
        'System Users',
        Icons.people_outlined,
        '/admin/users',
        requiredPermission: 'users:read',
      ),
      MenuNode.link(
        'Create User',
        Icons.person_add_outlined,
        '/admin/users/create',
      ),
      MenuNode.link('Staff', Icons.badge_outlined, '/users/staff'),
      MenuNode.link(
        'Guardians',
        Icons.family_restroom_outlined,
        '/users/guardians',
      ),
    ]),
    _adminStudents,
    _academics,
    _finance,
    const MenuNode.link('Reports', Icons.analytics_outlined, '/reports'),
    ..._commonNodes,
    const MenuNode.link(
      'Audit Log',
      Icons.history_outlined,
      '/admin/audit-log',
      requiredPermission: 'auditlog:read',
    ),
  ],
  'ADMINISTRATOR': [
    _adminStudents,
    const MenuNode.group('People', Icons.people_outline, [
      MenuNode.link('Staff', Icons.badge_outlined, '/users/staff'),
      MenuNode.link(
        'Guardians',
        Icons.family_restroom_outlined,
        '/users/guardians',
      ),
    ]),
    _academics,
    _finance,
    const MenuNode.link('Reports', Icons.analytics_outlined, '/reports'),
    ..._commonNodes,
  ],
  'HEAD_TEACHER': [
    const MenuNode.link('Students', Icons.groups_outlined, '/students'),
    _academics,
    const MenuNode.group('Reviews', Icons.rate_review_outlined, [
      MenuNode.link(
        'Progression Reviews',
        Icons.trending_up,
        '/progression/reviews',
      ),
      MenuNode.link(
        'Student Status Reviews',
        Icons.filter_alt_outlined,
        '/weeding/reviews',
      ),
    ]),
    const MenuNode.group('People', Icons.people_outline, [
      MenuNode.link('Staff', Icons.badge_outlined, '/users/staff'),
      MenuNode.link(
        'Guardians',
        Icons.family_restroom_outlined,
        '/users/guardians',
      ),
    ]),
    const MenuNode.link(
      'Teacher Comments',
      Icons.comment_outlined,
      '/teacher/comments',
    ),
    const MenuNode.link('Reports', Icons.analytics_outlined, '/reports'),
    ..._commonNodes,
  ],
  'TEACHER': [
    const MenuNode.link(
      'Classes You Teach',
      Icons.class_outlined,
      '/academics/assignments',
    ),
    const MenuNode.link('My Students', Icons.groups_outlined, '/students'),
    const MenuNode.link(
      'Assessments & Grades',
      Icons.assignment_outlined,
      '/assessments',
    ),
    const MenuNode.link(
      'Teacher Comments',
      Icons.comment_outlined,
      '/teacher/comments',
    ),
    ..._commonNodes,
  ],
  'ACCOUNTANT': [
    const MenuNode.link(
      'Students & Accounts',
      Icons.account_box_outlined,
      '/students',
    ),
    const MenuNode.link(
      'Payments',
      Icons.payments_outlined,
      '/finance/payments',
    ),
    const MenuNode.link(
      'Fee Structure',
      Icons.receipt_long_outlined,
      '/finance/fees',
    ),
    const MenuNode.link('Reports', Icons.analytics_outlined, '/reports'),
    ..._commonNodes,
  ],
  'GUARDIAN': [
    const MenuNode.link(
      'Progress',
      Icons.trending_up_outlined,
      '/guardian/progress',
    ),
    const MenuNode.link(
      'Report Cards',
      Icons.assessment_outlined,
      '/guardian/report-card',
    ),
    const MenuNode.link(
      'Payments',
      Icons.payment_outlined,
      '/guardian/payments',
    ),
    ..._commonNodes,
  ],
};

/// Returns the filtered menu for [roleName], dropping any link whose
/// [requiredPermission] is absent from [granted], and any group that
/// becomes empty after filtering.
List<MenuNode> menuForRole(String roleName, Set<String> granted) {
  List<MenuNode> filter(List<MenuNode> nodes) {
    final out = <MenuNode>[];
    for (final n in nodes) {
      if (n.isGroup) {
        final kids = filter(n.children);
        if (kids.isNotEmpty) {
          out.add(MenuNode.group(n.label, n.icon, kids));
        }
      } else if (n.requiredPermission == null ||
          granted.contains(n.requiredPermission)) {
        out.add(n);
      }
    }
    return out;
  }

  return filter(roleMenus[canonicalRole(roleName)] ?? const []);
}
