import '../../../core/database/supabase_client.dart';

String _personName(Object? row) {
  if (row is! Map) return '—';
  final first = row['firstname']?.toString().trim() ?? '';
  final last = row['lastname']?.toString().trim() ?? '';
  final full = '$first $last'.trim();
  return full.isEmpty ? '—' : full;
}

DateTime? _parseDate(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());

double _num(Object? value) => value is num ? value.toDouble() : 0;

/// A bank deposit slip submitted as payment evidence (`deposit_slips`).
class DepositSlipRow {
  final String id;
  final String studentId;
  final String studentName;
  final String bankName;
  final String reference;
  final double amount;
  final DateTime? depositDate;
  final String status;
  final String? rejectionReason;
  final DateTime? verifiedAt;
  final DateTime? createdAt;
  final bool linkedToPayment;

  /// Object path inside the private `deposit-slips` bucket.
  final String? storagePath;

  const DepositSlipRow({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.bankName,
    required this.reference,
    required this.amount,
    required this.depositDate,
    required this.status,
    required this.rejectionReason,
    required this.verifiedAt,
    required this.createdAt,
    required this.linkedToPayment,
    this.storagePath,
  });

  factory DepositSlipRow.fromJson(Map<String, dynamic> j) => DepositSlipRow(
    id: j['deposit_slip_id'] as String,
    studentId: j['student_id'] as String? ?? '',
    studentName: _personName(j['student']),
    bankName: j['bank_name'] as String? ?? '—',
    reference: j['reference'] as String? ?? '—',
    amount: _num(j['amount']),
    depositDate: _parseDate(j['deposit_date']),
    status: j['status'] as String? ?? '',
    rejectionReason: j['rejection_reason'] as String?,
    verifiedAt: _parseDate(j['verified_at'])?.toLocal(),
    createdAt: _parseDate(j['created_at'])?.toLocal(),
    linkedToPayment: j['payment_id'] != null,
    storagePath: j['storage_path'] as String?,
  );
}

class InstallmentRow {
  final DateTime? dueDate;
  final double amount;
  final String status;

  const InstallmentRow({
    required this.dueDate,
    required this.amount,
    required this.status,
  });

  factory InstallmentRow.fromJson(Map<String, dynamic> j) => InstallmentRow(
    dueDate: _parseDate(j['due_date']),
    amount: _num(j['amount']),
    status: j['status'] as String? ?? '',
  );
}

class ArrangementStudent {
  final String id;
  final String name;

  const ArrangementStudent({required this.id, required this.name});
}

/// An agreed instalment plan for a learner's balance (`payment_arrangements`).
class PaymentArrangementRow {
  final String id;
  final String studentName;
  final double totalAmount;
  final double paidAmount;
  final String status;
  final DateTime? nextFollowUp;
  final String? notes;
  final DateTime? createdAt;
  final List<InstallmentRow> installments;

  const PaymentArrangementRow({
    required this.id,
    required this.studentName,
    required this.totalAmount,
    required this.paidAmount,
    required this.status,
    required this.nextFollowUp,
    required this.notes,
    required this.createdAt,
    required this.installments,
  });

  int get paidInstallments =>
      installments.where((i) => i.status == 'PAID').length;

  double get remainingAmount =>
      (totalAmount - paidAmount).clamp(0, double.infinity).toDouble();

  factory PaymentArrangementRow.fromJson(Map<String, dynamic> j) {
    final installments =
        [
          for (final i
              in (j['payment_arrangement_installments'] as List? ?? const []))
            InstallmentRow.fromJson(Map<String, dynamic>.from(i as Map)),
        ]..sort(
          (a, b) =>
              (a.dueDate ?? DateTime(0)).compareTo(b.dueDate ?? DateTime(0)),
        );
    return PaymentArrangementRow(
      id: j['arrangement_id'] as String,
      studentName: _personName(j['student']),
      totalAmount: _num(j['total_amount']),
      paidAmount: _num(j['paid_amount']),
      status: j['status'] as String? ?? '',
      nextFollowUp: _parseDate(j['next_follow_up_date']),
      notes: j['notes'] as String?,
      createdAt: _parseDate(j['created_at'])?.toLocal(),
      installments: installments,
    );
  }
}

/// A reversed payment (`payment_reversals`). The original payment row is never
/// changed; the reversal is a separate, append-only record.
class PaymentReversalRow {
  final String id;
  final String reason;
  final DateTime? reversedAt;
  final String reversedByName;
  final String receiptNumber;
  final double amount;
  final DateTime? paymentDate;
  final String studentName;

  const PaymentReversalRow({
    required this.id,
    required this.reason,
    required this.reversedAt,
    required this.reversedByName,
    required this.receiptNumber,
    required this.amount,
    required this.paymentDate,
    required this.studentName,
  });

  factory PaymentReversalRow.fromJson(Map<String, dynamic> j) {
    final payment = j['payment'] as Map?;
    return PaymentReversalRow(
      id: j['reversal_id'] as String,
      reason: j['reason'] as String? ?? '',
      reversedAt: _parseDate(j['reversed_at'])?.toLocal(),
      reversedByName: _personName(j['reverser']),
      receiptNumber: payment?['receiptnumber']?.toString() ?? '—',
      amount: _num(payment?['amount']),
      paymentDate: _parseDate(payment?['paymentdate']),
      studentName: _personName(payment?['student']),
    );
  }
}

/// Read side for the deposit-slip, payment-arrangement and reversal screens.
/// Row visibility is decided by the database's RLS policies.
class FinanceRecordsRepository {
  Future<List<ArrangementStudent>> listArrangementStudents() async {
    final rows = await supabase
        .from('student')
        .select('studentid, firstname, lastname')
        .eq('enrollmentstatus', 'ACTIVE')
        .order('lastname')
        .order('firstname');
    return [
      for (final row in rows)
        ArrangementStudent(
          id: row['studentid'] as String,
          name: _personName(row),
        ),
    ];
  }

  Future<String> createArrangement({
    required String studentId,
    required List<({DateTime dueDate, double amount})> installments,
    String? notes,
  }) async {
    if (installments.isEmpty || installments.any((item) => item.amount <= 0)) {
      throw ArgumentError('Add at least one positive installment.');
    }
    final result = await supabase.rpc(
      'create_payment_arrangement',
      params: {
        'p_student_id': studentId,
        'p_installments': [
          for (final item in installments)
            {
              'dueDate': item.dueDate.toIso8601String().substring(0, 10),
              'amount': item.amount,
            },
        ],
        'p_notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      },
    );
    return result as String;
  }

  Future<List<DepositSlipRow>> listDepositSlips() async {
    final rows = await supabase
        .from('deposit_slips')
        .select(
          'deposit_slip_id, bank_name, deposit_date, reference, amount, status, '
          'rejection_reason, verified_at, created_at, payment_id, '
          'student_id, storage_path, student(firstname, lastname)',
        )
        .order('created_at', ascending: false)
        .limit(1000);
    return [for (final r in rows) DepositSlipRow.fromJson(r)];
  }

  /// Records the Accountant's decision on a PENDING slip.
  ///
  /// Allowed by the `deposit_slips_accountant_all` policy. The row is only
  /// changed while it is still PENDING, and the call fails if no row was
  /// updated (for example when RLS hides it), so a decision is never silent.
  Future<void> decideDepositSlip({
    required String slipId,
    required String staffId,
    required bool approve,
    String? rejectionReason,
  }) async {
    final reason = rejectionReason?.trim() ?? '';
    if (!approve && reason.isEmpty) {
      throw ArgumentError('A rejection reason is required.');
    }
    final updated = await supabase
        .from('deposit_slips')
        .update({
          'status': approve ? 'VERIFIED' : 'REJECTED',
          'verified_by': staffId,
          'verified_at': DateTime.now().toUtc().toIso8601String(),
          'rejection_reason': approve ? null : reason,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('deposit_slip_id', slipId)
        .eq('status', 'PENDING')
        .select('deposit_slip_id');
    if (updated.isEmpty) {
      throw StateError(
        'The slip was not updated. It may already have been decided, or you may not have permission.',
      );
    }
  }

  /// Short-lived signed link to the private slip image/PDF. Only roles with a
  /// SELECT policy on the `deposit-slips` bucket (Accountant and oversight
  /// roles) can obtain one; anyone else gets an error.
  Future<String> signedSlipUrl(String storagePath) {
    return supabase.storage
        .from('deposit-slips')
        .createSignedUrl(storagePath, 300);
  }

  Future<List<PaymentArrangementRow>> listArrangements() async {
    final rows = await supabase
        .from('payment_arrangements')
        .select(
          'arrangement_id, total_amount, paid_amount, status, next_follow_up_date, notes, '
          'created_at, student(firstname, lastname), '
          'payment_arrangement_installments(due_date, amount, status)',
        )
        .order('created_at', ascending: false)
        .limit(1000);
    return [for (final r in rows) PaymentArrangementRow.fromJson(r)];
  }

  Future<List<PaymentReversalRow>> listReversals() async {
    final rows = await supabase
        .from('payment_reversals')
        .select(
          'reversal_id, reason, reversed_at, '
          'reverser:staff!reversed_by(firstname, lastname), '
          'payment(receiptnumber, amount, paymentdate, '
          'student(firstname, lastname))',
        )
        .order('reversed_at', ascending: false)
        .limit(1000);
    return [for (final r in rows) PaymentReversalRow.fromJson(r)];
  }
}
