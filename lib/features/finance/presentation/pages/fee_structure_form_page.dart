import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../widgets/ui_kit.dart';
import '../../../academics/data/academic_repository.dart';
import '../../../academics/domain/models/academic_year.dart';
import '../../data/finance_repository.dart';
import '../../domain/models/fee_structure.dart';
import '../../../../core/navigation/close_form.dart';

/// Screen 38 - Create or edit a fee structure entry.
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
      if (mounted) closeForm(context, '/finance/fees', true);
    } catch (e) {
      setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormPageLayout(
      kicker: 'Finance',
      title: _isEdit ? 'Edit Fee' : 'Create Fee Structure',
      subtitle: 'Define fee items and amounts with a clear academic period.',
      formTitle: 'Fee details',
      saving: _loading,
      saveLabel: _isEdit ? 'Save Changes' : 'Create Fee',
      onSave: _submit,
      error: _error,
      guideTitle: 'Reminder:',
      guide:
          'Amounts must be positive. Existing payments keep the amount they were recorded against.',
      side: const [
        CheckRow(label: 'Amount is a positive value in MWK', checked: true),
        CheckRow(label: 'One fee item per academic period', checked: true),
        CheckRow(label: 'Changes are audited', checked: true),
      ],
      form: Form(
        key: _formKey,
        child: FieldGrid(
          children: [
            if (_academicYears.isNotEmpty)
              FullWidth(
                child: UiField(
                  label: 'Academic year, term and form',
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedAcademicYearId,
                    items: _academicYears
                        .map(
                          (year) => DropdownMenuItem(
                            value: year.id,
                            child: Text(year.selectionLabel),
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
              ),
            UiField(
              label: 'Fee type',
              child: TextFormField(
                controller: _feeTypeCtrl,
                decoration: const InputDecoration(hintText: 'e.g. Tuition'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Fee type is required.'
                    : null,
              ),
            ),
            UiField(
              label: 'Amount (MWK)',
              child: TextFormField(
                controller: _amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(hintText: '0.00'),
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
          ],
        ),
      ),
    );
  }
}
