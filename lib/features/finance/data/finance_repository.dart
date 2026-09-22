import '../../../core/database/supabase_client.dart';
import '../domain/models/fee_structure.dart';
import '../domain/models/payment.dart';
import '../domain/models/financial_adjustment.dart';

/// Data access layer for all finance tables:
/// [feestructure], [payment] and [financialadjustment].
class FinanceRepository {
  // ─────────────────────────────────────────────
  // Fee Structures
  // ─────────────────────────────────────────────

  /// Returns fee structures for a given academic year, joined with class data.
  Future<List<FeeStructure>> listFeeStructures(String academicYearId) async {
    final rows = await supabase
        .from('feestructure')
        .select('*, class(classname), academicyear(academicyear, term)')
        .eq('academicyearid', academicYearId)
        .order('feetype');
    return rows.map((r) => FeeStructure.fromJson(r)).toList();
  }

  /// Creates a new fee structure entry.
  Future<void> createFeeStructure(FeeStructure fs) async {
    await supabase.from('feestructure').insert(fs.toInsertJson());
  }

  /// Updates the amount for an existing fee structure.
  Future<void> updateFeeStructure(String id, double newAmount) async {
    await supabase
        .from('feestructure')
        .update({'amount': newAmount})
        .eq('feestructureid', id);
  }

  /// Deletes a fee structure (only when no payments reference it).
  Future<void> deleteFeeStructure(String id) async {
    await supabase.from('feestructure').delete().eq('feestructureid', id);
  }

  // ─────────────────────────────────────────────
  // Payments
  // ─────────────────────────────────────────────

  /// Returns all payments for a student, newest first.
  Future<List<Payment>> paymentsForStudent(String studentId) async {
    final rows = await supabase
        .from('payment')
        .select('*, feestructure(feetype)')
        .eq('studentid', studentId)
        .order('paymentdate', ascending: false);
    return rows.map((r) => Payment.fromJson(r)).toList();
  }

  /// Returns all payments for an academic year (accountant overview).
  Future<List<Payment>> allPayments({
    required String academicYearId,
    String? studentId,
  }) async {
    var query = supabase
        .from('payment')
        .select(
          '*, student(firstname, lastname), feestructure!inner(feetype, academicyearid)',
        )
        .eq('feestructure.academicyearid', academicYearId);

    if (studentId != null) {
      query = query.eq('studentid', studentId);
    }

    final rows = await query.order('paymentdate', ascending: false);
    return rows.map((r) => Payment.fromJson(r)).toList();
  }

  /// Records a new payment.
  Future<String> recordPayment({
    required String studentId,
    required String feeStructureId,
    required String staffId,
    required double amount,
    required DateTime paymentDate,
    required String method,
    String? referenceNumber,
    String? receiptNumber,
  }) async {
    final row = await supabase
        .from('payment')
        .insert({
          'studentid': studentId,
          'feestructureid': feeStructureId,
          'recordedby': staffId,
          'amount': amount,
          'paymentdate': paymentDate.toIso8601String().substring(0, 10),
          'method': method,
          'referencenumber': referenceNumber,
          'receiptnumber': receiptNumber,
        })
        .select('paymentid')
        .single();
    return row['paymentid'] as String;
  }

  /// Calculates the total amount paid by a student for a fee structure.
  Future<double> totalPaid(String studentId, String feeStructureId) async {
    final rows = await supabase
        .from('payment')
        .select('amount')
        .eq('studentid', studentId)
        .eq('feestructureid', feeStructureId);
    return rows.fold<double>(
      0.0,
      (sum, r) => sum + (r['amount'] as num).toDouble(),
    );
  }

  // ─────────────────────────────────────────────
  // Financial Adjustments
  // ─────────────────────────────────────────────

  /// Returns all adjustments for a student.
  Future<List<FinancialAdjustment>> adjustmentsForStudent(
    String studentId,
  ) async {
    final rows = await supabase
        .from('financialadjustment')
        .select(
          '*, student(firstname, lastname), staff!approvedby(firstname, lastname)',
        )
        .eq('studentid', studentId)
        .order('createdat', ascending: false);
    return rows.map((r) => FinancialAdjustment.fromJson(r)).toList();
  }

  /// Records a new financial adjustment.
  Future<void> createAdjustment({
    required String studentId,
    required String staffId,
    required double amount,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('A reason is required for financial adjustments.');
    }
    await supabase.from('financialadjustment').insert({
      'studentid': studentId,
      'approvedby': staffId,
      'amount': amount,
      'reason': reason.trim(),
    });
  }

  // ─────────────────────────────────────────────
  // Balance summary
  // ─────────────────────────────────────────────

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  /// Returns the staffid for a given auth [userId].
  Future<String> getStaffIdForUser(String userId) async {
    final row = await supabase
        .from('staff')
        .select('staffid')
        .eq('userid', userId)
        .single();
    return row['staffid'] as String;
  }

  /// Returns the outstanding balance for a student for one fee structure.
  /// balance = feeStructure.amount - totalPaid + totalPenalties - totalDiscounts
  Future<double> outstandingBalance({
    required String studentId,
    required String feeStructureId,
    required double feeAmount,
  }) async {
    final paid = await totalPaid(studentId, feeStructureId);
    final adjRows = await supabase
        .from('financialadjustment')
        .select('amount')
        .eq('studentid', studentId);
    final adjTotal = adjRows.fold<double>(
      0.0,
      (sum, r) => sum + (r['amount'] as num).toDouble(),
    );
    return feeAmount - paid + adjTotal;
  }
}
