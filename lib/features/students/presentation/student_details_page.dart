import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/student_repository.dart';
import '../domain/student.dart';
import 'student_form_page.dart';
import 'guardian_link_page.dart';
import 'class_history_page.dart';

/// Shows full student details with navigation to edit, guardian links
/// and class history.
class StudentDetailsPage extends StatefulWidget {
  final String studentId;
  const StudentDetailsPage({required this.studentId, super.key});

  @override
  State<StudentDetailsPage> createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends State<StudentDetailsPage> {
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
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
              await Navigator.push<bool>(
                context,
                MaterialPageRoute(builder: (_) => StudentFormPage(existing: s)),
              );
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
          _actionTile(
            context,
            icon: Icons.family_restroom,
            title: 'Guardian Links',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => GuardianLinkPage(studentId: s.studentId),
              ),
            ),
          ),
          _actionTile(
            context,
            icon: Icons.history_edu,
            title: 'Class History',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ClassHistoryPage(studentId: s.studentId),
              ),
            ),
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
