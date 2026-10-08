class PaymentChannel {
  final String channelId;
  final String channelType;
  final String displayName;
  final String providerName;
  final String maskedIdentifier;
  final String currency;
  final bool isActive;

  const PaymentChannel({
    required this.channelId,
    required this.channelType,
    required this.displayName,
    required this.providerName,
    required this.maskedIdentifier,
    required this.currency,
    required this.isActive,
  });

  factory PaymentChannel.fromJson(Map<String, dynamic> json) => PaymentChannel(
    channelId: json['channelid'] as String,
    channelType: json['channeltype'] as String,
    displayName: json['displayname'] as String,
    providerName: json['providername'] as String,
    maskedIdentifier: json['maskedidentifier'] as String,
    currency: (json['currency'] as String?) ?? 'MWK',
    isActive: (json['isactive'] as bool?) ?? true,
  );

  String get safeLabel => '$displayName · $providerName · $maskedIdentifier';
}
