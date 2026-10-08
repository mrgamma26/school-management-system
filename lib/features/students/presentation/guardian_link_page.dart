import 'package:flutter/material.dart';
import '../../../../core/errors/app_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/student_repository.dart';
import '../../users/data/repositories/user_repository.dart';
import '../../users/domain/models/guardian.dart';
import '../../authentication/presentation/providers/auth_provider.dart';
import '../../../core/services/audit_service.dart';
import '../../../widgets/skeleton_loader.dart';

/// Manages the guardian links for one student.
class GuardianLinkPage extends ConsumerStatefulWidget {
  final String studentId;
  const GuardianLinkPage({required this.studentId, super.key});

  @override
  ConsumerState<GuardianLinkPage> createState() => _GuardianLinkPageState();
}

class _GuardianLinkPageState extends ConsumerState<GuardianLinkPage> {
  final _studentRepo = StudentRepository();
  final _userRepo = UserRepository();

  List<Map<String, dynamic>> _links = [];
  List<Guardian> _allGuardians = [];
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
      final results = await Future.wait([
        _studentRepo.getLinkedGuardians(widget.studentId),
        _userRepo.listGuardians(),
      ]);
      if (mounted) {
        setState(() {
          _links = results[0] as List<Map<String, dynamic>>;
          _allGuardians = results[1] as List<Guardian>;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _linkGuardian() async {
    final linkedIds = _links.map((l) => l['guardianid'] as String).toSet();
    final available = _allGuardians
        .where((g) => !linkedIds.contains(g.guardianId))
        .toList();

    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All guardians are already linked.')),
      );
      return;
    }

    Guardian? selected;
    String relationship = 'Parent';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('Link Guardian'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Guardian>(
                decoration: const InputDecoration(labelText: 'Guardian'),
                items: available
                    .map(
                      (g) =>
                          DropdownMenuItem(value: g, child: Text(g.fullName)),
                    )
                    .toList(),
                onChanged: (v) => setS(() => selected = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: relationship,
                decoration: const InputDecoration(labelText: 'Relationship'),
                onChanged: (v) => relationship = v,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selected == null
                  ? null
                  : () => Navigator.pop(ctx, selected),
              child: const Text('Link'),
            ),
          ],
        ),
      ),
    );

    if (selected == null) return;
    try {
      await _studentRepo.linkGuardian(
        studentId: widget.studentId,
        guardianId: selected!.guardianId,
        relationship: relationship,
      );
      final user = ref.read(authProvider).user!;
      await AuditService().log(
        userId: user.userId,
        action: 'GUARDIAN_LINKED',
        tableName: 'studentguardian',
        recordId: widget.studentId,
        actorRole: user.roleName,
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _unlink(String guardianId, String guardianName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Link'),
        content: Text('Remove the link to $guardianName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _studentRepo.unlinkGuardian(
        studentId: widget.studentId,
        guardianId: guardianId,
      );
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guardian Links')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _linkGuardian,
        icon: const Icon(Icons.add),
        label: const Text('Link Guardian'),
      ),
      body: _loading
          ? const SkeletonListLoader(itemCount: 3, itemHeight: 88)
          : _error != null
          ? Center(child: Text(_error!))
          : _links.isEmpty
          ? const Center(child: Text('No guardians linked yet.'))
          : ListView.builder(
              itemCount: _links.length,
              itemBuilder: (_, i) {
                final link = _links[i];
                final g = link['guardian'] as Map<String, dynamic>;
                final name = '${g['firstname']} ${g['lastname']}';
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(name),
                  subtitle: Text(link['relationship'] as String? ?? ''),
                  trailing: IconButton(
                    icon: const Icon(Icons.link_off, color: Colors.red),
                    tooltip: 'Remove link',
                    onPressed: () =>
                        _unlink(link['guardianid'] as String, name),
                  ),
                );
              },
            ),
    );
  }
}
