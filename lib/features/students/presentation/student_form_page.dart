import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../../core/errors/app_exception.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/app_router.dart' show homeForRole;
import '../../../core/utils/form_state_persistence.dart';
import '../../../core/validation/app_validators.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../../widgets/ui_kit.dart';
import '../../../widgets/ui_workspace.dart';
import '../domain/admission_progress.dart';
import '../domain/student.dart';
import '../data/student_repository.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../../users/data/repositories/user_repository.dart';
import '../../users/domain/models/guardian.dart';
import '../../../core/services/audit_service.dart';
import '../../academics/data/academic_repository.dart';
import '../../academics/data/academic_setup_repository.dart';
import '../../academics/domain/models/class_subject.dart';
import '../../academics/domain/models/academic_year.dart';
import '../../academics/domain/models/class_model.dart';
import '../../../theme/app_tokens.dart';
import 'admission_widgets.dart';
import '../../../core/navigation/close_form.dart';

final registrationAcademicRepositoryProvider = Provider<AcademicRepository>(
  (ref) => AcademicRepository(),
);
final registrationStudentRepositoryProvider = Provider<StudentRepository>(
  (ref) => StudentRepository(),
);
final registrationUserRepositoryProvider = Provider<UserRepository>(
  (ref) => UserRepository(),
);
final registrationAuditProvider = Provider<AuditService>(
  (ref) => AuditService(),
);

final registrationSetupRepositoryProvider = Provider<AcademicSetupRepository>(
  (ref) => AcademicSetupRepository(),
);

/// Names of the subjects a class offers (from the class-subject setup), used
/// for the read-only preview in the admission workspace.
final _classSubjectNamesProvider = FutureProvider.family<List<String>, String>((
  ref,
  classId,
) async {
  final rows = await ref
      .watch(registrationSetupRepositoryProvider)
      .configuredSubjects();
  final names = <String>[
    for (final row in rows)
      if (row['class_id'] == classId)
        ((row['subject'] as Map?)?['subjectname'] ?? '').toString(),
  ]..removeWhere((name) => name.isEmpty);
  names.sort();
  return names;
});

final _academicYearsProvider = FutureProvider<List<AcademicYear>>((ref) {
  return ref.watch(registrationAcademicRepositoryProvider).listAcademicYears();
});

final _classesForRegistrationProvider = FutureProvider<List<ClassModel>>((ref) {
  return ref.watch(registrationAcademicRepositoryProvider).listClasses();
});

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
  String? createdUserId;
  String? generatedPassword;
  bool linked = false;
  bool auditLogged = false;

  void dispose() {
    firstNameCtrl.dispose();
    lastNameCtrl.dispose();
    emailCtrl.dispose();
    phoneCtrl.dispose();
    addressCtrl.dispose();
  }
}

class _ExistingGuardianSelection {
  final Guardian guardian;
  String relationship;
  bool linked = false;
  bool auditLogged = false;

  _ExistingGuardianSelection({
    required this.guardian,
    this.relationship = 'PARENT',
  });
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

// Provider: Get current academic year
final _currentAcademicYearProvider = FutureProvider<Map<String, dynamic>?>((
  ref,
) async {
  final years = await AcademicRepository().currentAcademicYears();
  return years.isNotEmpty ? years.first : null;
});

// Provider: Get student's current class and subjects
final _studentSubjectsProvider = FutureProvider.family<List<ClassSubject>, String>((
  ref,
  studentId,
) async {
  final currentYear = await ref.watch(_currentAcademicYearProvider.future);
  if (currentYear == null) return [];

  final yearId = currentYear['academicyearid'] as String;
  final classHistory = await StudentRepository().getClassHistory(studentId);

  if (classHistory.isEmpty) return [];

  // Get the most recent class assignment (last one in the list, sorted by date)
  final currentClassEntry = classHistory.last;
  final classId = currentClassEntry['classid'] as String;

  // Get all assignments for this class-year combo and hydrate with class/subject/teacher info
  final assignments = await AcademicRepository().listAssignments(yearId);
  return assignments.where((a) => a.classId == classId).toList();
});

/// Optional initial placement. Classes are shared across academic years in the
/// schema; the selected year is stored on the student's placement record.
class RegistrationClassAssignment extends ConsumerWidget {
  final String? academicYearId;
  final String? classId;
  final ValueChanged<String?> onYearChanged;
  final ValueChanged<String?> onClassChanged;

  const RegistrationClassAssignment({
    super.key,
    required this.academicYearId,
    required this.classId,
    required this.onYearChanged,
    required this.onClassChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final years = ref.watch(_academicYearsProvider);
    final selectedYear = years.asData?.value
        .where((item) => item.id == academicYearId)
        .firstOrNull;
    final classes = academicYearId == null
        ? const AsyncData<List<ClassModel>>([])
        : ref.watch(_classesForRegistrationProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        years.when(
          loading: () => const SkeletonFormField(),
          error: (_, _) => TextButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Could not load academic years. Retry'),
            onPressed: () => ref.invalidate(_academicYearsProvider),
          ),
          data: (items) => DropdownButtonFormField<String>(
            key: ValueKey('registration-year-$academicYearId'),
            initialValue: academicYearId,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Academic year, term and form (optional)',
            ),
            items: [
              const DropdownMenuItem<String>(
                value: null,
                child: Text('Assign later'),
              ),
              for (final year in items)
                DropdownMenuItem(
                  value: year.id,
                  child: Text(year.selectionLabel),
                ),
            ],
            onChanged: onYearChanged,
          ),
        ),
        const SizedBox(height: 16),
        classes.when(
          loading: () => const SkeletonFormField(),
          error: (_, _) => TextButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Could not load classes. Retry'),
            onPressed: () => ref.invalidate(_classesForRegistrationProvider),
          ),
          data: (items) {
            final selectedForm = selectedYear?.form;
            final matchingItems = selectedForm == null
                ? items
                : items.where((item) => item.form == selectedForm).toList();
            final selectedClassValue =
                matchingItems.any((item) => item.classId == classId)
                ? classId
                : null;

            return DropdownButtonFormField<String>(
              key: ValueKey('registration-class-$academicYearId-$classId'),
              initialValue: selectedClassValue,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: 'Class (optional)',
                helperText: selectedForm == null
                    ? null
                    : 'Showing ${formatFormLevel(selectedForm)} classes only',
              ),
              disabledHint: const Text('Select an academic period first'),
              items: [
                const DropdownMenuItem<String>(
                  value: null,
                  child: Text('Assign later'),
                ),
                for (final item in matchingItems)
                  DropdownMenuItem(
                    value: item.classId,
                    child: Text(item.className),
                  ),
              ],
              validator: (_) {
                if (classId != null && selectedClassValue == null) {
                  return 'The selected class does not match this academic period.';
                }
                return null;
              },
              onChanged: academicYearId == null ? null : onClassChanged,
            );
          },
        ),
      ],
    );
  }
}

class StudentFormPage extends ConsumerStatefulWidget {
  final Student? existing;
  const StudentFormPage({this.existing, super.key});

  @override
  ConsumerState<StudentFormPage> createState() => _StudentFormPageState();
}

class _StudentFormPageState extends ConsumerState<StudentFormPage> {
  final _formKey = GlobalKey<FormState>();
  StudentRepository get _studentRepo =>
      ref.read(registrationStudentRepositoryProvider);
  UserRepository get _userRepo => ref.read(registrationUserRepositoryProvider);

  // Student fields
  late final TextEditingController _firstNameCtrl;
  late final TextEditingController _middleNameCtrl;
  late final TextEditingController _lastNameCtrl;
  late final TextEditingController _addressCtrl;
  String _gender = 'MALE';
  DateTime? _dateOfBirth;
  String _status = 'enrolled';
  String? _selectedAcademicYearId;
  String? _selectedClassId;
  String? _registrationStudentId;
  bool _placementSaved = false;
  bool _subjectsSaved = false;
  bool _placementLogged = false;
  bool _studentLogged = false;
  DateTime? _registrationDate;

  // Guardian entries: index 0 = mandatory, 1-3 = optional
  final List<_GuardianEntry> _guardians = [];
  final List<_ExistingGuardianSelection> _existingGuardians = [];

  // Loaded roles
  String? _guardianRoleId;

  bool _loading = false;
  bool _loadingExistingGuardians = false;
  String? _error;
  late final AutoSaveDebouncer _draftSaver;
  DateTime? _draftSavedAt;
  bool _restoringDraft = true;
  bool _draftCommitted = false;
  bool _draftDirty = false;

  late final String _draftId;
  final List<GlobalKey> _stageKeys = List.generate(5, (_) => GlobalKey());

  Map<String, dynamic> _draftData() => {
    'firstName': _firstNameCtrl.text,
    'middleName': _middleNameCtrl.text,
    'lastName': _lastNameCtrl.text,
    'address': _addressCtrl.text,
    'gender': _gender,
    'dateOfBirth': _dateOfBirth?.toIso8601String(),
    'status': _status,
    'academicYearId': _selectedAcademicYearId,
    'classId': _selectedClassId,
    'guardians': [
      for (final g in _guardians)
        {
          'firstName': g.firstNameCtrl.text,
          'lastName': g.lastNameCtrl.text,
          'email': g.emailCtrl.text,
          'phone': AppValidators.canonicalMalawiPhone(g.phoneCtrl.text),
          'address': g.addressCtrl.text,
          'gender': g.gender,
          'relationship': g.relationship,
        },
    ],
    'existingGuardians': [
      for (final selection in _existingGuardians)
        {
          'guardianId': selection.guardian.guardianId,
          'relationship': selection.relationship,
        },
    ],
  };

  void _scheduleDraft() {
    if (!_restoringDraft && _registrationStudentId == null && !_loading) {
      _draftDirty = true;
      _draftSaver.save();
    }
  }

  Future<void> _saveDraft() async {
    if (_registrationStudentId != null || _loading || !_draftDirty) return;
    final saved = await FormStatePersistence.saveFormStateWithTimestamp(
      _draftId,
      _draftData(),
    );
    if (mounted && saved) setState(() => _draftSavedAt = DateTime.now());
  }

  Future<void> _restoreDraft() async {
    final data = await FormStatePersistence.loadFormState(_draftId);
    if (!mounted) return;
    if (data != null) {
      setState(() {
        _firstNameCtrl.text = data['firstName'] as String? ?? '';
        _middleNameCtrl.text = data['middleName'] as String? ?? '';
        _lastNameCtrl.text = data['lastName'] as String? ?? '';
        _addressCtrl.text = data['address'] as String? ?? '';
        _gender = data['gender'] as String? ?? _gender;
        _status = data['status'] as String? ?? _status;
        _selectedAcademicYearId = data['academicYearId'] as String?;
        _selectedClassId = data['classId'] as String?;
        final dob = data['dateOfBirth'] as String?;
        _dateOfBirth = dob == null ? null : DateTime.tryParse(dob);
        if (!_isEdit) {
          final savedGuardians = data['guardians'] as List<dynamic>? ?? [];
          for (var i = 0; i < savedGuardians.length && i < 4; i++) {
            if (i >= _guardians.length) _guardians.add(_GuardianEntry());
            final saved = savedGuardians[i] as Map<String, dynamic>;
            final guardian = _guardians[i];
            guardian.firstNameCtrl.text = saved['firstName'] as String? ?? '';
            guardian.lastNameCtrl.text = saved['lastName'] as String? ?? '';
            guardian.emailCtrl.text = saved['email'] as String? ?? '';
            guardian.phoneCtrl.text = AppValidators.malawiSubscriberFromStored(
              saved['phone'] as String?,
            );
            guardian.addressCtrl.text = saved['address'] as String? ?? '';
            guardian.gender = saved['gender'] as String? ?? guardian.gender;
            guardian.relationship =
                saved['relationship'] as String? ?? guardian.relationship;
          }
        }
        _draftSavedAt = DateTime.now();
      });

      if (!_isEdit) {
        final savedExisting =
            data['existingGuardians'] as List<dynamic>? ?? const [];
        for (final raw in savedExisting) {
          final saved = raw as Map<String, dynamic>;
          final guardianId = saved['guardianId'] as String?;
          if (guardianId == null || guardianId.isEmpty) continue;
          try {
            final guardian = await _userRepo.getGuardian(guardianId);
            if (_existingGuardians.any(
              (selection) =>
                  selection.guardian.guardianId == guardian.guardianId,
            )) {
              continue;
            }
            _existingGuardians.add(
              _ExistingGuardianSelection(
                guardian: guardian,
                relationship: saved['relationship'] as String? ?? 'PARENT',
              ),
            );
          } catch (_) {
            // Ignore guardian records that were removed after the draft saved.
          }
        }
      }
    }
    if (mounted) setState(() => _restoringDraft = false);
  }

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _draftId =
        'student_${ref.read(authProvider).user?.userId ?? 'unknown'}_${widget.existing?.studentId ?? 'new'}';
    final s = widget.existing;
    _firstNameCtrl = TextEditingController(text: s?.firstName ?? '');
    _middleNameCtrl = TextEditingController(text: s?.middleName ?? '');
    _lastNameCtrl = TextEditingController(text: s?.lastName ?? '');
    _addressCtrl = TextEditingController(text: s?.physicalAddress ?? '');
    _gender = s?.gender ?? 'MALE';
    _dateOfBirth = s?.dateOfBirth;
    _status = (s?.enrollmentStatus ?? 'enrolled').toLowerCase();
    _draftSaver = AutoSaveDebouncer(onSave: _saveDraft);

    // Only add guardian section for new registrations
    if (!_isEdit) {
      _guardians.add(_GuardianEntry()); // mandatory primary guardian
      _loadGuardianRole();
    }
    _restoreDraft();
  }

  @override
  void dispose() {
    _draftSaver.dispose();
    if (!_restoringDraft &&
        !_draftCommitted &&
        _draftDirty &&
        _registrationStudentId == null) {
      unawaited(
        FormStatePersistence.saveFormStateWithTimestamp(_draftId, _draftData()),
      );
    }
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
      );
      if (mounted) setState(() => _guardianRoleId = role['roleid'] as String);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'Failed to load guardian role. Please try again.',
        );
      }
    }
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
      _scheduleDraft();
    }
  }

  void _removeGuardian(int index) {
    if (index == 0) return; // cannot remove primary
    if (_guardians[index].createdUserId != null) return;
    setState(() {
      _guardians[index].dispose();
      _guardians.removeAt(index);
    });
    _scheduleDraft();
  }

  Future<void> _selectExistingGuardian() async {
    if (_loadingExistingGuardians) return;
    setState(() {
      _loadingExistingGuardians = true;
      _error = null;
    });

    try {
      final selectedIds = _existingGuardians
          .map((selection) => selection.guardian.guardianId)
          .toSet();
      final guardians = await _userRepo.listGuardians();
      final available = guardians
          .where((guardian) => !selectedIds.contains(guardian.guardianId))
          .toList();

      if (!mounted) return;
      if (available.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('There are no other registered guardians to link.'),
          ),
        );
        return;
      }

      setState(() => _loadingExistingGuardians = false);
      final selected = await showDialog<Guardian>(
        context: context,
        builder: (_) => _GuardianSearchDialog(guardians: available),
      );
      if (selected == null || !mounted) return;

      setState(() {
        _existingGuardians.add(_ExistingGuardianSelection(guardian: selected));
      });
      _scheduleDraft();
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loadingExistingGuardians = false);
    }
  }

  void _removeExistingGuardian(_ExistingGuardianSelection selection) {
    if (selection.linked) return;
    setState(() => _existingGuardians.remove(selection));
    _scheduleDraft();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      if (!_isEdit) _revealFirstIssue();
      return;
    }
    if (_dateOfBirth == null) {
      setState(() => _error = 'Date of birth is required.');
      if (!_isEdit) _revealFirstIssue();
      return;
    }
    final guardiansToCreate = <_GuardianEntry>[];
    if (!_isEdit) {
      final emails = <String>{};
      for (final guardian in _guardians) {
        final email = guardian.emailCtrl.text.trim().toLowerCase();
        final hasDetails = [
          guardian.firstNameCtrl,
          guardian.lastNameCtrl,
          guardian.emailCtrl,
          guardian.phoneCtrl,
          guardian.addressCtrl,
        ].any((controller) => controller.text.trim().isNotEmpty);
        if (!hasDetails) continue;
        if (email.isEmpty ||
            guardian.firstNameCtrl.text.trim().isEmpty ||
            guardian.lastNameCtrl.text.trim().isEmpty) {
          setState(
            () => _error =
                'Enter a first name, last name and email for each added guardian, or leave the optional guardian blank.',
          );
          _revealFirstIssue();
          return;
        }
        if (!emails.add(email)) {
          setState(
            () => _error = 'Use a different email address for each guardian.',
          );
          _revealFirstIssue();
          return;
        }
        guardiansToCreate.add(guardian);
      }
      if (_existingGuardians.isEmpty && guardiansToCreate.isEmpty) {
        setState(
          () => _error =
              'Link an existing parent or guardian, or enter a new guardian.',
        );
        _revealFirstIssue();
        return;
      }
      if (guardiansToCreate.isNotEmpty && _guardianRoleId == null) {
        setState(
          () => _error =
              'Guardian account setup is still loading. Please wait and try again.',
        );
        return;
      }
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
        await ref
            .read(registrationAuditProvider)
            .log(
              userId: currentUser.userId,
              action: 'STUDENT_UPDATED',
              tableName: 'student',
              recordId: old.studentId,
              previousValue: old.toUpdateJson(),
              newValue: studentData,
              actorRole: currentUser.roleName,
            );
        _draftCommitted = true;
        _draftSaver.cancel();
        await FormStatePersistence.clearFormState(_draftId);
        if (mounted) closeForm(context, '/students', true);
        return;
      }

      // Create flow: student + guardians
      final registrationDate = _registrationDate ??= DateUtils.dateOnly(
        DateTime.now(),
      );
      final studentId = _registrationStudentId ??= await _studentRepo
          .createStudent(studentData);
      // Once the student exists, a locally restored draft could create a
      // duplicate. Keep any remaining guardian retry in this live form only.
      _draftCommitted = true;
      _draftSaver.cancel();
      await FormStatePersistence.clearFormState(_draftId);
      if (!_placementSaved &&
          _selectedAcademicYearId != null &&
          _selectedClassId != null) {
        await _studentRepo.assignClass(
          studentId: studentId,
          classId: _selectedClassId!,
          academicYearId: _selectedAcademicYearId!,
          enrollmentDate: registrationDate,
        );
        _placementSaved = true;
      }
      if (_placementSaved &&
          !_subjectsSaved &&
          _selectedAcademicYearId != null &&
          _selectedClassId != null) {
        await _studentRepo.enrolInClassSubjects(
          studentId: studentId,
          classId: _selectedClassId!,
          academicYearId: _selectedAcademicYearId!,
        );
        _subjectsSaved = true;
      }
      if (_placementSaved && !_placementLogged) {
        await ref
            .read(registrationAuditProvider)
            .log(
              userId: currentUser.userId,
              action: 'STUDENT_CLASS_ASSIGNED',
              tableName: 'studentclasshistory',
              actorRole: currentUser.roleName,
              newValue: {
                'studentid': studentId,
                'classid': _selectedClassId,
                'academicyearid': _selectedAcademicYearId,
                'enrollmentdate': registrationDate.toIso8601String().substring(
                  0,
                  10,
                ),
              },
            );
        _placementLogged = true;
      }
      if (!_studentLogged) {
        await ref
            .read(registrationAuditProvider)
            .log(
              userId: currentUser.userId,
              action: 'STUDENT_CREATED',
              tableName: 'student',
              recordId: studentId,
              actorRole: currentUser.roleName,
            );
        _studentLogged = true;
      }

      // Link existing guardians without creating duplicate accounts.
      for (final selection in _existingGuardians) {
        if (!selection.linked) {
          await _studentRepo.linkGuardian(
            studentId: studentId,
            guardianId: selection.guardian.guardianId,
            relationship: selection.relationship,
          );
          selection.linked = true;
        }

        if (!selection.auditLogged) {
          await ref
              .read(registrationAuditProvider)
              .log(
                userId: currentUser.userId,
                action: 'EXISTING_GUARDIAN_LINKED_TO_STUDENT',
                tableName: 'studentguardian',
                recordId: studentId,
                actorRole: currentUser.roleName,
                newValue: {
                  'studentId': studentId,
                  'guardianId': selection.guardian.guardianId,
                  'relationship': selection.relationship,
                },
              );
          selection.auditLogged = true;
        }
      }

      // Create each new guardian account and link it to the student.
      final createdGuardians = <_CreatedGuardian>[];

      for (final g in guardiansToCreate) {
        final email = g.emailCtrl.text.trim();

        final password = g.generatedPassword ??= _genPassword();
        final firstName = g.firstNameCtrl.text.trim();
        final lastName = g.lastNameCtrl.text.trim();

        final guardianUserId = g.createdUserId ??= await _userRepo.createUser({
          'email': email,
          'password': password,
          'username': email,
          'roleId': _guardianRoleId!,
          'userType': 'GUARDIAN',
          'profileData': {
            'firstname': firstName,
            'middlename': null,
            'lastname': lastName,
            'gender': g.gender,
            'email': email,
            'phonenumber': AppValidators.canonicalMalawiPhone(g.phoneCtrl.text),
            'physicaladdress': g.addressCtrl.text.trim().isEmpty
                ? null
                : g.addressCtrl.text.trim(),
          },
        });

        // guardianUserId is the auth UUID; look up the guardian row
        // to get the guardianid for linking.
        final guardianRow = await _userRepo.getGuardianByUserId(guardianUserId);

        if (!g.linked) {
          await _studentRepo.linkGuardian(
            studentId: studentId,
            guardianId: guardianRow['guardianid'] as String,
            relationship: g.relationship,
          );
          g.linked = true;
        }

        if (!g.auditLogged) {
          await ref
              .read(registrationAuditProvider)
              .log(
                userId: currentUser.userId,
                action: 'GUARDIAN_CREATED_FOR_STUDENT',
                tableName: 'guardian',
                recordId: guardianRow['guardianid'] as String,
                actorRole: currentUser.roleName,
                newValue: {'studentId': studentId, 'email': email},
              );
          g.auditLogged = true;
        }

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
      setState(() => _loading = false);
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

      // A direct visit to /students/new has no previous page to pop. The
      // messenger outlives this page, so the confirmation shows on the page
      // that replaces the form.
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final text =
            '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()} '
            'registered${_existingGuardians.isEmpty ? '' : ' and linked to the existing guardian'}.';
        context.go(homeForRole(currentUser.roleName));
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => messenger.showSnackBar(SnackBar(content: Text(text))),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = _registrationStudentId == null
              ? friendlyError(e)
              : 'Registration is partially saved. Retry here to finish without creating another student. ${friendlyError(e)}',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isEdit) return _buildAdmission(context);
    return UiPage(
      maxWidth: 920,
      children: [
        const PageHead(
          kicker: 'People',
          title: 'Edit Student',
          subtitle: 'Update identity details and enrollment status.',
        ),
        FormPanel(title: 'Student record', child: _buildFormBody(context)),
      ],
    );
  }

  // ── Admission workspace (registration mode) ──────────────────────────────

  static const _admissionSteps = [
    WorkspaceStep('Student', 'Identity'),
    WorkspaceStep('Guardian', 'Find or create'),
    WorkspaceStep('Class', 'Subjects follow'),
    WorkspaceStep('Access', 'Guardian login'),
    WorkspaceStep('Review', 'One submit'),
  ];

  AdmissionProgress _progress() => AdmissionProgress.from(
    firstName: _firstNameCtrl.text,
    lastName: _lastNameCtrl.text,
    hasDateOfBirth: _dateOfBirth != null,
    existingGuardians: _existingGuardians.length,
    newGuardianDrafts: [
      for (final g in _guardians)
        NewGuardianDraft(
          firstName: g.firstNameCtrl.text,
          lastName: g.lastNameCtrl.text,
          email: g.emailCtrl.text,
          touched: [
            g.firstNameCtrl,
            g.lastNameCtrl,
            g.emailCtrl,
            g.phoneCtrl,
            g.addressCtrl,
          ].any((controller) => controller.text.trim().isNotEmpty),
        ),
    ],
    classChosen: _selectedAcademicYearId != null && _selectedClassId != null,
  );

  String get _studentDisplayName => [
    _firstNameCtrl.text.trim(),
    _middleNameCtrl.text.trim(),
    _lastNameCtrl.text.trim(),
  ].where((part) => part.isNotEmpty).join(' ');

  void _onFormChanged() {
    _scheduleDraft();
    // Keep the stage ticks and the side summary in step with what is typed.
    if (mounted) setState(() {});
  }

  Future<void> _scrollToStage(int index) async {
    final target = _stageKeys[index].currentContext;
    if (target == null) return;
    await Scrollable.ensureVisible(
      target,
      duration: const Duration(milliseconds: 250),
      alignment: 0.02,
      curve: Curves.easeOut,
    );
  }

  /// Bring the first stage that still has a problem into view.
  void _revealFirstIssue() {
    final progress = _progress();
    final stage = !progress.studentReady
        ? AdmissionProgress.studentStage
        : AdmissionProgress.guardianStage;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToStage(stage);
    });
  }

  Widget _buildAdmission(BuildContext context) {
    final progress = _progress();
    final classLine = _classSummaryLine();
    final names = _selectedClassId == null
        ? null
        : ref
              .watch(_classSubjectNamesProvider(_selectedClassId!))
              .asData
              ?.value;
    final guardianLines = [
      for (final selection in _existingGuardians)
        '${selection.guardian.fullName} (linked)',
      for (final g in _guardians)
        if (g.firstNameCtrl.text.trim().isNotEmpty &&
            g.lastNameCtrl.text.trim().isNotEmpty)
          '${g.firstNameCtrl.text.trim()} ${g.lastNameCtrl.text.trim()} (new)',
    ];
    final facts = [
      if (_gender.isNotEmpty) _gender == 'MALE' ? 'Male' : 'Female',
      if (_dateOfBirth != null) 'born ${formatUiDate(_dateOfBirth)}',
    ].join(' · ');

    return UiPage(
      maxWidth: 1180,
      children: [
        const PageHead(
          kicker: 'People',
          title: 'Register Student',
          subtitle:
              'Student identity, guardian, class and access in one guided workspace. A single submission creates everything.',
        ),
        if (_restoringDraft) ...[
          const SkeletonFormField(),
          const SizedBox(height: 12),
          const SkeletonFormField(),
        ] else
          AutofillGroup(
            child: Form(
              key: _formKey,
              onChanged: _onFormChanged,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  WorkspaceStepper(
                    steps: _admissionSteps,
                    current: progress.currentStage,
                    completed: progress.completedStages,
                    freeNavigation: true,
                    onSelect: _scrollToStage,
                  ),
                  if (_draftSavedAt != null && !_loading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Draft saved on this device',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  SplitLayout(
                    main: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _studentStage(progress),
                        _guardianStage(progress),
                        _classStage(progress),
                        _accessStage(progress),
                        _reviewStage(progress),
                      ],
                    ),
                    side: AdmissionSummaryPanel(
                      progress: progress,
                      studentName: _studentDisplayName,
                      studentFacts: progress.studentReady ? facts : null,
                      guardianLines: guardianLines,
                      classLine: classLine,
                      subjectsLine: names == null
                          ? null
                          : names.isEmpty
                          ? 'No subjects set up for this class yet'
                          : '${names.length} subject${names.length == 1 ? '' : 's'} generated from Class Setup',
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  String? _classSummaryLine() {
    final classId = _selectedClassId;
    final yearId = _selectedAcademicYearId;
    if (classId == null || yearId == null) return null;
    final classes = ref.watch(_classesForRegistrationProvider).asData?.value;
    final years = ref.watch(_academicYearsProvider).asData?.value;
    final className = classes
        ?.where((c) => c.classId == classId)
        .map((c) => c.className)
        .firstOrNull;
    final year = years?.where((y) => y.id == yearId).firstOrNull;
    return 'Enrolment in ${className ?? 'the chosen class'}${year == null ? '' : ' (${year.selectionLabel})'}';
  }

  Widget _studentStage(AdmissionProgress progress) {
    return AdmissionStageCard(
      key: _stageKeys[AdmissionProgress.studentStage],
      number: 1,
      title: 'Student identity',
      subtitle: 'Who is being admitted. Required fields are marked.',
      done: progress.studentReady,
      child: AbsorbPointer(
        absorbing: _loading || _registrationStudentId != null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FieldGrid(
              children: [
                _field(_firstNameCtrl, 'First Name'),
                _field(_middleNameCtrl, 'Middle Name', required: false),
                _field(_lastNameCtrl, 'Last Name'),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: const [
                    DropdownMenuItem(value: 'MALE', child: Text('Male')),
                    DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                  ],
                  onChanged: (v) {
                    setState(() => _gender = v!);
                    _scheduleDraft();
                  },
                ),
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
                FullWidth(
                  child: _field(
                    _addressCtrl,
                    'Physical Address',
                    required: false,
                  ),
                ),
              ],
            ),
            DetailLine(
              'Admission date',
              '${formatUiDate(_registrationDate ?? DateTime.now())} (today)',
            ),
            const InlineGuide(
              text:
                  'Students never receive a login. Only the linked guardians can sign in to see their results and fees.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _guardianStage(AdmissionProgress progress) {
    return AdmissionStageCard(
      key: _stageKeys[AdmissionProgress.guardianStage],
      number: 2,
      title: 'Guardian and relationship',
      subtitle:
          'At least one guardian is required. Link a registered parent, create a new guardian here, or do both.',
      done: progress.guardianReady,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _loading || _loadingExistingGuardians
                  ? null
                  : _selectExistingGuardian,
              icon: _loadingExistingGuardians
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_search_outlined),
              label: const Text('Link Existing Parent or Guardian'),
            ),
          ),
          if (_existingGuardians.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._existingGuardians.map(
              (selection) => _ExistingGuardianCard(
                selection: selection,
                onRelationshipChanged: selection.linked
                    ? null
                    : (relationship) {
                        setState(() => selection.relationship = relationship);
                        _scheduleDraft();
                      },
                onRemove: selection.linked
                    ? null
                    : () => _removeExistingGuardian(selection),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Or create a new guardian',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ..._guardians.asMap().entries.map(
            (entry) => AbsorbPointer(
              absorbing: _loading || entry.value.createdUserId != null,
              child: _GuardianCard(
                index: entry.key,
                entry: entry.value,
                isPrimary: entry.key == 0,
                isRequired: entry.key == 0 && _existingGuardians.isEmpty,
                onRemove: () => _removeGuardian(entry.key),
              ),
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
      ),
    );
  }

  Widget _classStage(AdmissionProgress progress) {
    final classId = _selectedClassId;
    return AdmissionStageCard(
      key: _stageKeys[AdmissionProgress.classStage],
      number: 3,
      title: 'Current class',
      subtitle:
          'Choose the year and class now, or assign the class later. Subjects are generated from the class setup.',
      done: progress.classChosen,
      optional: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AbsorbPointer(
            absorbing: _placementSaved || _loading,
            child: RegistrationClassAssignment(
              academicYearId: _selectedAcademicYearId,
              classId: _selectedClassId,
              onYearChanged: (value) {
                setState(() {
                  _selectedAcademicYearId = value;
                  _selectedClassId = null;
                });
                _scheduleDraft();
              },
              onClassChanged: (value) {
                setState(() => _selectedClassId = value);
                _scheduleDraft();
              },
            ),
          ),
          if (classId == null)
            const InlineGuide(
              text:
                  'Pick a year and class to preview the subjects the student will receive. They follow the class; nothing is typed here.',
            )
          else
            _subjectPreview(classId),
        ],
      ),
    );
  }

  Widget _subjectPreview(String classId) {
    final names = ref.watch(_classSubjectNamesProvider(classId));
    return names.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 16),
        child: SkeletonFormField(),
      ),
      error: (_, _) => const InlineGuide(
        text:
            'The subject preview could not be loaded. Subjects still follow the class setup when the student is placed.',
      ),
      data: (items) {
        if (items.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const UiNotice(
                'No subjects are set up for this class yet. The student will be placed without subjects until the class lists them.',
                tone: StatusTone.warning,
                icon: Icons.info_outline,
              ),
              const SizedBox(height: 10),
              UiButton.secondary(
                'Open Class Setup',
                icon: Icons.account_tree_outlined,
                onPressed: () => context.push(
                  '/academics/class-setup?stage=subjects&classId=$classId',
                ),
              ),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${items.length} subject${items.length == 1 ? '' : 's'} generated for this class',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [for (final name in items) StatusPill(name)],
              ),
              const InlineGuide(
                text:
                    'To change what a class offers, use Class Setup. The student\'s class history is kept.',
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _accessStage(AdmissionProgress progress) {
    final newGuardians = [
      for (final g in _guardians)
        if (g.emailCtrl.text.trim().isNotEmpty &&
            g.firstNameCtrl.text.trim().isNotEmpty &&
            g.lastNameCtrl.text.trim().isNotEmpty)
          '${g.firstNameCtrl.text.trim()} ${g.lastNameCtrl.text.trim()} (${g.emailCtrl.text.trim()})',
    ];
    return AdmissionStageCard(
      key: _stageKeys[AdmissionProgress.accessStage],
      number: 4,
      title: 'Guardian access',
      subtitle: 'What each guardian receives when you submit.',
      done: progress.guardianReady,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_existingGuardians.isEmpty && newGuardians.isEmpty)
            const Text(
              'Add a guardian in stage 2 to see the access they will get.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          for (final selection in _existingGuardians)
            DetailLine(
              selection.guardian.fullName,
              'Already registered - no new login',
            ),
          for (final line in newGuardians)
            DetailLine(line, 'New login with a temporary password'),
          if (newGuardians.isNotEmpty)
            const InlineGuide(
              text:
                  'After you submit, the temporary passwords are shown once so you can hand them over. Each guardian must change the password at first sign-in.',
            ),
        ],
      ),
    );
  }

  Widget _reviewStage(AdmissionProgress progress) {
    final classLine = _classSummaryLine();
    return AdmissionStageCard(
      key: _stageKeys[AdmissionProgress.reviewStage],
      number: 5,
      title: 'Review and submit',
      subtitle: 'Check the summary, then register the student once.',
      done: progress.canSubmit,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DetailLine(
            'Student',
            _studentDisplayName.isEmpty ? '-' : _studentDisplayName,
          ),
          DetailLine(
            'Guardians',
            progress.guardiansToLink == 0
                ? '-'
                : '${progress.guardiansToLink} to link',
          ),
          DetailLine('Class', classLine ?? 'Assign later'),
          if (_error != null) UiNotice(_error!, icon: Icons.error_outline),
          if (!progress.canSubmit && progress.blockers.isNotEmpty)
            UiNotice(
              'Still needed: ${progress.blockers.join(', ')}.',
              tone: StatusTone.warning,
              icon: Icons.info_outline,
            ),
          const SizedBox(height: 16),
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
                  : const Icon(Icons.how_to_reg),
              label: Text(_loading ? 'Saving...' : 'Register Student'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormBody(BuildContext context) {
    return AutofillGroup(
      child: Form(
        key: _formKey,
        onChanged: _scheduleDraft,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_restoringDraft) ...[
              const SkeletonFormField(),
              const SizedBox(height: 12),
              const SkeletonFormField(),
            ] else ...[
              if (_draftSavedAt != null && !_loading)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Draft saved on this device',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              // Student details section
              AbsorbPointer(
                absorbing:
                    _loading || (!_isEdit && _registrationStudentId != null),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _sectionHeader('Student Information', Icons.school),
                    const SizedBox(height: 8),
                    _field(_firstNameCtrl, 'First Name'),
                    _field(_middleNameCtrl, 'Middle Name', required: false),
                    _field(_lastNameCtrl, 'Last Name'),
                    _field(_addressCtrl, 'Physical Address', required: false),
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      decoration: const InputDecoration(labelText: 'Gender'),
                      items: const [
                        DropdownMenuItem(value: 'MALE', child: Text('Male')),
                        DropdownMenuItem(
                          value: 'FEMALE',
                          child: Text('Female'),
                        ),
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
                              : _dateOfBirth!.toIso8601String().substring(
                                  0,
                                  10,
                                ),
                          style: TextStyle(
                            color: _dateOfBirth == null ? Colors.grey : null,
                          ),
                        ),
                      ),
                    ),
                    if (_isEdit) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _status,
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
                      const SizedBox(height: 24),
                      _sectionHeader('Assigned Subjects', Icons.book),
                      const SizedBox(height: 8),
                      _StudentSubjectsDisplay(
                        studentId: widget.existing!.studentId,
                      ),
                    ],

                    // Guardian section - only for new registration
                  ],
                ),
              ),
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
                      : const Icon(Icons.save),
                  label: Text(_loading ? 'Saving...' : 'Save Changes'),
                ),
              ),
            ],
          ],
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
        autofillHints: switch (label) {
          'First Name' => const [AutofillHints.givenName],
          'Middle Name' => const [AutofillHints.middleName],
          'Last Name' => const [AutofillHints.familyName],
          'Physical Address' => const [AutofillHints.fullStreetAddress],
          _ => null,
        },
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) =>
                  (v == null || v.trim().isEmpty) ? '$label is required.' : null
            : null,
      ),
    );
  }
}

class _ExistingGuardianCard extends StatelessWidget {
  final _ExistingGuardianSelection selection;
  final ValueChanged<String>? onRelationshipChanged;
  final VoidCallback? onRemove;

  const _ExistingGuardianCard({
    required this.selection,
    required this.onRelationshipChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final guardian = selection.guardian;
    final contact = [
      guardian.email,
      guardian.phoneNumber,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' • ');

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CircleAvatar(child: Icon(Icons.link)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    guardian.fullName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (contact.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(contact, style: Theme.of(context).textTheme.bodySmall),
                  ],
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selection.relationship,
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
                    onChanged: onRelationshipChanged == null
                        ? null
                        : (value) {
                            if (value != null) onRelationshipChanged!(value);
                          },
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: selection.linked ? 'Guardian already linked' : 'Remove',
              onPressed: onRemove,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuardianSearchDialog extends StatefulWidget {
  final List<Guardian> guardians;

  const _GuardianSearchDialog({required this.guardians});

  @override
  State<_GuardianSearchDialog> createState() => _GuardianSearchDialogState();
}

class _GuardianSearchDialogState extends State<_GuardianSearchDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = widget.guardians.where((guardian) {
      if (query.isEmpty) return true;
      return guardian.fullName.toLowerCase().contains(query) ||
          (guardian.email?.toLowerCase().contains(query) ?? false) ||
          (guardian.phoneNumber?.toLowerCase().contains(query) ?? false);
    }).toList();

    return AlertDialog(
      title: const Text('Link Existing Parent or Guardian'),
      content: SizedBox(
        width: 520,
        height: 430,
        child: Column(
          children: [
            TextField(
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Search by name, email, or phone',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: visible.isEmpty
                  ? const Center(child: Text('No matching guardians found.'))
                  : ListView.separated(
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final guardian = visible[index];
                        final contact =
                            guardian.email ??
                            guardian.phoneNumber ??
                            'No contact information';
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          title: Text(guardian.fullName),
                          subtitle: Text(contact),
                          onTap: () => Navigator.pop(context, guardian),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

// Card for one guardian entry in the form.
class _GuardianCard extends StatefulWidget {
  final int index;
  final _GuardianEntry entry;
  final bool isPrimary;
  final bool isRequired;
  final VoidCallback onRemove;

  const _GuardianCard({
    required this.index,
    required this.entry,
    required this.isPrimary,
    required this.isRequired,
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
        ? widget.isRequired
              ? 'Primary Guardian (Required)'
              : 'New Guardian (Optional)'
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
              required: widget.isRequired,
            ),
            _f(
              widget.entry.lastNameCtrl,
              'Last Name',
              required: widget.isRequired,
            ),
            _f(
              widget.entry.emailCtrl,
              'Email address',
              required: widget.isRequired,
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
              prefixText: '+265 ',
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              extraValidator: AppValidators.malawiSubscriberDigits,
            ),
            _f(widget.entry.addressCtrl, 'Physical Address', required: false),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: widget.entry.gender,
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
    String? prefixText,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? extraValidator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        autofillHints: switch (label) {
          'First Name' => const [AutofillHints.givenName],
          'Last Name' => const [AutofillHints.familyName],
          'Email address' => const [AutofillHints.email],
          'Phone Number' => const [AutofillHints.telephoneNumber],
          'Physical Address' => const [AutofillHints.fullStreetAddress],
          _ => null,
        },
        keyboardType: keyboard,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixText: prefixText,
        ),
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

// ── Student Subjects Display Widget ────────────────────────────────────────
// Shows read-only list of subjects for a student's current class
class _StudentSubjectsDisplay extends ConsumerWidget {
  final String studentId;
  const _StudentSubjectsDisplay({required this.studentId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(_studentSubjectsProvider(studentId));

    return subjectsAsync.when(
      loading: () => const Column(
        children: [
          SkeletonCard(height: 64),
          SkeletonCard(height: 64),
          SkeletonCard(height: 64),
        ],
      ),
      error: (e, _) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.red.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Error loading subjects: $e',
          style: TextStyle(color: Colors.red.shade800, fontSize: 12),
        ),
      ),
      data: (subjects) {
        if (subjects.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                'No subjects assigned to this student\'s current class',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: subjects.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final subject = subjects[i];
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.book_outlined,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          subject.subjectName ?? 'Unknown Subject',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Teacher: ${subject.staffName ?? 'TBD'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
