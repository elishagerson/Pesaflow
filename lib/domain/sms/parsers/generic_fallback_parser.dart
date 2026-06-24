import 'dart:developer' as developer;
import 'package:uuid/uuid.dart';
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
      if (type == null) {
        developer.log('GenericFallbackParser: no transaction keywords in "$text"', name: 'Parser');
        return null;
      }
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
    // Require a currency prefix (Tsh, TZS, /=) to avoid matching dates/phone numbers
    final regex = RegExp(
      r'(?:Tsh|TZS|TSh|Tshs|\d+\/=)\s*([\d,]+(?:\.[\d]{2})?)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match == null) return 0;
    final val = match.group(1);
    if (val == null) return 0;
    final numeric = val.replaceAll(',', '');
    final parsed = double.tryParse(numeric);
    if (parsed != null && parsed > 0) {
      return (parsed * 100).round();
    }
    return 0;
  }

  static String? _determineType(String text) {
    final lower = text.toLowerCase();
    final loanWords = [
      'loan', 'mkopo', 'kopeshwa', 'kopa', 'borrowed',
    ];
    final incomeWords = [
      'umepokea', 'umepewa', 'zimewekwa', 'received', 'deposit',
      'tumeongeza', 'credit', 'payment from',
      'cash-in', 'cash in',
    ];
    final expenseWords = [
      'umetuma', 'sent', 'paid', 'payment to', 'deducted',
      'purchase', 'withdrawal', 'withdraw', 'fee', 'charges',
      'airtime', 'bought', 'tumekutoa',
    ];

    // Check loan first — most specific, prevents "received a loan" from being income.
    for (final w in loanWords) {
      if (lower.contains(w)) return 'loan';
    }
    for (final w in incomeWords) {
      if (lower.contains(w)) return 'income';
    }
    for (final w in expenseWords) {
      if (lower.contains(w)) return 'expense';
    }

    // No transaction keywords found — likely an ad or promo, not a real transaction.
    return null;
  }

  static String _extractAnyReference(String text) {
    final regex = RegExp(
      r'(?:Rej|Ref|TxnID|TxnId|Transaction|Kumbukumbu|ID)[:\s]+([A-Za-z0-9]+)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    return match?.group(1) ?? 'GEN-${Uuid().v4()}';
  }

  static int? _extractAnyBalance(String text) {
    // Require a balance keyword before the number to avoid picking up the transaction amount
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
