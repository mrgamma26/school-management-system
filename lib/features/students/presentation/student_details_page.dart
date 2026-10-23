import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/school_role_access.dart';
import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_widgets.dart' show ErrorState, LoadingState;
import '../../../widgets/ui_kit.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../data/student_repository.dart';
import '../domain/student.dart';

/// Screen 10 - Student profile: key information and links to the related
/// records (account, guardians, subjects, class history).
class StudentDetailsPage extends ConsumerStatefulWidget {
  final String studentId;
  const StudentDetailsPage({required this.studentId, super.key});

  @override
  ConsumerState<StudentDetailsPage> createState() => _StudentDetailsPageState();
}

class _StudentDetailsPageState extends ConsumerState<StudentDetailsPage> {
  final _repo = StudentRepository();
  Student? _student;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _repo.getStudent(widget.studentId);
      if (mounted) setState(() => _student = s);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const UiPage(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 64),
            child: LoadingState(message: 'Loading student…'),
          ),
        ],
      );
    }
    if (_error != null) {
      return UiPage(
        children: [
          PageHead(
            kicker: 'People',
            title: 'Student',
            actions: [
              UiButton.secondary(
                'Back to students',
                icon: Icons.arrow_back_rounded,
                onPressed: () => context.go('/students'),
              ),
            ],
          ),
          ErrorState(error: _error!, onRetry: _load),
        ],
      );
    }

    final s = _student!;
    final role = ref.watch(authProvider).user?.roleName ?? '';
    final canManageAccounts = canRecordStudentPayments(role);

    return UiPage(
      children: [
        PageHead(
          kicker: 'People',
          title: 'Student Profile',
          subtitle: 'One student record with guardians, subjects and history.',
          actions: [
            UiButton.secondary(
              'Back to students',
              icon: Icons.arrow_back_rounded,
              onPressed: () => context.go('/students'),
            ),
            UiButton(
              'Edit',
              icon: Icons.edit_outlined,
              onPressed: () async {
                await context.push<bool>('/students/${s.studentId}/edit');
                _load();
              },
            ),
          ],
        ),
        ProfileHero(
          name: s.fullName,
          subtitle:
              '${s.gender} · Born ${formatUiDate(s.dateOfBirth)} · ID ${s.studentId.substring(0, 8).toUpperCase()}',
          pill: StatusPill.auto(s.enrollmentStatus),
        ),
        const SizedBox(height: 14),
        SplitLayout(
          mainFlex: 100,
          sideFlex: 100,
          main: Panel(
            title: 'Key information',
            child: Column(
              children: [
                DetailLine('Full name', s.fullName),
                DetailLine('Gender', s.gender),
                DetailLine('Date of birth', formatUiDate(s.dateOfBirth)),
                DetailLine('Enrollment status', s.enrollmentStatus),
                if (s.physicalAddress != null && s.physicalAddress!.isNotEmpty)
                  DetailLine('Address', s.physicalAddress!),
              ],
            ),
          ),
          side: Panel(
            title: 'Related records',
            child: QueueList(
              items: [
                if (canManageAccounts)
                  QueueItem(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Student Account & Payments',
                    subtitle: 'Balance, ledger and payment capture',
                    onTap: () => context.go(
                      '/finance/students/${s.studentId}/account'
                      '?name=${Uri.encodeComponent(s.fullName)}',
                    ),
                  ),
                QueueItem(
                  icon: Icons.family_restroom_outlined,
                  title: 'Manage Guardians',
                  subtitle: 'Link or unlink guardians',
                  onTap: () =>
                      context.go('/students/${s.studentId}/link-guardian'),
                ),
                QueueItem(
                  icon: Icons.menu_book_outlined,
                  title: 'Manage Subjects',
                  subtitle: 'Subject enrollments for this student',
                  onTap: () => context.go('/students/${s.studentId}/subjects'),
                ),
                QueueItem(
                  icon: Icons.history_edu_outlined,
                  title: 'Class History',
                  subtitle: 'Classes by year, promotions and transfers',
                  onTap: () =>
                      context.go('/students/${s.studentId}/class-history'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
