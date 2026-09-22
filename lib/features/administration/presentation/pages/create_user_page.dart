import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../users/data/repositories/user_repository.dart';

// Generates a secure random password: 12 chars, mixed case + digit + symbol.
String _generatePassword() {
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const lower = 'abcdefghjkmnpqrstuvwxyz';
  const digits = '23456789';
  const symbols = r'!@#$%&*';
  const all = upper + lower + digits + symbols;
  final rng = Random.secure();
  final buf = StringBuffer()
    ..write(upper[rng.nextInt(upper.length)])
    ..write(lower[rng.nextInt(lower.length)])
    ..write(digits[rng.nextInt(digits.length)])
    ..write(symbols[rng.nextInt(symbols.length)]);
  for (var i = 4; i < 12; i++) {
    buf.write(all[rng.nextInt(all.length)]);
  }
  final chars = buf.toString().split('')..shuffle(rng);
  return chars.join();
}

class CreateUserPage extends ConsumerStatefulWidget {
  const CreateUserPage({super.key});

  @override
  ConsumerState<CreateUserPage> createState() => _CreateUserPageState();
}

class _CreateUserPageState extends ConsumerState<CreateUserPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = UserRepository();

  final _emailCtrl = TextEditingController();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _employeeNumberCtrl = TextEditingController();

  String _userType = 'STAFF';
  String _gender = 'MALE';
  String? _selectedRoleId;
  List<Map<String, dynamic>> _roles = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _employeeNumberCtrl.dispose();
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
    if (_selectedRoleId == null) {
      setState(() => _error = 'Please select a role.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final generatedPassword = _generatePassword();

    try {
      final currentUser = ref.read(authProvider).user!;

      final payload = {
        'email': _emailCtrl.text.trim(),
        'password': generatedPassword,
        'username': _emailCtrl.text.trim().split('@').first,
        'roleId': _selectedRoleId!,
        'userType': _userType,
        'profileData': {
          'firstname': _firstNameCtrl.text.trim(),
          'middlename': _middleNameCtrl.text.trim().isEmpty
              ? null
              : _middleNameCtrl.text.trim(),
          'lastname': _lastNameCtrl.text.trim(),
          'gender': _gender,
          'email': _emailCtrl.text.trim(),
          if (_userType == 'STAFF')
            'employeenumber': _employeeNumberCtrl.text.trim(),
          if (_userType == 'GUARDIAN') ...{
            'phonenumber': _phoneCtrl.text.trim().isEmpty
                ? null
                : _phoneCtrl.text.trim(),
            'physicaladdress': _addressCtrl.text.trim().isEmpty
                ? null
                : _addressCtrl.text.trim(),
          },
        },
      };

      await _repo.createUser(payload);

      if (!mounted) return;

      // Show the generated password to the admin before popping.
      await _showPasswordDialog(
        context: context,
        name: '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}',
        email: _emailCtrl.text.trim(),
        password: generatedPassword,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  static Future<void> _showPasswordDialog({
    required BuildContext context,
    required String name,
    required String email,
    required String password,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) =>
          _PasswordCreatedDialog(name: name, email: email, password: password),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).user?.roleName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create User'),
        actions: [HomeButton(roleName: role)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User type toggle
              const Text(
                'User Type',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'STAFF', label: Text('Staff')),
                  ButtonSegment(value: 'GUARDIAN', label: Text('Guardian')),
                ],
                selected: {_userType},
                onSelectionChanged: (set) {
                  setState(() {
                    _userType = set.first;
                    _selectedRoleId = null;
                  });
                },
              ),
              const SizedBox(height: 16),

              // Email
              _textField(
                _emailCtrl,
                'Email address',
                required: true,
                keyboardType: TextInputType.emailAddress,
                hint: 'user@school.com',
              ),

              // Role dropdown - filtered by user type
              if (_roles.isNotEmpty) ...[
                const SizedBox(height: 4),
                DropdownButtonFormField<String>(
                  initialValue: _selectedRoleId,
                  decoration: const InputDecoration(labelText: 'Role *'),
                  items: _roles
                      .where((r) {
                        final rn = (r['rolename'] as String).toUpperCase();
                        if (_userType == 'GUARDIAN') {
                          return rn == 'GUARDIAN';
                        }
                        return rn != 'GUARDIAN';
                      })
                      .map(
                        (r) => DropdownMenuItem<String>(
                          value: r['roleid'] as String,
                          child: Text(r['rolename'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedRoleId = v),
                  validator: (v) => v == null ? 'Please select a role.' : null,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 14,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Need a role that is not listed? Go to User Management -> '
                        'select any user -> Manage Permissions to create new roles.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 16),
              const Divider(),
              const Text(
                'Personal Information',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              _textField(_firstNameCtrl, 'First Name', required: true),
              _textField(_middleNameCtrl, 'Middle Name'),
              _textField(_lastNameCtrl, 'Last Name', required: true),

              DropdownButtonFormField<String>(
                initialValue: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'MALE', child: Text('Male')),
                  DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                ],
                onChanged: (v) => setState(() => _gender = v!),
              ),

              // Staff-specific fields
              if (_userType == 'STAFF') ...[
                const SizedBox(height: 16),
                const Divider(),
                const Text(
                  'Staff Information',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _textField(
                  _employeeNumberCtrl,
                  'Employee Number',
                  required: true,
                ),
              ],

              // Guardian-specific fields
              if (_userType == 'GUARDIAN') ...[
                const SizedBox(height: 16),
                const Divider(),
                const Text(
                  'Contact Details',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _textField(
                  _phoneCtrl,
                  'Phone Number',
                  keyboardType: TextInputType.phone,
                ),
                _textField(_addressCtrl, 'Physical Address', maxLines: 2),
              ],

              // Password note
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: Colors.blue.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'A secure temporary password will be generated and shown to you '
                        'after the account is created. The user will be required to '
                        'change it on first login.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(color: Colors.red.shade800, fontSize: 13),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.person_add),
                  label: Text(_loading ? 'Creating...' : 'Create Account'),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    int? maxLines,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines ?? 1,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: required
            ? (v) =>
                  (v == null || v.trim().isEmpty) ? '$label is required.' : null
            : null,
      ),
    );
  }
}

// Dialog shown after successful user creation with the temp password.
class _PasswordCreatedDialog extends StatefulWidget {
  final String name;
  final String email;
  final String password;

  const _PasswordCreatedDialog({
    required this.name,
    required this.email,
    required this.password,
  });

  @override
  State<_PasswordCreatedDialog> createState() => _PasswordCreatedDialogState();
}

class _PasswordCreatedDialogState extends State<_PasswordCreatedDialog> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
      title: const Text('Account Created'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Account for ${widget.name} has been created successfully.',
            style: const TextStyle(fontSize: 14),
          ),
          const SizedBox(height: 16),
          const Text(
            'Share these credentials with the user:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),
          _credentialRow('Email', widget.email),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Temporary Password',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        widget.password,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _copied ? Icons.check : Icons.copy,
                    color: _copied ? Colors.green : null,
                  ),
                  tooltip: 'Copy password',
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: widget.password));
                    setState(() => _copied = true);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber,
                  size: 14,
                  color: Colors.orange.shade800,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'This password will not be shown again. '
                    'Copy or note it before closing.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _credentialRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}
