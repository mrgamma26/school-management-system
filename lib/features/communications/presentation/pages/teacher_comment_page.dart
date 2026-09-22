import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../../data/communications_repository.dart';
import '../../../../core/database/supabase_client.dart';
import '../../../../core/services/audit_service.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';

// Providers

final _tcYearsProvider = FutureProvider<List<Map<String, dynamic>>>((
  ref,
) async {
  final rows = await supabase
      .from('academicyear')
      .select('academicyearid, academicyear, term')
      .order('academicyear', ascending: false);
  return List<Map<String, dynamic>>.from(rows as List);
});

final _tcStudentsProvider =
    FutureProvider.family<List<Map<String, dynamic>>, String>((
      ref,
      yearId,
    ) async {
      // All students enrolled in the current year
      final rows = await supabase
          .from('studentclasshistory')
          .select(
            'student(studentid, firstname, lastname), class(classroomname)',
          )
          .eq('academicyearid', yearId)
          .isFilter('enddate', null);
      return List<Map<String, dynamic>>.from(rows as List);
    });

final _tcCommentProvider =
    FutureProvider.family<
      Map<String, dynamic>?,
      ({String staffId, String studentId, String academicYearId})
    >((ref, args) async {
      return CommunicationsRepository().getComment(
        staffId: args.staffId,
        studentId: args.studentId,
        academicYearId: args.academicYearId,
      );
    });

final _tcStaffIdProvider = FutureProvider<String>((ref) async {
  final uid = ref.watch(authProvider).user!.userId;
  final row = await supabase
      .from('staff')
      .select('staffid')
      .eq('userid', uid)
      .single();
  return row['staffid'] as String;
});

// Page

/// Teacher comments - one narrative comment per student per academic year.
/// Teachers write their own. Head Teacher / Admin reads all.
class TeacherCommentPage extends ConsumerStatefulWidget {
  const TeacherCommentPage({super.key});

  @override
  ConsumerState<TeacherCommentPage> createState() => _TeacherCommentPageState();
}

class _TeacherCommentPageState extends ConsumerState<TeacherCommentPage> {
  String? _yearId;

  bool get _canWrite {
    final r = ref.read(authProvider).user?.roleName.toUpperCase() ?? '';
    return r == 'TEACHER' || r == 'SYSTEM_ADMIN' || r == 'SUPER_USER';
  }

  @override
  Widget build(BuildContext context) {
    final yearsAsync = ref.watch(_tcYearsProvider);
    final staffAsync = ref.watch(_tcStaffIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Comments'),
        actions: [
          HomeButton(roleName: ref.watch(authProvider).user?.roleName ?? ''),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: yearsAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (years) => DropdownButtonFormField<String>(
                initialValue: _yearId,
                decoration: const InputDecoration(
                  labelText: 'Academic Year',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                hint: const Text('Select academic year'),
                items: years.map((y) {
                  final id = y['academicyearid'] as String;
                  final label = '${y['academicyear']} - ${y['term']}';
                  return DropdownMenuItem(value: id, child: Text(label));
                }).toList(),
                onChanged: (v) => setState(() => _yearId = v),
              ),
            ),
          ),
          Expanded(
            child: _yearId == null
                ? const Center(
                    child: Text(
                      'Select a year to view / write comments',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : staffAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) =>
                        Center(child: Text('Staff profile error: $e')),
                    data: (staffId) => _StudentCommentList(
                      yearId: _yearId!,
                      staffId: staffId,
                      canWrite: _canWrite,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// Student comment list

class _StudentCommentList extends ConsumerWidget {
  final String yearId;
  final String staffId;
  final bool canWrite;

  const _StudentCommentList({
    required this.yearId,
    required this.staffId,
    required this.canWrite,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final studentsAsync = ref.watch(_tcStudentsProvider(yearId));

    return studentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(
            child: Text(
              'No students enrolled for this year.',
              style: TextStyle(color: Colors.grey),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const SizedBox(height: 6),
          itemBuilder: (context, i) {
            final student = rows[i]['student'] as Map<String, dynamic>;
            final cls = rows[i]['class'] as Map<String, dynamic>?;
            final sid = student['studentid'] as String;
            final name = '${student['firstname']} ${student['lastname']}';
            final args = (
              staffId: staffId,
              studentId: sid,
              academicYearId: yearId,
            );
            final commentAsync = ref.watch(_tcCommentProvider(args));

            return Card(
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.teal,
                  child: Icon(Icons.person, color: Colors.white, size: 20),
                ),
                title: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  commentAsync.when(
                    loading: () => 'Loading...',
                    error: (_, _) => 'Error',
                    data: (c) => c != null
                        ? (c['comment'] as String).length > 60
                              ? '${(c['comment'] as String).substring(0, 60)}…'
                              : c['comment'] as String
                        : 'No comment yet',
                  ),
                ),
                trailing: canWrite
                    ? IconButton(
                        icon: Icon(
                          commentAsync.value != null
                              ? Icons.edit
                              : Icons.add_comment,
                          color: Colors.teal,
                        ),
                        onPressed: () => _showCommentDialog(
                          context,
                          ref,
                          sid,
                          name,
                          commentAsync.value?['comment'] as String?,
                        ),
                      )
                    : null,
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCommentDialog(
    BuildContext context,
    WidgetRef ref,
    String studentId,
    String studentName,
    String? existing,
  ) async {
    final ctrl = TextEditingController(text: existing ?? '');

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Comment for $studentName'),
        content: TextField(
          controller: ctrl,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Comment',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (ctrl.text.trim().isEmpty) return;
              await CommunicationsRepository().upsertComment(
                studentId: studentId,
                staffId: staffId,
                academicYearId: yearId,
                comment: ctrl.text.trim(),
              );
              final actor = ref.read(authProvider).user!;
              await AuditService().log(
                userId: actor.userId,
                action: existing != null
                    ? 'TEACHER_COMMENT_UPDATED'
                    : 'TEACHER_COMMENT_CREATED',
                tableName: 'teachercomment',
                recordId: studentId,
                actorRole: actor.roleName,
              );
              ref.invalidate(
                _tcCommentProvider((
                  staffId: staffId,
                  studentId: studentId,
                  academicYearId: yearId,
                )),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(existing != null ? 'Update' : 'Save'),
          ),
        ],
      ),
    );
    ctrl.dispose();
  }
}
