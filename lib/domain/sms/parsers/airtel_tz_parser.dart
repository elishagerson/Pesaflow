import 'dart:developer' as developer;
import '../../../data/models/sms_parsed.dart';
import 'sms_parser_interface.dart';

class AirtelTzParser implements SmsParser {
  int _parseAmount(String val) {
    final clean = val.replaceAll(',', '').trim();
    final doubleVal = double.tryParse(clean) ?? 0.0;
    return (doubleVal * 100).round();
  }

  String _extractReference(String text) {
    final regex = RegExp(r'Rej:\s*([A-Za-z0-9]+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    return match?.group(1) ?? 'AIRTEL-REF-UNKNOWN';
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
      // Example: "Umepokea Tsh 45,000.00 kutoka kwa 0712345678. Rej: AT123456. Salio: Tsh 300,000.00"
      final receivedRegex = RegExp(
        r'Umepokea\s+(?:Tsh|TZS)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:kutoka kwa|kutoka)\s+(.+?)\.',
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
          provider: 'AirtelMoney_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 2. Check for Sent Money (Expense)
      // Example: "Umetuma Tsh 20,000.00 kwa 0765432198. Rej: AT654321. Salio: Tsh 280,000.00"
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
          provider: 'AirtelMoney_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 3. Check for Direct Agent Deposit (Income)
      // Example: "Umeweka Tsh 100,000.00 kwenye Airtel Money. Salio: Tsh 380,000.00"
      final depositRegex = RegExp(
        r'Umeweka\s+(?:Tsh|TZS)?\s*([\d,]+(?:\.[\d]{2})?)\s+kwenye\s+Airtel\s+Money',
        caseSensitive: false,
      );
      match = depositRegex.firstMatch(text);
      if (match != null) {
        final amt = _parseAmount(match.group(1)!);
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
