import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/finance/domain/account_ledger.dart';
import 'package:school_management_app/features/finance/domain/models/fee_structure.dart';
import 'package:school_management_app/features/finance/domain/overdue_rules.dart';

FeeStructure _fee(String id, String year, double amount) => FeeStructure(
  feeStructureId: id,
  academicYearId: year,
  feeType: 'Tuition',
  amount: amount,
);

StudentBalanceRow _row(
  String name,
  double balance, {
  DateTime? dueDate,
}) => StudentBalanceRow(
  studentId: name,
  name: name,
  enrollmentStatus: 'ACTIVE',
  className: null,
  form: null,
  feesDue: balance,
  paid: 0,
  adjustments: 0,
  balance: balance,
  lastPaymentDate: null,
  dueDate: dueDate,
);

void main() {
  final today = DateTime(2026, 10, 19, 15, 30);

  group('daysOverdue', () {
    test('counts whole calendar days since the due date', () {
      expect(daysOverdue(DateTime(2026, 10, 9), today), 10);
      expect(daysOverdue(DateTime(2026, 10, 19), today), 0);
    });

    test('ignores the time of day', () {
      expect(daysOverdue(DateTime(2026, 10, 18, 23, 59), today), 1);
    });

    test('is never negative for a future period', () {
      expect(daysOverdue(DateTime(2027, 1, 5), today), 0);
    });

    test('is null (blank) without a due date', () {
      expect(daysOverdue(null, today), isNull);
    });
  });

  group('earliestOutstandingDueDate', () {
    final starts = {
      'y1': DateTime(2026, 1, 12),
      'y2': DateTime(2026, 5, 4),
    };

    test('uses the earliest period that still has an unpaid fee', () {
      final due = earliestOutstandingDueDate(
        applicable: [_fee('f1', 'y1', 100), _fee('f2', 'y2', 100)],
        paidByFee: const {'f1': 40},
        periodStarts: starts,
      );
      expect(due, DateTime(2026, 1, 12));
    });

    test('skips fees that are fully paid', () {
      final due = earliestOutstandingDueDate(
        applicable: [_fee('f1', 'y1', 100), _fee('f2', 'y2', 100)],
        paidByFee: const {'f1': 100},
        periodStarts: starts,
      );
      expect(due, DateTime(2026, 5, 4));
    });

    test('is null when every fee is paid or the start date is unknown', () {
      expect(
        earliestOutstandingDueDate(
          applicable: [_fee('f1', 'y1', 100)],
          paidByFee: const {'f1': 100},
          periodStarts: starts,
        ),
        isNull,
      );
      expect(
        earliestOutstandingDueDate(
          applicable: [_fee('f9', 'unknown', 100)],
          paidByFee: const {},
          periodStarts: starts,
        ),
        isNull,
      );
    });
  });

  group('buildBalanceRows dueDateFor', () {
    test('attaches the callback result to each row', () {
      final rows = buildBalanceRows(
        students: const [
          LedgerStudent(studentId: 's1', name: 'Ada', enrollmentStatus: 'ACTIVE'),
        ],
        placementsByStudent: const {
          's1': [LedgerPlacement(classId: 'c1', academicYearId: 'y1')],
        },
        fees: [_fee('f1', 'y1', 100)],
        paymentsByStudent: const {},
        adjustmentTotalByStudent: const {},
        dueDateFor: (id, applicable) =>
            applicable.isEmpty ? null : DateTime(2026, 1, 12),
      );
      expect(rows.single.dueDate, DateTime(2026, 1, 12));
    });
  });

  group('sortOverdueRows', () {
    final rows = [
      _row('Ben', 50, dueDate: DateTime(2026, 9, 1)),
      _row('Ada', 200, dueDate: DateTime(2026, 5, 1)),
      _row('Cy', 300),
      _row('Dee', 200, dueDate: DateTime(2026, 5, 1)),
    ];

    test('by balance, largest first, ties by name', () {
      final names = sortOverdueRows(
        rows,
        OverdueSort.balanceHighToLow,
        today,
      ).map((r) => r.name);
      expect(names, ['Cy', 'Ada', 'Dee', 'Ben']);
    });

    test('by days overdue, most first, unknown dates last', () {
      final names = sortOverdueRows(
        rows,
        OverdueSort.daysOverdueHighToLow,
        today,
      ).map((r) => r.name);
      expect(names, ['Ada', 'Dee', 'Ben', 'Cy']);
    });

    test('does not mutate the input', () {
      sortOverdueRows(rows, OverdueSort.daysOverdueHighToLow, today);
      expect(rows.first.name, 'Ben');
    });
  });
}
