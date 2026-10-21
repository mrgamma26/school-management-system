import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../widgets/ui_kit.dart';
import '../../../academics/data/academic_repository.dart';
import '../../../academics/domain/models/academic_year.dart';
import '../../data/finance_repository.dart';
import '../../domain/models/fee_structure.dart';
import '../../domain/models/payment.dart';
import '../../domain/models/payment_channel.dart';

const int maxDepositSlipBytes = 5 * 1024 * 1024;

bool isDepositSlipSizeAllowed(int bytes) =>
    bytes > 0 && bytes <= maxDepositSlipBytes;

String? depositSlipMimeTypeForName(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  return switch (extension) {
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'pdf' => 'application/pdf',
    _ => null,
  };
}

/// A validated payment, ready for [FinanceRepository.recordPayment].
class PaymentRequest {
  final FeeStructure fee;
  final double amount;
  final DateTime paymentDate;
  final String method;
  final String? referenceNumber;
  final String? channelId;
  final double processingFee;
  final Map<String, dynamic> transactionDetails;
  final Uint8List? depositSlipBytes;
  final String? depositSlipName;

  const PaymentRequest({
    required this.fee,
    required this.amount,
    required this.paymentDate,
    required this.method,
    required this.referenceNumber,
    required this.channelId,
    required this.processingFee,
    required this.transactionDetails,
    this.depositSlipBytes,
    this.depositSlipName,
  });
}

/// What the form currently holds, for live summaries and previews.
class PaymentFormSnapshot {
  final FeeStructure? fee;
  final double? amount;
  final String method;
  final DateTime date;

  const PaymentFormSnapshot({
    required this.fee,
    required this.amount,
    required this.method,
    required this.date,
  });
}

/// The payment-capture fields shared by the standalone Record Payment page and
/// the in-place form in the Student Account workspace.
///
/// With [fees] set the fee picker offers only those obligations (workspace
/// mode). With [fees] null it first asks for the academic period and lists the
/// fees of that period (standalone mode). Parents call [PaymentFormFieldsState.validate]
/// to obtain a [PaymentRequest]; posting stays with the parent.
class PaymentFormFields extends StatefulWidget {
  final List<FeeStructure>? fees;
  final FeeStructure? initialFee;

  /// Extra text under a fee in the picker (e.g. what is still owed).
  final String Function(FeeStructure fee)? feeLabel;
  final ValueChanged<PaymentFormSnapshot>? onChanged;

  const PaymentFormFields({
    super.key,
    this.fees,
    this.initialFee,
    this.feeLabel,
    this.onChanged,
  });

  @override
  State<PaymentFormFields> createState() => PaymentFormFieldsState();
}

class PaymentFormFieldsState extends State<PaymentFormFields> {
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
  Uint8List? _depositSlipBytes;
  String? _depositSlipName;
  List<AcademicYear> _years = const [];
  List<FeeStructure> _periodFees = const [];
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
  String? _error;

  bool get _fixedFees => widget.fees != null;
  List<FeeStructure> get _selectableFees =>
      _fixedFees ? widget.fees! : _periodFees;

  @override
  void initState() {
    super.initState();
    if (_fixedFees) {
      _fee = widget.initialFee;
      if (_fee != null) _amount.text = _fee!.amount.toStringAsFixed(2);
    } else {
      _loadYears();
    }
    _amount.addListener(_notify);
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  @override
  void dispose() {
    _amount.removeListener(_notify);
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

  void _notify() {
    if (!mounted) return;
    setState(() {});
    widget.onChanged?.call(
      PaymentFormSnapshot(
        fee: _fee,
        amount: double.tryParse(_amount.text.trim()),
        method: _method,
        date: _paymentDate,
      ),
    );
  }

  /// Sets the amount (used by parents, e.g. to pre-fill what is still owed).
  void setAmount(double value) => _amount.text = value.toStringAsFixed(2);

  /// Clears the typed reference and amount after a successful post.
  void reset() {
    _amount.clear();
    _reference.clear();
    _chequeNumber.clear();
    _depositSlip.clear();
    _lastFour.clear();
    _approvalCode.clear();
    _senderPhone.clear();
    _description.clear();
    _depositSlipBytes = null;
    _depositSlipName = null;
    _payerBank.clear();
    _draweeBank.clear();
    setState(() => _error = null);
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
      _periodFees = const [];
    });
    try {
      final all = await _financeRepo.listFeeStructures();
      if (mounted) {
        setState(
          () => _periodFees = all
              .where((f) => f.academicYearId == year.id)
              .toList(),
        );
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to load fee structures.');
    }
    _notify();
  }

  Future<void> _changeMethod(String method) async {
    setState(() {
      _method = method;
      _channel = null;
      _channels = const [];
      _error = null;
    });
    _notify();
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
    'DEPOSIT' => {
      'depositSlipFileName': _depositSlipName,
      'depositBankName': _payerBank.text.trim(),
    },
    _ => <String, dynamic>{},
  };

  /// Validates every visible field and returns the payment to post, or null
  /// (the reason is shown on the form).
  PaymentRequest? validate() {
    if (!_formKey.currentState!.validate()) return null;
    if (_fee == null) {
      setState(() => _error = 'Select a fee type.');
      return null;
    }
    if (const {'BANK_TRANSFER', 'CARD', 'MOBILE_MONEY'}.contains(_method) &&
        _channel == null) {
      setState(() => _error = 'Select a configured receiving channel.');
      return null;
    }
    final amount = double.tryParse(_amount.text.trim());
    final processingFee = double.tryParse(_processingFee.text.trim()) ?? 0;
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid positive amount.');
      return null;
    }
    if (_method == 'DEPOSIT' && _depositSlipBytes == null) {
      setState(() => _error = 'Attach the bank deposit slip image or PDF.');
      return null;
    }
    setState(() => _error = null);
    return PaymentRequest(
      fee: _fee!,
      amount: amount,
      paymentDate: _paymentDate,
      method: _method,
      referenceNumber: _method == 'CHEQUE'
          ? _chequeNumber.text.trim()
          : (_reference.text.trim().isEmpty ? null : _reference.text.trim()),
      channelId: _channel?.channelId,
      processingFee: processingFee,
      transactionDetails: _details(),
      depositSlipBytes: _depositSlipBytes,
      depositSlipName: _depositSlipName,
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool required = true,
    TextInputType? keyboard,
    List<TextInputFormatter>? formatters,
    int? maxLength,
  }) => UiField(
    label: label,
    child: TextFormField(
      controller: controller,
      keyboardType: keyboard,
      inputFormatters: formatters,
      maxLength: maxLength,
      validator: required
          ? (v) => v == null || v.trim().isEmpty ? '$label is required.' : null
          : null,
    ),
  );

  Widget _dateField(String label, DateTime value, VoidCallback onTap) =>
      UiField(
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: InputDecorator(
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
            ),
            child: Text(formatUiDate(value)),
          ),
        ),
      );

  Widget _channelPicker(String label) => UiField(
    label: label,
    child: DropdownButtonFormField<PaymentChannel>(
      initialValue: _channel,
      isExpanded: true,
      decoration: InputDecoration(
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

  Widget _enumDropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> changed,
  ) => UiField(
    label: label,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      items: values
          .map(
            (v) =>
                DropdownMenuItem(value: v, child: Text(v.replaceAll('_', ' '))),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) changed(v);
      },
    ),
  );

  /// Fields that depend on the selected payment method.
  List<Widget> _methodFields() {
    switch (_method) {
      case 'BANK_TRANSFER':
        return [
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
        ];
      case 'CHEQUE':
        return [
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
          _enumDropdown('Cheque Status', _chequeStatus, const [
            'PENDING_CLEARANCE',
            'CLEARED',
            'POST_DATED',
            'BOUNCED_RETURNED',
          ], (v) => setState(() => _chequeStatus = v)),
          _field(_depositSlip, 'Bank Deposit Slip Reference', required: false),
        ];
      case 'CARD':
        return [
          _channelPicker('Payment Gateway / POS Terminal'),
          _enumDropdown('Card Network / Scheme', _cardNetwork, const [
            'VISA',
            'MASTERCARD',
            'AMERICAN_EXPRESS',
            'LOCAL_DEBIT',
          ], (v) => setState(() => _cardNetwork = v)),
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
          const FullWidth(
            child: InlineGuide(
              text: 'Never enter a full card number, PIN, or CVV.',
            ),
          ),
        ];
      case 'MOBILE_MONEY':
        return [
          _channelPicker('Receiving Merchant Till / Wallet'),
          _field(_reference, 'Transaction Reference Code / SMS ID'),
          _field(
            _senderPhone,
            "Sender's Registered Mobile Number",
            keyboard: TextInputType.phone,
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
          ),
          UiField(
            label: 'Exact Timestamp',
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: _pickTimestamp,
              child: InputDecorator(
                decoration: const InputDecoration(
                  suffixIcon: Icon(Icons.schedule, size: 18),
                ),
                child: Text(_transactionTimestamp.toString().substring(0, 16)),
              ),
            ),
          ),
        ];
      case 'OTHER':
        return [
          _field(_description, 'Payment Description'),
          _field(_reference, 'External Reference'),
        ];
      case 'DEPOSIT':
        return [
          _field(_payerBank, 'Bank Name'),
          _field(_reference, 'Deposit Reference Number'),
          OutlinedButton.icon(
            onPressed: () async {
              final file = await FilePicker.pickFile(
                type: FileType.custom,
                allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
              );
              if (file == null) return;

              final bytes = await file.readAsBytes();
              if (!mounted) return;
              if (!isDepositSlipSizeAllowed(bytes.length)) {
                setState(
                  () =>
                      _error = 'The deposit slip must be no larger than 5 MB.',
                );
                return;
              }
              if (depositSlipMimeTypeForName(file.name) == null) {
                setState(
                  () => _error =
                      'Use a JPG, PNG, WebP, or PDF deposit slip file.',
                );
                return;
              }
              setState(() {
                _depositSlipBytes = bytes;
                _depositSlipName = file.name;
                _error = null;
              });
            },
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: Text(
              _depositSlipName == null
                  ? 'Add deposit slip image / PDF'
                  : 'Attached: $_depositSlipName',
            ),
          ),
        ];
      default:
        return [
          FullWidth(
            child: _field(
              _reference,
              'Payer Reference / Note',
              required: false,
            ),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final fees = _selectableFees;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldGrid(
            children: [
              if (!_fixedFees)
                UiField(
                  label: 'Academic year, term and form',
                  child: DropdownButtonFormField<AcademicYear>(
                    initialValue: _year,
                    items: _years
                        .map(
                          (y) => DropdownMenuItem(
                            value: y,
                            child: Text(y.selectionLabel),
                          ),
                        )
                        .toList(),
                    onChanged: _changeYear,
                    validator: (v) =>
                        v == null ? 'Select an academic period.' : null,
                  ),
                ),
              UiField(
                label: 'Fee type',
                child: DropdownButtonFormField<FeeStructure>(
                  initialValue: _fee,
                  isExpanded: true,
                  decoration: InputDecoration(
                    helperText: _fixedFees
                        ? (fees.isEmpty
                              ? 'No fees apply to this student.'
                              : null)
                        : (_year != null && fees.isEmpty
                              ? 'No fees configured for this period.'
                              : null),
                  ),
                  items: fees
                      .map(
                        (f) => DropdownMenuItem(
                          value: f,
                          child: Text(
                            widget.feeLabel?.call(f) ??
                                '${f.feeType} — ${formatMwk(f.amount)}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) {
                    _fee = v;
                    if (v != null) _amount.text = v.amount.toStringAsFixed(2);
                    _notify();
                  },
                  validator: (v) => v == null ? 'Select a fee type.' : null,
                ),
              ),
              _field(
                _amount,
                'Amount (MWK)',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
              ),
              UiField(
                label: 'Payment method',
                child: DropdownButtonFormField<String>(
                  initialValue: _method,
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
              ),
              _dateField('Payment date', _paymentDate, () async {
                final v = await _pickDate(_paymentDate, future: false);
                if (v != null) {
                  _paymentDate = v;
                  _notify();
                }
              }),
              ..._methodFields(),
            ],
          ),
          if (_error != null) UiNotice(_error!, icon: Icons.error_outline),
        ],
      ),
    );
  }
}
