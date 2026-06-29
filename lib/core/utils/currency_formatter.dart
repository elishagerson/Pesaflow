import 'package:intl/intl.dart';

class CurrencyFormatter {
  static const String currencyPrefix = 'Tsh ';

  static final NumberFormat _commaFormatter = NumberFormat('#,##0', 'en_US');
  static final NumberFormat _decimalFormatter = NumberFormat(
    '#,##0.00',
    'en_US',
  );

  /// Formats TZS amount stored in integer cents (e.g. 5000000 -> Tsh 50,000)
  /// If [showDecimals] is true or [amountInCents] has a remainder, it displays cents decimals.
  static String formatCents(int amountInCents, {bool showDecimals = false}) {
    final double value = amountInCents / 100.0;

    // Check if the cents portion is non-zero
    final bool hasCents = (amountInCents % 100) != 0;

    if (showDecimals || hasCents) {
      return '$currencyPrefix${_decimalFormatter.format(value)}';
    } else {
      return '$currencyPrefix${_commaFormatter.format(value)}';
    }
  }

  /// Parses a user-input decimal string back into integer cents (e.g. "50,000.25" -> 5000025)
  /// Returns 0 if parsing fails.
  ///
  /// Handles:
  ///   - Currency symbols (Tsh, TZS, $, etc.)
  ///   - Thousand separators (commas, spaces)
  ///   - Decimal dots (last dot wins when multiple present)
  ///   - Negative amounts (leading "-" or "\u2212")
  ///   - Leading/trailing whitespace
  static int parseToCents(String text) {
    if (text.isEmpty) return 0;

    String cleaned = text.trim();

    // Detect and preserve negative sign
    bool isNegative = false;
    if (cleaned.startsWith('-') || cleaned.startsWith('\u2212')) {
      isNegative = true;
      cleaned = cleaned.substring(1).trim();
    }

    // Strip currency symbols, letters, and whitespace (keep digits, dots, commas)
    cleaned = cleaned.replaceAll(RegExp(r'[^\d.,]'), '').trim();
    if (cleaned.isEmpty) return 0;

    // Remove all commas (thousand separators)
    cleaned = cleaned.replaceAll(',', '');

    // Handle dots — keep the last as decimal, remove the rest (thousand separators)
    final dotCount = '.'.allMatches(cleaned).length;
    if (dotCount > 1) {
      final lastDot = cleaned.lastIndexOf('.');
      final before = cleaned.substring(0, lastDot).replaceAll('.', '');
      final after = cleaned.substring(lastDot);
      cleaned = '$before$after';
    }

    if (cleaned == '.' || cleaned.isEmpty) return 0;

    try {
      final doubleValue = double.parse(cleaned);
      final cents = (doubleValue * 100).round();
      return isNegative ? -cents : cents;
    } catch (_) {
      return 0;
    }
  }
}
