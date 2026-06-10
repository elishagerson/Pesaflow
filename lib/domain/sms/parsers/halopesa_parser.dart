import 'dart:developer' as developer;
import '../../../data/models/sms_parsed.dart';
import 'amount_helper.dart';
import 'sms_parser_interface.dart';

class HalopesaParser implements SmsParser {
  String _extractReference(String text) {
    final regex = RegExp(r'(?:Rej|Kumbukumbu|Ref|TxnID):\s*([A-Za-z0-9]+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    return match?.group(1) ?? 'HALO-REF-UNKNOWN';
  }

  int? _extractBalance(String text) {
    final regex = RegExp(
      r'(?:Salio|Balance|Bal):\s*(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)', 
      caseSensitive: false
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      return parseAmount(match.group(1)!);
    }
    return null;
  }

  @override
  SmsParsed? parse(String rawSmsBody, DateTime timestamp) {
    final text = rawSmsBody.trim();

    try {
      // 1. Swahili Received Money (Income)
      // Example: "Umepokea TZS 10,000.00 kutoka kwa 0621234567. Rej: HP12345. Salio: TZS 50,000.00"
      final receivedRegex = RegExp(
        r'Umepokea\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:kutoka kwa|kutoka)\s+(.+?)(?:\.|\s+Rej|\s+Salio|$)',
        caseSensitive: false,
      );
      var match = receivedRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1)!);
        final sender = match.group(2)!.trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: sender,
          reference: ref,
          provider: 'Halopesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 2. English Received Money (Income)
      // Example: "You have received TZS 10,000.00 from 0621234567. Ref: HP12345. Balance: TZS 50,000.00"
      final engReceivedRegex = RegExp(
        r'You have received\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+from\s+(.+?)(?:\.|\s+Ref|\s+Balance|$)',
        caseSensitive: false,
      );
      match = engReceivedRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1)!);
        final sender = match.group(2)!.trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: sender,
          reference: ref,
          provider: 'Halopesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 3. Swahili Sent Money (Expense)
      // Example: "Umetuma TZS 5,000.00 kwa 0627654321. Rej: HP54321. Salio: TZS 45,000.00"
      final sentRegex = RegExp(
        r'Umetuma\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:kwa|kwenda)\s+(.+?)(?:\.|\s+Rej|\s+Salio|$)',
        caseSensitive: false,
      );
      match = sentRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1)!);
        final recipient = match.group(2)!.trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: recipient,
          reference: ref,
          provider: 'Halopesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 4. English Sent Money (Expense)
      // Example: "You have sent TZS 5,000.00 to 0627654321. Ref: HP54321. Balance: TZS 45,000.00"
      final engSentRegex = RegExp(
        r'You have sent\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+to\s+(.+?)(?:\.|\s+Ref|\s+Balance|$)',
        caseSensitive: false,
      );
      match = engSentRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1)!);
        final recipient = match.group(2)!.trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: recipient,
          reference: ref,
          provider: 'Halopesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }
    } catch (e) {
      developer.log('HalopesaParser error: $e', name: 'Parser');
    }

    return null;
  }
}
