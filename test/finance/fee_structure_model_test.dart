import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/finance/domain/models/fee_structure.dart';

void main() {
  group('FeeStructure.fromJson', () {
    const baseJson = {
      'feestructureid': 'fee-001',
      'academicyearid': 'yr-001',
      'feetype': 'TUITION',
      'amount': 75000.00,
    };

    test('parses required fields', () {
      final fs = FeeStructure.fromJson(baseJson);
      expect(fs.feeStructureId, 'fee-001');
      expect(fs.academicYearId, 'yr-001');
      expect(fs.feeType, 'TUITION');
      expect(fs.amount, 75000.0);
    });

    test('joined fields are null when absent', () {
      final fs = FeeStructure.fromJson(baseJson);
      expect(fs.academicYearLabel, isNull);
    });

    test('parses integer amount as double', () {
      final json = {...baseJson, 'amount': 50000};
      final fs = FeeStructure.fromJson(json);
      expect(fs.amount, 50000.0);
      expect(fs.amount, isA<double>());
    });

    test('toInsertJson excludes id field', () {
      final fs = FeeStructure.fromJson(baseJson);
      final insert = fs.toInsertJson();
      expect(insert.containsKey('feestructureid'), isFalse);
      expect(insert['academicyearid'], 'yr-001');
      expect(insert['feetype'], 'TUITION');
      expect(insert['amount'], 75000.0);
    });

    test('toInsertJson contains exactly 3 keys', () {
      final fs = FeeStructure.fromJson(baseJson);
      expect(fs.toInsertJson().length, 3);
    });
  });
}
