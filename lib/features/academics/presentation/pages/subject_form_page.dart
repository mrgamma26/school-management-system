import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/academic_repository.dart';
import '../../domain/models/subject.dart';

/// Create or edit a subject.
class SubjectFormPage extends ConsumerStatefulWidget {
  final Subject? existing;

  const SubjectFormPage({this.existing, super.key});

  @override
  ConsumerState<SubjectFormPage> createState() => _SubjectFormPageState();
}

class _SubjectFormPageState extends ConsumerState<SubjectFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = AcademicRepository();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.subjectName ?? '');
    _descCtrl = TextEditingController(text: existing?.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final description = _descCtrl.text.trim();
      if (_isEdit) {
        await _repo.updateSubject(
          widget.existing!.subjectId,
          _nameCtrl.text.trim(),
          description.isEmpty ? null : description,
        );
      } else {
        await _repo.createSubject(
          _nameCtrl.text.trim(),
          description.isEmpty ? null : description,
        );
      }

      if (mounted) context.go('/academics/subjects');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Subject' : 'Create Subject')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Subject Name',
                  hintText: 'e.g., Mathematics, English, Biology',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Subject name is required.'
                    : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Brief description of the subject',
                ),
                maxLines: 3,
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red)),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_isEdit ? 'Update Subject' : 'Create Subject'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
