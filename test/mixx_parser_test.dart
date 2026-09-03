import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/domain/sms/provider_matcher.dart';
import 'package:pesaflow/domain/sms/parsers/mixx_parser.dart';

void main() {
  test('Mixx parser payment successful to sporty bet', () {
    final text =
        "Payment Successful to Sporty Bet PUSH, Amount TSh 25,000. New Balance TSh 370. Charges TSh 500. VAT TSh 76. TxnID: 26607196230775.26/08/26 19:12.";
    final provider = ProviderMatcher.matchProvider('Mixx BY Yas', body: text);
    // ignore: avoid_print
    print('Provider: $provider');
    expect(provider, 'TigoPesa_TZ');

    final parsed = MixxParser().parse(text, DateTime.now());
    expect(parsed, isNotNull);
    // ignore: avoid_print
    print(
      'Parsed: amount=${parsed?.amount}, type=${parsed?.type}, recipient=${parsed?.senderOrRecipient}, fee=${parsed?.feeAmount}, ref=${parsed?.reference}, bal=${parsed?.balanceAfter}',
    );
  });
}
