/// Payment record from the [payment] table.
class Payment {
  final String paymentId;
  final String studentId;
  final String feeStructureId;
  final String recordedBy;
  final double amount;
  final DateTime paymentDate;
  final String method;
  final String? referenceNumber;
  final String? receiptNumber;
  final String? channelId;
  final String? channelSummary;
  final double processingFee;

  /// Optional joined data
  final String? studentName;
  final String? feeType;

  const Payment({
    required this.paymentId,
    required this.studentId,
    required this.feeStructureId,
    required this.recordedBy,
    required this.amount,
    required this.paymentDate,
    required this.method,
    this.referenceNumber,
    this.receiptNumber,
    this.channelId,
    this.channelSummary,
    this.processingFee = 0,
    this.studentName,
    this.feeType,
  });

  factory Payment.fromJson(Map<String, dynamic> j) {
    final student = j['student'] as Map<String, dynamic>?;
    final fee = j['feestructure'] as Map<String, dynamic>?;
    final channel = j['paymentchannel'] as Map<String, dynamic>?;
    return Payment(
      paymentId: j['paymentid'] as String,
      studentId: j['studentid'] as String,
      feeStructureId: j['feestructureid'] as String,
      recordedBy: j['recordedby'] as String,
      amount: (j['amount'] as num).toDouble(),
      paymentDate: DateTime.parse(j['paymentdate'] as String),
      method: j['method'].toString(),
      referenceNumber: j['referencenumber'] as String?,
      receiptNumber: j['receiptnumber'] as String?,
      channelId: j['channelid'] as String?,
      channelSummary: channel == null
          ? null
          : '${channel['displayname']} · ${channel['providername']} · ${channel['maskedidentifier']}',
      processingFee: (j['processingfee'] as num?)?.toDouble() ?? 0,
      studentName: student != null
          ? '${student['firstname']} ${student['lastname']}'
          : null,
      feeType: fee?['feetype'] as String?,
    );
  }

  @override
  String toString() => 'Payment($paymentId, $amount, $method)';
}

/// Valid payment methods matching the [payment_method_enum] in the database.
const List<String> kPaymentMethods = [
  'CASH',
  'BANK_TRANSFER',
  'MOBILE_MONEY',
  'CARD',
  'CHEQUE',
  'OTHER',
];
