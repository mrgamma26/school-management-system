import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import 'payment_list_page.dart';
import 'adjustment_page.dart';

/// Student financial account overview — entry point for the accountant
/// when they tap a student. Shows navigation tiles to Payments and Adjustments.
class StudentAccountPage extends ConsumerWidget {
  final String studentId;
  final String studentName;

  const StudentAccountPage({
    required this.studentId,
    required this.studentName,
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).user?.roleName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(studentName),
        actions: [HomeButton(roleName: role)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          _tile(
            context,
            icon: Icons.payments,
            color: Colors.green,
            title: 'Payments',
            subtitle: 'View and record fee payments',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PaymentListPage(
                  studentId: studentId,
                  studentName: studentName,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _tile(
            context,
            icon: Icons.tune,
            color: Colors.blue,
            title: 'Adjustments',
            subtitle: 'Discounts, waivers and penalties',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AdjustmentPage(
                  studentId: studentId,
                  studentName: studentName,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
