import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/student.dart';
import '../data/student_repository.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../../users/data/repositories/user_repository.dart';
import '../../../core/services/audit_service.dart';
import '../../../core/widgets/app_widgets.dart';

// Generates a 12-char secure random password.
String _genPassword() {
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

// Holds one guardian's form data.
class _GuardianEntry {
  final TextEditingController firstNameCtrl = TextEditingController();
  final TextEditingController lastNameCtrl = TextEditingController();
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController phoneCtrl = TextEditingController();
  final TextEditingController addressCtrl = TextEditingController();
  String gender = 'FEMALE';
  String relationship = 'PARENT';

  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
  }
}

// Result of creating one guardian account.
class _CreatedGuardian {
  final String name;
  final String email;
  final String password;
  const _CreatedGuardian({
    required this.name,
    required this.email,
    required this.password,
  });
}

class StudentFormPage extends ConsumerStatefulWidget {
  final Student? existing;
  const StudentFormPage({this.existing, super.key});

  @override
  ConsumerState<StudentFormPage> createState() => _StudentFormPageState();
}

class _StudentFormPageState extends ConsumerState<StudentFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _studentRepo = StudentRepository();
  final _userRepo = UserRepository();

  // Student fields
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _middleNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _addressCtrl;
  String _gender = 'MALE';
  DateTime? _dateOfBirth;
  String _status = 'enrolled';

  // Guardian entries: index 0 = mandatory, 1-3 = optional
  final List<_GuardianEntry> _guardians = [];

  // Loaded roles
  String? _guardianRoleId;

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
    _addressCtrl = TextEditingController(text: s?.physicalAddress ?? '');
    _gender = s?.gender ?? 'MALE';
    _dateOfBirth = s?.dateOfBirth;
    // Normalise to lowercase to match the live DB enum (student_status_enum)
    _status = (s?.enrollmentStatus ?? 'enrolled').toLowerCase();

    // Only add guardian section for new registrations
    if (!_isEdit) {
      _guardians.add(_GuardianEntry()); // mandatory primary guardian
      _loadGuardianRole();
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _addressCtrl.dispose();
    for (final g in _guardians) {
      g.dispose();
    }
    super.dispose();
  }

  Future<void> _loadGuardianRole() async {
    try {
      final roles = await _userRepo.listRoles();
      final role = roles.firstWhere(
        (r) => (r['rolename'] as String).toUpperCase() == 'GUARDIAN',
        orElse: () => roles.first,
      );
      if (mounted) setState(() => _guardianRoleId = role['roleid'] as String);
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2010),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  void _addOptionalGuardian() {
    if (_guardians.length < 4) {
      setState(() => _guardians.add(_GuardianEntry()));
    }
  }

  void _removeGuardian(int index) {
    if (index == 0) return; // cannot remove primary
    setState(() {
      _guardians[index].dispose();
      _guardians.removeAt(index);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dateOfBirth == null) {
      setState(() => _error = 'Date of birth is required.');
      return;
    }
    if (!_isEdit && _guardianRoleId == null) {
      setState(
        () => _error = 'Guardian role not loaded. Please wait and try again.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final currentUser = ref.read(authProvider).user!;
      final studentData = <String, dynamic>{
        'firstname': _firstNameCtrl.text.trim(),
        'middlename': _middleNameCtrl.text.trim().isEmpty
            ? null
            : _middleNameCtrl.text.trim(),
        'lastname': _lastNameCtrl.text.trim(),
        'gender': _gender,
        'enrollmentstatus': _status.toLowerCase(),
        'dateofbirth': _dateOfBirth?.toIso8601String().substring(0, 10),
        'physicaladdress': _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
      };

      if (_isEdit) {
        // Edit flow: student only, no guardian changes here
        final old = widget.existing!;
        await _studentRepo.updateStudent(old.studentId, studentData);
        await AuditService().log(
          userId: currentUser.userId,
          action: 'STUDENT_UPDATED',
          tableName: 'student',
          recordId: old.studentId,
          previousValue: old.toUpdateJson(),
          newValue: studentData,
          actorRole: currentUser.roleName,
        );
        if (mounted) Navigator.pop(context, true);
        return;
      }

      // Create flow: student + guardians
      final studentId = await _studentRepo.createStudent(studentData);
      await AuditService().log(
        userId: currentUser.userId,
        action: 'STUDENT_CREATED',
        tableName: 'student',
        recordId: studentId,
        actorRole: currentUser.roleName,
      );

      // Create each guardian account and link to student
      final createdGuardians = <_CreatedGuardian>[];

      for (final g in _guardians) {
        final email = g.emailCtrl.text.trim();
        if (email.isEmpty) continue; // skip blank optional entries

        final password = _genPassword();
        final firstName = g.firstNameCtrl.text.trim();
        final lastName = g.lastNameCtrl.text.trim();

        final guardianUserId = await _userRepo.createUser({
          'email': email,
          'password': password,
          'username': email.split('@').first,
          'roleId': _guardianRoleId!,
          'userType': 'GUARDIAN',
          'profileData': {
            'firstname': firstName,
            'middlename': null,
            'lastname': lastName,
            'gender': g.gender,
            'email': email,
            'phonenumber': g.phoneCtrl.text.trim().isEmpty
                ? null
                : g.phoneCtrl.text.trim(),
            'physicaladdress': g.addressCtrl.text.trim().isEmpty
                ? null
                : g.addressCtrl.text.trim(),
          },
        });

        // guardianUserId is the auth UUID; look up the guardian row
        // to get the guardianid for linking.
        final guardianRow = await _userRepo.getGuardianByUserId(guardianUserId);

        await _studentRepo.linkGuardian(
          studentId: studentId,
          guardianId: guardianRow['guardianid'] as String,
          relationship: g.relationship,
        );

        await AuditService().log(
          userId: currentUser.userId,
          action: 'GUARDIAN_CREATED_FOR_STUDENT',
          tableName: 'guardian',
          recordId: guardianRow['guardianid'] as String,
          actorRole: currentUser.roleName,
          newValue: {'studentId': studentId, 'email': email},
        );

        createdGuardians.add(
          _CreatedGuardian(
            name: '$firstName $lastName',
            email: email,
            password: password,
          ),
        );
      }

      if (!mounted) return;

      // Show credentials dialog if any guardians were created
      if (createdGuardians.isNotEmpty) {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _GuardianCredentialsDialog(
            studentName:
                '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}',
            guardians: createdGuardians,
          ),
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
        title: Text(_isEdit ? 'Edit Student' : 'Register Student'),
        actions: [HomeButton(roleName: role)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Student details section
              _sectionHeader('Student Information', Icons.school),
              const SizedBox(height: 8),
              _field(_firstNameCtrl, 'First Name'),
              _field(_middleNameCtrl, 'Middle Name', required: false),
              _field(_lastNameCtrl, 'Last Name'),
              _field(_addressCtrl, 'Physical Address', required: false),
              DropdownButtonFormField<String>(
                value: _gender,
                decoration: const InputDecoration(labelText: 'Gender'),
                items: const [
                  DropdownMenuItem(value: 'MALE', child: Text('Male')),
                  DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                ],
                onChanged: (v) => setState(() => _gender = v!),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of Birth *',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _dateOfBirth == null
                        ? 'Tap to select'
                        : _dateOfBirth!.toIso8601String().substring(0, 10),
                    style: TextStyle(
                      color: _dateOfBirth == null ? Colors.grey : null,
                    ),
                  ),
                ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(
                    labelText: 'Enrollment Status',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'enrolled',
                      child: Text('Enrolled'),
                    ),
                    DropdownMenuItem(
                      value: 'withdrawn',
                      child: Text('Withdrawn'),
                    ),
                    DropdownMenuItem(
                      value: 'graduated',
                      child: Text('Graduated'),
                    ),
                    DropdownMenuItem(
                      value: 'transferred',
                      child: Text('Transferred'),
                    ),
                    DropdownMenuItem(
                      value: 'suspended',
                      child: Text('Suspended'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _status = v!),
                ),
              ],

              // Guardian section - only for new registration
              if (!_isEdit) ...[
                const SizedBox(height: 24),
                _sectionHeader('Guardians', Icons.family_restroom),
                const SizedBox(height: 4),
                Text(
                  'At least one guardian is required. Up to 3 additional guardians '
                  'can be added. Each guardian will receive a login account.',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
                ..._guardians.asMap().entries.map(
                  (entry) => _GuardianCard(
                    index: entry.key,
                    entry: entry.value,
                    isPrimary: entry.key == 0,
                    onRemove: () => _removeGuardian(entry.key),
                  ),
                ),
                if (_guardians.length < 4)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: _addOptionalGuardian,
                      icon: const Icon(Icons.add),
                      label: Text(
                        'Add ${_guardians.length == 1
                            ? 'Second'
                            : _guardians.length == 2
                            ? 'Third'
                            : 'Fourth'} Guardian (Optional)',
                      ),
                    ),
                  ),
              ],

              // Error
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
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
                      : Icon(_isEdit ? Icons.save : Icons.how_to_reg),
                  label: Text(
                    _loading
                        ? 'Saving...'
                        : _isEdit
                        ? 'Save Changes'
                        : 'Register Student',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) =>
                  (v == null || v.trim().isEmpty) ? '$label is required.' : null
            : null,
      ),
    );
  }
}

// Card for one guardian entry in the form.
class _GuardianCard extends StatefulWidget {
  final int index;
  final _GuardianEntry entry;
  final bool isPrimary;
  final VoidCallback onRemove;

  const _GuardianCard({
    required this.index,
    required this.entry,
    required this.isPrimary,
    required this.onRemove,
  });

  @override
  State<_GuardianCard> createState() => _GuardianCardState();
}

class _GuardianCardState extends State<_GuardianCard> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final label = widget.isPrimary
        ? 'Primary Guardian (Required)'
        : 'Guardian ${widget.index + 1} (Optional)';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: widget.isPrimary
              ? cs.primary.withValues(alpha: 0.4)
              : cs.outline.withValues(alpha: 0.3),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 16,
                  color: widget.isPrimary ? cs.primary : Colors.grey,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: widget.isPrimary ? cs.primary : Colors.grey.shade700,
                  ),
                ),
                const Spacer(),
                if (!widget.isPrimary)
                  IconButton(
                    icon: const Icon(
                      Icons.remove_circle_outline,
                      color: Colors.red,
                    ),
                    tooltip: 'Remove guardian',
                    onPressed: widget.onRemove,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            _f(
              widget.entry.firstNameCtrl,
              'First Name',
              required: widget.isPrimary,
            ),
            _f(
              widget.entry.lastNameCtrl,
              'Last Name',
              required: widget.isPrimary,
            ),
            _f(
              widget.entry.emailCtrl,
              'Email address',
              required: widget.isPrimary,
              keyboard: TextInputType.emailAddress,
              hint: 'guardian@email.com',
              extraValidator: (v) {
                if (v != null && v.isNotEmpty && !v.contains('@')) {
                  return 'Enter a valid email.';
                }
                return null;
              },
            ),
            _f(
              widget.entry.phoneCtrl,
              'Phone Number',
              required: false,
              keyboard: TextInputType.phone,
            ),
            _f(widget.entry.addressCtrl, 'Physical Address', required: false),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: widget.entry.gender,
                    decoration: const InputDecoration(labelText: 'Gender'),
                    items: const [
                      DropdownMenuItem(value: 'MALE', child: Text('Male')),
                      DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                    ],
                    onChanged: (v) => setState(() => widget.entry.gender = v!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: widget.entry.relationship,
                    decoration: const InputDecoration(
                      labelText: 'Relationship',
                    ),
                    items: const [
                      DropdownMenuItem(value: 'PARENT', child: Text('Parent')),
                      DropdownMenuItem(
                        value: 'GUARDIAN',
                        child: Text('Guardian'),
                      ),
                      DropdownMenuItem(
                        value: 'SIBLING',
                        child: Text('Sibling'),
                      ),
                      DropdownMenuItem(
                        value: 'GRANDPARENT',
                        child: Text('Grandparent'),
                      ),
                      DropdownMenuItem(
                        value: 'UNCLE/AUNT',
                        child: Text('Uncle/Aunt'),
                      ),
                      DropdownMenuItem(value: 'OTHER', child: Text('Other')),
                    ],
                    onChanged: (v) =>
                        setState(() => widget.entry.relationship = v!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 12,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'A login account will be created automatically. '
                      'Credentials shown after registration.',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.blue.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _f(
    TextEditingController ctrl,
    String label, {
    bool required = true,
    TextInputType? keyboard,
    String? hint,
    String? Function(String?)? extraValidator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, hintText: hint),
        validator: (v) {
          if (required && (v == null || v.trim().isEmpty)) {
            return '$label is required.';
          }
          return extraValidator?.call(v);
        },
      ),
    );
  }
}

// Dialog shown after all guardian accounts are created.
class _GuardianCredentialsDialog extends StatefulWidget {
  final String studentName;
  final List<_CreatedGuardian> guardians;

  const _GuardianCredentialsDialog({
    required this.studentName,
    required this.guardians,
  });

  @override
  State<_GuardianCredentialsDialog> createState() =>
      _GuardianCredentialsDialogState();
}

class _GuardianCredentialsDialogState
    extends State<_GuardianCredentialsDialog> {
  final Set<int> _copied = {};

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.check_circle, color: Colors.green, size: 40),
      title: const Text('Student Registered'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${widget.studentName} has been registered and '
                '${widget.guardians.length == 1 ? 'a guardian account has' : '${widget.guardians.length} guardian accounts have'} been created.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Guardian Login Credentials',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Share these with each guardian. They must change their password on first login.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 12),
              ...widget.guardians.asMap().entries.map((e) {
                final i = e.key;
                final g = e.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        g.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Email: ${g.email}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Password:',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                Text(
                                  g.password,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              _copied.contains(i) ? Icons.check : Icons.copy,
                              color: _copied.contains(i) ? Colors.green : null,
                              size: 18,
                            ),
                            tooltip: 'Copy password',
                            onPressed: () {
                              Clipboard.setData(
                                ClipboardData(text: g.password),
                              );
                              setState(() => _copied.add(i));
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }),
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
                        'These passwords will not be shown again. Copy them before closing.',
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
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
    );
  }
}
