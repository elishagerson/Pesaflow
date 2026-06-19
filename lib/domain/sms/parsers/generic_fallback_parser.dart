import 'dart:developer' as developer;
import '../../../data/models/sms_parsed.dart';
import 'amount_helper.dart';
import 'sms_parser_interface.dart';

class GenericFallbackParser implements SmsParser {
  final String provider;

  const GenericFallbackParser({required this.provider});

  @override
  SmsParsed? parse(String rawSmsBody, DateTime timestamp) {
    final text = rawSmsBody.trim();
    if (text.isEmpty) return null;

    try {
      final amount = _extractFirstAmount(text);
      if (amount == 0) {
        developer.log('GenericFallbackParser: could not extract amount from "$text"', name: 'Parser');
        return null;
      }

      final type = _determineType(text);
      final ref = _extractAnyReference(text);
      final bal = _extractAnyBalance(text);

      return SmsParsed(
        amount: amount,
        type: type,
        senderOrRecipient: 'Unknown',
        reference: ref,
        provider: provider,
        balanceAfter: bal,
        timestamp: timestamp,
        rawSmsBody: text,
      );
    } catch (e) {
      developer.log('GenericFallbackParser error: $e', name: 'Parser');
      return null;
    }
  }

  static int _extractFirstAmount(String text) {
    final regex = RegExp(r'(?:Tsh|TZS|TSh|Tshs|tsh)?\s*([\d,]+(?:\.[\d]{2})?)', caseSensitive: false);
    final matches = regex.allMatches(text);
    for (final m in matches) {
      final val = m.group(1);
      if (val == null) continue;
      final numeric = val.replaceAll(',', '');
      final parsed = double.tryParse(numeric);
      if (parsed != null && parsed > 0) {
        return (parsed * 100).round();
      }
    }
    return 0;
  }

  static String _determineType(String text) {
    final lower = text.toLowerCase();
    final incomeWords = [
      'umepokea', 'umepewa', 'zimewekwa', 'received', 'deposit',
      'tumeongeza', 'tumekutoa', 'credit', 'payment from',
      'cash-in', 'cash in',
    ];
    final expenseWords = [
      'umetuma', 'sent', 'paid', 'payment to', 'deducted',
      'purchase', 'withdrawal', 'withdraw', 'fee', 'charges',
      'airtime', 'bought',
    ];
    final loanWords = [
      'loan', 'mkopo', 'kopeshwa', 'kopa', 'borrowed',
    ];

    for (final w in incomeWords) {
      if (lower.contains(w)) return 'income';
    }
    for (final w in expenseWords) {
      if (lower.contains(w)) return 'expense';
    }
    for (final w in loanWords) {
      if (lower.contains(w)) return 'loan';
    }

    return 'expense';
  }

  static String _extractAnyReference(String text) {
    final regex = RegExp(
      r'(?:Rej|Ref|TxnID|TxnId|Transaction|Kumbukumbu|ID)[:\s]+([A-Za-z0-9]+)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    return match?.group(1) ?? 'GEN-${DateTime.now().millisecondsSinceEpoch}';
  }

  static int? _extractAnyBalance(String text) {
    final regex = RegExp(
      r'(?:Salio|Balance|New balance|Bal)[:\s]*(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      return parseAmount(match.group(1) ?? '');
    }
    return null;
  }
}
