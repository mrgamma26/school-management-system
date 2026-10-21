// Static guidance text for the Roles & Workflow Map, Supabase Setup and Help
// pages. Nothing here is read from, or sent to, the database.

/// One role card on the Roles & Workflow Map.
class RoleCardInfo {
  final String name;
  final String responsibilities;
  final String boundary;
  final String quickStart;

  const RoleCardInfo({
    required this.name,
    required this.responsibilities,
    required this.boundary,
    required this.quickStart,
  });
}

/// One end-to-end workflow row. [route] is the real workspace it opens.
class WorkflowInfo {
  final String name;
  final String role;
  final String description;
  final String workspace;
  final String shape;
  final String? route;

  const WorkflowInfo({
    required this.name,
    required this.role,
    required this.description,
    required this.workspace,
    required this.shape,
    this.route,
  });
}

const roleCards = <RoleCardInfo>[
  RoleCardInfo(
    name: 'Super User',
    responsibilities: 'Accounts, permissions, audit, email delivery, security',
    boundary: 'Does not post payments',
    quickStart: 'Create user, Review access, Audit log',
  ),
  RoleCardInfo(
    name: 'Administrator',
    responsibilities:
        'Students, guardians, staff, classes, assignments, calendar, settings',
    boundary: 'Finance is read-only',
    quickStart: 'Admit student, Onboard staff, Set up class',
  ),
  RoleCardInfo(
    name: 'Head Teacher',
    responsibilities:
        'Approve and publish results, corrections, progression, weeding',
    boundary: 'Final academic decision maker',
    quickStart: 'Review results, Decide corrections, Progression',
  ),
  RoleCardInfo(
    name: 'Teacher',
    responsibilities:
        'Assigned classes, assessments, marks, comments, result sheets',
    boundary: 'Sees only current assignments',
    quickStart: 'Enter marks, Create assessment, Result sheet',
  ),
  RoleCardInfo(
    name: 'Accountant',
    responsibilities:
        'Fees, payments, slips, arrangements, statements, finance reports',
    boundary: 'Only role that posts or reverses payments',
    quickStart: 'Record payment, Verify slips, Follow up balances',
  ),
  RoleCardInfo(
    name: 'Guardian',
    responsibilities:
        'Linked children, notices, calendar, fees, permitted reports',
    boundary: 'Students never get accounts',
    quickStart: 'Child results, Fees and payments, Events',
  ),
];

const workflows = <WorkflowInfo>[
  WorkflowInfo(
    name: 'Class setup',
    role: 'Administrator',
    description:
        'Create a class by name, link its subjects, then pick one teacher per '
        'subject from the teachers marked as teaching it. Reassign changes or '
        'removes a teacher, or unlinks a subject; the old assignment is kept '
        'in history.',
    workspace: 'Class Setup',
    shape: '1 workspace, class list and subject table',
    route: '/academics/class-setup',
  ),
  WorkflowInfo(
    name: 'Student admission',
    role: 'Administrator',
    description:
        'Identity, find or create the guardian inline with relationship, '
        'current class with subjects set automatically, optional expiring '
        'invitation, one submit. Students have no login.',
    workspace: 'Add Student',
    shape: '1 workspace, 4 steps',
    route: '/students/new',
  ),
  WorkflowInfo(
    name: 'Staff onboarding',
    role: 'Administrator',
    description:
        'Profile, role, optional invitation, optional Head Teacher dual '
        'role, then hand-off to the teacher assignment matrix.',
    workspace: 'Add Staff',
    shape: '1 workspace + matrix',
    route: '/users/staff/new',
  ),
  WorkflowInfo(
    name: 'Account invitation',
    role: 'Super User',
    description:
        'Search an existing staff or guardian record, choose the role, and '
        'send the secure invitation. Passwords are never shown or emailed.',
    workspace: 'Create User Account',
    shape: '1 workspace',
    route: '/admin/users/create',
  ),
  WorkflowInfo(
    name: 'Calendar',
    role: 'Administrator',
    description:
        'Select a date; the event editor opens beside the calendar and '
        'saving marks the date.',
    workspace: 'School Calendar',
    shape: 'No page change',
    route: '/calendar',
  ),
  WorkflowInfo(
    name: 'Marks and submission',
    role: 'Teacher',
    description:
        'Pick an assigned class and subject, choose or create the '
        'assessment, enter marks for the roster, and submit to the Head '
        'Teacher.',
    workspace: 'Assessments & Grades',
    shape: '1 workspace',
    route: '/assessments',
  ),
  WorkflowInfo(
    name: 'Review and publish',
    role: 'Head Teacher',
    description:
        'Completeness, missing marks, averages and comments. Approve and '
        'publish, or return with a reason; decide result corrections; then '
        'promote, retain or weed out students.',
    workspace: 'Review Workspace',
    shape: '1 workspace, queue',
    route: '/results/review',
  ),
  WorkflowInfo(
    name: 'Student account and payment',
    role: 'Accountant',
    description:
        'Search a student, see obligations, payments, adjustments and '
        'balance, record the payment in place and post it. Payments are '
        'never edited; they are reversed.',
    workspace: 'Student Accounts',
    shape: '1 workspace',
    route: '/finance/accounts',
  ),
  WorkflowInfo(
    name: 'Deposit verification',
    role: 'Accountant',
    description:
        'Review the deposit slip list; approve and post the payment, or '
        'reject the slip with a reason.',
    workspace: 'Deposit Slips',
    shape: 'List + side panel',
    route: '/finance/deposit-slips',
  ),
  WorkflowInfo(
    name: 'Overdue follow-up',
    role: 'Accountant',
    description:
        'The overdue list opens the selected account so a reminder, notice '
        'or payment arrangement can follow.',
    workspace: 'Overdue Accounts',
    shape: 'List + account',
    route: '/finance/overdue',
  ),
  WorkflowInfo(
    name: 'Guardian child view',
    role: 'Guardian',
    description:
        'Child switcher with Overview, Results, Fees and payments, and '
        'Calendar and notices. Results stay locked while a balance is owed.',
    workspace: 'My Children',
    shape: '1 workspace, 4 tabs',
    route: '/guardian/child',
  ),
  WorkflowInfo(
    name: 'Database change',
    role: 'Developer',
    description:
        'Migration, local test, review, dry run, push. The developer safety '
        'steps are unchanged.',
    workspace: 'Supabase Setup',
    shape: 'Unchanged',
    route: '/admin/supabase-setup',
  ),
];

// ── Supabase migration setup ────────────────────────────────────────────────

class SetupStep {
  final String title;
  final String text;
  const SetupStep(this.title, this.text);
}

class SetupRequirement {
  final String label;
  final String value;
  const SetupRequirement(this.label, this.value);
}

const supabaseRequirements = <SetupRequirement>[
  SetupRequirement('Account', 'Individual Supabase account'),
  SetupRequirement('Environment', 'Development or staging'),
  SetupRequirement('Local tools', 'Supabase CLI + Docker'),
  SetupRequirement('Repository', 'Committed migrations + seed'),
  SetupRequirement('Frontend key', 'Publishable key only'),
  SetupRequirement('Secrets', 'Local environment / Supabase Vault'),
];

const supabaseSteps = <SetupStep>[
  SetupStep(
    'Create or accept access',
    'Use your own Supabase account. The repository owner invites the '
        'developer to a dedicated development or staging organization and '
        'project.',
  ),
  SetupStep(
    'Authenticate the CLI',
    'Run supabase login. Authentication stays on the developer machine and '
        'is never committed to Git.',
  ),
  SetupStep(
    'Link the safe project',
    'Run supabase link --project-ref <development-project-ref>, then '
        'confirm the linked project before any remote command.',
  ),
  SetupStep(
    'Test migrations locally',
    'Run supabase start and supabase db reset. This rebuilds only the '
        'local database from migrations and seed data.',
  ),
  SetupStep(
    'Review before deployment',
    'Run supabase migration list and supabase db push --dry-run. Review the '
        'SQL, RLS, functions, storage policies and advisors.',
  ),
  SetupStep(
    'Apply and verify',
    'Run supabase db push, confirm the migration history, then run the '
        'application tests against the development project.',
  ),
];

/// The four-command strip. Placeholders only; never a real project reference.
const supabaseCommandStrip = <String>[
  'supabase login',
  'supabase link --project-ref <development-project-ref>',
  'supabase db push --dry-run',
  'supabase db push',
];

const supabaseNeverRunCommand = 'supabase db reset --linked';

// ── Help & Support ──────────────────────────────────────────────────────────

class HelpItem {
  final String title;
  final String text;
  final String route;
  const HelpItem(this.title, this.text, this.route);
}

const _changePasswordHelp = HelpItem(
  'Change your password',
  'Choose a new password from your profile or the change-password page.',
  '/change-password',
);

/// Popular guidance per canonical role. Each item points at a real screen.
const helpByRole = <String, List<HelpItem>>{
  'SUPER_USER': [
    HelpItem(
      'Create a user account',
      'Invite a staff member or guardian and choose their role.',
      '/admin/users/create',
    ),
    HelpItem(
      'Review the audit log',
      'See who changed what and when.',
      '/admin/audit-log',
    ),
    HelpItem(
      'Check email delivery',
      'Find out whether an invitation or notice email was sent.',
      '/admin/email-log',
    ),
    HelpItem(
      'Understand roles and boundaries',
      'The six roles, their limits and the end-to-end workflows.',
      '/admin/roles-map',
    ),
    HelpItem(
      'Set up a Supabase development account',
      'Safe steps for testing and applying database migrations.',
      '/admin/supabase-setup',
    ),
    HelpItem(
      'Update school settings',
      'School name, logo and contact details used across the app.',
      '/settings/school',
    ),
    _changePasswordHelp,
  ],
  'ADMINISTRATOR': [
    HelpItem(
      'Admit a student',
      'Record the student, link a guardian and place them in a class.',
      '/students/new',
    ),
    HelpItem(
      'Set up a class',
      'Create the class, link its subjects, then choose a teacher for each.',
      '/academics/class-setup',
    ),
    HelpItem(
      'Onboard a staff member',
      'Create the staff profile and, if needed, a login.',
      '/users/staff/new',
    ),
    HelpItem(
      'Add a school event',
      'Open the calendar and pick a date to add an event.',
      '/calendar',
    ),
    HelpItem(
      'Update school settings',
      'School name, logo and contact details used across the app.',
      '/settings/school',
    ),
    _changePasswordHelp,
  ],
  'HEAD_TEACHER': [
    HelpItem(
      'Review submitted results',
      'Check completeness and averages, then approve or return a sheet.',
      '/results/review',
    ),
    HelpItem(
      'Decide a correction request',
      'Approve or reject corrections raised on published results.',
      '/results/corrections',
    ),
    HelpItem(
      'Publish results',
      'Release approved results to guardians.',
      '/results/publish',
    ),
    HelpItem(
      'Review student progression',
      'Promote or retain students at the end of the year.',
      '/progression/reviews',
    ),
    HelpItem(
      'Switch to your Teacher workspace',
      'If you also teach, switch role from your profile.',
      '/profile',
    ),
    _changePasswordHelp,
  ],
  'TEACHER': [
    HelpItem(
      'Enter and validate marks',
      'Pick a class and assessment, enter marks and submit them.',
      '/assessments',
    ),
    HelpItem(
      'Request a correction to a published result',
      'Raise a correction request for the Head Teacher to decide.',
      '/results/corrections',
    ),
    HelpItem(
      'Write teacher comments',
      'Add comments for your students.',
      '/teacher/comments',
    ),
    HelpItem(
      'See the classes you teach',
      'Your current class and subject assignments.',
      '/academics/assignments',
    ),
    HelpItem(
      'Switch to your Head Teacher workspace',
      'If you also hold that role, switch from your profile.',
      '/profile',
    ),
    _changePasswordHelp,
  ],
  'ACCOUNTANT': [
    HelpItem(
      'Record a payment',
      'Open a student account and post the payment.',
      '/finance/accounts',
    ),
    HelpItem(
      'Follow up overdue balances',
      'See accounts that are past due.',
      '/finance/overdue',
    ),
    HelpItem(
      'Verify a deposit slip',
      'Approve or reject slips uploaded for bank deposits.',
      '/finance/deposit-slips',
    ),
    HelpItem(
      'Reverse a payment',
      'Payments are never edited; use a reversal with a reason.',
      '/finance/reversals',
    ),
    HelpItem(
      'Open finance reports',
      'Fees, payments and balances in one place.',
      '/reports',
    ),
    _changePasswordHelp,
  ],
  'GUARDIAN': [
    HelpItem(
      'See your children',
      'Overview, fees and notices for each linked child.',
      '/guardian/child',
    ),
    HelpItem(
      'Read a report card',
      'Results are available once published and fees are up to date.',
      '/guardian/report-card',
    ),
    HelpItem(
      'View payment history',
      'Every payment recorded against your child.',
      '/guardian/payments',
    ),
    HelpItem(
      'Check notices and events',
      'School notifications and the calendar.',
      '/notifications',
    ),
    _changePasswordHelp,
  ],
};
