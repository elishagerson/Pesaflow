import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _commaFormatter = NumberFormat('#,##0', 'en_US');
  static final NumberFormat _decimalFormatter = NumberFormat('#,##0.00', 'en_US');

  /// Formats TZS amount stored in integer cents (e.g. 5000000 -> Tsh 50,000)
  /// If [showDecimals] is true or [amountInCents] has a remainder, it displays cents decimals.
  static String formatCents(int amountInCents, {bool showDecimals = false}) {
    final double value = amountInCents / 100.0;
    
    // Check if the cents portion is non-zero
    final bool hasCents = (amountInCents % 100) != 0;
    
    if (showDecimals || hasCents) {
      return 'Tsh ${_decimalFormatter.format(value)}';
    } else {
      return 'Tsh ${_commaFormatter.format(value)}';
    }
  }

  /// Parses a user-input decimal string back into integer cents (e.g. "50,000.25" -> 5000025)
  /// Returns 0 if parsing fails.
  static int parseToCents(String text) {
    if (text.isEmpty) return 0;
    
    // Strip TZS/Tsh symbols, commas, and trailing/leading spacing
    String cleaned = text
        .replaceAll(RegExp(r'[a-zA-Z\s,]+'), '')
        .trim();
        
    if (cleaned.isEmpty) return 0;
    
    try {
      final double doubleValue = double.parse(cleaned);
      return (doubleValue * 100).round();
    } catch (_) {
      return 0;
    }
  }
}
