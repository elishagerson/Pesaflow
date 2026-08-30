import 'package:pesaflow/domain/sms/provider_matcher.dart';
import 'package:pesaflow/domain/sms/parsers/mixx_parser.dart';

void main() {
  final text = "Txn Amt TSh 40,000 sent to Yas PostPaid (100100). Wait for confirmation. Ref: 0675259341. New Bal: TSh 1,099. Total Charges TSh 0.(Fees TSh 0, Levy TSh 0), VAT TSh 0. TxnID: 26395682971003. 30/08/26 10:33";
  final parsed = MixxParser().parse(text, DateTime.now());
  if (parsed != null) {
    // ignore: avoid_print
    print('amount=${parsed.amount}, type=${parsed.type}, recipient=${parsed.senderOrRecipient}, ref=${parsed.reference}, balance=${parsed.balanceAfter}');
  } else {
    // ignore: avoid_print
    print('NOT PARSED');
  }
}
