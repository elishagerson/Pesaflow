import 'dart:developer' as developer;
import '../../../data/models/sms_parsed.dart';
import 'sms_parser_interface.dart';

class HalopesaParser implements SmsParser {
  int _parseAmount(String val) {
    final clean = val.replaceAll(',', '').trim();
    final doubleVal = double.tryParse(clean) ?? 0.0;
    return (doubleVal * 100).round();
  }

  String _extractReference(String text) {
    final regex = RegExp(r'(?:Rej|Kumbukumbu|Ref):\s*([A-Za-z0-9]+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    return match?.group(1) ?? 'HALO-REF-UNKNOWN';
  }

  int? _extractBalance(String text) {
    final regex = RegExp(r'Salio:\s*(?:Tsh|TZS)?\s*([\d,]+(?:\.[\d]{2})?)', caseSensitive: false);
    final match = regex.firstMatch(text);
    if (match != null) {
      return _parseAmount(match.group(1)!);
    }
    return null;
  }

  @override
  SmsParsed? parse(String rawSmsBody, DateTime timestamp) {
    final text = rawSmsBody.trim();

    try {
      // 1. Check for Received Money (Income)
      // Example: "Umepokea TZS 10,000.00 kutoka kwa 0621234567. Rej: HP12345. Salio: TZS 50,000.00"
      final receivedRegex = RegExp(
        r'(?:Umepokea|Umepokea kutoka)\s+(?:Tsh|TZS)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:kutoka kwa|kutoka)\s+(.+?)\.',
        caseSensitive: false,
      );
      var match = receivedRegex.firstMatch(text);
      if (match != null) {
        final amt = _parseAmount(match.group(1)!);
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

      // 2. Check for Sent Money (Expense)
      // Example: "Umetuma TZS 5,000.00 kwa 0627654321. Rej: HP54321. Salio: TZS 45,000.00"
      final sentRegex = RegExp(
        r'Umetuma\s+(?:Tsh|TZS)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:kwa|kwenda)\s+(.+?)\.',
        caseSensitive: false,
      );
      match = sentRegex.firstMatch(text);
      if (match != null) {
        final amt = _parseAmount(match.group(1)!);
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
