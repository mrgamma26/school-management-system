import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/authentication/domain/models/app_user.dart';
import 'package:school_management_app/features/authentication/presentation/providers/auth_provider.dart';
import 'package:school_management_app/features/help/data/external_launcher.dart';
import 'package:school_management_app/features/help/presentation/pages/help_support_page.dart';
import 'package:school_management_app/features/settings/domain/school_settings.dart';
import 'package:school_management_app/features/settings/presentation/settings_providers.dart';

class _FakeAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState(
    user: AppUser(
      userId: 'u1',
      username: 'tester@example.test',
      roleId: 'r1',
      roleName: 'TEACHER',
      mustChangePassword: false,
      isActive: true,
      roles: {},
    ),
  );
}

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

Future<void> _pump(WidgetTester tester, UriLauncher launcher) async {
  tester.view.physicalSize = const Size(1200, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authProvider.overrideWith(_FakeAuth.new),
        schoolSettingsProvider.overrideWith((ref) async => _settings),
        schoolBrandingProvider.overrideWith((ref) async => _settings),
        uriLauncherProvider.overrideWithValue(launcher),
      ],
      child: const MaterialApp(home: Scaffold(body: HelpSupportPage())),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('link builders', () {
    test('mailto uses the address and an encoded subject', () {
      final uri = supportMailtoUri(' office@test.example ', subject: 'Help me');
      expect(uri.toString(), 'mailto:office@test.example?subject=Help%20me');
    });

    test('mailto is null for a blank address', () {
      expect(supportMailtoUri('  '), isNull);
      expect(supportMailtoUri(null), isNull);
    });

    test('tel strips spaces and keeps a leading plus', () {
      expect(supportTelUri('+265 111 222 333').toString(), 'tel:+265111222333');
      expect(supportTelUri('0999 123 456').toString(), 'tel:0999123456');
      expect(supportTelUri('n/a'), isNull);
    });
  });

  testWidgets('Email support opens a mailto link to the school address', (
    tester,
  ) async {
    final opened = <Uri>[];
    await _pump(tester, (uri) async {
      opened.add(uri);
      return true;
    });
    await tester.tap(find.text('Email support'));
    await tester.pump();
    expect(opened, hasLength(1));
    expect(opened.single.scheme, 'mailto');
    expect(opened.single.path, 'office@test.example');
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Call school opens a tel link', (tester) async {
    final opened = <Uri>[];
    await _pump(tester, (uri) async {
      opened.add(uri);
      return true;
    });
    await tester.tap(find.text('Call school'));
    await tester.pump();
    expect(opened.single.toString(), 'tel:+265111222333');
  });

  testWidgets('a failed launch shows a snackbar', (tester) async {
    await _pump(tester, (uri) async => false);
    await tester.tap(find.text('Email support'));
    await tester.pump();
    expect(find.textContaining('Could not open an email app'), findsOneWidget);
  });

  testWidgets('a launcher that throws also shows a snackbar', (tester) async {
    await _pump(tester, (uri) async => throw Exception('no handler'));
    await tester.tap(find.text('Email support'));
    await tester.pump();
    expect(find.textContaining('Could not open an email app'), findsOneWidget);
  });
}
