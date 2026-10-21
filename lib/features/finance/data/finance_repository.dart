import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/database/supabase_client.dart';
import '../../../core/errors/app_exception.dart';
import '../domain/models/fee_structure.dart';
import '../domain/models/payment.dart';
import '../domain/models/payment_channel.dart';
import '../domain/models/financial_adjustment.dart';

/// Maximum rows returned by list methods in a single fetch.
const int kPaymentPageSize = 500;

/// Maps Supabase/database errors to [AppException] subtypes.
AppException _mapException(Object error) {
  final text = error.toString();

  if (text.contains('P0001') || text.contains('23505')) {
    final match = RegExp(r'message:\s*([^,]+)').firstMatch(text);
    return ValidationException(
      match?.group(1)?.trim() ?? 'The payment details are not valid.',
    );
  }

  // Permission/auth errors → ForbiddenException
  if (text.contains('permission') ||
      text.contains('42501') ||
      text.contains('denied')) {
    return ForbiddenException(
      'You do not have permission to perform this action.',
    );
  }

  // Not found errors → NotFoundException
  if (text.contains('0 rows') ||
      text.contains('PGRST116') ||
      text.contains('single()') ||
      text.contains('no rows')) {
    return NotFoundException('Resource not found.');
  }

  // Network errors → NetworkException
  if (text.contains('network') ||
      text.contains('SocketException') ||
      text.contains('Connection refused') ||
      text.contains('Connection reset')) {
    return NetworkException(
      'Network error. Check your connection and try again.',
    );
  }

  // Server/database errors → ServerException
  return ServerException('Something went wrong. Please try again.');
}

/// Data access layer for all finance tables:
/// [feestructure], [payment] and [financialadjustment].
class FinanceRepository {
  /// Stores evidence for a bank deposit after its payment row has been posted.
  /// The payment id links the slip to the normal payment ledger.
  Future<void> attachDepositSlip({
    required String studentId,
    required String paymentId,
    required String bankName,
    required String reference,
    required double amount,
    required DateTime depositDate,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final user = supabase.auth.currentUser;
    if (user == null) throw StateError('You must be signed in.');
    final staff = await supabase
        .from('staff')
        .select('staffid')
        .eq('userid', user.id)
        .single();
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final extension = safeName.split('.').last.toLowerCase();
    final mimeType = switch (extension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      'pdf' => 'application/pdf',
      _ => throw ArgumentError('Unsupported deposit-slip file type.'),
    };
    if (bytes.isEmpty || bytes.length > 5 * 1024 * 1024) {
      throw ArgumentError('The deposit slip must be between 1 byte and 5 MB.');
    }
    final path =
        '${user.id}/${DateTime.now().microsecondsSinceEpoch}_$safeName';
    await supabase.storage.from('deposit-slips').uploadBinary(
      path,
      bytes,
      fileOptions: FileOptions(contentType: mimeType),
    );
    try {
      await supabase.from('deposit_slips').insert({
        'student_id': studentId,
        'payment_id': paymentId,
        'bank_name': bankName.trim(),
        'deposit_date': depositDate.toIso8601String().substring(0, 10),
        'reference': reference.trim(),
        'amount': amount,
        'storage_path': path,
        'created_by': staff['staffid'],
      });
    } catch (_) {
      await supabase.storage.from('deposit-slips').remove([path]);
      rethrow;
    }
  }

  /// Reverses a posted payment without mutating the original ledger row.
  Future<String> reversePayment({
    required String paymentId,
    required String reason,
  }) async {
    if (reason.trim().isEmpty) {
      throw ArgumentError('A reversal reason is required.');
    }
    try {
      final result = await supabase.rpc(
        'reverse_payment',
        params: {'p_payment_id': paymentId, 'p_reason': reason.trim()},
      );
      return result as String;
    } catch (error) {
      throw ServerException('Could not reverse the payment: $error');
    }
  }

  // ─────────────────────────────────────────────
  // Fee Structures
  // ─────────────────────────────────────────────

  /// Returns all school-wide fee structures, joined with their year and term.
  Future<List<FeeStructure>> listFeeStructures() async {
    try {
      final rows = await supabase
          .from('feestructure')
          .select('*, academicyear(academicyear, term)')
          .order('feetype');
      return rows.map((r) => FeeStructure.fromJson(r)).toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Creates a new fee structure entry.
  Future<void> createFeeStructure(FeeStructure fs) async {
    try {
      await supabase.from('feestructure').insert(fs.toInsertJson());
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Updates an existing school-wide fee structure.
  Future<void> updateFeeStructure(FeeStructure fee) async {
    try {
      await supabase
          .from('feestructure')
          .update({
            'academicyearid': fee.academicYearId,
            'feetype': fee.feeType,
            'amount': fee.amount,
          })
          .eq('feestructureid', fee.feeStructureId);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Deletes a fee structure (only when no payments reference it).
  Future<void> deleteFeeStructure(String id) async {
    try {
      await supabase.from('feestructure').delete().eq('feestructureid', id);
    } catch (e) {
      throw _mapException(e);
    }
  }

  // ─────────────────────────────────────────────
  // Payments
  // ─────────────────────────────────────────────

  /// Returns the most recent payments for a student (up to 200), newest first.
  Future<List<Payment>> paymentsForStudent(String studentId) async {
    try {
      final rows = await supabase
          .from('payment')
          .select(
            '*, feestructure(feetype), paymentchannel(displayname, providername, maskedidentifier)',
          )
          .eq('studentid', studentId)
          .order('paymentdate', ascending: false)
          .limit(200);
      return rows.map((r) => Payment.fromJson(r)).toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Returns up to [kPaymentPageSize] payments for an academic year
  /// (accountant overview), newest first.
  ///
  /// Optional filters:
  /// - [studentId]: filter to payments for a specific student
  /// - [searchQuery]: filter by student name or ID (case-insensitive substring match)
  /// - [classId]: filter to payments by students currently in this class
  /// - [academicYearId]: required; filters to payments in this academic year
  ///
  /// The [classId] filter joins through:
  ///   payment → student → studentclasshistory (enddate IS NULL) → class
  /// to show only students currently enrolled in that class.
  Future<List<Payment>> allPayments({
    required String academicYearId,
    String? studentId,
    String? classId,
    String? searchQuery,
    int offset = 0,
  }) async {
    try {
      if (classId != null && studentId != null) {
        throw ArgumentError('Specify either classId or studentId, not both.');
      }

      var query = supabase
          .from('payment')
          .select(
            '*, student(studentid, firstname, lastname), feestructure!inner(feetype, academicyearid), paymentchannel(displayname, providername, maskedidentifier)',
          );

      // Always filter by academic year
      query = query.eq('feestructure.academicyearid', academicYearId);

      // Filter by specific student if provided
      if (studentId != null) {
        query = query.eq('studentid', studentId);
      }

      // Filter by class: join through studentclasshistory to get current students
      if (classId != null) {
        // Fetch student IDs currently in this class for the given academic year
        final classStudents = await supabase
            .from('studentclasshistory')
            .select('studentid')
            .eq('classid', classId)
            .eq('academicyearid', academicYearId)
            .isFilter('enddate', null);

        final allowedStudentIds = (classStudents as List)
            .map((row) => row['studentid'] as String)
            .toSet();

        // Filter payments to only those from students in the class (client-side)
        final rows = await query
            .order('paymentdate', ascending: false)
            .range(offset, offset + kPaymentPageSize - 1);
        final payments = rows.map((r) => Payment.fromJson(r)).toList();
        return payments
            .where((p) => allowedStudentIds.contains(p.studentId))
            .toList();
      }

      // Search by student name or student ID (case-insensitive substring)
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final search = searchQuery.trim().toLowerCase();
        // PostgREST doesn't have a case-insensitive substring filter,
        // so we fetch all and filter in Dart. For large datasets, consider
        // implementing full-text search or a stored function.
        final rows = await query
            .order('paymentdate', ascending: false)
            .range(offset, offset + kPaymentPageSize - 1);
        final payments = rows.map((r) => Payment.fromJson(r)).toList();
        return payments.where((p) {
          final name = (p.studentName ?? '').toLowerCase();
          final id = (p.studentId).toLowerCase();
          return name.contains(search) || id.contains(search);
        }).toList();
      }

      final rows = await query
          .order('paymentdate', ascending: false)
          .range(offset, offset + kPaymentPageSize - 1);
      return rows.map((r) => Payment.fromJson(r)).toList();
    } catch (e) {
      if (e is ArgumentError) rethrow;
      throw _mapException(e);
    }
  }

  Future<List<PaymentChannel>> listPaymentChannels({
    String? type,
    bool activeOnly = false,
  }) async {
    try {
      var query = supabase.from('paymentchannel').select();
      if (type != null) query = query.eq('channeltype', type);
      if (activeOnly) query = query.eq('isactive', true);
      final rows = await query.order('displayname');
      return rows.map((row) => PaymentChannel.fromJson(row)).toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> savePaymentChannel({
    String? channelId,
    required String channelType,
    required String displayName,
    required String providerName,
    required String maskedIdentifier,
    String currency = 'MWK',
  }) async {
    try {
      final values = {
        'channeltype': channelType,
        'displayname': displayName.trim(),
        'providername': providerName.trim(),
        'maskedidentifier': maskedIdentifier.trim(),
        'currency': currency.trim().toUpperCase(),
        'createdby': supabase.auth.currentUser!.id,
        'updatedat': DateTime.now().toIso8601String(),
      };
      if (channelId == null) {
        await supabase.from('paymentchannel').insert(values);
      } else {
        values.remove('createdby');
        await supabase
            .from('paymentchannel')
            .update(values)
            .eq('channelid', channelId);
      }
    } catch (e) {
      throw _mapException(e);
    }
  }

  Future<void> setPaymentChannelActive(String channelId, bool active) async {
    try {
      await supabase
          .from('paymentchannel')
          .update({
            'isactive': active,
            'updatedat': DateTime.now().toIso8601String(),
          })
          .eq('channelid', channelId);
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Records and audits a payment atomically and returns its generated receipt.
  Future<({String paymentId, String receiptNumber})> recordPayment({
    required String studentId,
    required String feeStructureId,
    required double amount,
    required DateTime paymentDate,
    required String method,
    String? referenceNumber,
    String? channelId,
    double processingFee = 0,
    Map<String, dynamic> transactionDetails = const {},
  }) async {
    try {
      final raw = await supabase.rpc(
        'record_payment_v2',
        params: {
          'p_student_id': studentId,
          'p_fee_structure_id': feeStructureId,
          'p_amount': amount,
          'p_payment_date': paymentDate.toIso8601String().substring(0, 10),
          'p_method': method,
          'p_channel_id': channelId,
          'p_external_reference': referenceNumber,
          'p_processing_fee': processingFee,
          'p_transaction_details': transactionDetails,
        },
      );
      final row = Map<String, dynamic>.from(raw as Map);
      return (
        paymentId: row['paymentId'] as String,
        receiptNumber: row['receiptNumber'] as String,
      );
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Calculates the total amount paid by a student for a fee structure.
  ///
  /// Uses a server-side SUM aggregate instead of fetching every row,
  /// which is O(1) network cost regardless of payment count.
  Future<double> totalPaid(String studentId, String feeStructureId) async {
    try {
      final rows = await supabase
          .from('payment')
          .select('amount.sum()')
          .eq('studentid', studentId)
          .eq('feestructureid', feeStructureId);
      // PostgREST aggregate returns [{sum: <value>}]; value is null when 0 rows.
      final raw = rows.isNotEmpty ? rows.first['sum'] : null;
      return raw == null ? 0.0 : (raw as num).toDouble();
    } catch (e) {
      throw _mapException(e);
    }
  }

  // ─────────────────────────────────────────────
  // Financial Adjustments
  // ─────────────────────────────────────────────

  /// Returns all adjustments for a student.
  Future<List<FinancialAdjustment>> adjustmentsForStudent(
    String studentId,
  ) async {
    try {
      final rows = await supabase
          .from('financialadjustment')
          .select(
            '*, student(firstname, lastname), staff!approvedby(firstname, lastname)',
          )
          .eq('studentid', studentId)
          .order('createdat', ascending: false);
      return rows.map((r) => FinancialAdjustment.fromJson(r)).toList();
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Records a new financial adjustment.
  Future<void> createAdjustment({
    required String studentId,
    required String staffId,
    required double amount,
    required String reason,
  }) async {
    try {
      if (reason.trim().isEmpty) {
        throw ArgumentError('A reason is required for financial adjustments.');
      }
      await supabase.from('financialadjustment').insert({
        'studentid': studentId,
        'approvedby': staffId,
        'amount': amount,
        'reason': reason.trim(),
      });
    } catch (e) {
      if (e is ArgumentError) rethrow;
      throw _mapException(e);
    }
  }

  // ─────────────────────────────────────────────
  // Balance summary
  // ─────────────────────────────────────────────

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  /// Returns the staffid for a given auth [userId].
  Future<String> getStaffIdForUser(String userId) async {
    try {
      final row = await supabase
          .from('staff')
          .select('staffid')
          .eq('userid', userId)
          .single();
      return row['staffid'] as String;
    } catch (e) {
      throw _mapException(e);
    }
  }

  /// Returns the outstanding balance for a student for one fee structure.
  ///
  /// balance = feeStructure.amount − totalPaid + totalAdjustments
  ///
  /// Both aggregations are done server-side (PostgREST SUM) so only two
  /// lightweight scalar rows cross the wire instead of N payment/adjustment rows.
  ///
  /// Note: [financialadjustment] rows are scoped to the student (not per
  /// fee structure — the schema has no feestructureid on that table). This
  /// matches the original business rule: adjustments affect the student's
  /// overall account balance, proportionally shared across fee structures.
  Future<double> outstandingBalance({
    required String studentId,
    required String feeStructureId,
    required double feeAmount,
  }) async {
    try {
      // Server-side SUM of payments for this student + fee structure.
      final paidRows = await supabase
          .from('payment')
          .select('amount.sum()')
          .eq('studentid', studentId)
          .eq('feestructureid', feeStructureId);
      final rawPaid = paidRows.isNotEmpty ? paidRows.first['sum'] : null;
      final paid = rawPaid == null ? 0.0 : (rawPaid as num).toDouble();

      // Server-side SUM of all adjustments for this student (student-scoped,
      // no fee-structure column exists on financialadjustment).
      final adjRows = await supabase
          .from('financialadjustment')
          .select('amount.sum()')
          .eq('studentid', studentId);
      final rawAdj = adjRows.isNotEmpty ? adjRows.first['sum'] : null;
      final adjTotal = rawAdj == null ? 0.0 : (rawAdj as num).toDouble();

      return feeAmount - paid + adjTotal;
    } catch (e) {
      throw _mapException(e);
    }
  }
}
