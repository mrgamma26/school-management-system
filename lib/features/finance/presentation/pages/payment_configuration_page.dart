import 'package:flutter/material.dart';

import '../../../../widgets/ui_kit.dart';
import '../../data/finance_repository.dart';
import '../../domain/models/payment_channel.dart';

/// Payment configuration: the receiving accounts, terminals and wallets that
/// accountants can select when recording payments.
class PaymentConfigurationPage extends StatefulWidget {
  const PaymentConfigurationPage({super.key});

  @override
  State<PaymentConfigurationPage> createState() =>
      _PaymentConfigurationPageState();
}

class _PaymentConfigurationPageState extends State<PaymentConfigurationPage> {
  final _repo = FinanceRepository();
  List<PaymentChannel> _channels = const [];
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
      final rows = await _repo.listPaymentChannels();
      if (mounted) setState(() => _channels = rows);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not load payment configuration. Apply migration 0042, then refresh.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([PaymentChannel? existing]) async {
    final key = GlobalKey<FormState>();
    var type = existing?.channelType ?? 'BANK_TRANSFER';
    var mobileProvider = existing?.channelType == 'MOBILE_MONEY'
        ? existing!.providerName
        : 'Airtel Money';
    final name = TextEditingController(text: existing?.displayName);
    final provider = TextEditingController(text: existing?.providerName);
    final identifier = TextEditingController(text: existing?.maskedIdentifier);
    final currency = TextEditingController(text: existing?.currency ?? 'MWK');
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            existing == null
                ? 'Add Receiving Channel'
                : 'Edit Receiving Channel',
          ),
          content: SizedBox(
            width: 460,
            child: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: type,
                      decoration: const InputDecoration(
                        labelText: 'Channel Type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'BANK_TRANSFER',
                          child: Text('Bank Account'),
                        ),
                        DropdownMenuItem(
                          value: 'CARD',
                          child: Text('Card / POS'),
                        ),
                        DropdownMenuItem(
                          value: 'MOBILE_MONEY',
                          child: Text('Mobile Money'),
                        ),
                      ],
                      onChanged: existing == null
                          ? (v) => setDialogState(() => type = v!)
                          : null,
                    ),
                    const SizedBox(height: 12),
                    _input(name, 'Display Label', 'e.g. Main Fees Account'),
                    if (type == 'MOBILE_MONEY')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          initialValue:
                              const {
                                'Airtel Money',
                                'TNM Mpamba',
                              }.contains(mobileProvider)
                              ? mobileProvider
                              : 'Airtel Money',
                          decoration: const InputDecoration(
                            labelText: 'Mobile Provider',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Airtel Money',
                              child: Text('Airtel Money'),
                            ),
                            DropdownMenuItem(
                              value: 'TNM Mpamba',
                              child: Text('TNM Mpamba'),
                            ),
                          ],
                          onChanged: (value) =>
                              setDialogState(() => mobileProvider = value!),
                        ),
                      )
                    else
                      _input(
                        provider,
                        type == 'BANK_TRANSFER'
                            ? 'Bank Name'
                            : 'Gateway / POS Provider',
                        null,
                      ),
                    _input(
                      identifier,
                      type == 'BANK_TRANSFER'
                          ? 'Masked Account Number'
                          : type == 'CARD'
                          ? 'Terminal / Merchant ID'
                          : 'Masked Till / Wallet Number',
                      'Do not enter secrets or PINs',
                    ),
                    _input(currency, 'Currency', null, maxLength: 3),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!key.currentState!.validate()) return;
                await _repo.savePaymentChannel(
                  channelId: existing?.channelId,
                  channelType: type,
                  displayName: name.text,
                  providerName: type == 'MOBILE_MONEY'
                      ? mobileProvider
                      : provider.text,
                  maskedIdentifier: identifier.text,
                  currency: currency.text,
                );
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    name.dispose();
    provider.dispose();
    identifier.dispose();
    currency.dispose();
    if (saved == true) await _load();
  }

  static Widget _input(
    TextEditingController controller,
    String label,
    String? hint, {
    int? maxLength,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLength: maxLength,
      decoration: InputDecoration(labelText: label, hintText: hint),
      validator: (v) =>
          v == null || v.trim().isEmpty ? '$label is required.' : null,
    ),
  );

  String _groupTitle(String type) => switch (type) {
    'BANK_TRANSFER' => 'Bank Accounts',
    'CARD' => 'Card & POS Channels',
    _ => 'Mobile Money Wallets',
  };

  IconData _groupIcon(String type) => switch (type) {
    'BANK_TRANSFER' => Icons.account_balance_outlined,
    'CARD' => Icons.credit_card_outlined,
    _ => Icons.phone_android_outlined,
  };

  @override
  Widget build(BuildContext context) => UiPage(
    children: [
      PageHead(
        kicker: 'Finance',
        title: 'Payment Configuration',
        subtitle:
            'Configure the accounts and terminals accountants can select when recording payments. Only masked identifiers are stored.',
        actions: [
          UiButton.secondary(
            'Refresh',
            icon: Icons.refresh_rounded,
            onPressed: _load,
          ),
          UiButton('Add Channel', icon: Icons.add_rounded, onPressed: _edit),
        ],
      ),
      if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_error != null)
        UiNotice(_error!, icon: Icons.error_outline)
      else
        for (final type in const ['BANK_TRANSFER', 'CARD', 'MOBILE_MONEY'])
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Panel(
              title: _groupTitle(type),
              trailing: Icon(
                _groupIcon(type),
                size: 20,
                color: const Color(0xFF64758B),
              ),
              child: _channels.where((c) => c.channelType == type).isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'No channels configured yet.',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64758B),
                        ),
                      ),
                    )
                  : QueueList(
                      items: [
                        for (final channel in _channels.where(
                          (c) => c.channelType == type,
                        ))
                          QueueItem(
                            icon: channel.isActive
                                ? Icons.check_circle_rounded
                                : Icons.pause_circle_outline_rounded,
                            title: channel.displayName,
                            subtitle:
                                '${channel.providerName} · ${channel.maskedIdentifier} · ${channel.currency}',
                            pill: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Edit',
                                  onPressed: () => _edit(channel),
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 19,
                                  ),
                                ),
                                Switch(
                                  value: channel.isActive,
                                  onChanged: (active) async {
                                    await _repo.setPaymentChannelActive(
                                      channel.channelId,
                                      active,
                                    );
                                    await _load();
                                  },
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
          ),
    ],
  );
}
