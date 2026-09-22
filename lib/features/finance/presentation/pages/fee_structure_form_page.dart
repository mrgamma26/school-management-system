import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/finance_repository.dart';
import '../../domain/models/fee_structure.dart';
import '../../../academics/data/academic_repository.dart';
import '../../../academics/domain/models/class_model.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/widgets/app_widgets.dart';

/// Create or edit a fee structure entry.
class FeeStructureFormPage extends ConsumerStatefulWidget {
  final String academicYearId;
  final FeeStructure? existing;

  const FeeStructureFormPage({
    required this.academicYearId,
    this.existing,
    super.key,
  });

  @override
  ConsumerState<FeeStructureFormPage> createState() =>
      _FeeStructureFormPageState();
}

class _FeeStructureFormPageState extends ConsumerState<FeeStructureFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repo = FinanceRepository();
  final _academicRepo = AcademicRepository();

  late final TextEditingController _feeTypeCtrl;
  late final TextEditingController _amountCtrl;

  List<ClassModel> _classes = [];
  String? _selectedClassId;
  bool _loading = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _feeTypeCtrl = TextEditingController(text: e?.feeType ?? '');
    _amountCtrl = TextEditingController(
      text: e != null ? e.amount.toStringAsFixed(2) : '',
    );
    _selectedClassId = e?.classId;
    _loadClasses();
  }

  @override
  void dispose() {
    _feeTypeCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadClasses() async {
    try {
      final classes = await _academicRepo.listClasses();
      if (mounted) setState(() => _classes = classes);
    } catch (_) {}
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedClassId == null && !_isEdit) {
      setState(() => _error = 'Please select a class.');
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount < 0) {
      setState(() => _error = 'Enter a valid positive amount.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await _repo.updateFeeStructure(widget.existing!.feeStructureId, amount);
      } else {
        await _repo.createFeeStructure(
          FeeStructure(
            feeStructureId: '',
            classId: _selectedClassId!,
            academicYearId: widget.academicYearId,
            feeType: _feeTypeCtrl.text.trim(),
            amount: amount,
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
        title: Text(_isEdit ? 'Edit Fee' : 'Add Fee Structure'),
        actions: [HomeButton(roleName: role)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (!_isEdit && _classes.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    value: _selectedClassId,
                    decoration: const InputDecoration(labelText: 'Class'),
                    items: _classes
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.classId,
                            child: Text(c.className),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _selectedClassId = v),
                    validator: (v) =>
                        v == null ? 'Please select a class.' : null,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _feeTypeCtrl,
                  enabled: !_isEdit,
                  decoration: const InputDecoration(labelText: 'Fee Type'),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Fee type is required.'
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Amount (MWK)'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Amount is required.';
                    }
                    final n = double.tryParse(v.trim());
                    if (n == null || n < 0) {
                      return 'Enter a valid positive amount.';
                    }
                    return null;
                  },
                ),
              ),
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
                      : Text(_isEdit ? 'Save Changes' : 'Create Fee'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
