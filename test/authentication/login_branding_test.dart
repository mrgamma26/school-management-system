import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/authentication/presentation/pages/login_page.dart';
import 'package:school_management_app/features/authentication/presentation/providers/auth_provider.dart';
import 'package:school_management_app/features/settings/domain/school_settings.dart';
import 'package:school_management_app/features/settings/presentation/settings_providers.dart';

class _SignedOutAuth extends AuthNotifier {
  @override
  AuthState build() => const AuthState();
}

void main() {
  testWidgets('login headline uses the configured school name', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authProvider.overrideWith(_SignedOutAuth.new),
          schoolBrandingProvider.overrideWith(
            (ref) async => const SchoolBranding(schoolName: 'New School Name'),
          ),
        ],
        child: const MaterialApp(home: LoginPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New School Name'), findsOneWidget);
    expect(find.text('School Management System'), findsNothing);
    expect(find.text('Management Portal'), findsNothing);
  });
}
