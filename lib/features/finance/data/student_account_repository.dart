import '../../../core/database/supabase_client.dart';
import '../domain/account_ledger.dart';
import '../domain/models/fee_structure.dart';
import '../domain/overdue_rules.dart';

const int _chunk = 1000;

String _fullName(Object? row) {
  if (row is! Map) return '';
  return [row['firstname'], row['middlename'], row['lastname']]
      .whereType<String>()
      .map((p) => p.trim())
      .where((p) => p.isNotEmpty)
      .join(' ');
}

DateTime? _date(Object? value) =>
    value == null ? null : DateTime.tryParse(value.toString());

/// Reads every row of a query by walking it in [_chunk]-sized ranges.
Future<List<Map<String, dynamic>>> _fetchAll(
  Future<List<Map<String, dynamic>>> Function(int from, int to) page,
) async {
  final out = <Map<String, dynamic>>[];
  var from = 0;
  while (true) {
    final rows = await page(from, from + _chunk - 1);
    out.addAll(rows);
    if (rows.length < _chunk) break;
    from += _chunk;
  }
  return out;
}

/// Everything the Student Account workspace shows for one learner.
class StudentAccount {
  final String studentId;
  final String name;
  final String enrollmentStatus;
  final List<LedgerPlacement> placements;
  final List<FeeStructure> fees;
  final List<LedgerPayment> payments;
  final List<LedgerAdjustment> adjustments;
  final List<String> guardianNames;

  const StudentAccount({
    required this.studentId,
    required this.name,
    required this.enrollmentStatus,
    required this.placements,
    required this.fees,
    required this.payments,
    required this.adjustments,
    required this.guardianNames,
  });

  /// Fees the student owes, per the same rule the database uses.
  List<FeeStructure> get obligations => applicableFees(fees, placements);

  double get totalDue => totalFeesDue(obligations);
  double get totalPaid => totalPaidNet(payments);
  double get totalAdjusted => totalAdjustments(adjustments);
  double get balance => computeOutstandingBalance(
    fees: fees,
    placements: placements,
    payments: payments,
    adjustments: adjustments,
  );

  List<FeeStanding> get standings => feeStandings(obligations, payments);

  /// The open placement (no end date), else the most recent one.
  LedgerPlacement? get currentPlacement {
    for (final p in placements) {
      if (p.endDate == null) return p;
    }
    return placements.isEmpty ? null : placements.last;
  }

  String get classLabel => currentPlacement?.className ?? 'No class placement';
}

/// Loads student accounts and the bulk balance overview.
///
/// All reads go through the signed-in user's RLS policies; nothing here writes.
class StudentAccountRepository {
  Future<StudentAccount> loadAccount(String studentId) async {
    final student = await supabase
        .from('student')
        .select('studentid, firstname, middlename, lastname, enrollmentstatus')
        .eq('studentid', studentId)
        .single();

    final placementRows = await supabase
        .from('studentclasshistory')
        .select('classid, academicyearid, enddate, enrollmentdate, class(classroomname, form)')
        .eq('studentid', studentId)
        .order('enrollmentdate');

    final feeRows = await supabase
        .from('feestructure')
        .select(
          'feestructureid, academicyearid, classid, feetype, amount, academicyear(academicyear, term)',
        )
        .order('feetype');

    final paymentRows = await _fetchAll(
      (from, to) => supabase
          .from('payment')
          .select(
            'paymentid, feestructureid, amount, paymentdate, method, receiptnumber, '
            'referencenumber, feestructure(feetype), '
            'paymentchannel(displayname, providername, maskedidentifier), '
            'payment_reversals(reason)',
          )
          .eq('studentid', studentId)
          .order('paymentdate', ascending: false)
          .order('paymentid')
          .range(from, to),
    );

    final adjustmentRows = await supabase
        .from('financialadjustment')
        .select('adjustmentid, amount, reason, createdat, staff!approvedby(firstname, lastname)')
        .eq('studentid', studentId)
        .order('createdat', ascending: false);

    // Guardian names are context only; a policy that hides them must not
    // break the account, so an empty list is the honest fallback.
    var guardians = <String>[];
    try {
      final rows = await supabase
          .from('studentguardian')
          .select('guardian(firstname, lastname)')
          .eq('studentid', studentId);
      guardians = [
        for (final r in rows)
          if (_fullName(r['guardian']).isNotEmpty) _fullName(r['guardian']),
      ];
    } catch (_) {}

    return StudentAccount(
      studentId: studentId,
      name: _fullName(student),
      enrollmentStatus: student['enrollmentstatus'].toString(),
      placements: [
        for (final r in placementRows)
          LedgerPlacement(
            classId: r['classid'] as String,
            academicYearId: r['academicyearid'] as String,
            className: (r['class'] as Map?)?['classroomname'] as String?,
            form: (r['class'] as Map?)?['form']?.toString(),
            endDate: _date(r['enddate']),
          ),
      ],
      fees: [for (final r in feeRows) FeeStructure.fromJson(r)],
      payments: [for (final r in paymentRows) _paymentFrom(r)],
      adjustments: [
        for (final r in adjustmentRows)
          LedgerAdjustment(
            adjustmentId: r['adjustmentid'] as String,
            amount: (r['amount'] as num).toDouble(),
            reason: r['reason'] as String? ?? '',
            createdAt: DateTime.parse(r['createdat'] as String).toLocal(),
            approvedByName: _fullName(r['staff']).isEmpty
                ? null
                : _fullName(r['staff']),
          ),
      ],
      guardianNames: guardians,
    );
  }

  LedgerPayment _paymentFrom(Map<String, dynamic> r) {
    final channel = r['paymentchannel'] as Map?;
    // payment_reversals.payment_id is UNIQUE, so PostgREST embeds one object
    // (or null); tolerate a list as well.
    final reversal = r['payment_reversals'];
    final reversalMap = reversal is Map
        ? reversal
        : (reversal is List && reversal.isNotEmpty ? reversal.first as Map : null);
    return LedgerPayment(
      paymentId: r['paymentid'] as String,
      feeStructureId: r['feestructureid'] as String,
      amount: (r['amount'] as num).toDouble(),
      paymentDate: DateTime.parse(r['paymentdate'] as String),
      method: r['method'].toString(),
      feeType: (r['feestructure'] as Map?)?['feetype'] as String?,
      receiptNumber: r['receiptnumber'] as String?,
      referenceNumber: r['referencenumber'] as String?,
      channelSummary: channel == null
          ? null
          : '${channel['displayname']} · ${channel['providername']} · ${channel['maskedidentifier']}',
      reversed: reversalMap != null,
      reversalReason: reversalMap?['reason'] as String?,
    );
  }

  /// Every student's balance, computed client-side with [buildBalanceRows]
  /// because `private.student_outstanding_balance` is not callable from the app.
  Future<List<StudentBalanceRow>> loadBalanceOverview() async {
    final studentRows = await _fetchAll(
      (from, to) => supabase
          .from('student')
          .select('studentid, firstname, middlename, lastname, enrollmentstatus')
          .order('lastname')
          .order('studentid')
          .range(from, to),
    );
    final placementRows = await _fetchAll(
      (from, to) => supabase
          .from('studentclasshistory')
          .select('studentid, classid, academicyearid, enddate, class(classroomname, form)')
          .order('historyid')
          .range(from, to),
    );
    final feeRows = await supabase
        .from('feestructure')
        .select('feestructureid, academicyearid, classid, feetype, amount');
    final paymentRows = await _fetchAll(
      (from, to) => supabase
          .from('payment')
          .select('paymentid, studentid, feestructureid, amount, paymentdate')
          .order('paymentid')
          .range(from, to),
    );
    final reversedRows = await _fetchAll(
      (from, to) => supabase
          .from('payment_reversals')
          .select('payment_id')
          .order('payment_id')
          .range(from, to),
    );
    final adjustmentRows = await _fetchAll(
      (from, to) => supabase
          .from('financialadjustment')
          .select('adjustmentid, studentid, amount')
          .order('adjustmentid')
          .range(from, to),
    );

    final reversed = {for (final r in reversedRows) r['payment_id'] as String};
    final placements = <String, List<LedgerPlacement>>{};
    for (final r in placementRows) {
      placements.putIfAbsent(r['studentid'] as String, () => []).add(
        LedgerPlacement(
          classId: r['classid'] as String,
          academicYearId: r['academicyearid'] as String,
          className: (r['class'] as Map?)?['classroomname'] as String?,
          form: (r['class'] as Map?)?['form']?.toString(),
          endDate: _date(r['enddate']),
        ),
      );
    }
    final payments =
        <String, List<({double amount, DateTime? date, bool reversed})>>{};
    final paidByFee = <String, Map<String, double>>{};
    for (final r in paymentRows) {
      final isReversed = reversed.contains(r['paymentid'] as String);
      final amount = (r['amount'] as num).toDouble();
      payments.putIfAbsent(r['studentid'] as String, () => []).add((
        amount: amount,
        date: _date(r['paymentdate']),
        reversed: isReversed,
      ));
      if (!isReversed) {
        final perFee = paidByFee.putIfAbsent(r['studentid'] as String, () => {});
        final feeId = r['feestructureid'] as String;
        perFee[feeId] = (perFee[feeId] ?? 0) + amount;
      }
    }

    // Fees have no due date: the due date is the start of the fee's academic
    // period. If the periods cannot be read, days overdue stay blank.
    final periodStarts = <String, DateTime>{};
    try {
      final periodRows = await _fetchAll(
        (from, to) => supabase
            .from('academicyear')
            .select('academicyearid, startdate')
            .order('academicyearid')
            .range(from, to),
      );
      for (final r in periodRows) {
        final start = _date(r['startdate']);
        if (start != null) periodStarts[r['academicyearid'] as String] = start;
      }
    } catch (_) {}
    final adjustments = <String, double>{};
    for (final r in adjustmentRows) {
      final id = r['studentid'] as String;
      adjustments[id] = (adjustments[id] ?? 0) + (r['amount'] as num).toDouble();
    }

    return buildBalanceRows(
      students: [
        for (final r in studentRows)
          LedgerStudent(
            studentId: r['studentid'] as String,
            name: _fullName(r),
            enrollmentStatus: r['enrollmentstatus'].toString(),
          ),
      ],
      placementsByStudent: placements,
      fees: [for (final r in feeRows) FeeStructure.fromJson(r)],
      paymentsByStudent: payments,
      adjustmentTotalByStudent: adjustments,
      dueDateFor: (studentId, applicable) => earliestOutstandingDueDate(
        applicable: applicable,
        paidByFee: paidByFee[studentId] ?? const {},
        periodStarts: periodStarts,
      ),
    );
  }
}
