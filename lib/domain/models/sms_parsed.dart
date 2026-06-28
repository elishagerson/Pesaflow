class SmsParsed {
  final int amount;
  final String type;
  final String senderOrRecipient;
  final String reference;
  final String provider;
  final int? balanceAfter;
  final DateTime timestamp;
  final String rawSmsBody;

  const SmsParsed({
    required this.amount,
    required this.type,
    required this.senderOrRecipient,
    required this.reference,
    required this.provider,
    this.balanceAfter,
    required this.timestamp,
    required this.rawSmsBody,
  });

  @override
  String toString() {
    return 'SmsParsed(amount: $amount, type: $type, senderOrRecipient: $senderOrRecipient, reference: $reference, provider: $provider, balanceAfter: $balanceAfter, timestamp: $timestamp)';
  }
}
