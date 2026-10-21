import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_management_app/core/navigation/close_form.dart';

/// A form opened by a dashboard shortcut or typed address replaces the page
/// (go), so there is nothing to pop. closeForm must then go to the list instead
/// of leaving a blank screen; a form pushed from the list must pop back to it.
void main() {
  GoRouter buildRouter(String initial) => GoRouter(
    initialLocation: initial,
    routes: [
      GoRoute(
        path: '/list',
        builder: (context, _) => Scaffold(
          body: Column(
            children: [
              const Text('List page'),
              TextButton(
                onPressed: () => context.push('/form'),
                child: const Text('Open form'),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/form',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => closeForm(context, '/list', true),
            child: const Text('Save'),
          ),
        ),
      ),
    ],
  );

  testWidgets('a form opened by address falls back to the list', (
    tester,
  ) async {
    final router = buildRouter('/form');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('List page'), findsOneWidget);
    expect(router.routeInformationProvider.value.uri.path, '/list');
  });

  testWidgets('a form pushed from the list pops back to it', (tester) async {
    final router = buildRouter('/list');
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open form'));
    await tester.pumpAndSettle();
    expect(find.text('Save'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('List page'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
  });
}
