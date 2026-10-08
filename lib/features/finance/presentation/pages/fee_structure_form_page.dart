import 'package:flutter/material.dart';
import '../../../../core/errors/app_exception.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/finance_repository.dart';
import '../../domain/models/fee_structure.dart';
import '../../../academics/data/academic_repository.dart';
import '../../../academics/domain/models/academic_year.dart';

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

  List<AcademicYear> _academicYears = [];
  String? _selectedAcademicYearId;
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
    _selectedAcademicYearId = e?.academicYearId;
    _loadAcademicYears();
  }

  @override
  void dispose() {
    _feeTypeCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAcademicYears() async {
    try {
      final years = await _academicRepo.listAcademicYears();
      if (mounted) setState(() => _academicYears = years);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = 'Failed to load academic years. Please try again.',
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedAcademicYearId == null) {
      setState(() => _error = 'Please select an academic year and term.');
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
        await _repo.updateFeeStructure(
          FeeStructure(
            feeStructureId: widget.existing!.feeStructureId,
            academicYearId: _selectedAcademicYearId!,
            feeType: _feeTypeCtrl.text.trim(),
            amount: amount,
          ),
        );
      } else {
        await _repo.createFeeStructure(
          FeeStructure(
            feeStructureId: '',
            academicYearId: _selectedAcademicYearId!,
            feeType: _feeTypeCtrl.text.trim(),
            amount: amount,
          ),
        );
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
      appBar: AppBar(title: Text(_isEdit ? 'Edit Fee' : 'Add Fee Structure')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_academicYears.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedAcademicYearId,
                    decoration: const InputDecoration(
                      labelText: 'Academic Year and Term',
                    ),
                    items: _academicYears
                        .map(
                          (year) => DropdownMenuItem(
                            value: year.id,
                            child: Text(
                              '${formatAcademicYear(year.year)} · ${year.term}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _selectedAcademicYearId = v),
                    validator: (v) => v == null
                        ? 'Please select an academic year and term.'
                        : null,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: _feeTypeCtrl,
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
