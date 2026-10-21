import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_management_app/features/authentication/domain/models/app_user.dart';
import 'package:school_management_app/features/authentication/presentation/providers/auth_provider.dart';
import 'package:school_management_app/features/help/data/guidance_content.dart';
import 'package:school_management_app/features/help/presentation/pages/help_support_page.dart';
import 'package:school_management_app/features/help/presentation/pages/roles_workflow_map_page.dart';
import 'package:school_management_app/features/help/presentation/pages/supabase_setup_page.dart';
import 'package:school_management_app/features/profile/presentation/pages/my_profile_page.dart';
import 'package:school_management_app/features/profile/presentation/providers/profile_providers.dart';
import 'package:school_management_app/features/settings/domain/school_settings.dart';
import 'package:school_management_app/features/settings/presentation/settings_providers.dart';
import 'package:school_management_app/features/users/domain/models/staff.dart';

class _FakeAuth extends AuthNotifier {
  final AppUser? fakeUser;
  _FakeAuth(this.fakeUser);

  @override
  AuthState build() => AuthState(user: fakeUser);

  @override
  Future<void> signOut() async {
    state = const AuthState();
  }
}

AppUser _user(String role, {Map<String, String> roles = const {}}) => AppUser(
  userId: 'u1',
  username: 'tester@example.test',
  roleId: 'r1',
  roleName: role,
  mustChangePassword: false,
  isActive: true,
  roles: roles,
);

const _settings = SchoolSettings(
  settingsId: 's1',
  schoolName: 'Test School',
  phoneNumber: '+265 111 222 333',
  emailAddress: 'office@test.example',
  physicalAddress: 'Area 1, Lilongwe',
  defaultCurrency: 'MWK',
  studentMinimumAge: 9,
  staffMinimumAge: 18,
  acceptedPaymentMethods: ['CASH'],
  balanceCarryForwardPolicy: 'NEXT_TERM',
  depositSlipMaxBytes: 1,
  depositSlipMimeTypes: ['image/png'],
);

Future<void> _pump(
  WidgetTester tester, {
  required Widget page,
  required AppUser? user,
  List<Override> extra = const [],
}) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: '/page',
    routes: [
      GoRoute(
        path: '/page',
        builder: (context, state) => Scaffold(body: page),
      ),
      GoRoute(
        path: '/:any(.*)',
        builder: (context, state) =>
            Scaffold(body: Text('went to ${state.uri.path}')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [authProvider.overrideWith(() => _FakeAuth(user)), ...extra],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('roles map shows six role cards and the workflow rows', (
    tester,
  ) async {
    await _pump(
      tester,
      page: const RolesWorkflowMapPage(),
      user: _user('SUPER_USER'),
    );
    expect(find.text('Roles & Workflow Map'), findsOneWidget);
    for (final role in roleCards) {
      expect(find.text(role.name), findsWidgets);
    }
    expect(
      find.text('Only role that posts or reverses payments'),
      findsOneWidget,
    );
    expect(find.text('Class setup'), findsOneWidget);
    // Super User can open some workspaces (class setup) but not all of them.
    expect(find.text('Open'), findsWidgets);
    expect(find.text('Open').evaluate().length, lessThan(workflows.length));
  });

  testWidgets('supabase setup is static guidance with copyable commands', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await _pump(
      tester,
      page: const SupabaseSetupPage(),
      user: _user('SUPER_USER'),
    );
    expect(find.text('Supabase Migration Setup'), findsOneWidget);
    expect(find.text('Authenticate the CLI'), findsOneWidget);
    expect(find.text('supabase login'), findsOneWidget);
    expect(find.textContaining('<development-project-ref>'), findsWidgets);
    expect(find.textContaining('supabase db reset --linked'), findsWidgets);

    await tester.tap(find.byTooltip('Copy command 4'));
    await tester.pump();
    expect(copied, 'supabase db push');
  });

  testWidgets('help shows guidance for the signed-in role and links to it', (
    tester,
  ) async {
    await _pump(
      tester,
      page: const HelpSupportPage(),
      user: _user('TEACHER'),
      extra: [
        schoolSettingsProvider.overrideWith((ref) async => _settings),
        schoolBrandingProvider.overrideWith((ref) async => _settings),
      ],
    );
    expect(find.text('Enter and validate marks'), findsOneWidget);
    expect(find.text('Record a payment'), findsNothing);
    expect(find.text('Contact support'), findsOneWidget);
    expect(find.text('+265 111 222 333'), findsOneWidget);
    expect(find.text('office@test.example'), findsOneWidget);

    await tester.tap(find.text('Enter and validate marks'));
    await tester.pumpAndSettle();
    expect(find.text('went to /assessments'), findsOneWidget);
  });

  testWidgets('help falls back to default contact details', (tester) async {
    await _pump(
      tester,
      page: const HelpSupportPage(),
      user: _user('GUARDIAN'),
      extra: [
        schoolSettingsProvider.overrideWith(
          (ref) async => throw Exception('no access'),
        ),
        schoolBrandingProvider.overrideWith(
          (ref) async => const SchoolBranding(schoolName: 'Test School'),
        ),
      ],
    );
    expect(find.text('See your children'), findsOneWidget);
    expect(find.textContaining('default details are shown'), findsOneWidget);
  });

  testWidgets('profile shows the user, role switch and sign out', (
    tester,
  ) async {
    final user = _user(
      'TEACHER',
      roles: {'TEACHER': 'r1', 'HEAD_TEACHER': 'r2'},
    );
    await _pump(
      tester,
      page: const MyProfilePage(),
      user: user,
      extra: [
        myStaffProfileProvider.overrideWith(
          (ref) async => const Staff(
            staffId: 'st1',
            userId: 'u1',
            employeeNumber: 'EMP-001',
            firstName: 'Ada',
            lastName: 'Banda',
            gender: 'FEMALE',
            email: 'ada@test.example',
            jobTitle: 'Mathematics teacher',
          ),
        ),
      ],
    );
    expect(find.text('Ada Banda'), findsOneWidget);
    expect(find.text('tester@example.test'), findsOneWidget);
    expect(find.text('Other available role'), findsOneWidget);
    expect(find.text('Mathematics teacher'), findsOneWidget);
    expect(find.text('Change password'), findsOneWidget);
    expect(find.text('Sign out'), findsOneWidget);

    await tester.tap(find.text('Switch to Head Teacher workspace'));
    await tester.pumpAndSettle();
    expect(find.text('went to /headteacher/home'), findsOneWidget);
  });

  testWidgets('profile without a staff record or second role stays simple', (
    tester,
  ) async {
    await _pump(
      tester,
      page: const MyProfilePage(),
      user: _user('GUARDIAN'),
      extra: [myStaffProfileProvider.overrideWith((ref) async => null)],
    );
    expect(find.text('tester@example.test'), findsWidgets);
    expect(find.text('Other available role'), findsNothing);
    expect(find.text('Staff profile'), findsNothing);

    await tester.tap(find.text('Change password'));
    await tester.pumpAndSettle();
    expect(find.text('went to /change-password'), findsOneWidget);
  });
}
