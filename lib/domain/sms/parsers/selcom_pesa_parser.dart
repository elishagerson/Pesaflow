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
    final regex = RegExp(r'(?:Ref|Txn|ID|ID ya muamala):\s*([A-Za-z0-9]+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    return match?.group(1) ?? 'SELCOM-REF-UNKNOWN';
  }

  int? _extractBalance(String text) {
    final regex = RegExp(
      r'(?:Salio|Balance|Bal|New Balance):\s*(?:TZS|Tsh)?\s*([\d,]+(?:\.[\d]{2})?)',
      caseSensitive: false,
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
      // 1. Amount Extraction (Look for Tsh X or TZS X)
      final amtRegex = RegExp(
        r'(?:Tsh|TZS)?\s*([\d,]+(?:\.[\d]{2})?)\s*(?:credited|debited|sent|received|umepokea|umetuma|imehamishwa|imesafirishwa)',
        caseSensitive: false,
      );
      
      // Secondary amount regex if first doesn't match
      final fallbackAmtRegex = RegExp(
        r'(?:Umetuma|Umepokea|Tumeongeza|Tumekutoa|Sent|Received|Paid)\s+(?:Tsh|TZS)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      );

      var match = amtRegex.firstMatch(text) ?? fallbackAmtRegex.firstMatch(text);
      if (match == null) return null;

      final amt = parseAmount(match.group(1)!);
      if (amt == 0) return null;

      // 2. Determine transaction type (income / expense)
      String type = 'expense';
      final incomeKeywords = ['receive', 'deposit', 'credit', 'umepokea', 'tumeongeza', 'ingia', 'ingizwa'];
      final lowercaseBody = text.toLowerCase();
      for (final kw in incomeKeywords) {
        if (lowercaseBody.contains(kw)) {
          type = 'income';
          break;
        }
      }

      // 3. Extract sender or recipient
      String senderOrRecipient = 'Selcom';
      final toRegex = RegExp(
        r'\b(?:to|kwa|kwenda)\s+([A-Za-z0-9\s_]+?)(?:\.|\s+tarehe|\s+Ref)',
        caseSensitive: false,
      );
      final fromRegex = RegExp(
        r'\b(?:from|kutoka(?:\s+kwa)?)\s+([A-Za-z0-9\s_]+?)(?:\.|\s+tarehe|\s+Ref)',
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
