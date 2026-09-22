/// Fee structure row from the [feestructure] table.
class FeeStructure {
  final String feeStructureId;
  final String classId;
  final String academicYearId;
  final String feeType;
  final double amount;

  /// Optional joined data
  final String? className;
  final String? academicYearLabel;

  const FeeStructure({
    required this.feeStructureId,
    required this.classId,
    required this.academicYearId,
    required this.feeType,
    required this.amount,
    this.className,
    this.academicYearLabel,
  });

  factory FeeStructure.fromJson(Map<String, dynamic> j) {
    final cls = j['class'] as Map<String, dynamic>?;
    final yr = j['academicyear'] as Map<String, dynamic>?;
    return FeeStructure(
      feeStructureId: j['feestructureid'] as String,
      classId: j['classid'] as String,
      academicYearId: j['academicyearid'] as String,
      feeType: j['feetype'] as String,
      amount: (j['amount'] as num).toDouble(),
      className: cls?['classroomname'] as String?,
      academicYearLabel: yr != null
          ? '${yr['academicyear']} – ${yr['termname']}'
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'classid': classId,
    'academicyearid': academicYearId,
    'feetype': feeType,
    'amount': amount,
  };

  @override
  String toString() => 'FeeStructure($feeStructureId, $feeType, $amount)';
}
