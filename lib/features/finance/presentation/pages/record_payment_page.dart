import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/errors/app_exception.dart';
import '../../data/finance_repository.dart';
import '../../domain/models/payment.dart';
import '../../domain/models/payment_channel.dart';
import '../../domain/models/fee_structure.dart';
import '../../../academics/data/academic_repository.dart';
import '../../../academics/domain/models/academic_year.dart';

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
  final _amount = TextEditingController();
  final _reference = TextEditingController();
  final _processingFee = TextEditingController(text: '0');
  final _payerBank = TextEditingController();
  final _chequeNumber = TextEditingController();
  final _draweeBank = TextEditingController();
  final _depositSlip = TextEditingController();
  final _lastFour = TextEditingController();
  final _approvalCode = TextEditingController();
  final _senderPhone = TextEditingController();
  final _description = TextEditingController();
  List<AcademicYear> _years = const [];
  List<FeeStructure> _fees = const [];
  List<PaymentChannel> _channels = const [];
  AcademicYear? _year;
  FeeStructure? _fee;
  PaymentChannel? _channel;
  String _method = 'CASH';
  String _cardNetwork = 'VISA';
  String _chequeStatus = 'PENDING_CLEARANCE';
  DateTime _paymentDate = DateTime.now();
  DateTime _clearanceDate = DateTime.now();
  DateTime _chequeDate = DateTime.now();
  DateTime _depositDate = DateTime.now();
  DateTime _transactionTimestamp = DateTime.now();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadYears();
  }

  @override
  void dispose() {
    for (final c in [
      _amount,
      _reference,
      _processingFee,
      _payerBank,
      _chequeNumber,
      _draweeBank,
      _depositSlip,
      _lastFour,
      _approvalCode,
      _senderPhone,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadYears() async {
    try {
      final rows = await _academicRepo.listAcademicYears();
      if (mounted) setState(() => _years = rows);
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load academic years.');
    }
  }

  Future<void> _changeYear(AcademicYear? year) async {
    if (year == null) return;
    setState(() {
      _year = year;
      _fee = null;
      _fees = const [];
    });
    try {
      final all = await _financeRepo.listFeeStructures();
      if (mounted) {
        setState(
          () => _fees = all.where((f) => f.academicYearId == year.id).toList(),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load fee structures.');
    }
  }

  Future<void> _changeMethod(String method) async {
    setState(() {
      _method = method;
      _channel = null;
      _channels = const [];
      _error = null;
    });
    if (!const {'BANK_TRANSFER', 'CARD', 'MOBILE_MONEY'}.contains(method)) {
      return;
    }
    try {
      final rows = await _financeRepo.listPaymentChannels(
        type: method,
        activeOnly: true,
      );
      if (mounted) setState(() => _channels = rows);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not load receiving channels. Ask an administrator to configure them.',
        );
      }
    }
  }

  String _date(DateTime value) => value.toIso8601String().substring(0, 10);
  Future<DateTime?> _pickDate(DateTime initial, {bool future = true}) =>
      showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(2020),
        lastDate: future ? DateTime(2035) : DateTime.now(),
      );
  Future<void> _pickTimestamp() async {
    final date = await _pickDate(_transactionTimestamp, future: false);
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_transactionTimestamp),
    );
    if (time != null) {
      setState(
        () => _transactionTimestamp = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  Map<String, dynamic> _details() => switch (_method) {
    'BANK_TRANSFER' => {
      'payerBankName': _payerBank.text.trim(),
      'clearanceDate': _date(_clearanceDate),
    },
    'CHEQUE' => {
      'chequeNumber': _chequeNumber.text.trim(),
      'draweeBankBranch': _draweeBank.text.trim(),
      'chequeDate': _date(_chequeDate),
      'depositDate': _date(_depositDate),
      'chequeStatus': _chequeStatus,
      if (_depositSlip.text.trim().isNotEmpty)
        'depositSlipReference': _depositSlip.text.trim(),
    },
    'CARD' => {
      'cardNetwork': _cardNetwork,
      'lastFourDigits': _lastFour.text.trim(),
      'approvalCode': _approvalCode.text.trim(),
    },
    'MOBILE_MONEY' => {
      'senderPhone': _senderPhone.text.trim(),
      'transactionTimestamp': _transactionTimestamp.toIso8601String(),
    },
    'OTHER' => {'description': _description.text.trim()},
    _ => <String, dynamic>{},
  };

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fee == null) {
      setState(() => _error = 'Select a fee type.');
      return;
    }
    if (const {'BANK_TRANSFER', 'CARD', 'MOBILE_MONEY'}.contains(_method) &&
        _channel == null) {
      setState(() => _error = 'Select a configured receiving channel.');
      return;
    }
    final amount = double.tryParse(_amount.text.trim());
    final processingFee = double.tryParse(_processingFee.text.trim()) ?? 0;
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid positive amount.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _financeRepo.recordPayment(
        studentId: widget.studentId,
        feeStructureId: _fee!.feeStructureId,
        amount: amount,
        paymentDate: _paymentDate,
        method: _method,
        referenceNumber: _method == 'CHEQUE'
            ? _chequeNumber.text.trim()
            : (_reference.text.trim().isEmpty ? null : _reference.text.trim()),
        channelId: _channel?.channelId,
        processingFee: processingFee,
        transactionDetails: _details(),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 42),
          title: const Text('Payment Recorded'),
          content: SelectableText(
            'School receipt: ${result.receiptNumber}\n\nThis payment is now available in account and guardian history.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Done'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: formatters,
      maxLength: maxLength,
      decoration: InputDecoration(labelText: label),
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? '$label is required.' : null
          : null,
    ),
  );
  Widget _dateField(String label, DateTime value, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: onTap,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: const Icon(Icons.calendar_today_outlined),
            ),
            child: Text(_date(value)),
          ),
        ),
      );
  Widget _channelPicker(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: DropdownButtonFormField<PaymentChannel>(
      initialValue: _channel,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        helperText: _channels.isEmpty
            ? 'No active channels. Ask an administrator to configure one.'
            : null,
      ),
      items: _channels
          .map(
            (c) => DropdownMenuItem(
              value: c,
              child: Text(c.safeLabel, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (v) => setState(() => _channel = v),
      validator: (v) => v == null ? 'Select $label.' : null,
    ),
  );

  Widget _methodFields() {
    switch (_method) {
      case 'BANK_TRANSFER':
        return Column(
          children: [
            _channelPicker('Receiving Business Account'),
            _field(_payerBank, "Payer's Bank Name"),
            _field(_reference, 'Transaction Reference / UTR Number'),
            _dateField(
              'Value / Effective Clearance Date',
              _clearanceDate,
              () async {
                final v = await _pickDate(_clearanceDate);
                if (v != null) setState(() => _clearanceDate = v);
              },
            ),
            _field(
              _processingFee,
              'Bank / Intermediary Fees',
              required: false,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        );
      case 'CHEQUE':
        return Column(
          children: [
            _field(
              _chequeNumber,
              '6-Digit Cheque Number',
              keyboard: TextInputType.number,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              maxLength: 6,
            ),
            _field(_draweeBank, 'Drawee Bank & Branch Name'),
            _dateField('Cheque Date', _chequeDate, () async {
              final v = await _pickDate(_chequeDate);
              if (v != null) setState(() => _chequeDate = v);
            }),
            _dateField('Deposit Date', _depositDate, () async {
              final v = await _pickDate(_depositDate);
              if (v != null) setState(() => _depositDate = v);
            }),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: _chequeStatus,
                decoration: const InputDecoration(labelText: 'Cheque Status'),
                items:
                    const [
                          'PENDING_CLEARANCE',
                          'CLEARED',
                          'POST_DATED',
                          'BOUNCED_RETURNED',
                        ]
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(v.replaceAll('_', ' ')),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _chequeStatus = v!),
              ),
            ),
            _field(
              _depositSlip,
              'Bank Deposit Slip Reference',
              required: false,
            ),
          ],
        );
      case 'CARD':
        return Column(
          children: [
            _channelPicker('Payment Gateway / POS Terminal'),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DropdownButtonFormField<String>(
                initialValue: _cardNetwork,
                decoration: const InputDecoration(
                  labelText: 'Card Network / Scheme',
                ),
                items:
                    const [
                          'VISA',
                          'MASTERCARD',
                          'AMERICAN_EXPRESS',
                          'LOCAL_DEBIT',
                        ]
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(v.replaceAll('_', ' ')),
                          ),
                        )
                        .toList(),
                onChanged: (v) => setState(() => _cardNetwork = v!),
              ),
            ),
            _field(
              _lastFour,
              'Last 4 Digits of Card',
              keyboard: TextInputType.number,
              formatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
              maxLength: 4,
            ),
            _field(_approvalCode, 'Authorization / Approval Code'),
            _field(
              _processingFee,
              'MDR / Processing Fee',
              required: false,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Never enter a full card number, PIN, or CVV.'),
                  ),
                ],
              ),
            ),
          ],
        );
      case 'MOBILE_MONEY':
        return Column(
          children: [
            _channelPicker('Receiving Merchant Till / Wallet'),
            _field(_reference, 'Transaction Reference Code / SMS ID'),
            _field(
              _senderPhone,
              "Sender's Registered Mobile Number",
              keyboard: TextInputType.phone,
              formatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: _pickTimestamp,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Exact Timestamp',
                    suffixIcon: Icon(Icons.schedule),
                  ),
                  child: Text(
                    _transactionTimestamp.toString().substring(0, 16),
                  ),
                ),
              ),
            ),
          ],
        );
      case 'OTHER':
        return Column(
          children: [
            _field(_description, 'Payment Description'),
            _field(_reference, 'External Reference'),
          ],
        );
      default:
        return _field(_reference, 'Payer Reference / Note', required: false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Record Payment · ${widget.studentName}')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<AcademicYear>(
                  initialValue: _year,
                  decoration: const InputDecoration(
                    labelText: 'Academic Year / Term',
                  ),
                  items: _years
                      .map(
                        (y) => DropdownMenuItem(value: y, child: Text(y.label)),
                      )
                      .toList(),
                  onChanged: _changeYear,
                  validator: (v) =>
                      v == null ? 'Select an academic period.' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<FeeStructure>(
                  initialValue: _fee,
                  decoration: InputDecoration(
                    labelText: 'Fee Type',
                    helperText: _year != null && _fees.isEmpty
                        ? 'No fees configured for this period.'
                        : null,
                  ),
                  items: _fees
                      .map(
                        (f) => DropdownMenuItem(
                          value: f,
                          child: Text(
                            '${f.feeType} — MWK ${f.amount.toStringAsFixed(2)}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() {
                    _fee = v;
                    if (v != null) _amount.text = v.amount.toStringAsFixed(2);
                  }),
                  validator: (v) => v == null ? 'Select a fee type.' : null,
                ),
                const SizedBox(height: 12),
                _field(
                  _amount,
                  'Amount (MWK)',
                  keyboard: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _method,
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
                  onChanged: (v) {
                    if (v != null) _changeMethod(v);
                  },
                ),
                const SizedBox(height: 12),
                _dateField('Payment Date', _paymentDate, () async {
                  final v = await _pickDate(_paymentDate, future: false);
                  if (v != null) setState(() => _paymentDate = v);
                }),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: KeyedSubtree(
                    key: ValueKey(_method),
                    child: _methodFields(),
                  ),
                ),
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(Icons.receipt_long_outlined),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'A unique school receipt number will be generated automatically.',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: _loading ? null : _submit,
                  icon: _loading
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: const Text('Record Payment'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
