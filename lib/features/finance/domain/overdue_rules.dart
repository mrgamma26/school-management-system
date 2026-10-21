import 'account_ledger.dart';
import 'models/fee_structure.dart';

/// Pure rules behind the "Days overdue" column on Overdue Accounts.
///
/// Fee structures carry no due date of their own, so the due date of a fee is
/// defined as the START DATE of its academic period (`academicyear.startdate`
/// of the fee's `academicyearid`). A student's due date is the earliest such
/// date among the fees on which something is still owed. No date is invented:
/// when the period start is unknown the result is null and the UI stays blank.

/// Earliest period start among the [applicable] fees that still have an unpaid
/// amount. [paidByFee] is the non-reversed amount paid per fee structure id and
/// [periodStarts] maps an academic year id to that period's start date.
DateTime? earliestOutstandingDueDate({
  required Iterable<FeeStructure> applicable,
  required Map<String, double> paidByFee,
  required Map<String, DateTime> periodStarts,
}) {
  DateTime? earliest;
  for (final fee in applicable) {
    final remaining = roundMoney(fee.amount - (paidByFee[fee.feeStructureId] ?? 0));
    if (remaining <= 0) continue;
    final start = periodStarts[fee.academicYearId];
    if (start == null) continue;
    if (earliest == null || start.isBefore(earliest)) earliest = start;
  }
  return earliest;
}

/// Whole calendar days from [dueDate] to [today], never negative. Null when
/// there is no [dueDate]. Time of day and time zone offsets are ignored.
int? daysOverdue(DateTime? dueDate, DateTime today) {
  if (dueDate == null) return null;
  final due = DateTime.utc(dueDate.year, dueDate.month, dueDate.day);
  final now = DateTime.utc(today.year, today.month, today.day);
  final days = now.difference(due).inDays;
  return days < 0 ? 0 : days;
}

/// How the overdue list is ordered.
enum OverdueSort {
  balanceHighToLow('Balance: high to low'),
  daysOverdueHighToLow('Days overdue: most first');

  final String label;
  const OverdueSort(this.label);
}

/// A sorted copy of [rows]. For days overdue, rows without a date go last; ties
/// fall back to the larger balance, then the name, so the order is stable.
List<StudentBalanceRow> sortOverdueRows(
  Iterable<StudentBalanceRow> rows,
  OverdueSort sort,
  DateTime today,
) {
  int byBalance(StudentBalanceRow a, StudentBalanceRow b) {
    final c = b.balance.compareTo(a.balance);
    return c != 0 ? c : a.name.compareTo(b.name);
  }

  final list = rows.toList();
  switch (sort) {
    case OverdueSort.balanceHighToLow:
      list.sort(byBalance);
    case OverdueSort.daysOverdueHighToLow:
      list.sort((a, b) {
        final da = daysOverdue(a.dueDate, today);
        final db = daysOverdue(b.dueDate, today);
        if (da == null && db == null) return byBalance(a, b);
        if (da == null) return 1;
        if (db == null) return -1;
        final c = db.compareTo(da);
        return c != 0 ? c : byBalance(a, b);
      });
  }
  return list;
}
