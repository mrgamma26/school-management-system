import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/finance_repository.dart';
import '../../domain/models/payment.dart';
import '../../domain/models/fee_structure.dart';
import '../../../academics/data/academic_repository.dart';
import '../../../academics/domain/models/academic_year.dart';
import '../../../authentication/presentation/providers/auth_provider.dart';
import '../../../../core/services/audit_service.dart';
import '../../../../core/widgets/app_widgets.dart';

/// Records a new fee payment for one student.
class RecordPaymentPage extends ConsumerStatefulWidget {
  final String studentId;
  final String studentName;

  const RecordPaymentPage({
    required this.studentId,
    required this.studentName,
    super.key,
  });

  @override
  ConsumerState<RecordPaymentPage> createState() => _RecordPaymentPageState();
}

class _RecordPaymentPageState extends ConsumerState<RecordPaymentPage> {
  final _formKey = GlobalKey<FormState>();
  final _financeRepo = FinanceRepository();
  final _academicRepo = AcademicRepository();

  final _amountCtrl = TextEditingController();
  final _refCtrl = TextEditingController();
  final _receiptCtrl = TextEditingController();

  List<AcademicYear> _years = [];
  List<FeeStructure> _feeStructures = [];
  AcademicYear? _selectedYear;
  FeeStructure? _selectedFee;
  String _method = 'CASH';
  DateTime _paymentDate = DateTime.now();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadYears();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _refCtrl.dispose();
    _receiptCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadYears() async {
    try {
      final years = await _academicRepo.listAcademicYears();
      if (mounted) setState(() => _years = years);
    } catch (_) {}
  }

  Future<void> _onYearChanged(AcademicYear? year) async {
    if (year == null) return;
    setState(() {
      _selectedYear = year;
      _selectedFee = null;
      _feeStructures = [];
    });
    try {
      final fees = await _financeRepo.listFeeStructures(year.id);
      if (mounted) setState(() => _feeStructures = fees);
    } catch (_) {}
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _paymentDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedFee == null) {
      setState(() => _error = 'Please select a fee type.');
      return;
    }

    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid positive amount.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final currentUser = ref.read(authProvider).user!;

      // Fetch the staff record for the current user
      final staffId = await _financeRepo.getStaffIdForUser(currentUser.userId);

      final paymentId = await _financeRepo.recordPayment(
        studentId: widget.studentId,
        feeStructureId: _selectedFee!.feeStructureId,
        staffId: staffId,
        amount: amount,
        paymentDate: _paymentDate,
        method: _method,
        referenceNumber: _refCtrl.text.trim().isEmpty
            ? null
            : _refCtrl.text.trim(),
        receiptNumber: _receiptCtrl.text.trim().isEmpty
            ? null
            : _receiptCtrl.text.trim(),
      );

      await AuditService().log(
        userId: currentUser.userId,
        action: 'PAYMENT_RECORDED',
        tableName: 'payment',
        recordId: paymentId,
        newValue: {
          'studentid': widget.studentId,
          'amount': amount,
          'method': _method,
          'feestructureid': _selectedFee!.feeStructureId,
        },
        actorRole: currentUser.roleName,
      );

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
        title: Text('Record Payment\n${widget.studentName}'),
        actions: [HomeButton(roleName: role)],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Academic year picker
              if (_years.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber,
                          color: Colors.orange.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'No academic years found. Ask your administrator to '
                            'create an academic year before recording payments.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<AcademicYear>(
                    value: _selectedYear,
                    decoration: const InputDecoration(
                      labelText: 'Academic Year',
                    ),
                    items: _years
                        .map(
                          (y) =>
                              DropdownMenuItem(value: y, child: Text(y.label)),
                        )
                        .toList(),
                    onChanged: _onYearChanged,
                    validator: (v) =>
                        v == null ? 'Select an academic year.' : null,
                  ),
                ),

              // Fee type picker
              if (_selectedYear != null && _feeStructures.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue.shade700,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Text(
                            'No fee structures for this year yet. Set them up '
                            'under Finance → Fee Structures first.',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (_feeStructures.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: DropdownButtonFormField<FeeStructure>(
                    value: _selectedFee,
                    decoration: const InputDecoration(labelText: 'Fee Type'),
                    items: _feeStructures
                        .map(
                          (f) => DropdownMenuItem(
                            value: f,
                            child: Text(
                              '${f.feeType} — MWK ${f.amount.toStringAsFixed(2)}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedFee = v;
                        if (v != null) {
                          _amountCtrl.text = v.amount.toStringAsFixed(2);
                        }
                      });
                    },
                    validator: (v) => v == null ? 'Select a fee type.' : null,
                  ),
                ),

              // Amount
              _field(
                _amountCtrl,
                'Amount (MWK)',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),

              // Method
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DropdownButtonFormField<String>(
                  value: _method,
                  decoration: const InputDecoration(
                    labelText: 'Payment Method',
                  ),
                  items: kPaymentMethods
                      .map(
                        (m) => DropdownMenuItem(
                          value: m,
                          child: Text(m.replaceAll('_', ' ')),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _method = v!),
                ),
              ),

              // Payment date
              GestureDetector(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Payment Date',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(_paymentDate.toIso8601String().substring(0, 10)),
                ),
              ),
              const SizedBox(height: 12),

              _field(_refCtrl, 'Reference Number', required: false),
              _field(_receiptCtrl, 'Receipt Number', required: false),

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
                      : const Text('Record Payment'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = true,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label),
        validator: required
            ? (v) =>
                  (v == null || v.trim().isEmpty) ? '$label is required.' : null
            : null,
      ),
    );
  }
}
