import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import 'package:go_router/go_router.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../data/student_repository.dart';
import '../domain/student.dart';
import '../../../widgets/skeleton_loader.dart';

/// Shows full student details with navigation to edit, guardian links
/// and class history.
class StudentDetailsPage extends ConsumerStatefulWidget {
  final String studentId;
  const StudentDetailsPage({required this.studentId, super.key});

  @override
  ConsumerState<StudentDetailsPage> createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends ConsumerState<StudentDetailsPage> {
  final _repo = StudentRepository();
  Student? _student;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _repo.getStudent(widget.studentId);
      if (mounted) setState(() => _student = s);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: SkeletonListLoader(itemCount: 4, itemHeight: 100),
      );
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Student'),
          actions: [
            IconButton(
              icon: const Icon(Icons.home_outlined),
              tooltip: 'Home',
              onPressed: () => context.go('/students'),
            ),
          ],
        ),
        body: Center(child: Text(_error!)),
      );
    }

    final s = _student!;
    final role = ref.watch(authProvider).user?.roleName.trim().toUpperCase();
    final canManageAccounts = role == 'ACCOUNTANT' || role == 'SUPER_USER';

    return Scaffold(
      appBar: AppBar(
        title: Text(s.fullName),
        actions: [
          IconButton(
            icon: const Icon(Icons.home_outlined),
            tooltip: 'Home',
            onPressed: () => context.go('/students'),
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit',
            onPressed: () async {
              await context.push<bool>('/students/${s.studentId}/edit');
              _load();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _infoCard(s),
          const SizedBox(height: 12),
          if (canManageAccounts)
            _actionTile(
              context,
              icon: Icons.account_balance_wallet_outlined,
              title: 'Student Account & Payments',
              onTap: () => context.go(
                '/finance/students/${s.studentId}/account'
                '?name=${Uri.encodeComponent(s.fullName)}',
              ),
            ),
          _actionTile(
            context,
            icon: Icons.family_restroom,
            title: 'Manage Guardians',
            onTap: () => context.go('/students/${s.studentId}/link-guardian'),
          ),
          _actionTile(
            context,
            icon: Icons.menu_book_outlined,
            title: 'Manage Subjects',
            onTap: () => context.go('/students/${s.studentId}/subjects'),
          ),
          _actionTile(
            context,
            icon: Icons.history_edu,
            title: 'Class History',
            onTap: () => context.go('/students/${s.studentId}/class-history'),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(Student s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _row('Full Name', s.fullName),
            _row('Gender', s.gender),
            _row(
              'Date of Birth',
              s.dateOfBirth.toIso8601String().substring(0, 10),
            ),
            _row('Enrollment Status', s.enrollmentStatus),
            if (s.physicalAddress != null) _row('Address', s.physicalAddress!),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );

  Widget _actionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
