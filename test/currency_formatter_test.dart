import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';

void main() {
  group('CurrencyFormatter - formatCents', () {
    test('Formats round amounts without decimals by default', () {
      expect(CurrencyFormatter.formatCents(5000000), 'Tsh 50,000');
      expect(CurrencyFormatter.formatCents(1230000), 'Tsh 12,300');
      expect(CurrencyFormatter.formatCents(0), 'Tsh 0');
    });

    test('Formats decimal cents automatically', () {
      expect(CurrencyFormatter.formatCents(5000025), 'Tsh 50,000.25');
      expect(CurrencyFormatter.formatCents(1500), 'Tsh 15');
    });

    test('Enforces decimals display when specified', () {
      expect(CurrencyFormatter.formatCents(5000000, showDecimals: true), 'Tsh 50,000.00');
    });
  });

  group('CurrencyFormatter - parseToCents', () {
    test('Parses standard decimal numbers to integer cents', () {
      expect(CurrencyFormatter.parseToCents('50,000.25'), 5000025);
      expect(CurrencyFormatter.parseToCents('12000'), 1200000);
    });

    test('Strips Tsh and TZS symbols and handles whitespaces', () {
      expect(CurrencyFormatter.parseToCents('Tsh 15,000.50'), 1500050);
      expect(CurrencyFormatter.parseToCents('  TZS  5,000 '), 500000);
    });

    test('Handles whole TSh amounts (no decimals)', () {
      expect(CurrencyFormatter.parseToCents('1500'), 150000);
      expect(CurrencyFormatter.parseToCents('0'), 0);
    });

    test('Handles amounts with decimal point', () {
      expect(CurrencyFormatter.parseToCents('15.50'), 1550);
      expect(CurrencyFormatter.parseToCents('1000.75'), 100075);
    });

    test('Handles multiple dots (European-style thousand sep + decimal)', () {
      expect(CurrencyFormatter.parseToCents('1.234.56'), 123456);
      expect(CurrencyFormatter.parseToCents('12.345.67'), 1234567);
    });

    test('Handles negative amounts', () {
      expect(CurrencyFormatter.parseToCents('-5000'), -500000);
      expect(CurrencyFormatter.parseToCents('-\u22125000'), -500000);
    });

    test('Handles leading/trailing whitespace', () {
      expect(CurrencyFormatter.parseToCents('  1500  '), 150000);
    });

    test('Gracefully returns 0 for empty or invalid text', () {
      expect(CurrencyFormatter.parseToCents(''), 0);
      expect(CurrencyFormatter.parseToCents('abc'), 0);
      expect(CurrencyFormatter.parseToCents('.'), 0);
    });
  });
}
