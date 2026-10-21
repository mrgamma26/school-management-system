import 'models/fee_structure.dart';

/// Pure balance maths for a student account.
///
/// This mirrors the database function `private.student_outstanding_balance`
/// (migration 20261017000200_guardian_report_balance_gate.sql) exactly:
///
///   balance = applicable fees - non-reversed payments + adjustments
///
/// * A fee applies when the student has ANY class-history row in the fee's
///   academic year and the fee is school-wide (`classid IS NULL`) or matches
///   that row's class. Each fee is counted once however many rows match.
/// * Payments that have a `payment_reversals` row are excluded.
/// * Adjustments are student-level; a negative amount is a discount/waiver
///   and a positive amount a penalty.

/// One `studentclasshistory` row, reduced to what the balance rule needs.
class LedgerPlacement {
  final String classId;
  final String academicYearId;
  final String? className;
  final String? form;
  final DateTime? endDate;

  const LedgerPlacement({
    required this.classId,
    required this.academicYearId,
    this.className,
    this.form,
    this.endDate,
  });
}

/// One posted payment of a student, flagged when a reversal exists for it.
class LedgerPayment {
  final String paymentId;
  final String feeStructureId;
  final double amount;
  final DateTime paymentDate;
  final String method;
  final String? feeType;
  final String? receiptNumber;
  final String? referenceNumber;
  final String? channelSummary;
  final bool reversed;
  final String? reversalReason;

  const LedgerPayment({
    required this.paymentId,
    required this.feeStructureId,
    required this.amount,
    required this.paymentDate,
    required this.method,
    this.feeType,
    this.receiptNumber,
    this.referenceNumber,
    this.channelSummary,
    this.reversed = false,
    this.reversalReason,
  });
}

/// One `financialadjustment` row.
class LedgerAdjustment {
  final String adjustmentId;
  final double amount;
  final String reason;
  final DateTime createdAt;
  final String? approvedByName;

  const LedgerAdjustment({
    required this.adjustmentId,
    required this.amount,
    required this.reason,
    required this.createdAt,
    this.approvedByName,
  });
}

/// Rounds to whole cents so sums of decimals compare cleanly.
double roundMoney(double value) => (value * 100).roundToDouble() / 100;

/// True when [fee] is owed by a student with these [placements].
bool feeAppliesToPlacements(
  FeeStructure fee,
  Iterable<LedgerPlacement> placements,
) {
  for (final p in placements) {
    if (p.academicYearId == fee.academicYearId &&
        (fee.classId == null || fee.classId == p.classId)) {
      return true;
    }
  }
  return false;
}

/// The fees a student owes (each at most once), in the order given.
List<FeeStructure> applicableFees(
  Iterable<FeeStructure> fees,
  Iterable<LedgerPlacement> placements,
) {
  final list = placements.toList();
  return [
    for (final fee in fees)
      if (feeAppliesToPlacements(fee, list)) fee,
  ];
}

double totalFeesDue(Iterable<FeeStructure> applicable) =>
    roundMoney(applicable.fold<double>(0, (sum, f) => sum + f.amount));

/// Sum of payments that have not been reversed.
double totalPaidNet(Iterable<LedgerPayment> payments) => roundMoney(
  payments
      .where((p) => !p.reversed)
      .fold<double>(0, (sum, p) => sum + p.amount),
);

double totalAdjustments(Iterable<LedgerAdjustment> adjustments) =>
    roundMoney(adjustments.fold<double>(0, (sum, a) => sum + a.amount));

/// The outstanding balance. Positive means the student owes money; a negative
/// value means the account is in credit.
double computeOutstandingBalance({
  required Iterable<FeeStructure> fees,
  required Iterable<LedgerPlacement> placements,
  required Iterable<LedgerPayment> payments,
  required Iterable<LedgerAdjustment> adjustments,
}) {
  final due = totalFeesDue(applicableFees(fees, placements));
  return roundMoney(
    due - totalPaidNet(payments) + totalAdjustments(adjustments),
  );
}

/// Same rule from pre-aggregated amounts (used for the bulk overview).
double balanceFromTotals({
  required double feesDue,
  required double paidNet,
  required double adjustments,
}) => roundMoney(feesDue - paidNet + adjustments);

/// What one obligation (fee structure) looks like right now.
class FeeStanding {
  final FeeStructure fee;
  final double paid;

  const FeeStanding(this.fee, this.paid);

  /// Still owed on this fee alone (never below zero).
  double get remaining => roundMoney((fee.amount - paid).clamp(0, double.infinity));
}

/// Per-fee paid/remaining using only non-reversed payments of that fee.
List<FeeStanding> feeStandings(
  Iterable<FeeStructure> applicable,
  Iterable<LedgerPayment> payments,
) {
  final live = payments.where((p) => !p.reversed).toList();
  return [
    for (final fee in applicable)
      FeeStanding(
        fee,
        roundMoney(
          live
              .where((p) => p.feeStructureId == fee.feeStructureId)
              .fold<double>(0, (sum, p) => sum + p.amount),
        ),
      ),
  ];
}

/// Effect of a payment of [amount] against one fee, before it is posted.
class PaymentPreview {
  final double previousBalance;
  final double amount;
  final double newBalance;
  final double feeRemainingBefore;
  final double feeRemainingAfter;

  const PaymentPreview({
    required this.previousBalance,
    required this.amount,
    required this.newBalance,
    required this.feeRemainingBefore,
    required this.feeRemainingAfter,
  });

  /// Amount that would exceed what is still owed on the chosen fee.
  double get overFee => roundMoney((amount - feeRemainingBefore).clamp(0, double.infinity));

  /// True when the payment would take the whole account into credit.
  bool get createsCredit => newBalance < 0;
}

PaymentPreview previewPayment({
  required double balance,
  required double feeRemaining,
  required double amount,
}) {
  final amt = amount > 0 ? amount : 0.0;
  return PaymentPreview(
    previousBalance: roundMoney(balance),
    amount: roundMoney(amt),
    newBalance: roundMoney(balance - amt),
    feeRemainingBefore: roundMoney(feeRemaining),
    feeRemainingAfter: roundMoney((feeRemaining - amt).clamp(0, double.infinity)),
  );
}

/// One student's standing in the bulk overview (search and overdue lists).
class StudentBalanceRow {
  final String studentId;
  final String name;
  final String enrollmentStatus;
  final String? className;
  final String? form;
  final double feesDue;
  final double paid;
  final double adjustments;
  final double balance;
  final DateTime? lastPaymentDate;

  /// Start date of the earliest academic period with an unpaid fee, or null
  /// when unknown. See overdue_rules.dart: fees have no due date of their own.
  final DateTime? dueDate;

  const StudentBalanceRow({
    required this.studentId,
    required this.name,
    required this.enrollmentStatus,
    required this.className,
    required this.form,
    required this.feesDue,
    required this.paid,
    required this.adjustments,
    required this.balance,
    required this.lastPaymentDate,
    this.dueDate,
  });

  bool get owes => balance > 0;
}

/// Minimal student identity for [buildBalanceRows].
class LedgerStudent {
  final String studentId;
  final String name;
  final String enrollmentStatus;

  const LedgerStudent({
    required this.studentId,
    required this.name,
    required this.enrollmentStatus,
  });
}

/// Builds every student's balance from bulk-loaded tables. [payments] must
/// carry only `studentId`, `amount`, `date` and the `reversed` flag.
List<StudentBalanceRow> buildBalanceRows({
  required Iterable<LedgerStudent> students,
  required Map<String, List<LedgerPlacement>> placementsByStudent,
  required Iterable<FeeStructure> fees,
  required Map<String, List<({double amount, DateTime? date, bool reversed})>>
  paymentsByStudent,
  required Map<String, double> adjustmentTotalByStudent,
  DateTime? Function(String studentId, List<FeeStructure> applicable)?
  dueDateFor,
}) {
  final feeList = fees.toList();
  final rows = <StudentBalanceRow>[];
  for (final s in students) {
    final placements = placementsByStudent[s.studentId] ?? const [];
    final applicable = applicableFees(feeList, placements);
    final due = totalFeesDue(applicable);
    final live = (paymentsByStudent[s.studentId] ?? const []).where(
      (p) => !p.reversed,
    );
    final paid = roundMoney(live.fold<double>(0, (sum, p) => sum + p.amount));
    DateTime? last;
    for (final p in live) {
      if (p.date != null && (last == null || p.date!.isAfter(last))) {
        last = p.date;
      }
    }
    final adj = roundMoney(adjustmentTotalByStudent[s.studentId] ?? 0);
    // The "current" placement is the open one, else the most recent.
    LedgerPlacement? current;
    for (final p in placements) {
      if (p.endDate == null) {
        current = p;
        break;
      }
    }
    current ??= placements.isEmpty ? null : placements.last;
    rows.add(
      StudentBalanceRow(
        studentId: s.studentId,
        name: s.name,
        enrollmentStatus: s.enrollmentStatus,
        className: current?.className,
        form: current?.form,
        feesDue: due,
        paid: paid,
        adjustments: adj,
        balance: balanceFromTotals(feesDue: due, paidNet: paid, adjustments: adj),
        lastPaymentDate: last,
        dueDate: dueDateFor?.call(s.studentId, applicable),
      ),
    );
  }
  return rows;
}
