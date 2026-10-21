import 'package:school_management_app/features/academics/domain/models/academic_year.dart';

/// Fee structure row from the [feestructure] table.
class FeeStructure {
  final String feeStructureId;
  final String academicYearId;
  final String feeType;
  final double amount;

  /// Nullable `classid`. Fee structures are school-wide (NULL) since migration
  /// 0035, but the balance rule in SQL still honours a class when present.
  final String? classId;

  /// Optional joined data
  final String? academicYearLabel;

  const FeeStructure({
    required this.feeStructureId,
    required this.academicYearId,
    required this.feeType,
    required this.amount,
    this.classId,
    this.academicYearLabel,
  });

  factory FeeStructure.fromJson(Map<String, dynamic> j) {
    final yr = j['academicyear'] as Map<String, dynamic>?;
    return FeeStructure(
      feeStructureId: j['feestructureid'] as String,
      academicYearId: j['academicyearid'] as String,
      feeType: j['feetype'] as String,
      amount: (j['amount'] as num).toDouble(),
      classId: j['classid'] as String?,
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
