import 'dart:developer' as developer;
import '../../models/sms_parsed.dart';
import '../sms_classifier.dart';
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
      // Run the signal-based classifier to determine if this is a real transaction
      final classification = SmsClassifier.classify(text);
      if (!classification.isTransaction) {
        developer.log(
          'GenericFallbackParser: rejected as ${classification.label} '
          '(confidence: ${classification.transactionConfidence.toStringAsFixed(2)}) — '
          'reasons: ${classification.reasons.join("; ")}',
          name: 'Parser',
        );
        return null;
      }

      final amount = _extractFirstAmount(text);
      if (amount == 0) {
        developer.log(
          'GenericFallbackParser: could not extract amount from "$text"',
          name: 'Parser',
        );
        return null;
      }

      final type = _determineType(text);
      if (type == null) {
        developer.log(
          'GenericFallbackParser: no transaction keywords in "$text"',
          name: 'Parser',
        );
        return null;
      }

      // Require a real transaction reference pattern.
      // If the SMS has no recognisable reference, it is almost certainly not
      // a transaction receipt — reject it to prevent promo false positives.
      final ref = _extractAnyReference(text);
      if (ref == null) {
        developer.log(
          'GenericFallbackParser: no transaction reference found — rejecting "$text"',
          name: 'Parser',
        );
        return null;
      }

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
    const loanWords = ['loan', 'mkopo', 'kopeshwa', 'kopa', 'borrowed'];
    // Removed 'credit' and 'deposit' — too generic, match promo text.
    const incomeWords = [
      'umepokea',
      'umepewa',
      'zimewekwa',
      'received',
      'tumeongeza',
      'payment from',
      'cash-in',
      'cash in',
    ];
    // Removed 'fee', 'charges', 'bought' — too generic, match promo text.
    const expenseWords = [
      'umetuma',
      'sent',
      'paid',
      'payment to',
      'deducted',
      'purchase',
      'withdrawal',
      'withdraw',
      'airtime',
      'tumekutoa',
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

  /// Extracts a transaction reference from the SMS text.
  /// Returns `null` if no recognisable reference pattern is found — this
  /// signals that the SMS is likely not a transaction receipt.
  ///
  /// When a reference IS found, it is returned as-is (carrier-assigned).
  /// We no longer generate random UUIDs as fallback references because they
  /// defeat deduplication across inbox re-scans.
  static String? _extractAnyReference(String text) {
    // Pattern 1: Explicit labelled reference (Rej:, Ref:, TxnID:, etc.)
    final labelledRegex = RegExp(
      r'(?:Rej|Ref|TxnID|TxnId|Transaction|Kumbukumbu|ID)[:\s]+([A-Za-z0-9]+)',
      caseSensitive: false,
    );
    final labelledMatch = labelledRegex.firstMatch(text);
    if (labelledMatch != null) return labelledMatch.group(1);

    // Pattern 2: Reference code before "Confirmed." (e.g., "Z10DN636 Confirmed.")
    final confirmedRegex = RegExp(r'([A-Za-z0-9]{6,})\s+[Cc]onfirmed');
    final confirmedMatch = confirmedRegex.firstMatch(text);
    if (confirmedMatch != null) return confirmedMatch.group(1);

    // No recognisable reference — signal that this is likely not a receipt.
    return null;
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
