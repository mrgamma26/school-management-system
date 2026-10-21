import 'dart:math';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/utils/form_state_persistence.dart';
import '../../../../widgets/skeleton_loader.dart';
import '../../../../widgets/ui_kit.dart';
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

/// Screen 16 - Create a staff user account.
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

  final String _userType = 'STAFF'; // Only STAFF, no guardian option
  String _gender = 'MALE';
  String? _selectedRoleId;
  List<Map<String, dynamic>> _roles = [];
  bool _loading = false;
  bool _rolesLoading = true;
  bool _restoringDraft = true;
  bool _draftSaved = false;
  bool _draftCommitted = false;
  bool _draftDirty = false;
  late final AutoSaveDebouncer _draftSaver;
  String? _error;

  late final String _draftId;

  void _scheduleDraft() {
    if (!_restoringDraft && !_loading) {
      _draftDirty = true;
      _draftSaver.save();
    }
  }

  Future<void> _saveDraft() async {
    if (!_draftDirty || _draftCommitted) return;
    final saved =
        await FormStatePersistence.saveFormStateWithTimestamp(_draftId, {
          'email': _emailCtrl.text,
          'firstName': _firstNameCtrl.text,
          'middleName': _middleNameCtrl.text,
          'lastName': _lastNameCtrl.text,
          'phone': _phoneCtrl.text,
          'address': _addressCtrl.text,
          'employeeNumber': _employeeNumberCtrl.text,
          'gender': _gender,
          'roleId': _selectedRoleId,
        });
    if (mounted && saved) setState(() => _draftSaved = true);
  }

  Future<void> _restoreDraft() async {
    final data = await FormStatePersistence.loadFormState(_draftId);
    if (!mounted) return;
    setState(() {
      if (data != null) {
        _emailCtrl.text = data['email'] as String? ?? '';
        _firstNameCtrl.text = data['firstName'] as String? ?? '';
        _middleNameCtrl.text = data['middleName'] as String? ?? '';
        _lastNameCtrl.text = data['lastName'] as String? ?? '';
        _phoneCtrl.text = data['phone'] as String? ?? '';
        _addressCtrl.text = data['address'] as String? ?? '';
        _employeeNumberCtrl.text = data['employeeNumber'] as String? ?? '';
        _gender = data['gender'] as String? ?? _gender;
        final roleId = data['roleId'] as String?;
        if (_roles.any((role) => role['roleid'] == roleId)) {
          _selectedRoleId = roleId;
        }
        _draftSaved = true;
      }
      _restoringDraft = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _draftId =
        'create_user_${ref.read(authProvider).user?.userId ?? 'unknown'}';
    _draftSaver = AutoSaveDebouncer(onSave: _saveDraft);
    _loadRoles().then((_) => _restoreDraft());
  }

  @override
  void dispose() {
    _draftSaver.dispose();
    if (!_restoringDraft && !_draftCommitted && _draftDirty) {
      unawaited(_saveDraft());
    }
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
      if (mounted) {
        setState(() {
          _roles = roles;
          _rolesLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _rolesLoading = false;
          _error = 'Failed to load roles. Please try again.';
        });
      }
    }
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
      _draftCommitted = true;
      _draftSaver.cancel();
      await FormStatePersistence.clearFormState(_draftId);

      if (!mounted) return;

      // Show the generated password to the admin before navigating back.
      await _showPasswordDialog(
        context: context,
        name: '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}',
        email: _emailCtrl.text.trim(),
        password: generatedPassword,
      );

      // Navigate back after dialog is confirmed (dialog closes and this code runs).
      if (mounted) {
        context.go('/admin/users');
      }
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
    final ready = !(_restoringDraft || _rolesLoading);
    return AutofillGroup(
      child: Form(
        key: _formKey,
        onChanged: _scheduleDraft,
        child: UiPage(
          maxWidth: 980,
          children: [
            PageHead(
              kicker: 'Users & Access',
              title: 'Create User Account',
              subtitle:
                  'Create a staff account and send a secure first-login password. Guardians are created when you register a student.',
              actions: [
                UiButton.secondary(
                  'Cancel',
                  onPressed: () => context.go('/admin/users'),
                ),
                UiButton(
                  _loading ? 'Creating…' : 'Create Account',
                  icon: Icons.person_add_alt,
                  onPressed: ready && !_loading ? _submit : null,
                ),
              ],
            ),
            if (!ready) ...[
              const SkeletonFormField(),
              const SizedBox(height: 12),
              const SkeletonFormField(),
            ] else ...[
              if (_draftSaved && !_loading)
                const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: Text(
                    'Draft saved on this device',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF64758B),
                    ),
                  ),
                ),
              _section('Account', [
                _textField(
                  _emailCtrl,
                  'Email address',
                  required: true,
                  keyboardType: TextInputType.emailAddress,
                  hint: 'user@school.com',
                ),
                if (_roles.isNotEmpty)
                  UiField(
                    label: 'Role *',
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedRoleId,
                      items: _roles
                          .where((r) {
                            final rn = (r['rolename'] as String).toUpperCase();
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
                      validator: (v) =>
                          v == null ? 'Please select a role.' : null,
                    ),
                  ),
              ]),
              _section('Personal information', [
                _textField(_firstNameCtrl, 'First Name', required: true),
                _textField(_middleNameCtrl, 'Middle Name'),
                _textField(_lastNameCtrl, 'Last Name', required: true),
                UiField(
                  label: 'Gender',
                  child: DropdownButtonFormField<String>(
                    initialValue: _gender,
                    items: const [
                      DropdownMenuItem(value: 'MALE', child: Text('Male')),
                      DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                    ],
                    onChanged: (v) => setState(() => _gender = v!),
                  ),
                ),
              ]),
              _section('Staff information', [
                _textField(
                  _employeeNumberCtrl,
                  'Employee Number',
                  required: true,
                ),
              ]),
              const InlineGuide(
                title: 'Sign-in:',
                text:
                    'A secure temporary password will be generated and emailed to the user (it is also shown to you once, in case the email fails). The user must choose their own password on first login.',
              ),
              if (_roles.isNotEmpty)
                const InlineGuide(
                  text:
                      'Need a role that is not listed? Open any user in User Accounts and choose Manage Permissions.',
                ),
              if (_error != null) UiNotice(_error!, icon: Icons.error_outline),
            ],
          ],
        ),
      ),
    );
  }

  Widget _section(String title, List<Widget> fields) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: FormPanel(
      title: title,
      child: FieldGrid(children: fields),
    ),
  );

  Widget _textField(
    TextEditingController controller,
    String label, {
    bool required = false,
    TextInputType? keyboardType,
    int? maxLines,
    String? hint,
  }) {
    return UiField(
      label: label,
      child: TextFormField(
        controller: controller,
        autofillHints: switch (label) {
          'Email address' => const [AutofillHints.email],
          'First Name' => const [AutofillHints.givenName],
          'Middle Name' => const [AutofillHints.middleName],
          'Last Name' => const [AutofillHints.familyName],
          'Phone Number' => const [AutofillHints.telephoneNumber],
          'Physical Address' => const [AutofillHints.fullStreetAddress],
          _ => null,
        },
        keyboardType: keyboardType,
        maxLines: maxLines ?? 1,
        decoration: InputDecoration(hintText: hint),
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
          onPressed: () => Navigator.of(context).pop(),
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
