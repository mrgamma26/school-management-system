import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/supabase_client.dart';
import '../../../../core/widgets/app_widgets.dart'
    show ErrorState, LoadingState;
import '../../../../widgets/ui_kit.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final guardianChildrenProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final uid = ref.watch(authProvider).user!.userId;
  final g = await supabase
      .from('guardian')
      .select('guardianid')
      .eq('userid', uid)
      .single();
  final guardianId = g['guardianid'] as String;
  final rows = await supabase
      .from('studentguardian')
      .select('student(studentid, firstname, lastname, enrollmentstatus)')
      .eq('guardianid', guardianId);
  return List<Map<String, dynamic>>.from(rows as List);
});

final guardianStudentPaymentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      studentId,
    ) async {
      final rows = await supabase
          .from('payment')
          .select(
            'paymentid, amount, paymentdate, method, receiptnumber, referencenumber, '
            'paymentchannel(displayname, providername, maskedidentifier), '
            'feestructure(feetype, class(classroomname))',
          )
          .eq('studentid', studentId)
          .order('paymentdate', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    });

// ── Page ──────────────────────────────────────────────────────────────────────

/// Screen 60 - Guardian view of payment history for all linked children.
class GuardianPaymentHistoryPage extends ConsumerStatefulWidget {
  const GuardianPaymentHistoryPage({super.key});

  @override
  ConsumerState<GuardianPaymentHistoryPage> createState() =>
      _GuardianPaymentHistoryPageState();
}

class _GuardianPaymentHistoryPageState
    extends ConsumerState<GuardianPaymentHistoryPage> {
  String? _selectedStudentId;
  String? _selectedStudentName;

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(guardianChildrenProvider);

    return UiPage(
      children: [
        const PageHead(
          kicker: 'Guardian',
          title: 'Payment History',
          subtitle: 'Read-only receipts, payments and remaining balance.',
        ),
        childrenAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: LoadingState(message: 'Loading your children…'),
          ),
          error: (e, _) => ErrorState(
            error: e,
            onRetry: () => ref.invalidate(guardianChildrenProvider),
          ),
          data: (children) {
            if (children.isEmpty) {
              return const UiCard(
                child: UiEmptyState(
                  icon: Icons.family_restroom_outlined,
                  title: 'No children linked yet',
                  message:
                      'No children linked to your account yet. Contact the school administrator.',
                ),
              );
            }
            final onlyStudent = children.length == 1
                ? children.single['student'] as Map<String, dynamic>
                : null;
            if (onlyStudent != null && _selectedStudentId == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _selectedStudentId == null) {
                  setState(() {
                    _selectedStudentId = onlyStudent['studentid'] as String;
                    _selectedStudentName =
                        '${onlyStudent['firstname']} ${onlyStudent['lastname']}';
                  });
                }
              });
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                UiCard(
                  padding: const EdgeInsets.all(12),
                  child: UiField(
                    label: 'Child',
                    child: onlyStudent != null
                        ? InputDecorator(
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.child_care),
                            ),
                            child: Text(
                              '${onlyStudent['firstname']} ${onlyStudent['lastname']}',
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            initialValue: _selectedStudentId,
                            hint: const Text('Choose a child'),
                            items: children.map((c) {
                              final st = c['student'] as Map<String, dynamic>;
                              final id = st['studentid'] as String;
                              final name =
                                  '${st['firstname']} ${st['lastname']}';
                              return DropdownMenuItem(
                                value: id,
                                child: Text(name),
                              );
                            }).toList(),
                            onChanged: (v) {
                              final st = children
                                  .map(
                                    (c) => c['student'] as Map<String, dynamic>,
                                  )
                                  .firstWhere((s) => s['studentid'] == v);
                              setState(() {
                                _selectedStudentId = v;
                                _selectedStudentName =
                                    '${st['firstname']} ${st['lastname']}';
                              });
                            },
                          ),
                  ),
                ),
                const SizedBox(height: 14),
                if (_selectedStudentId == null)
                  const UiCard(
                    child: UiEmptyState(
                      icon: Icons.payments_outlined,
                      title: 'Select a child',
                      message: 'Select a child to view their payments.',
                    ),
                  )
                else
                  GuardianPaymentList(
                    studentId: _selectedStudentId!,
                    studentName: _selectedStudentName!,
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

// ── Payment list ──────────────────────────────────────────────────────────────

class GuardianPaymentList extends ConsumerWidget {
  final String studentId;
  final String studentName;

  const GuardianPaymentList({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(guardianStudentPaymentsProvider(studentId));

    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: LoadingState(message: 'Loading payments…'),
      ),
      error: (e, _) => ErrorState(
        error: e,
        onRetry: () =>
            ref.invalidate(guardianStudentPaymentsProvider(studentId)),
      ),
      data: (payments) {
        if (payments.isEmpty) {
          return UiCard(
            child: UiEmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'No payments yet',
              message: 'No payments recorded for $studentName yet.',
            ),
          );
        }

        final total = payments.fold<double>(
          0.0,
          (sum, p) => sum + (p['amount'] as num).toDouble(),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdaptiveGrid(
              columns: 2,
              phoneColumns: 2,
              children: [
                MetricCard(
                  icon: Icons.payments_outlined,
                  label: 'Total paid',
                  value: formatMwk(total),
                  note: studentName,
                  noteTone: StatusTone.neutral,
                ),
                MetricCard(
                  icon: Icons.receipt_long_outlined,
                  label: 'Payments',
                  value: '${payments.length}',
                  note: 'Receipts on record',
                  noteTone: StatusTone.neutral,
                ),
              ],
            ),
            const SizedBox(height: 14),
            DataTableCard(
              columns: const [
                UiColumn('Date', flex: 9),
                UiColumn('Fee', flex: 11),
                UiColumn('Amount', flex: 10),
                UiColumn('Method', flex: 8, hideOnPhone: true),
                UiColumn('Receipt / reference', flex: 14, hideOnPhone: true),
              ],
              rows: [
                for (final p in payments)
                  () {
                    final fs = p['feestructure'] as Map<String, dynamic>?;
                    final channel =
                        p['paymentchannel'] as Map<String, dynamic>?;
                    final date = DateTime.tryParse('${p['paymentdate']}');
                    return UiTableRow([
                      UiCellText(formatUiDate(date)),
                      UiCellText(fs?['feetype'] as String? ?? 'Fee'),
                      UiCellText(
                        formatMwk((p['amount'] as num).toDouble()),
                        bold: true,
                      ),
                      UiCellText('${p['method']}'.replaceAll('_', ' ')),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          UiCellText(
                            p['receiptnumber'] == null
                                ? '—'
                                : 'Receipt ${p['receiptnumber']}',
                          ),
                          if (p['referencenumber'] != null)
                            Text(
                              'Ref ${p['referencenumber']}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64758B),
                              ),
                            ),
                          if (channel != null)
                            Text(
                              '${channel['displayname']} · ${channel['providername']} · ${channel['maskedidentifier']}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF64758B),
                              ),
                            ),
                        ],
                      ),
                    ]);
                  }(),
              ],
            ),
          ],
        );
      },
    );
  }
}
