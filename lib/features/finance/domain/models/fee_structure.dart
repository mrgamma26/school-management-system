import 'package:school_management_app/features/academics/domain/models/academic_year.dart';

/// Fee structure row from the [feestructure] table.
class FeeStructure {
  final String feeStructureId;
  final String academicYearId;
  final String feeType;
  final double amount;

  /// Optional joined data
  final String? academicYearLabel;

  const FeeStructure({
    required this.feeStructureId,
    required this.academicYearId,
    required this.feeType,
    required this.amount,
    this.academicYearLabel,
  });

  factory FeeStructure.fromJson(Map<String, dynamic> j) {
    final yr = j['academicyear'] as Map<String, dynamic>?;
    return FeeStructure(
      feeStructureId: j['feestructureid'] as String,
      academicYearId: j['academicyearid'] as String,
      feeType: j['feetype'] as String,
      amount: (j['amount'] as num).toDouble(),
      academicYearLabel: yr != null
          ? '${formatAcademicYear(yr['academicyear'])} · ${yr['term']}'
          : null,
    );
  }

  Map<String, dynamic> toInsertJson() => {
    'academicyearid': academicYearId,
    'feetype': feeType,
    'amount': amount,
  };

  @override
  String toString() => 'FeeStructure($feeStructureId, $feeType, $amount)';
}
