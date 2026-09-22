import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/staff.dart';
import '../../data/repositories/user_repository.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/services/audit_service.dart';
import '../../../../core/widgets/app_widgets.dart';

/// Create or edit a staff member.
/// New accounts are created via the [create-user] Edge Function.
class StaffFormPage extends ConsumerStatefulWidget {
  final Staff? existing;
  const StaffFormPage({this.existing, super.key});

  @override
  ConsumerState<StaffFormPage> createState() => _StaffFormPageState();
}

class _StaffFormPageState extends ConsumerState<StaffFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = UserRepository();

  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _middleNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _employeeNumberCtrl;
  late final TextEditingController _passwordCtrl;
  String _gender = 'MALE';
  String? _selectedRoleId;
  List<Map<String, dynamic>> _roles = [];
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    _firstNameCtrl = TextEditingController(text: s?.firstName ?? '');
    _middleNameCtrl = TextEditingController(text: s?.middleName ?? '');
    _lastNameCtrl = TextEditingController(text: s?.lastName ?? '');
    _emailCtrl = TextEditingController(text: s?.email ?? '');
    _employeeNumberCtrl = TextEditingController(text: s?.employeeNumber ?? '');
    _passwordCtrl = TextEditingController();
    _gender = s?.gender ?? 'MALE';
    _loadRoles();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _emailCtrl.dispose();
    _employeeNumberCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await _repo.listRoles();
      if (mounted) setState(() => _roles = roles);
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final currentUser = ref.read(authProvider).user!;

      if (_isEdit) {
        final old = widget.existing!;
        final data = {
          'firstname': _firstNameCtrl.text.trim(),
          'middlename': _middleNameCtrl.text.trim().isEmpty
              ? null
              : _middleNameCtrl.text.trim(),
          'lastname': _lastNameCtrl.text.trim(),
          'gender': _gender,
          'email': _emailCtrl.text.trim(),
        };
        await _repo.updateStaff(old.staffId, data);
        await AuditService().log(
          userId: currentUser.userId,
          action: 'STAFF_UPDATED',
          tableName: 'staff',
          recordId: old.staffId,
          previousValue: old.toUpdateJson(),
          newValue: data,
          actorRole: currentUser.roleName,
        );
      } else {
        await _repo.createUser({
          'email': _emailCtrl.text.trim(),
          'password': _passwordCtrl.text,
          'username': _emailCtrl.text.trim(),
          'roleId': _selectedRoleId,
          'type': 'staff',
          'firstName': _firstNameCtrl.text.trim(),
          'middleName': _middleNameCtrl.text.trim().isEmpty
              ? null
              : _middleNameCtrl.text.trim(),
          'lastName': _lastNameCtrl.text.trim(),
          'gender': _gender,
          'employeeNumber': _employeeNumberCtrl.text.trim(),
        });
        await AuditService().log(
          userId: currentUser.userId,
          action: 'STAFF_CREATED',
          tableName: 'staff',
          actorRole: currentUser.roleName,
        );
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
        title: Text(_isEdit ? 'Edit Staff' : 'Add Staff'),
        actions: [HomeButton(roleName: role)],
      ),
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
              if (!_isEdit) ...[
                _field(_employeeNumberCtrl, 'Employee Number'),
                _field(_passwordCtrl, 'Temporary Password', obscure: true),
                if (_roles.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedRoleId,
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: _roles
                        .map(
                          (r) => DropdownMenuItem(
                            value: r['roleid'] as String,
                            child: Text(r['rolename'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedRoleId = v),
                    validator: (v) =>
                        v == null ? 'Please select a role.' : null,
                  ),
                const SizedBox(height: 8),
              ],
              DropdownButtonFormField<String>(
                value: _gender,
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
                      : Text(_isEdit ? 'Save Changes' : 'Create Staff'),
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
    bool obscure = false,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
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
