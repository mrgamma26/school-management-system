import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/student_account_repository.dart';
import '../domain/account_ledger.dart';

/// One student's full account (obligations, payments, adjustments, balance).
final studentAccountProvider = FutureProvider.autoDispose
    .family<StudentAccount, String>((ref, studentId) {
      return StudentAccountRepository().loadAccount(studentId);
    });

/// Every student's computed balance. Feeds the Student Accounts search and the
/// Overdue Accounts list; invalidate it after a payment is posted.
final balanceOverviewProvider =
    FutureProvider.autoDispose<List<StudentBalanceRow>>((ref) {
      return StudentAccountRepository().loadBalanceOverview();
    });
