import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/school_role_access.dart';
import '../../../../core/errors/app_exception.dart';
import '../../../../theme/app_tokens.dart';
import '../../../../widgets/ui_kit.dart';
import '../../../../widgets/ui_record_list.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../data/finance_records_repository.dart';
import '../../data/finance_repository.dart';
import '../finance_account_providers.dart';

final _depositSlipsProvider = FutureProvider.autoDispose<List<DepositSlipRow>>(
  (ref) => FinanceRecordsRepository().listDepositSlips(),
);

StatusTone _toneFor(String status) => switch (status) {
  'VERIFIED' => StatusTone.success,
  'REJECTED' => StatusTone.danger,
  'PENDING' => StatusTone.warning,
  _ => StatusTone.neutral,
};

String _labelFor(String status) =>
    status.isEmpty ? '—' : status[0] + status.substring(1).toLowerCase();

/// Screens 43 and 44 - Deposit slips and their verification.
///
/// Selecting a slip opens a preview and decision panel beside the list (a
/// bottom sheet on narrow screens). The Accountant can approve or reject a
/// PENDING slip (rejection needs a reason); the `deposit_slips_accountant_all`
/// RLS policy allows that update. Oversight roles (Administrator, Head
/// Teacher, Super User) can read the slip but not decide it. The slip image
/// lives in the private `deposit-slips` bucket and is only ever shown through a
/// short-lived signed link.
class DepositSlipsPage extends ConsumerStatefulWidget {
  const DepositSlipsPage({super.key});

  @override
  ConsumerState<DepositSlipsPage> createState() => _DepositSlipsPageState();
}

class _DepositSlipsPageState extends ConsumerState<DepositSlipsPage> {
  String? _selectedId;

  void _select(DepositSlipRow slip, bool wide, bool canDecide) {
    if (wide) {
      setState(() => _selectedId = slip.id);
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        builder: (_, controller) => SingleChildScrollView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: _SlipPanel(
            slip: slip,
            canDecide: canDecide,
            onDecided: () {
              ref.invalidate(_depositSlipsProvider);
              Navigator.of(ctx).pop();
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(_depositSlipsProvider);
    final role = ref.watch(activeWorkspaceRoleProvider);
    final canDecide = canRecordStudentPayments(role);
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    final selected = _selectedId == null
        ? null
        : (data.value ?? const <DepositSlipRow>[])
              .where((s) => s.id == _selectedId)
              .firstOrNull;

    final list = RecordListView<DepositSlipRow>(
      data: data,
      onRetry: () => ref.invalidate(_depositSlipsProvider),
      loadingMessage: 'Loading deposit slips…',
      searchHint: 'Search student, reference or bank',
      searchText: (s) => '${s.studentName} ${s.reference} ${s.bankName}',
      filters: const ['All', 'Pending', 'Verified', 'Rejected'],
      matchesFilter: (s, f) => _labelFor(s.status) == f,
      emptyIcon: Icons.receipt_long_outlined,
      emptyTitle: 'No deposit slips yet',
      emptyMessage: 'Slips appear here once the Accountant records them.',
      header: (items) => AdaptiveGrid(
        columns: 3,
        phoneColumns: 1,
        children: [
          MetricCard(
            icon: Icons.hourglass_empty_rounded,
            label: 'Pending verification',
            value: '${items.where((s) => s.status == 'PENDING').length}',
            noteTone: StatusTone.warning,
          ),
          MetricCard(
            icon: Icons.verified_outlined,
            label: 'Verified',
            value: '${items.where((s) => s.status == 'VERIFIED').length}',
            noteTone: StatusTone.neutral,
          ),
          MetricCard(
            icon: Icons.cancel_outlined,
            label: 'Rejected',
            value: '${items.where((s) => s.status == 'REJECTED').length}',
            noteTone: StatusTone.neutral,
          ),
        ],
      ),
      columns: const [
        UiColumn('Student', flex: 14),
        UiColumn('Reference', flex: 10, hideOnPhone: true),
        UiColumn('Bank', flex: 10, hideOnPhone: true),
        UiColumn('Deposited', flex: 9, hideOnPhone: true),
        UiColumn('Amount', flex: 10),
        UiColumn('Status', width: 100),
      ],
      rowOf: (s) => UiTableRow([
        PersonCell(s.studentName),
        UiCellText(s.reference),
        UiCellText(s.bankName),
        UiCellText(formatUiDate(s.depositDate)),
        UiCellText(formatMwk(s.amount), bold: true),
        Align(
          alignment: Alignment.centerLeft,
          child: StatusPill(_labelFor(s.status), tone: _toneFor(s.status)),
        ),
      ], onTap: () => _select(s, wide, canDecide)),
    );

    return UiPage(
      maxWidth: 1400,
      children: [
        PageHead(
          kicker: 'Finance',
          title: 'Deposit Slips',
          subtitle: canDecide
              ? 'Preview bank deposit evidence, then approve or reject it.'
              : 'Bank deposit evidence and its verification status.',
          actions: [
            if (canDecide)
              UiButton(
                'Add deposit image',
                icon: Icons.add_photo_alternate_outlined,
                onPressed: () => context.go('/finance/accounts'),
              ),
            UiButton.secondary(
              'Refresh',
              icon: Icons.refresh_rounded,
              onPressed: () => ref.invalidate(_depositSlipsProvider),
            ),
          ],
        ),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 11, child: list),
              const SizedBox(width: 14),
              Expanded(
                flex: 9,
                child: selected == null
                    ? const UiCard(
                        child: UiEmptyState(
                          icon: Icons.touch_app_outlined,
                          title: 'Select a slip',
                          message:
                              'Pick a deposit slip on the left to preview the evidence and decide it.',
                        ),
                      )
                    : _SlipPanel(
                        key: ValueKey(selected.id),
                        slip: selected,
                        canDecide: canDecide,
                        onDecided: () => ref.invalidate(_depositSlipsProvider),
                      ),
              ),
            ],
          )
        else
          list,
      ],
    );
  }
}

/// Preview of one slip plus the Accountant's decision controls.
class _SlipPanel extends ConsumerStatefulWidget {
  final DepositSlipRow slip;
  final bool canDecide;
  final VoidCallback onDecided;

  const _SlipPanel({
    super.key,
    required this.slip,
    required this.canDecide,
    required this.onDecided,
  });

  @override
  ConsumerState<_SlipPanel> createState() => _SlipPanelState();
}

class _SlipPanelState extends ConsumerState<_SlipPanel> {
  final _records = FinanceRecordsRepository();
  final _reason = TextEditingController();
  late Future<String> _signedUrl;
  bool _rejecting = false;
  bool _busy = false;
  String? _error;
  String? _flash;

  static const _presets = [
    'Image too blurry to read the amount',
    'Reference does not match the bank statement',
    'Amount does not match the bank statement',
  ];

  @override
  void initState() {
    super.initState();
    _signedUrl = _loadUrl();
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<String> _loadUrl() {
    final path = widget.slip.storagePath;
    if (path == null || path.isEmpty) {
      return Future.error('No file is attached to this slip.');
    }
    return _records.signedSlipUrl(path);
  }

  bool get _isImage {
    final p = (widget.slip.storagePath ?? '').toLowerCase();
    return p.endsWith('.jpg') ||
        p.endsWith('.jpeg') ||
        p.endsWith('.png') ||
        p.endsWith('.webp');
  }

  Future<void> _decide({required bool approve}) async {
    final reason = _reason.text.trim();
    if (!approve && reason.length < 10) {
      setState(() => _error = 'Write a reason of at least 10 characters.');
      return;
    }
    final userId = ref.read(authProvider).user?.userId;
    if (userId == null) {
      setState(() => _error = 'You are not signed in.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final staffId = await FinanceRepository().getStaffIdForUser(userId);
      await _records.decideDepositSlip(
        slipId: widget.slip.id,
        staffId: staffId,
        approve: approve,
        rejectionReason: reason,
      );
      if (!mounted) return;
      setState(() {
        _flash = approve
            ? 'Slip ${widget.slip.reference} marked as verified.'
            : 'Slip ${widget.slip.reference} rejected.';
        _rejecting = false;
      });
      widget.onDecided();
    } catch (e) {
      if (mounted) {
        setState(() => _error = e is StateError ? e.message : friendlyError(e));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _evidence() {
    return FutureBuilder<String>(
      future: _signedUrl,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 160,
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'The slip file could not be opened: ${friendlyError(snap.error!)}',
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          );
        }
        final url = snap.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 340),
                  color: AppColors.surfaceVariant,
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('The image could not be displayed.'),
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'This slip is a PDF, which cannot be previewed here. Copy the link (valid for 5 minutes) and open it in a browser.',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: UiButton.secondary(
                'Copy temporary link',
                icon: Icons.link,
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: url));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Link copied. It expires in 5 minutes.'),
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.slip;
    final pending = s.status == 'PENDING';
    final balance = widget.canDecide && s.studentId.isNotEmpty
        ? ref.watch(studentAccountProvider(s.studentId))
        : null;
    return Panel(
      title: 'Slip ${s.reference}',
      trailing: StatusPill(_labelFor(s.status), tone: _toneFor(s.status)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_flash != null)
            UiNotice(
              _flash!,
              tone: StatusTone.success,
              icon: Icons.check_circle_outline,
            ),
          const Text(
            'Private evidence. Visible only to the Accountant and oversight roles.',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          _evidence(),
          const SizedBox(height: 12),
          DetailLine('Student', s.studentName),
          DetailLine('Bank', s.bankName),
          DetailLine('Amount', formatMwk(s.amount)),
          DetailLine('Deposit date', formatUiDate(s.depositDate)),
          DetailLine('Submitted', formatUiDate(s.createdAt)),
          DetailLine('Linked to a payment', s.linkedToPayment ? 'Yes' : 'No'),
          if (balance != null)
            balance.when(
              data: (a) => DetailLine('Account balance', formatMwk(a.balance)),
              loading: () => const DetailLine('Account balance', 'Loading…'),
              error: (_, _) =>
                  const DetailLine('Account balance', 'Unavailable'),
            ),
          if (!pending) ...[
            DetailLine('Decided', formatUiDate(s.verifiedAt)),
            if (s.rejectionReason != null)
              DetailLine('Rejection reason', s.rejectionReason!),
          ],
          if (pending && widget.canDecide) ...[
            const SizedBox(height: 12),
            if (_rejecting) ...[
              UiField(
                label: 'Reason for rejection (required)',
                child: TextField(
                  controller: _reason,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText:
                        'e.g. The reference does not match the bank statement',
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in _presets)
                    FilterChipBox(
                      p,
                      onTap: () => setState(() => _reason.text = p),
                    ),
                ],
              ),
            ] else
              const Text(
                'Approving marks the slip verified. It does not post a payment: record the payment from the student account.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            if (_error != null) UiNotice(_error!, icon: Icons.error_outline),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (_rejecting) ...[
                  UiButton.secondary(
                    'Cancel',
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _rejecting = false;
                            _error = null;
                          }),
                  ),
                  UiButton(
                    _busy ? 'Saving…' : 'Reject slip',
                    icon: Icons.close_rounded,
                    onPressed: _busy ? null : () => _decide(approve: false),
                  ),
                ] else ...[
                  UiButton.secondary(
                    'Reject with reason',
                    icon: Icons.close_rounded,
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                            _rejecting = true;
                            _error = null;
                          }),
                  ),
                  UiButton(
                    _busy ? 'Saving…' : 'Approve',
                    icon: Icons.check,
                    onPressed: _busy ? null : () => _decide(approve: true),
                  ),
                ],
              ],
            ),
          ] else if (pending) ...[
            const SizedBox(height: 12),
            const Text(
              'Only the Accountant can approve or reject a slip.',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (widget.canDecide && s.studentId.isNotEmpty) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: UiButton.secondary(
                'Open student account',
                icon: Icons.account_box_outlined,
                onPressed: () => context.go(
                  '/finance/students/${s.studentId}/account?name=${Uri.encodeComponent(s.studentName)}',
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
