import 'dart:developer' as developer;
import '../../../data/models/sms_parsed.dart';
import 'sms_parser_interface.dart';

class MpesaTzParser implements SmsParser {
  // Helper to convert money strings like "50,000.00" or "50000" into integer cents
  int _parseAmount(String val) {
    final clean = val.replaceAll(',', '').trim();
    final doubleVal = double.tryParse(clean) ?? 0.0;
    return (doubleVal * 100).round();
  }

  String _extractReference(String text) {
    final regex = RegExp(r'Rej:\s*([A-Za-z0-9]+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    return match?.group(1) ?? 'MPESA-REF-UNKNOWN';
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
      // Example: "Pesa zimewekwa Tsh 50,000.00 na John Doe tarehe 15/5/2026... Rej: P65AB. Salio: Tsh 250,000.00"
      final receivedRegex = RegExp(
        r'(?:Pesa zimewekwa|Umepokea|Umepewa)\s+(?:Tsh|TZS)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:na|kutoka kwa|kutoka)\s+(.+?)\s+tarehe',
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
          provider: 'M-Pesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 2. Check for Sent Money (Expense)
      // Example: "Umetuma Tsh 30,000.00 kwa Jane Doe tarehe 15/5/2026... Rej: P65XYZ. Salio: Tsh 220,000.00"
      final sentRegex = RegExp(
        r'Umetuma\s+(?:Tsh|TZS)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:kwa|kwenda)\s+(.+?)\s+tarehe',
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
          provider: 'M-Pesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 3. Check for Airtime purchase (Expense/Airtime)
      // Example: "Umenunua airtime Tsh 5,000.00 kwa 0712345678 tarehe 15/5/2026. Rej: A65ABC. Salio: Tsh 215,000.00"
      final airtimeRegex = RegExp(
        r'Umenunua\s+airtime\s+(?:Tsh|TZS)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      );
      match = airtimeRegex.firstMatch(text);
      if (match != null) {
        final amt = _parseAmount(match.group(1)!);
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'airtime',
          senderOrRecipient: 'Vodacom Airtime',
          reference: ref,
          provider: 'M-Pesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 4. Check for service fee / carrier deduction (Expense/Fee)
      // Example: "Kodi ya kuhudumia Tsh 500.00 tarehe 15/5/2026. Salio: Tsh 214,500.00"
      final feeRegex = RegExp(
        r'Kodi\s+ya\s+kuhudumia\s+(?:Tsh|TZS)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      );
      match = feeRegex.firstMatch(text);
      if (match != null) {
        final amt = _parseAmount(match.group(1)!);
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'fee',
          senderOrRecipient: 'Vodacom Service Fee',
          reference: ref,
          provider: 'M-Pesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }
    } catch (e) {
      developer.log('MpesaTzParser error: $e', name: 'Parser');
    }

    return null;
  }
}
