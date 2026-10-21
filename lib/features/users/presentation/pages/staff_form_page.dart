import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/services/audit_service.dart';
import '../../../../core/validation/app_validators.dart';
import '../../../../widgets/ui_kit.dart';
import '../../../../widgets/ui_workspace.dart' show WorkspaceChoiceChip;
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/repositories/user_repository.dart';
import '../../domain/models/staff.dart';
import '../../domain/staff_onboarding.dart';

typedef TemporaryPasswordGenerator = String Function();

/// Generates a temporary password without using a predictable random source.
String generateSecureTemporaryPassword() {
  const upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
  const lower = 'abcdefghjkmnpqrstuvwxyz';
  const digits = '23456789';
  const symbols = r'!@#$%&*';
  const all = upper + lower + digits + symbols;
  final random = Random.secure();
  final characters = <String>[
    upper[random.nextInt(upper.length)],
    lower[random.nextInt(lower.length)],
    digits[random.nextInt(digits.length)],
    symbols[random.nextInt(symbols.length)],
    for (var i = 4; i < 12; i++) all[random.nextInt(all.length)],
  ]..shuffle(random);
  return characters.join();
}

/// Single request shape shared by every staff-account entry point.
Map<String, dynamic> buildStaffAccountRequest({
  required String roleId,
  required String temporaryPassword,
  required Map<String, dynamic> profile,
}) => {
  'email': profile['email'],
  'password': temporaryPassword,
  'username': profile['email'],
  'roleId': roleId,
  'type': 'staff',
  'userType': 'STAFF',
  'profileData': profile,
};

/// What the onboarding hand-off needs once a staff account exists.
class _CreatedStaff {
  final String name;
  final String? staffId;
  final bool teaching;
  final bool dualRoleRequested;
  final String? dualRoleError;
  final String email;
  final String temporaryPassword;
  final int subjectCount;
  final String? subjectsError;
  const _CreatedStaff({
    required this.name,
    required this.staffId,
    required this.teaching,
    required this.dualRoleRequested,
    required this.dualRoleError,
    required this.email,
    required this.temporaryPassword,
    this.subjectCount = 0,
    this.subjectsError,
  });
}

/// Screen 14 - Add or edit a staff member.
///
/// Create mode also offers the optional Teacher + Head Teacher dual role and,
/// once a teaching member is saved, a hand-off to the class assignments.
class StaffFormPage extends ConsumerStatefulWidget {
  final Staff? existing;
  final UserRepository? repository;
  final TemporaryPasswordGenerator temporaryPasswordGenerator;
  const StaffFormPage({
    this.existing,
    this.repository,
    this.temporaryPasswordGenerator = generateSecureTemporaryPassword,
    super.key,
  });
  @override
  ConsumerState<StaffFormPage> createState() => _StaffFormPageState();
}

class _StaffFormPageState extends ConsumerState<StaffFormPage> {
  final _form = GlobalKey<FormState>();
  late final UserRepository _repo = widget.repository ?? UserRepository();
  bool _alsoHeadTeacher = false;
  _CreatedStaff? _created;
  final _fields = <String, TextEditingController>{};
  List<Map<String, dynamic>> _roles = const [];
  String? _roleId;
  String _gender = 'MALE', _status = 'ACTIVE';
  DateTime? _birthDate, _startDate;
  bool _saving = false;
  String? _error;
  bool get _editing => widget.existing != null;

  // Subjects this person is marked as teaching (drives Class Setup's teacher
  // lists). Only saved when the catalogue and current marks loaded cleanly, so
  // a failed read can never wipe them.
  List<Map<String, dynamic>> _subjectOptions = const [];
  final _teaches = <String>{};
  bool _subjectsReady = false;

  @override
  void initState() {
    super.initState();
    final s = widget.existing;
    final values = <String, String?>{
      'firstName': s?.firstName,
      'middleName': s?.middleName,
      'lastName': s?.lastName,
      'email': s?.email,
      'employeeNumber': s?.employeeNumber,
      'nationalId': s?.nationalId,
      'phone': s?.phoneNumber,
      'alternativePhone': s?.alternativePhone,
      'address': s?.physicalAddress,
      'jobTitle': s?.jobTitle,
      'department': s?.department,
      'employmentType': s?.employmentType,
      'experience': s?.yearsOfExperience?.toString(),
      'professionalQualifications': s?.professionalQualifications,
      'highestQualification': s?.highestAcademicQualification,
      'emergencyName': s?.emergencyContactName,
      'emergencyPhone': s?.emergencyContactPhone,
      'emergencyRelationship': s?.emergencyContactRelationship,
    };
    for (final entry in values.entries) {
      _fields[entry.key] = TextEditingController(text: entry.value ?? '');
    }
    _gender = s?.gender ?? 'MALE';
    _status = s?.employmentStatus ?? 'ACTIVE';
    _birthDate = s?.dateOfBirth;
    _startDate = s?.employmentStartDate;
    if (!_editing) _loadRoles();
    _loadSubjects();
  }

  Future<void> _loadSubjects() async {
    try {
      final options = await _repo.subjectOptions();
      final current = _editing
          ? await _repo.staffSubjectIds(widget.existing!.staffId)
          : <String>{};
      if (!mounted) return;
      setState(() {
        _subjectOptions = options;
        _teaches
          ..clear()
          ..addAll(current);
        _subjectsReady = true;
      });
    } catch (_) {
      // The picker stays hidden; the rest of the profile still saves.
    }
  }

  /// The picker is for teaching staff: always when editing (the role is not
  /// loaded here), and in create mode once a teaching role is chosen.
  bool get _showsSubjects =>
      _subjectsReady && (_editing || isTeachingRole(_roleNameFor(_roleId)));

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _loadRoles() async {
    try {
      final roles = await _repo.listRoles();
      if (mounted) setState(() => _roles = roles);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load account roles.');
    }
  }

  String? _optional(String key) {
    final value = _fields[key]!.text.trim();
    return value.isEmpty ? null : value;
  }

  Map<String, dynamic> _profile() => {
    'firstName': AppValidators.normalizeSpaces(_fields['firstName']!.text),
    'middleName': _optional('middleName') == null
        ? null
        : AppValidators.normalizeSpaces(_optional('middleName')!),
    'lastName': AppValidators.normalizeSpaces(_fields['lastName']!.text),
    'email': _fields['email']!.text.trim().toLowerCase(),
    'employeeNumber': _fields['employeeNumber']!.text.trim(),
    'gender': _gender,
    'dateOfBirth': _date(_birthDate),
    'nationalId': _optional('nationalId'),
    'phoneNumber': _phone('phone'),
    'alternativePhone': _phone('alternativePhone'),
    'physicalAddress': _optional('address'),
    'jobTitle': _optional('jobTitle'),
    'department': _optional('department'),
    'employmentType': _optional('employmentType'),
    'employmentStatus': _status,
    'employmentStartDate': _date(_startDate),
    'professionalQualifications': _optional('professionalQualifications'),
    'highestAcademicQualification': _optional('highestQualification'),
    'yearsOfExperience': int.tryParse(_fields['experience']!.text.trim()),
    'emergencyContactName': _optional('emergencyName'),
    'emergencyContactPhone': _phone('emergencyPhone'),
    'emergencyContactRelationship': _optional('emergencyRelationship'),
  };
  String? _date(DateTime? value) => value?.toIso8601String().split('T').first;
  String? _phone(String key) =>
      _optional(key)?.replaceAll(RegExp(r'[\s-]'), '');

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final ageError = AppValidators.staffBirthDate(_birthDate);
    if (ageError != null || _startDate == null) {
      setState(() => _error = ageError ?? 'Employment start date is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final profile = _profile();
      final current = ref.read(authProvider).user!;
      if (_editing) {
        final data = <String, dynamic>{
          for (final e in profile.entries) _dbKey(e.key): e.value,
        }..remove('employeenumber');
        await _repo.updateStaff(widget.existing!.staffId, data);
        await AuditService().log(
          userId: current.userId,
          action: 'STAFF_UPDATED',
          tableName: 'staff',
          recordId: widget.existing!.staffId,
          previousValue: widget.existing!.toUpdateJson(),
          newValue: data,
          actorRole: current.roleName,
        );
        if (_showsSubjects) {
          await _repo.setStaffSubjects(widget.existing!.staffId, _teaches);
        }
      } else {
        final temporaryPassword = widget.temporaryPasswordGenerator();
        final newUserId = await _repo.createUser(
          buildStaffAccountRequest(
            roleId: _roleId!,
            temporaryPassword: temporaryPassword,
            profile: profile,
          ),
        );
        try {
          await AuditService().log(
            userId: current.userId,
            action: 'STAFF_CREATED',
            tableName: 'staff',
            actorRole: current.roleName,
          );
        } catch (_) {
          // The account already exists. A missed audit entry must not hide the
          // one-time password or cause the administrator to create a duplicate.
        }
        final created = await _finishOnboarding(
          newUserId,
          profile,
          temporaryPassword,
        );
        if (mounted) setState(() => _created = created);
        return;
      }
      if (mounted) _backToStaff(saved: true);
    } catch (error) {
      if (mounted) setState(() => _error = friendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Back to the staff list. The form is pushed from the list (so there is a
  /// page to return to and the list refreshes on [saved]) but is also opened
  /// directly from dashboards and the menu, where there is nothing to pop.
  void _backToStaff({bool saved = false}) {
    if (context.canPop()) {
      context.pop(saved);
    } else {
      context.go('/users/staff');
    }
  }

  String _dbKey(String key) =>
      const {
        'firstName': 'firstname',
        'middleName': 'middlename',
        'lastName': 'lastname',
        'employeeNumber': 'employeenumber',
        'dateOfBirth': 'dateofbirth',
        'nationalId': 'nationalid',
        'phoneNumber': 'phonenumber',
        'alternativePhone': 'alternativephone',
        'physicalAddress': 'physicaladdress',
        'jobTitle': 'jobtitle',
        'employmentType': 'employmenttype',
        'employmentStatus': 'employmentstatus',
        'employmentStartDate': 'employmentstartdate',
        'professionalQualifications': 'professionalqualifications',
        'highestAcademicQualification': 'highestacademicqualification',
        'yearsOfExperience': 'yearsofexperience',
        'emergencyContactName': 'emergencycontactname',
        'emergencyContactPhone': 'emergencycontactphone',
        'emergencyContactRelationship': 'emergencycontactrelationship',
      }[key] ??
      key;

  String? _roleNameFor(String? roleId) {
    for (final role in _roles) {
      if (role['roleid'] == roleId) return role['rolename'] as String?;
    }
    return null;
  }

  String? _roleIdNamed(String name) {
    for (final role in _roles) {
      if ((role['rolename'] as String? ?? '').trim().toUpperCase() == name) {
        return role['roleid'] as String?;
      }
    }
    return null;
  }

  bool _canOfferRole(Map<String, dynamic> role) {
    final target = (role['rolename'] as String? ?? '').trim().toUpperCase();
    final actor = (ref.read(authProvider).user?.roleName ?? '')
        .trim()
        .toUpperCase();
    if (target == 'GUARDIAN') return false;
    if (actor == 'SUPER_USER') {
      return const {
        'SUPER_USER',
        'ADMINISTRATOR',
        'HEAD_TEACHER',
        'TEACHER',
        'ACCOUNTANT',
      }.contains(target);
    }
    return actor == 'ADMINISTRATOR' &&
        const {'TEACHER', 'ACCOUNTANT'}.contains(target);
  }

  /// After the account exists: optional Head Teacher dual role, then find the
  /// staff row so the assignment matrix can preselect this teacher.
  Future<_CreatedStaff> _finishOnboarding(
    String userId,
    Map<String, dynamic> profile,
    String temporaryPassword,
  ) async {
    final actor = ref.read(authProvider).user!;
    final roleName = _roleNameFor(_roleId);
    String? dualError;
    final wantsDual =
        _alsoHeadTeacher &&
        canGrantHeadTeacherDualRole(
          selectedRoleName: roleName,
          actorRole: actor.roleName,
        );
    if (wantsDual) {
      final headTeacherId = _roleIdNamed('HEAD_TEACHER');
      if (headTeacherId == null) {
        dualError = 'The Head Teacher role could not be found.';
      } else {
        try {
          await _repo.addSecondaryRole(userId: userId, roleId: headTeacherId);
        } catch (error) {
          dualError = friendlyError(error);
        }
        if (dualError == null) {
          try {
            await AuditService().log(
              userId: actor.userId,
              action: 'DUAL_ROLE_GRANTED',
              tableName: 'user_roles',
              recordId: userId,
              newValue: const {'role': 'HEAD_TEACHER', 'is_primary': false},
              actorRole: actor.roleName,
            );
          } catch (_) {
            // The role is already granted; a missed audit row must not hide that.
          }
        }
      }
    }
    String? staffId;
    if (isTeachingRole(roleName)) {
      try {
        staffId = await _repo.staffIdForUser(userId);
      } catch (_) {
        staffId = null;
      }
    }
    var subjectCount = 0;
    String? subjectsError;
    if (staffId != null && _showsSubjects && _teaches.isNotEmpty) {
      try {
        await _repo.setStaffSubjects(staffId, _teaches);
        subjectCount = _teaches.length;
      } catch (error) {
        subjectsError = friendlyError(error);
      }
    }
    final name = [
      profile['firstName'],
      profile['lastName'],
    ].where((part) => part != null && '$part'.isNotEmpty).join(' ');
    return _CreatedStaff(
      name: name,
      staffId: staffId,
      teaching: isTeachingRole(roleName),
      dualRoleRequested: wantsDual,
      dualRoleError: dualError,
      email: profile['email'] as String,
      temporaryPassword: temporaryPassword,
      subjectCount: subjectCount,
      subjectsError: subjectsError,
    );
  }

  Widget _successView(_CreatedStaff created) => UiPage(
    maxWidth: 760,
    children: [
      PageHead(
        kicker: 'People',
        title: '${created.name} saved',
        subtitle: 'The staff account and profile were created.',
      ),
      FormPanel(
        title: 'What was created',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailLine('Staff profile', created.name),
            DetailLine(
              'Role',
              [
                _roleNameFor(_roleId)?.replaceAll('_', ' ') ?? 'Staff',
                if (created.dualRoleRequested && created.dualRoleError == null)
                  'Head Teacher',
              ].join(' + '),
            ),
            DetailLine(
              'Teaching',
              !created.teaching
                  ? 'Not applicable for this role'
                  : created.subjectCount > 0
                  ? 'Marked as teaching ${created.subjectCount} subject${created.subjectCount == 1 ? '' : 's'}; not in a class yet'
                  : 'No subjects marked yet',
            ),
            if (created.subjectsError != null)
              UiNotice(
                'The account was created, but the subjects could not be saved: ${created.subjectsError} Mark them by editing this staff profile.',
                tone: StatusTone.warning,
                icon: Icons.info_outline,
              ),
            const SizedBox(height: 12),
            const InlineGuide(
              title: 'Temporary sign-in credentials',
              text:
                  'Copy this password now. It is shown once, and the user must change it after signing in.',
            ),
            DetailLine('Email', created.email),
            Row(
              children: [
                Expanded(
                  child: DetailLine(
                    'Temporary password',
                    created.temporaryPassword,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy temporary password',
                  onPressed: () => Clipboard.setData(
                    ClipboardData(text: created.temporaryPassword),
                  ),
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
            if (created.dualRoleError != null)
              UiNotice(
                'The account was created, but the Head Teacher dual role could not be added: ${created.dualRoleError} Ask a Super User to add it.',
                tone: StatusTone.warning,
                icon: Icons.info_outline,
              ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (created.teaching)
                  UiButton(
                    'Continue to class assignments',
                    icon: Icons.arrow_forward_rounded,
                    onPressed: () => context.go(classSetupRoute),
                  ),
                UiButton.secondary(
                  'Back to staff',
                  onPressed: () => _backToStaff(saved: true),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) =>
      _created != null ? _successView(_created!) : _formView(context);

  Widget _formView(BuildContext context) => Form(
    key: _form,
    child: UiPage(
      maxWidth: 980,
      children: [
        PageHead(
          kicker: 'People',
          title: _editing ? 'Edit Staff Profile' : 'Create Staff Account',
          subtitle:
              'Personal, employment, qualification and emergency information.',
          actions: [
            UiButton.secondary(
              'Cancel',
              onPressed: _backToStaff,
            ),
            UiButton(
              _saving
                  ? 'Saving…'
                  : (_editing ? 'Save profile' : 'Create staff account'),
              icon: Icons.save_outlined,
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
        _section('Identity', [
          _input(
            'firstName',
            'First name',
            validator: (v) =>
                AppValidators.requiredName(v, label: 'First name'),
          ),
          _input(
            'middleName',
            'Middle name',
            validator: (v) =>
                AppValidators.optionalName(v, label: 'Middle name'),
          ),
          _input(
            'lastName',
            'Last name',
            validator: (v) => AppValidators.requiredName(v, label: 'Last name'),
          ),
          _datePicker(
            'Date of birth',
            _birthDate,
            (value) => setState(() => _birthDate = value),
          ),
          _select('Gender', _gender, const [
            'MALE',
            'FEMALE',
          ], (v) => setState(() => _gender = v!)),
          _input('nationalId', 'National ID (optional)'),
        ]),
        _section('Contact', [
          _input(
            'email',
            'Email',
            keyboard: TextInputType.emailAddress,
            validator: AppValidators.email,
          ),
          _input(
            'phone',
            'Phone number',
            keyboard: TextInputType.phone,
            validator: (v) => AppValidators.malawiPhone(v, required: true),
          ),
          _input(
            'alternativePhone',
            'Alternative phone',
            keyboard: TextInputType.phone,
            validator: AppValidators.malawiPhone,
          ),
          FullWidth(
            child: _input(
              'address',
              'Physical address',
              required: true,
              lines: 2,
            ),
          ),
        ]),
        _section('Employment', [
          _input(
            'employeeNumber',
            'Employee number',
            required: true,
            enabled: !_editing,
          ),
          _input('jobTitle', 'Job title', required: true),
          _input('department', 'Department'),
          _input('employmentType', 'Employment type', required: true),
          _datePicker(
            'Employment start date',
            _startDate,
            (value) => setState(() => _startDate = value),
          ),
          _select('Employment status', _status, const [
            'ACTIVE',
            'ON_LEAVE',
            'SUSPENDED',
            'FORMER',
          ], (v) => setState(() => _status = v!)),
          _input(
            'experience',
            'Years of experience',
            keyboard: TextInputType.number,
            validator: (v) {
              final n = int.tryParse((v ?? '').trim());
              return n == null || n < 0 || n > 70
                  ? 'Enter a value from 0 to 70.'
                  : null;
            },
          ),
          _input('highestQualification', 'Highest academic qualification'),
          FullWidth(
            child: _input(
              'professionalQualifications',
              'Professional qualifications',
              lines: 2,
            ),
          ),
        ]),
        if (_showsSubjects) _subjectsSection(),
        _section('Emergency contact', [
          _input('emergencyName', 'Contact name', required: true),
          _input(
            'emergencyPhone',
            'Contact phone',
            keyboard: TextInputType.phone,
            validator: (v) => AppValidators.malawiPhone(v, required: true),
          ),
          _input('emergencyRelationship', 'Relationship', required: true),
        ]),
        if (!_editing)
          _section('Account', [
            UiField(
              label: 'Role',
              child: DropdownButtonFormField<String>(
                initialValue: _roleId,
                items: _roles
                    .where(_canOfferRole)
                    .map(
                      (r) => DropdownMenuItem(
                        value: r['roleid'] as String,
                        child: Text(r['rolename'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  _roleId = v;
                  if (!showsDualRoleControl(_roleNameFor(v))) {
                    _alsoHeadTeacher = false;
                  }
                }),
                validator: (v) => v == null ? 'Role is required.' : null,
              ),
            ),
            const FullWidth(
              child: InlineGuide(
                title: 'Sign-in:',
                text:
                    'A secure temporary password is generated automatically and shown once after the account is created.',
              ),
            ),
            if (showsDualRoleControl(_roleNameFor(_roleId)))
              FullWidth(child: _dualRoleControl()),
          ]),
        if (_error != null) UiNotice(_error!, icon: Icons.error_outline),
        const InlineGuide(
          title: 'Before you save:',
          text:
              'Dates must be valid, required fields cannot be empty, and phone numbers must be Malawian numbers.',
        ),
      ],
    ),
  );

  /// Which subjects this person teaches. Class Setup only offers a teacher for
  /// the subjects marked here.
  Widget _subjectsSection() => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: FormPanel(
      title: 'Subjects they teach',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tick every subject this person can teach. They can then be chosen for those subjects in Class Setup.',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          if (_subjectOptions.isEmpty)
            const Text('No subjects yet. Create subjects under Academics first.')
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final subject in _subjectOptions)
                  WorkspaceChoiceChip(
                    label: subject['subjectname'] as String,
                    on: _teaches.contains(subject['subjectid']),
                    onTap: () => setState(() {
                      final id = subject['subjectid'] as String;
                      _teaches.contains(id)
                          ? _teaches.remove(id)
                          : _teaches.add(id);
                    }),
                  ),
              ],
            ),
        ],
      ),
    ),
  );

  /// Optional Teacher + Head Teacher dual role (stored as a second row in
  /// `user_roles`). Only a Super User can grant it, matching create-user.
  Widget _dualRoleControl() {
    final actor = ref.watch(authProvider).user;
    final allowed = canGrantHeadTeacherDualRole(
      selectedRoleName: _roleNameFor(_roleId),
      actorRole: actor?.roleName ?? '',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckRow(
          label: 'Also act as Head Teacher (optional dual role)',
          checked: _alsoHeadTeacher && allowed,
          onChanged: allowed
              ? (value) => setState(() => _alsoHeadTeacher = value)
              : null,
        ),
        InlineGuide(
          text: allowed
              ? 'One person, two roles. They use Switch role to move between the Teacher and Head Teacher workspaces.'
              : 'Only a Super User can give a Teacher the Head Teacher dual role. Ask a Super User to create this account if the dual role is needed.',
        ),
      ],
    );
  }

  Widget _section(String title, List<Widget> fields) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: FormPanel(
      title: title,
      child: FieldGrid(children: fields),
    ),
  );

  Widget _input(
    String key,
    String label, {
    bool required = false,
    bool enabled = true,
    bool obscure = false,
    int lines = 1,
    TextInputType? keyboard,
    String? Function(String?)? validator,
  }) => UiField(
    label: label,
    child: TextFormField(
      controller: _fields[key],
      enabled: enabled,
      obscureText: obscure,
      maxLines: lines,
      keyboardType: keyboard,
      validator:
          validator ??
          (required
              ? (v) => (v ?? '').trim().isEmpty ? '$label is required.' : null
              : null),
    ),
  );

  Widget _select(
    String label,
    String value,
    List<String> values,
    ValueChanged<String?> changed,
  ) => UiField(
    label: label,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      items: values
          .map(
            (v) =>
                DropdownMenuItem(value: v, child: Text(v.replaceAll('_', ' '))),
          )
          .toList(),
      onChanged: changed,
    ),
  );

  Widget _datePicker(
    String label,
    DateTime? value,
    ValueChanged<DateTime> changed,
  ) => UiField(
    label: label,
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        final selected = await showDatePicker(
          context: context,
          initialDate:
              value ?? DateTime.now().subtract(const Duration(days: 365 * 20)),
          firstDate: DateTime(1940),
          lastDate: DateTime.now(),
        );
        if (selected != null) changed(selected);
      },
      child: InputDecorator(
        decoration: const InputDecoration(
          suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
        ),
        child: Text(value == null ? 'Required' : formatUiDate(value)),
      ),
    ),
  );
}
