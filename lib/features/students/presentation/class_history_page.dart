import 'package:flutter/material.dart';
import '../data/student_repository.dart';

/// Shows the class-placement history for one student
/// and allows assigning a new class.
class ClassHistoryPage extends StatefulWidget {
  final String studentId;
  const ClassHistoryPage({required this.studentId, super.key});

  @override
  State<ClassHistoryPage> createState() => _ClassHistoryPageState();
}

class _ClassHistoryPageState extends State<ClassHistoryPage> {
  final _repo = StudentRepository();
  List<Map<String, dynamic>> _history = [];
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
      final rows = await _repo.getClassHistory(widget.studentId);
      if (mounted) setState(() => _history = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Class History'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _history.isEmpty
          ? const Center(child: Text('No class history recorded.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _history.length,
              itemBuilder: (_, i) {
                final row = _history[i];
                final cls = row['class'] as Map<String, dynamic>?;
                final year = row['academicyear'] as Map<String, dynamic>?;
                final isActive = row['enddate'] == null;

                return Card(
                  child: ListTile(
                    leading: Icon(
                      isActive ? Icons.circle : Icons.circle_outlined,
                      color: isActive ? Colors.green : Colors.grey,
                    ),
                    title: Text(cls?['classname'] as String? ?? '—'),
                    subtitle: Text(
                      '${year?['academicyear'] ?? ''} '
                      '${year?['term'] ?? ''}\n'
                      'From: ${row['enrollmentdate']}'
                      '${row['enddate'] != null ? '  To: ${row['enddate']}' : '  (current)'}',
                    ),
                    isThreeLine: true,
                    trailing: isActive
                        ? const Chip(label: Text('Active'))
                        : null,
                  ),
                );
              },
            ),
    );
  }
}
