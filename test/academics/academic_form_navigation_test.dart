import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:school_management_app/features/academics/data/academic_repository.dart';
import 'package:school_management_app/features/academics/presentation/pages/academic_year_form_page.dart';
import 'package:school_management_app/features/academics/presentation/pages/subject_form_page.dart';

class _FakeAcademicRepository extends AcademicRepository {
  final subjects = <String>[];

  @override
  Future<void> createSubject(String name, String? description) async {
    subjects.add(name);
  }
}

Future<void> _pumpRoute(
  WidgetTester tester, {
  required Widget Function(_FakeAcademicRepository repository) form,
  required _FakeAcademicRepository repository,
}) async {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(
          body: FilledButton(
            onPressed: () async {
              final saved = await context.push<bool>('/new');
              if (context.mounted && saved == true) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('refreshed after save')),
                );
              }
            },
            child: const Text('Add'),
          ),
        ),
      ),
      GoRoute(path: '/new', builder: (_, _) => form(repository)),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(child: MaterialApp.router(routerConfig: router)),
  );
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('empty date pickers open in the entered starting year', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: AcademicYearFormPage())),
    );
    await tester.enterText(find.byType(TextFormField).first, '2027');
    await tester.tap(find.text('Select date').first);
    await tester.pumpAndSettle();

    expect(find.text('2027'), findsWidgets);
  });

  testWidgets('subject save pops with a successful result for list refresh', (
    tester,
  ) async {
    final repository = _FakeAcademicRepository();
    await _pumpRoute(
      tester,
      repository: repository,
      form: (repository) => SubjectFormPage(repository: repository),
    );
    await tester.enterText(find.byType(TextFormField).first, 'Geography');
    await tester.tap(find.text('Create Subject').last);
    await tester.pumpAndSettle();

    expect(repository.subjects, ['Geography']);
    expect(find.text('refreshed after save'), findsOneWidget);
  });
}
