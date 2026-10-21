import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/enrolment_report_repository.dart';

final enrolmentReportRepositoryProvider = Provider<EnrolmentReportRepository>(
  (ref) => const EnrolmentReportRepository(),
);

final enrolmentReportTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 15),
);

final enrolmentReportProvider = FutureProvider.autoDispose
    .family<EnrolmentReportData, String>((ref, yearId) {
      // Keep an in-flight report alive until it resolves or times out. Without
      // this, a transient rebuild can dispose the provider and replace the
      // intended timeout with Riverpod's generic disposal StateError.
      final keepAlive = ref.keepAlive();
      return ref
          .watch(enrolmentReportRepositoryProvider)
          .load(yearId)
          .timeout(ref.watch(enrolmentReportTimeoutProvider))
          .whenComplete(keepAlive.close);
    });
