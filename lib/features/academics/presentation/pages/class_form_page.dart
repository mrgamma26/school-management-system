import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/academic_repository.dart';
import '../../domain/models/class_model.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/app_widgets.dart';

/// Create or edit a class.
class ClassFormPage extends ConsumerStatefulWidget {
  final ClassModel? existing;

  const ClassFormPage({this.existing, super.key});

  @override
  ConsumerState<ClassFormPage> createState() => _ClassFormPageState();
}

class _ClassFormPageState extends ConsumerState<ClassFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = AcademicRepository();

  late final TextEditingController _nameCtrl;
  String? _form;
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.className ?? '');
    _form = existing?.form;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await _repo.updateClass(
          widget.existing!.classId,
          _nameCtrl.text.trim(),
          _form,
        );
      } else {
        await _repo.createClass(_nameCtrl.text.trim(), _form);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.roleName ?? '';
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit Class' : 'Create Class'),
        actions: [HomeButton(roleName: role)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Class Name',
                  hintText: 'e.g., Form 1A, Form 2B',
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Class name is required.'
                    : null,
              ),
              const SizedBox(height: 16),

              // Form Level Selection
              DropdownButtonFormField<String>(
                initialValue: _form,
                decoration: const InputDecoration(
                  labelText: 'Form Level',
                  hintText: 'Select form level',
                ),
                items: const [
                  DropdownMenuItem(value: null, child: Text('None/Other')),
                  DropdownMenuItem(value: 'FORM_1', child: Text('Form 1')),
                  DropdownMenuItem(value: 'FORM_2', child: Text('Form 2')),
                  DropdownMenuItem(value: 'FORM_3', child: Text('Form 3')),
                  DropdownMenuItem(value: 'FORM_4', child: Text('Form 4')),
                ],
                onChanged: (v) => setState(() => _form = v),
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
                      : Text(_isEdit ? 'Update Class' : 'Create Class'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
