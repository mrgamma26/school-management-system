import 'package:flutter/material.dart';
import '../../../../core/errors/app_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/models/staff.dart';
import '../../data/repositories/user_repository.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/services/audit_service.dart';
import '../../../academics/data/academic_repository.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../../core/utils/autofill_helper.dart';

/// Create or edit a staff member.
/// New accounts are created via the [create-user] Edge Function.
class StaffFormPage extends ConsumerStatefulWidget {
  final Staff? existing;
  const StaffFormPage({this.existing, super.key});

  @override
  ConsumerState<StaffFormPage> createState() => _StaffFormPageState();
}

final _allClassesProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final rows = await supabase
      .from('class')
      .select('classid, classroomname')
      .order('classroomname');
  return List<Map<String, dynamic>>.from(rows as List);
});

final _allSubjectsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final rows = await supabase
      .from('subject')
      .select('subjectid, subjectname')
      .order('subjectname');
  return List<Map<String, dynamic>>.from(rows as List);
});

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

  // Teacher subject assignments
  String? _currentAcademicYearId;
  final List<Map<String, dynamic>> _selectedAssignments = [];
  String? _pendingClassId;
  String? _pendingSubjectId;

  bool get _isEdit => widget.existing != null;
  bool get _isTeacherRole {
    if (_selectedRoleId == null || _roles.isEmpty) return false;
    final roleData = _roles.firstWhere(
      (r) => r['roleid'] == _selectedRoleId,
      orElse: () => {},
    );
    return (roleData['rolename'] as String?)?.toUpperCase() == 'TEACHER';
  }

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
    _loadCurrentAcademicYear();
  }

  Future<void> _loadCurrentAcademicYear() async {
    try {
      final years = await AcademicRepository().currentAcademicYears();
      if (mounted && years.isNotEmpty) {
        setState(() => _currentAcademicYearId = years.first['academicyearid']);
      }
    } catch (e) {
      // Silently fail if no current academic year
    }
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
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to load roles. Please try again.');
      }
    }
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
        final createdStaff = await _repo.createUser({
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

        // If this is a teacher, assign subjects
        if (_isTeacherRole &&
            _currentAcademicYearId != null &&
            _selectedAssignments.isNotEmpty) {
          final staffId =
              (await supabase
                      .from('staff')
                      .select('staffid')
                      .eq('userid', createdStaff)
                      .single())['staffid']
                  as String;

          for (final assignment in _selectedAssignments) {
            await AcademicRepository().assignTeacher(
              classId: assignment['classid'] as String,
              subjectId: assignment['subjectid'] as String,
              staffId: staffId,
              academicYearId: _currentAcademicYearId!,
            );

            await AuditService().log(
              userId: currentUser.userId,
              action: 'TEACHER_SUBJECT_ASSIGNED',
              tableName: 'classsubject',
              actorRole: currentUser.roleName,
              newValue: {
                'staffId': staffId,
                'classId': assignment['classid'],
                'subjectId': assignment['subjectid'],
                'yearId': _currentAcademicYearId,
              },
            );
          }
        }
      }

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
      appBar: AppBar(title: Text(_isEdit ? 'Edit Staff' : 'Add Staff')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _field(
                  _firstNameCtrl,
                  'First Name',
                  autofillHint: AutofillHintStrings.givenName,
                ),
                _field(_middleNameCtrl, 'Middle Name', required: false),
                _field(
                  _lastNameCtrl,
                  'Last Name',
                  autofillHint: AutofillHintStrings.familyName,
                ),
                _field(
                  _emailCtrl,
                  'Email',
                  keyboard: TextInputType.emailAddress,
                  autofillHint: AutofillHintStrings.email,
                ),
                if (!_isEdit) ...[
                  _field(_employeeNumberCtrl, 'Employee Number'),
                  _field(
                    _passwordCtrl,
                    'Temporary Password',
                    obscure: true,
                    autofillHint: AutofillHintStrings.password,
                  ),
                  if (_roles.isNotEmpty)
                    DropdownButtonFormField<String>(
                      initialValue: _selectedRoleId,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: _roles
                          .map(
                            (r) => DropdownMenuItem(
                              value: r['roleid'] as String,
                              child: Text(r['rolename'] as String),
                            ),
                          )
                          .toList(),
                      onChanged: (v) => setState(() {
                        _selectedRoleId = v;
                        _selectedAssignments.clear();
                        _pendingClassId = null;
                        _pendingSubjectId = null;
                      }),
                      validator: (v) =>
                          v == null ? 'Please select a role.' : null,
                    ),
                ],
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _gender,
                  decoration: const InputDecoration(labelText: 'Gender'),
                  items: const [
                    DropdownMenuItem(value: 'MALE', child: Text('Male')),
                    DropdownMenuItem(value: 'FEMALE', child: Text('Female')),
                  ],
                  onChanged: (v) => setState(() => _gender = v!),
                ),

                // Teacher subject assignment section
                if (!_isEdit &&
                    _isTeacherRole &&
                    _currentAcademicYearId != null) ...[
                  const SizedBox(height: 24),
                  const Divider(),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Subjects to Teach',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSubjectAssignmentUI(ref),
                ],

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
      ),
    );
  }

  Widget _buildSubjectAssignmentUI(WidgetRef ref) {
    final classesAsync = ref.watch(_allClassesProvider);
    final subjectsAsync = ref.watch(_allSubjectsProvider);

    return Column(
      children: [
        classesAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error loading classes: $e'),
          data: (classes) => DropdownButtonFormField<String>(
            initialValue: _pendingClassId,
            decoration: const InputDecoration(
              labelText: 'Class',
              border: OutlineInputBorder(),
            ),
            items: classes
                .map(
                  (c) => DropdownMenuItem(
                    value: c['classid'] as String,
                    child: Text(c['classroomname'] as String),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _pendingClassId = v),
          ),
        ),
        const SizedBox(height: 12),
        subjectsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => Text('Error loading subjects: $e'),
          data: (subjects) => DropdownButtonFormField<String>(
            initialValue: _pendingSubjectId,
            decoration: const InputDecoration(
              labelText: 'Subject',
              border: OutlineInputBorder(),
            ),
            items: subjects
                .map(
                  (s) => DropdownMenuItem(
                    value: s['subjectid'] as String,
                    child: Text(s['subjectname'] as String),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() => _pendingSubjectId = v),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _pendingClassId != null && _pendingSubjectId != null
                ? () {
                    setState(() {
                      _selectedAssignments.add({
                        'classid': _pendingClassId,
                        'subjectid': _pendingSubjectId,
                      });
                      _pendingClassId = null;
                      _pendingSubjectId = null;
                    });
                  }
                : null,
            icon: const Icon(Icons.add),
            label: const Text('Add Subject'),
          ),
        ),
        if (_selectedAssignments.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Selected Subjects:',
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ),
          const SizedBox(height: 8),
          classesAsync.when(
            loading: () => const SizedBox(),
            error: (_, _) => const SizedBox(),
            data: (classes) => subjectsAsync.when(
              loading: () => const SizedBox(),
              error: (_, _) => const SizedBox(),
              data: (subjects) {
                final classMap = {
                  for (var c in classes) c['classid']: c['classroomname'],
                };
                final subjectMap = {
                  for (var s in subjects) s['subjectid']: s['subjectname'],
                };

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _selectedAssignments.map((a) {
                    final className = classMap[a['classid']] ?? 'Unknown';
                    final subjectName = subjectMap[a['subjectid']] ?? 'Unknown';
                    return Chip(
                      label: Text('$subjectName — $className'),
                      onDeleted: () {
                        setState(() => _selectedAssignments.remove(a));
                      },
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = true,
    bool obscure = false,
    TextInputType? keyboard,
    String autofillHint = '',
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        obscureText: obscure,
        keyboardType: keyboard,
        autofillHints: autofillHint.isNotEmpty ? [autofillHint] : null,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) =>
                  (v == null || v.trim().isEmpty) ? '$label is required.' : null
            : null,
      ),
    );
  }
}
