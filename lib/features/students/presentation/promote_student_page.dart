import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../../core/services/audit_service.dart';
import '../../academics/data/academic_repository.dart';
import '../../academics/domain/models/academic_year.dart';
import '../../academics/domain/models/class_model.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../../../widgets/ui_kit.dart';
import '../data/student_repository.dart';

final _promotionYearsProvider = FutureProvider<List<AcademicYear>>((ref) {
  return AcademicRepository().listAcademicYears();
});

final _promotionClassesProvider = FutureProvider<List<ClassModel>>((ref) {
  return AcademicRepository().listClasses();
});

final _manualPromotionBlockProvider = FutureProvider.family<String?, String>((
  ref,
  studentId,
) async {
  final rows = await supabase
      .from('progressionreview')
      .select('reviewid')
      .eq('studentid', studentId)
      .eq('decision', 'PENDING')
      .limit(1);
  if ((rows as List).isNotEmpty) {
    return 'Manual class movement is blocked while a progression review is pending.';
  }
  final placement = await supabase
      .from('studentclasshistory')
      .select('academicyear(academicyear)')
      .eq('studentid', studentId)
      .isFilter('enddate', null)
      .order('enrollmentdate', ascending: false)
      .limit(1)
      .maybeSingle();
  final period = placement?['academicyear'] as Map?;
  final schoolYear = period?['academicyear'] as int?;
  if (schoolYear == null) {
    return 'Manual class movement is blocked because the active placement or academic year is incomplete.';
  }
  try {
    final evidence = Map<String, dynamic>.from(
      await supabase.rpc(
            'calculate_student_annual_result',
            params: {'p_student_id': studentId, 'p_school_year': schoolYear},
          )
          as Map,
    );
    if (evidence['complete'] != true) {
      return 'Manual class movement is blocked until all enrolled-term results are submitted.';
    }
  } catch (_) {
    return 'Manual class movement is blocked until progression evidence can be verified.';
  }
  return null;
});

class PromoteStudentPage extends ConsumerStatefulWidget {
  final String studentId;

  const PromoteStudentPage({required this.studentId, super.key});

  @override
  ConsumerState<PromoteStudentPage> createState() => _PromoteStudentPageState();
}

class _PromoteStudentPageState extends ConsumerState<PromoteStudentPage> {
  AcademicYear? _selectedYear;
  ClassModel? _selectedClass;
  DateTime _enrollmentDate = DateTime.now();
  bool _saving = false;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _enrollmentDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _enrollmentDate = picked);
  }

  Future<void> _submit() async {
    final year = _selectedYear;
    final classModel = _selectedClass;
    if (year == null || classModel == null) return;

    final blocked = await ref.read(
      _manualPromotionBlockProvider(widget.studentId).future,
    );
    if (blocked != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(blocked)));
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final history = await StudentRepository().getClassHistory(
        widget.studentId,
      );
      final previous = history.cast<Map<String, dynamic>?>().firstWhere(
        (row) => row?['enddate'] == null,
        orElse: () => null,
      );
      final user = ref.read(authProvider).user!;

      await StudentRepository().assignClass(
        studentId: widget.studentId,
        classId: classModel.classId,
        academicYearId: year.id,
        enrollmentDate: _enrollmentDate,
      );

      final previousClass = previous?['class'] as Map<String, dynamic>?;
      final previousYear = previous?['academicyear'] as Map<String, dynamic>?;
      await AuditService().log(
        userId: user.userId,
        action: 'STUDENT_PROMOTED',
        tableName: 'studentclasshistory',
        recordId: widget.studentId,
        previousValue: {
          'class': previousClass?['classroomname'],
          'academicYear': previousYear?['academicyear'],
          'term': previousYear?['term'],
        },
        newValue: {
          'class': classModel.className,
          'academicYear': year.year,
          'term': year.term,
        },
        actorRole: user.roleName,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update class: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(_promotionYearsProvider);
    final classesAsync = ref.watch(_promotionClassesProvider);
    final blockAsync = ref.watch(
      _manualPromotionBlockProvider(widget.studentId),
    );
    final blocked = blockAsync.maybeWhen(
      data: (message) => message != null,
      orElse: () => true,
    );

    final saveEnabled =
        !(blocked || _saving || _selectedYear == null || _selectedClass == null);
    final blockMessage = blockAsync.maybeWhen(
      data: (message) => message,
      orElse: () => null,
    );

    return FormPageLayout(
      kicker: 'Students',
      title: 'Promote / Move Class',
      subtitle: 'Place this learner in a class for an academic period.',
      formTitle: 'Class placement',
      saveLabel: 'Save Class Placement',
      saving: _saving,
      onSave: saveEnabled ? _submit : null,
      error: blockMessage,
      form: FieldGrid(
        children: [
          FullWidth(
            child: UiField(
              label: 'Academic year / term',
              child: yearsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) =>
                    Text('Could not load academic years: $error'),
                data: (years) => DropdownButtonFormField<AcademicYear>(
                  initialValue: _selectedYear,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    hintText: 'Select academic year and term',
                  ),
                  items: years
                      .map(
                        (year) => DropdownMenuItem(
                          value: year,
                          child: Text(
                            '${year.label} • ${formatFormLevel(year.form)} • ${year.term.replaceAll('_', ' ')}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: blocked
                      ? null
                      : (value) => setState(() {
                          _selectedYear = value;
                          _selectedClass = null;
                        }),
                ),
              ),
            ),
          ),
          UiField(
            label: 'New class',
            child: classesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => Text('Could not load classes: $error'),
              data: (classes) => DropdownButtonFormField<ClassModel>(
                initialValue: _selectedClass,
                isExpanded: true,
                decoration: const InputDecoration(hintText: 'Select class'),
                items: classes
                    .where(
                      (classModel) => classModel.form == _selectedYear?.form,
                    )
                    .map(
                      (classModel) => DropdownMenuItem(
                        value: classModel,
                        child: Text(classModel.className),
                      ),
                    )
                    .toList(),
                onChanged: blocked || _selectedYear == null
                    ? null
                    : (value) => setState(() => _selectedClass = value),
              ),
            ),
          ),
          UiField(
            label: 'Enrollment date',
            child: Row(
              children: [
                Expanded(child: UiCellText(formatUiDate(_enrollmentDate))),
                UiButton.secondary('Change', onPressed: _pickDate),
              ],
            ),
          ),
        ],
      ),
      side: [
        CheckRow(
          label: 'Academic period chosen',
          checked: _selectedYear != null,
        ),
        CheckRow(label: 'Class chosen', checked: _selectedClass != null),
        CheckRow(
          label: 'No pending progression review',
          checked: !blocked,
        ),
      ],
    );
  }
}
