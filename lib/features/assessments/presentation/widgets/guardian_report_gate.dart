import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/database/supabase_client.dart';
import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../widgets/ui_kit.dart';

/// Result of `get_guardian_report_access` for one linked student.
class GuardianReportAccess {
  final bool allowed;
  final double outstandingBalance;
  final String? message;

  const GuardianReportAccess({
    required this.allowed,
    required this.outstandingBalance,
    this.message,
  });

  factory GuardianReportAccess.fromJson(Map<String, dynamic> json) =>
      GuardianReportAccess(
        allowed: json['allowed'] == true,
        outstandingBalance:
            (json['outstandingBalance'] as num?)?.toDouble() ?? 0,
        message: json['message'] as String?,
      );
}

/// Asks the backend whether results may be shown. The server re-checks the
/// guardian link and the outstanding balance; the UI never decides this alone.
final guardianReportAccessProvider = FutureProvider.autoDispose
    .family<GuardianReportAccess, String>((ref, studentId) async {
      final result = await supabase.rpc(
        'get_guardian_report_access',
        params: {'p_student_id': studentId},
      );
      return GuardianReportAccess.fromJson(
        Map<String, dynamic>.from(result as Map),
      );
    });

/// Shows [child] only when the backend allows this guardian to see results for
/// [studentId]; otherwise shows the "pay the balance" locked state.
class GuardianReportGate extends ConsumerWidget {
  final String studentId;
  final Widget child;

  /// Replaces the default "View payment history" action of the locked state,
  /// for hosts (such as the child workspace) that link inside their own page.
  final List<Widget>? lockedActions;

  const GuardianReportGate({
    super.key,
    required this.studentId,
    required this.child,
    this.lockedActions,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final access = ref.watch(guardianReportAccessProvider(studentId));
    return access.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: LoadingState(message: 'Checking report access…'),
      ),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () => ref.invalidate(guardianReportAccessProvider(studentId)),
      ),
      data: (value) {
        if (value.allowed) return child;
        return Align(
          alignment: Alignment.topCenter,
          child: SingleChildScrollView(
            child: LockedState(
              title: 'Report card currently unavailable',
              message:
                  value.message ?? 'Pay the balance to view the report card',
              balanceLabel:
                  'Outstanding balance: ${formatMwk(value.outstandingBalance, decimals: 0)}',
              actions:
                  lockedActions ??
                  [
                    UiButton.secondary(
                      'View payment history',
                      icon: Icons.receipt_long_outlined,
                      onPressed: () => context.go('/guardian/payments'),
                    ),
                  ],
            ),
          ),
        );
      },
    );
  }
}
