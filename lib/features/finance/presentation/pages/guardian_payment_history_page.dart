import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _guardianChildrenProvider = FutureProvider<List<Map<String, dynamic>>>((
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

final _studentPaymentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      studentId,
    ) async {
      final rows = await supabase
          .from('payment')
          .select(
            'paymentid, amount, paymentdate, method, receiptnumber, '
            'feestructure(feetype, class(classroomname))',
          )
          .eq('studentid', studentId)
          .order('paymentdate', ascending: false);
      return List<Map<String, dynamic>>.from(rows as List);
    });

// ── Page ──────────────────────────────────────────────────────────────────────

/// Guardian view of payment history for all their linked children.
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
    final childrenAsync = ref.watch(_guardianChildrenProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment History'),
        actions: [
          HomeButton(roleName: ref.watch(authProvider).user?.roleName ?? ''),
        ],
      ),
      body: childrenAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading children: $e')),
        data: (children) {
          if (children.isEmpty) {
            return const Center(
              child: Text(
                'No children linked to your account yet.\n'
                'Contact the school administrator.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return Column(
            children: [
              // Child selector
              Padding(
                padding: const EdgeInsets.all(16),
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedStudentId,
                  decoration: const InputDecoration(
                    labelText: 'Select Child',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.child_care),
                  ),
                  hint: const Text('Choose a child'),
                  items: children.map((c) {
                    final st = c['student'] as Map<String, dynamic>;
                    final id = st['studentid'] as String;
                    final name = '${st['firstname']} ${st['lastname']}';
                    return DropdownMenuItem(value: id, child: Text(name));
                  }).toList(),
                  onChanged: (v) {
                    final st = children
                        .map((c) => c['student'] as Map<String, dynamic>)
                        .firstWhere((s) => s['studentid'] == v);
                    setState(() {
                      _selectedStudentId = v;
                      _selectedStudentName =
                          '${st['firstname']} ${st['lastname']}';
                    });
                  },
                ),
              ),

              // Payment list
              Expanded(
                child: _selectedStudentId == null
                    ? const Center(
                        child: Text(
                          'Select a child to view their payments',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : _PaymentList(
                        studentId: _selectedStudentId!,
                        studentName: _selectedStudentName!,
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Payment list ──────────────────────────────────────────────────────────────

class _PaymentList extends ConsumerWidget {
  final String studentId;
  final String studentName;

  const _PaymentList({required this.studentId, required this.studentName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_studentPaymentsProvider(studentId));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading payments: $e')),
      data: (payments) {
        if (payments.isEmpty) {
          return Center(
            child: Text(
              'No payments recorded for $studentName yet.',
              style: const TextStyle(color: Colors.grey),
            ),
          );
        }

        final total = payments.fold<double>(
          0.0,
          (sum, p) => sum + (p['amount'] as num).toDouble(),
        );

        return Column(
          children: [
            // Total banner
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.payments, color: Colors.green, size: 28),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        studentName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Total paid: MWK ${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.green.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // List
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: payments.length,
                separatorBuilder: (_, _) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final p = payments[i];
                  final fs = p['feestructure'] as Map<String, dynamic>?;
                  final cls = fs?['class'] as Map<String, dynamic>?;
                  final amt = (p['amount'] as num).toDouble();
                  return Card(
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.green,
                        child: Icon(
                          Icons.receipt,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      title: Text(
                        fs?['feetype'] as String? ?? 'Fee',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'MWK ${amt.toStringAsFixed(2)} — ${p['method']}',
                          ),
                          Text('Date: ${p['paymentdate']}'),
                          if (cls != null)
                            Text('Class: ${cls['classroomname']}'),
                          if (p['receiptnumber'] != null)
                            Text('Receipt: ${p['receiptnumber']}'),
                        ],
                      ),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
