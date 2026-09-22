/// Financial adjustment (discount, waiver or penalty) from [financialadjustment].
class FinancialAdjustment {
  final String adjustmentId;
  final String studentId;
  final String approvedBy;
  final double amount; // negative = discount/waiver, positive = penalty
  final String reason;
  final DateTime createdAt;

  /// Optional joined data
  final String? studentName;
  final String? approvedByName;

  const FinancialAdjustment({
    required this.adjustmentId,
    required this.studentId,
    required this.approvedBy,
    required this.amount,
    required this.reason,
    required this.createdAt,
    this.studentName,
    this.approvedByName,
  });

  bool get isDiscount => amount < 0;
  bool get isPenalty => amount > 0;

  factory FinancialAdjustment.fromJson(Map<String, dynamic> j) {
    final student = j['student'] as Map<String, dynamic>?;
    final staff = j['staff'] as Map<String, dynamic>?;
    return FinancialAdjustment(
      adjustmentId: j['adjustmentid'] as String,
      studentId: j['studentid'] as String,
      approvedBy: j['approvedby'] as String,
      amount: (j['amount'] as num).toDouble(),
      reason: j['reason'] as String,
      createdAt: DateTime.parse(j['createdat'] as String),
      studentName: student != null
          ? '${student['firstname']} ${student['lastname']}'
          : null,
      approvedByName: staff != null
          ? '${staff['firstname']} ${staff['lastname']}'
          : null,
    );
  }

  @override
  String toString() => 'FinancialAdjustment($adjustmentId, $amount)';
}
