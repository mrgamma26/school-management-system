import 'package:flutter/material.dart';
import '../../../../core/errors/app_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/guardian.dart';
import '../../data/repositories/user_repository.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/services/audit_service.dart';

/// Edit an existing guardian account. New guardians are registered with students.
class GuardianFormPage extends ConsumerStatefulWidget {
  final Guardian existing;
  const GuardianFormPage({required this.existing, super.key});

  @override
  ConsumerState<GuardianFormPage> createState() => _GuardianFormPageState();
}

class _GuardianFormPageState extends ConsumerState<GuardianFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = UserRepository();

  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _middleNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _addressCtrl;
  String _gender = 'MALE';
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final g = widget.existing;
    _firstNameCtrl = TextEditingController(text: g.firstName);
    _middleNameCtrl = TextEditingController(text: g.middleName ?? '');
    _lastNameCtrl = TextEditingController(text: g.lastName);
    _emailCtrl = TextEditingController(text: g.email ?? '');
    _phoneCtrl = TextEditingController(text: g.phoneNumber ?? '');
    _addressCtrl = TextEditingController(text: g.physicalAddress ?? '');
    _gender = g.gender;
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final currentUser = ref.read(authProvider).user!;

      final old = widget.existing;
      final data = {
        'firstname': _firstNameCtrl.text.trim(),
        'middlename': _middleNameCtrl.text.trim().isEmpty
            ? null
            : _middleNameCtrl.text.trim(),
        'lastname': _lastNameCtrl.text.trim(),
        'gender': _gender,
        'phonenumber': _phoneCtrl.text.trim().isEmpty
            ? null
            : _phoneCtrl.text.trim(),
        'physicaladdress': _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
      };
      await _repo.updateGuardian(old.guardianId, data);
      await AuditService().log(
        userId: currentUser.userId,
        action: 'GUARDIAN_UPDATED',
        tableName: 'guardian',
        recordId: old.guardianId,
        previousValue: old.toUpdateJson(),
        newValue: data,
        actorRole: currentUser.roleName,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Guardian')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _field(_firstNameCtrl, 'First Name'),
              _field(_middleNameCtrl, 'Middle Name', required: false),
              _field(_lastNameCtrl, 'Last Name'),
              _field(_emailCtrl, 'Email', keyboard: TextInputType.emailAddress),
              _field(
                _phoneCtrl,
                'Phone Number',
                required: false,
                keyboard: TextInputType.phone,
              ),
              _field(_addressCtrl, 'Physical Address', required: false),
              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'MALE', child: Text('Male')),
                  DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                ],
                onChanged: (v) => setState(() => _gender = v!),
              ),
              const SizedBox(height: 16),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
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
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = true,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) =>
                  (v == null || v.trim().isEmpty) ? '$label is required.' : null
            : null,
      ),
    );
  }
}
