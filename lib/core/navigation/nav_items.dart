// ── FIX 11: Role-based Navigation Items ──────────────────────────────────────
// Dynamically generates navigation menu items based on user role.
// Uses the route access control map from FIX 5 to ensure consistency.

import 'package:flutter/material.dart';
import '../../widgets/app_shell.dart';

/// Returns the list of navigation items for a given role.
/// Only includes items that the role has access to based on FIX 5 route map.
List<NavItem> getNavItemsForRole(String role) {
  final normalizedRole = role.trim().toUpperCase();

  switch (normalizedRole) {
    case 'SUPER_USER':
    case 'SYSTEM_ADMIN':
      return _superAdminNav;

    case 'ADMINISTRATOR':
    case 'REGISTRAR':
      return _administratorNav;

    case 'HEAD_TEACHER':
      return _headTeacherNav;

    case 'TEACHER':
      return _teacherNav;

    case 'ACCOUNTANT':
      return _accountantNav;

    case 'GUARDIAN':
      return _guardianNav;

    default:
      return [];
  }
}

// ── Super Admin / System Admin Navigation ─────────────────────────────────────

const List<NavItem> _superAdminNav = [
  NavItem(
    label: 'Users',
    icon: Icons.people_outlined,
    activeIcon: Icons.people,
    route: '/admin/users',
  ),
  NavItem(
    label: 'Students',
    icon: Icons.school_outlined,
    activeIcon: Icons.school,
    route: '/students',
  ),
  NavItem(
    label: 'Staff',
    icon: Icons.badge_outlined,
    activeIcon: Icons.badge,
    route: '/users/staff',
  ),
  NavItem(
    label: 'Guardians',
    icon: Icons.family_restroom_outlined,
    activeIcon: Icons.family_restroom,
    route: '/users/guardians',
  ),
  NavItem(
    label: 'Academics',
    icon: Icons.book_outlined,
    activeIcon: Icons.book,
    route: '/academics/years',
  ),
  NavItem(
    label: 'Finance',
    icon: Icons.payments_outlined,
    activeIcon: Icons.payments,
    route: '/finance/payments',
  ),
  NavItem(
    label: 'Calendar',
    icon: Icons.calendar_month_outlined,
    activeIcon: Icons.calendar_month,
    route: '/calendar',
  ),
  NavItem(
    label: 'Assessments',
    icon: Icons.assignment_outlined,
    activeIcon: Icons.assignment,
    route: '/assessments',
  ),
  NavItem(
    label: 'Reviews',
    icon: Icons.rate_review_outlined,
    activeIcon: Icons.rate_review,
    route: '/progression/reviews',
  ),
  NavItem(
    label: 'Reports',
    icon: Icons.analytics_outlined,
    activeIcon: Icons.analytics,
    route: '/reports',
  ),
  NavItem(
    label: 'Audit Log',
    icon: Icons.history_outlined,
    activeIcon: Icons.history,
    route: '/admin/audit-log',
  ),
];

// ── Administrator / Registrar Navigation ──────────────────────────────────────

const List<NavItem> _administratorNav = [
  NavItem(
    label: 'Students',
    icon: Icons.school_outlined,
    activeIcon: Icons.school,
    route: '/students',
  ),
  NavItem(
    label: 'Staff',
    icon: Icons.badge_outlined,
    activeIcon: Icons.badge,
    route: '/users/staff',
  ),
  NavItem(
    label: 'Guardians',
    icon: Icons.family_restroom_outlined,
    activeIcon: Icons.family_restroom,
    route: '/users/guardians',
  ),
  NavItem(
    label: 'Academics',
    icon: Icons.book_outlined,
    activeIcon: Icons.book,
    route: '/academics/years',
  ),
  NavItem(
    label: 'Finance',
    icon: Icons.payments_outlined,
    activeIcon: Icons.payments,
    route: '/finance/payments',
  ),
  NavItem(
    label: 'Calendar',
    icon: Icons.calendar_month_outlined,
    activeIcon: Icons.calendar_month,
    route: '/calendar',
  ),
  NavItem(
    label: 'Assessments',
    icon: Icons.assignment_outlined,
    activeIcon: Icons.assignment,
    route: '/assessments',
  ),
  NavItem(
    label: 'Reviews',
    icon: Icons.rate_review_outlined,
    activeIcon: Icons.rate_review,
    route: '/progression/reviews',
  ),
  NavItem(
    label: 'Reports',
    icon: Icons.analytics_outlined,
    activeIcon: Icons.analytics,
    route: '/reports',
  ),
];

// ── Head Teacher Navigation ───────────────────────────────────────────────────

const List<NavItem> _headTeacherNav = [
  NavItem(
    label: 'Students',
    icon: Icons.school_outlined,
    activeIcon: Icons.school,
    route: '/students',
  ),
  NavItem(
    label: 'Staff',
    icon: Icons.badge_outlined,
    activeIcon: Icons.badge,
    route: '/users/staff',
  ),
  NavItem(
    label: 'Academics',
    icon: Icons.book_outlined,
    activeIcon: Icons.book,
    route: '/academics/years',
  ),
  NavItem(
    label: 'Calendar',
    icon: Icons.calendar_month_outlined,
    activeIcon: Icons.calendar_month,
    route: '/calendar',
  ),
  NavItem(
    label: 'Assessments',
    icon: Icons.assignment_outlined,
    activeIcon: Icons.assignment,
    route: '/assessments',
  ),
  NavItem(
    label: 'Reviews',
    icon: Icons.rate_review_outlined,
    activeIcon: Icons.rate_review,
    route: '/progression/reviews',
  ),
  NavItem(
    label: 'Comments',
    icon: Icons.comment_outlined,
    activeIcon: Icons.comment,
    route: '/teacher/comments',
  ),
  NavItem(
    label: 'Reports',
    icon: Icons.analytics_outlined,
    activeIcon: Icons.analytics,
    route: '/reports',
  ),
];

// ── Teacher Navigation ────────────────────────────────────────────────────────

const List<NavItem> _teacherNav = [
  NavItem(
    label: 'Students',
    icon: Icons.school_outlined,
    activeIcon: Icons.school,
    route: '/students',
  ),
  NavItem(
    label: 'Assignments',
    icon: Icons.assignment_ind_outlined,
    activeIcon: Icons.assignment_ind,
    route: '/academics/assignments',
  ),
  NavItem(
    label: 'Calendar',
    icon: Icons.calendar_month_outlined,
    activeIcon: Icons.calendar_month,
    route: '/calendar',
  ),
  NavItem(
    label: 'Assessments',
    icon: Icons.assignment_outlined,
    activeIcon: Icons.assignment,
    route: '/assessments',
  ),
  NavItem(
    label: 'Comments',
    icon: Icons.comment_outlined,
    activeIcon: Icons.comment,
    route: '/teacher/comments',
  ),
];

// ── Accountant Navigation ─────────────────────────────────────────────────────

const List<NavItem> _accountantNav = [
  NavItem(
    label: 'Students',
    icon: Icons.school_outlined,
    activeIcon: Icons.school,
    route: '/students',
  ),
  NavItem(
    label: 'Finance',
    icon: Icons.payments_outlined,
    activeIcon: Icons.payments,
    route: '/finance/payments',
  ),
  NavItem(
    label: 'Fee Structure',
    icon: Icons.receipt_long_outlined,
    activeIcon: Icons.receipt_long,
    route: '/finance/fees',
  ),
  NavItem(
    label: 'Calendar',
    icon: Icons.calendar_month_outlined,
    activeIcon: Icons.calendar_month,
    route: '/calendar',
  ),
  NavItem(
    label: 'Reports',
    icon: Icons.analytics_outlined,
    activeIcon: Icons.analytics,
    route: '/reports',
  ),
];

// ── Guardian Navigation ───────────────────────────────────────────────────────

const List<NavItem> _guardianNav = [
  NavItem(
    label: 'Progress',
    icon: Icons.trending_up_outlined,
    activeIcon: Icons.trending_up,
    route: '/guardian/progress',
  ),
  NavItem(
    label: 'Report Card',
    icon: Icons.assessment_outlined,
    activeIcon: Icons.assessment,
    route: '/guardian/report-card',
  ),
  NavItem(
    label: 'Payments',
    icon: Icons.payment_outlined,
    activeIcon: Icons.payment,
    route: '/guardian/payments',
  ),
  NavItem(
    label: 'Notifications',
    icon: Icons.notifications_outlined,
    activeIcon: Icons.notifications,
    route: '/notifications',
  ),
];
