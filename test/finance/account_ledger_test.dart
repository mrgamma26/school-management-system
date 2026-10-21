import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/features/finance/domain/account_ledger.dart';
import 'package:school_management_app/features/finance/domain/models/fee_structure.dart';

FeeStructure fee(String id, String year, double amount, {String? classId}) =>
    FeeStructure(
      feeStructureId: id,
      academicYearId: year,
      feeType: 'Fee $id',
      amount: amount,
      classId: classId,
    );

LedgerPlacement place(String year, {String classId = 'c1'}) =>
    LedgerPlacement(classId: classId, academicYearId: year);

LedgerPayment pay(String id, String feeId, double amount,
        {bool reversed = false}) =>
    LedgerPayment(
      paymentId: id,
      feeStructureId: feeId,
      amount: amount,
      paymentDate: DateTime(2026, 10, 1),
      method: 'CASH',
      reversed: reversed,
    );

LedgerAdjustment adj(double amount) => LedgerAdjustment(
  adjustmentId: 'a$amount',
  amount: amount,
  reason: 'test',
  createdAt: DateTime(2026, 10, 1),
);

void main() {
  group('computeOutstandingBalance mirrors private.student_outstanding_balance',
      () {
    test('fees minus payments plus adjustments', () {
      final balance = computeOutstandingBalance(
        fees: [fee('f1', 'y1', 150000), fee('f2', 'y1', 30000)],
        placements: [place('y1')],
        payments: [pay('p1', 'f1', 50000), pay('p2', 'f1', 70000)],
        adjustments: [adj(-15000), adj(5000)],
      );
      // 180000 - 120000 + (-10000)
      expect(balance, 50000);
    });

    test('only fees of academic years the student was placed in count', () {
      final balance = computeOutstandingBalance(
        fees: [fee('f1', 'y1', 100), fee('f2', 'y2', 900)],
        placements: [place('y1')],
        payments: const [],
        adjustments: const [],
      );
      expect(balance, 100);
    });

    test('a class-specific fee only applies to that class', () {
      final fees = [
        fee('school', 'y1', 100),
        fee('c1fee', 'y1', 40, classId: 'c1'),
        fee('c2fee', 'y1', 70, classId: 'c2'),
      ];
      expect(
        computeOutstandingBalance(
          fees: fees,
          placements: [place('y1', classId: 'c1')],
          payments: const [],
          adjustments: const [],
        ),
        140,
      );
    });

    test('a fee matching several placements is counted once', () {
      final balance = computeOutstandingBalance(
        fees: [fee('f1', 'y1', 100)],
        placements: [place('y1'), place('y1', classId: 'c9')],
        payments: const [],
        adjustments: const [],
      );
      expect(balance, 100);
    });

    test('reversed payments are excluded from what was paid', () {
      final balance = computeOutstandingBalance(
        fees: [fee('f1', 'y1', 100)],
        placements: [place('y1')],
        payments: [pay('p1', 'f1', 60), pay('p2', 'f1', 40, reversed: true)],
        adjustments: const [],
      );
      expect(balance, 40);
    });

    test('negative balance means credit and decimals stay clean', () {
      final balance = computeOutstandingBalance(
        fees: [fee('f1', 'y1', 100.10)],
        placements: [place('y1')],
        payments: [pay('p1', 'f1', 100.20)],
        adjustments: const [],
      );
      expect(balance, -0.10);
    });

    test('no placement means nothing is owed', () {
      expect(
        computeOutstandingBalance(
          fees: [fee('f1', 'y1', 100)],
          placements: const [],
          payments: const [],
          adjustments: const [],
        ),
        0,
      );
    });
  });

  group('feeStandings and previewPayment', () {
    test('per-fee remaining ignores reversed payments', () {
      final standings = feeStandings(
        [fee('f1', 'y1', 100), fee('f2', 'y1', 50)],
        [pay('p1', 'f1', 30), pay('p2', 'f1', 20, reversed: true)],
      );
      expect(standings[0].paid, 30);
      expect(standings[0].remaining, 70);
      expect(standings[1].remaining, 50);
    });

    test('preview gives new balance and fee remainder', () {
      final p = previewPayment(balance: 130000, feeRemaining: 80000, amount: 70000);
      expect(p.newBalance, 60000);
      expect(p.feeRemainingAfter, 10000);
      expect(p.overFee, 0);
      expect(p.createsCredit, isFalse);
    });

    test('preview flags amounts above the fee remainder and credit', () {
      final p = previewPayment(balance: 50, feeRemaining: 50, amount: 80);
      expect(p.overFee, 30);
      expect(p.newBalance, -30);
      expect(p.createsCredit, isTrue);
      expect(p.feeRemainingAfter, 0);
    });

    test('non-positive amounts preview as zero', () {
      final p = previewPayment(balance: 100, feeRemaining: 100, amount: -5);
      expect(p.amount, 0);
      expect(p.newBalance, 100);
    });
  });

  group('buildBalanceRows', () {
    test('combines totals per student', () {
      final rows = buildBalanceRows(
        students: const [
          LedgerStudent(studentId: 's1', name: 'A One', enrollmentStatus: 'ENROLLED'),
          LedgerStudent(studentId: 's2', name: 'B Two', enrollmentStatus: 'ENROLLED'),
        ],
        placementsByStudent: {
          's1': [place('y1')],
          's2': [place('y1')],
        },
        fees: [fee('f1', 'y1', 100)],
        paymentsByStudent: {
          's1': [
            (amount: 60.0, date: DateTime(2026, 9, 1), reversed: false),
            (amount: 10.0, date: DateTime(2026, 10, 2), reversed: false),
            (amount: 30.0, date: DateTime(2026, 10, 3), reversed: true),
          ],
        },
        adjustmentTotalByStudent: {'s2': -25},
      );
      final one = rows.firstWhere((r) => r.studentId == 's1');
      final two = rows.firstWhere((r) => r.studentId == 's2');
      expect(one.balance, 30);
      expect(one.owes, isTrue);
      expect(one.lastPaymentDate, DateTime(2026, 10, 2));
      expect(two.balance, 75);
    });

    test('a paid-up student does not owe', () {
      final rows = buildBalanceRows(
        students: const [
          LedgerStudent(studentId: 's1', name: 'A One', enrollmentStatus: 'ENROLLED'),
        ],
        placementsByStudent: {
          's1': [place('y1')],
        },
        fees: [fee('f1', 'y1', 100)],
        paymentsByStudent: {
          's1': [(amount: 100.0, date: null, reversed: false)],
        },
        adjustmentTotalByStudent: const {},
      );
      expect(rows.single.owes, isFalse);
      expect(rows.single.balance, 0);
    });
  });
}
