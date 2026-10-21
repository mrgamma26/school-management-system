import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/reports/data/enrolment_report_repository.dart';
import 'package:school_management_app/features/reports/presentation/report_providers.dart';

class _NeverCompletesRepository extends EnrolmentReportRepository {
  _NeverCompletesRepository() : super();

  @override
  Future<EnrolmentReportData> load(String yearId) =>
      Completer<EnrolmentReportData>().future;
}

void main() {
  test('aggregates every selected-year placement from one result set', () {
    final data = EnrolmentReportData.fromRows([
      {
        'studentid': 'student-1',
        'enddate': null,
        'class': {'classroomname': 'Form 1A'},
        'student': {'gender': 'MALE'},
      },
      {
        'studentid': 'student-2',
        'enddate': '2026-12-15',
        'class': {'classroomname': 'Form 1A'},
        'student': {'gender': 'FEMALE'},
      },
      {
        'studentid': 'student-3',
        'enddate': null,
        'class': {'classroomname': 'Form 2B'},
        'student': {'gender': 'FEMALE'},
      },
    ]);

    expect(data.totalEnrolled, 3);
    expect(data.maleCount, 1);
    expect(data.femaleCount, 2);
    expect(data.activeInYear, 2);
    expect(data.byClass, {'Form 1A': 2, 'Form 2B': 1});
  });

  test(
    'deduplicates a learner if malformed history contains duplicate rows',
    () {
      final row = {
        'studentid': 'student-1',
        'enddate': null,
        'class': {'classroomname': 'Form 1A'},
        'student': {'gender': 'MALE'},
      };
      final data = EnrolmentReportData.fromRows([row, row]);
      expect(data.totalEnrolled, 1);
      expect(data.byClass, {'Form 1A': 1});
    },
  );

  test('provider turns a stalled request into a timeout error', () async {
    final container = ProviderContainer(
      overrides: [
        enrolmentReportRepositoryProvider.overrideWithValue(
          _NeverCompletesRepository(),
        ),
        enrolmentReportTimeoutProvider.overrideWithValue(
          const Duration(milliseconds: 5),
        ),
      ],
    );
    addTearDown(container.dispose);

    final provider = enrolmentReportProvider('year-1');
    final emittedError = Completer<Object>();
    final subscription = container.listen(provider, (_, next) {
      final error = next.error;
      if (error != null && !emittedError.isCompleted) {
        emittedError.complete(error);
      }
    }, fireImmediately: true);
    addTearDown(subscription.close);

    await expectLater(emittedError.future, completion(isA<TimeoutException>()));
  });
}
