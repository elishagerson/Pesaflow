import 'dart:developer' as developer;
import '../../../data/models/sms_parsed.dart';
import 'amount_helper.dart';
import 'sms_parser_interface.dart';

class AirtelTzParser implements SmsParser {
  String _extractReference(String text) {
    final regex = RegExp(r'(?:Rej|Ref|TxnID):\s*([A-Za-z0-9]+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    return match?.group(1) ?? 'AIRTEL-REF-UNKNOWN';
  }

  int? _extractBalance(String text) {
    final regex = RegExp(
      r'(?:Salio|Balance|Bal):\s*(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)', 
      caseSensitive: false
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      return parseAmount(match.group(1) ?? '');
    }
    return null;
  }

  @override
  SmsParsed? parse(String rawSmsBody, DateTime timestamp) {
    final text = rawSmsBody.trim();

    try {
      // 1. Swahili Received Money (Income)
      // Example: "Umepokea Tsh 45,000.00 kutoka kwa 0712345678. Rej: AT123456. Salio: Tsh 300,000.00"
      final swReceivedRegex = RegExp(
        r'Umepokea\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:kutoka kwa|kutoka)\s+(.+?)(?:\.|\s+Rej|\s+Salio|\s+tarehe|$)',
        caseSensitive: false,
      );
      var match = swReceivedRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        final sender = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: sender,
          reference: ref,
          provider: 'AirtelMoney_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 2. English Received Money (Income)
      // Example: "You have received TZS 45,000.00 from 0712345678. TxnID: AT123456. Balance: TZS 300,000.00"
      final engReceivedRegex = RegExp(
        r'You have received\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+from\s+(.+?)(?:\.|\s+TxnID|\s+Balance|\s+on|$)',
        caseSensitive: false,
      );
      match = engReceivedRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        final sender = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: sender,
          reference: ref,
          provider: 'AirtelMoney_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 3. Swahili Sent Money (Expense)
      // Example: "Umetuma Tsh 20,000.00 kwa 0765432198. Rej: AT654321. Salio: Tsh 280,000.00"
      final swSentRegex = RegExp(
        r'Umetuma\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:kwa|kwenda)\s+(.+?)(?:\.|\s+Rej|\s+Salio|\s+tarehe|$)',
        caseSensitive: false,
      );
      match = swSentRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        final recipient = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: recipient,
          reference: ref,
          provider: 'AirtelMoney_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 4. English Sent Money (Expense)
      // Example: "You have sent TZS 20,000.00 to 0765432198. TxnID: AT654321. Balance: TZS 280,000.00"
      final engSentRegex = RegExp(
        r'You have sent\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+to\s+(.+?)(?:\.|\s+TxnID|\s+Balance|\s+on|$)',
        caseSensitive: false,
      );
      match = engSentRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        final recipient = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: recipient,
          reference: ref,
          provider: 'AirtelMoney_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 5. Swahili Agent Deposit (Income)
      // Example: "Umeweka Tsh 100,000.00 kwenye Airtel Money. Salio: Tsh 380,000.00"
      final swDepositRegex = RegExp(
        r'Umeweka\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+kwenye\s+Airtel\s+Money',
        caseSensitive: false,
      );
      match = swDepositRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: 'Airtel Money Agent Deposit',
          reference: ref,
          provider: 'AirtelMoney_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 6. English Agent Deposit (Income)
      // Example: "You have deposited TZS 100,000.00 to Airtel Money. Balance: TZS 380,000.00"
      final engDepositRegex = RegExp(
        r'You have deposited\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:to|into)\s+Airtel\s+Money',
        caseSensitive: false,
      );
      match = engDepositRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: 'Airtel Money Agent Deposit',
          reference: ref,
          provider: 'AirtelMoney_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }
    } catch (e) {
      developer.log('AirtelTzParser error: $e', name: 'Parser');
    }

    return null;
  }
}
