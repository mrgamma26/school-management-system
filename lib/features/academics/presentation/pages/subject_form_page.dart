import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../widgets/ui_kit.dart';
import '../../data/academic_repository.dart';
import '../../domain/models/subject.dart';

/// Screen 24 - Create or edit a subject.
class SubjectFormPage extends ConsumerStatefulWidget {
  final Subject? existing;
  final AcademicRepository? repository;

  const SubjectFormPage({this.existing, this.repository, super.key});

  @override
  ConsumerState<SubjectFormPage> createState() => _SubjectFormPageState();
}

class _SubjectFormPageState extends ConsumerState<SubjectFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final AcademicRepository _repo =
      widget.repository ?? AcademicRepository();

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

      if (mounted) {
        if (context.canPop()) {
          context.pop(true);
        } else {
          context.go('/academics/subjects');
        }
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormPageLayout(
      kicker: 'Academics',
      title: _isEdit ? 'Edit Subject' : 'Create Subject',
      subtitle: 'Add a reusable subject to the school catalogue.',
      formTitle: 'Subject information',
      saving: _loading,
      saveLabel: _isEdit ? 'Update Subject' : 'Create Subject',
      onSave: _submit,
      error: _error,
      guideTitle: 'Next:',
      guide:
          'After saving, mark the teachers who teach it on their staff profile, then add it to each class in Class Setup and choose a teacher.',
      side: const [
        CheckRow(label: 'Subject names must be unique', checked: true),
        CheckRow(
          label: 'Deleting is blocked once a class uses it',
          checked: true,
        ),
        CheckRow(label: 'Changes are audited', checked: true),
      ],
      form: Form(
        key: _formKey,
        child: FieldGrid(
          children: [
            FullWidth(
              child: UiField(
                label: 'Subject name',
                child: TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    hintText: 'e.g., Mathematics, English, Biology',
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Subject name is required.'
                      : null,
                ),
              ),
            ),
            FullWidth(
              child: UiField(
                label: 'Description (optional)',
                child: TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Brief description of the subject',
                  ),
                  maxLines: 3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
