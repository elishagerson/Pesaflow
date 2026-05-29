import 'dart:developer' as developer;
import '../../../data/models/sms_parsed.dart';
import 'sms_parser_interface.dart';

class SelcomPesaParser implements SmsParser {
  int parseAmount(String val) {
    final clean = val.replaceAll(',', '').trim();
    final doubleVal = double.tryParse(clean) ?? 0.0;
    return (doubleVal * 100).round();
  }

  String _extractReference(String text) {
    // Swahili: Ref/Txn/ID ya muamala: XXXXX
    final swaRegex = RegExp(r'(?:Ref|Txn|ID|ID ya muamala):\s*([A-Za-z0-9]+)', caseSensitive: false);
    final match = swaRegex.firstMatch(text);
    if (match != null) return match.group(1)!;

    // English: word before "Accepted." or "Confirmed."
    final engRegex = RegExp(r'(\w+)\s+(?:Accepted|Confirmed)\.\s*You have', caseSensitive: false);
    final engMatch = engRegex.firstMatch(text);
    if (engMatch != null) return engMatch.group(1)!;

    return 'SELCOM-REF-UNKNOWN';
  }

  int? _extractBalance(String text) {
    // Swahili: Salio/Balance: TZS XXX
    final swaRegex = RegExp(
      r'(?:Salio|Balance|Bal|New Balance):\s*(?:TZS|Tsh)?\s*([\d,]+(?:\.[\d]{2})?)',
      caseSensitive: false,
    );
    final match = swaRegex.firstMatch(text);
    if (match != null) {
      return parseAmount(match.group(1)!);
    }

    // English: "Updated balance is TZS XXX"
    final engRegex = RegExp(r'Updated balance is TZS\s*([\d,]+(?:\.[\d]{2})?)', caseSensitive: false);
    final engMatch = engRegex.firstMatch(text);
    if (engMatch != null) {
      return parseAmount(engMatch.group(1)!);
    }

    return null;
  }

  @override
  SmsParsed? parse(String rawSmsBody, DateTime timestamp) {
    final text = rawSmsBody.trim();

    try {
      // ========== English-format patterns (real Selcom Pesa) ==========

      // 1. English: Received Money (Income)
      // Example: "0517EQMYW Confirmed. You have received TZS 473,000.00 from ELISHA NDUNDULU - Mixx by Yas (255675259341) on 2026-05-17 17:57:46. Updated balance is TZS 477,319.85."
      final engReceivedRegex = RegExp(
        r'Confirmed\.\s*You have received TZS\s*([\d,]+(?:\.[\d]{2})?)\s+from\s+(.+?)\s+on\s+\d{4}-\d{2}-\d{2}',
        caseSensitive: false,
      );
      var match = engReceivedRegex.firstMatch(text);
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
          provider: 'SelcomPesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 2. English: Sent Money (Expense)
      // Example: "0517EQN0Z Accepted. You have sent TZS 477,000.00 to PARTS AND COMPONENTS MBEYA - 19938686 on 2026-05-17 17:58:34. Charge is FREE. Updated balance is TZS 319.85."
      final engSentRegex = RegExp(
        r'Accepted\.\s*You have sent TZS\s*([\d,]+(?:\.[\d]{2})?)\s+to\s+(.+?)\s+on\s+\d{4}-\d{2}-\d{2}',
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
          provider: 'SelcomPesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // ========== Swahili-format patterns (legacy) ==========

      // 3. Swahili/Fallback: Amount Extraction
      final amtRegex = RegExp(
        r'(?:Tsh|TZS)?\s*([\d,]+(?:\.[\d]{2})?)\s*(?:credited|debited|sent|received|umepokea|umetuma|imehamishwa|imesafirishwa)',
        caseSensitive: false,
      );

      // Secondary amount regex if first doesn't match
      final fallbackAmtRegex = RegExp(
        r'(?:Umetuma|Umepokea|Tumeongeza|Tumekutoa|Sent|Received|Paid)\s+(?:Tsh|TZS)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      );

      match = amtRegex.firstMatch(text) ?? fallbackAmtRegex.firstMatch(text);
      if (match == null) return null;

      final amt = parseAmount(match.group(1)!);
      if (amt == 0) return null;

      // 4. Determine transaction type (income / expense)
      String type = 'expense';
      final incomeKeywords = ['receive', 'deposit', 'credit', 'umepokea', 'tumeongeza', 'ingia', 'ingizwa'];
      final lowercaseBody = text.toLowerCase();
      for (final kw in incomeKeywords) {
        if (lowercaseBody.contains(kw)) {
          type = 'income';
          break;
        }
      }

      // 5. Extract sender or recipient
      String senderOrRecipient = 'Selcom';
      final toRegex = RegExp(
        r'\b(?:to|kwa|kwenda)\s+([A-Za-z0-9\s_\-\(\)\+]+?)(?:\.|\s+tarehe|\s+Ref|\s+Updated balance|\s+Salio|\s+Balance|$)',
        caseSensitive: false,
      );
      final fromRegex = RegExp(
        r'\b(?:from|kutoka(?:\s+kwa)?)\s+([A-Za-z0-9\s_\-\(\)\+]+?)(?:\.|\s+tarehe|\s+Ref|\s+Updated balance|\s+Salio|\s+Balance|$)',
        caseSensitive: false,
      );

      final partyMatch = type == 'income' ? fromRegex.firstMatch(text) : toRegex.firstMatch(text);
      if (partyMatch != null) {
        senderOrRecipient = partyMatch.group(1)!.trim();
      }

      final ref = _extractReference(text);
      final bal = _extractBalance(text);

      return SmsParsed(
        amount: amt,
        type: type,
        senderOrRecipient: senderOrRecipient,
        reference: ref,
        provider: 'SelcomPesa_TZ',
        balanceAfter: bal,
        timestamp: timestamp,
        rawSmsBody: text,
      );
    } catch (e) {
      developer.log('SelcomPesaParser error: $e', name: 'Parser');
    }

    return null;
  }
}
