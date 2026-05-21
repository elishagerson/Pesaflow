import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/core/utils/csv_helper.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';

void main() {
  group('CsvHelper', () {
    test('converts empty list to header-only CSV', () {
      final csv = CsvHelper.convertToCsv([]);
      expect(csv.trim(), equals(
        'Transaction ID,Date,Type,Account,Category,Description,Amount (TZS),Reference,Sender,Recipient,Source'
      ));
    });

    test('correctly converts and escapes fields according to RFC 4180', () {
      final now = DateTime(2026, 5, 21, 10, 0, 0);
      final transaction = Transaction(
        id: 'tx-123',
        accountId: 'acc-1',
        categoryId: 'cat-1',
        amount: 250000, // TZS 2,500.00
        type: 'expense',
        description: 'Buying, "milk" & bread', // contains comma and quotes
        source: 'manual',
        createdAt: now,
        updatedAt: now,
      );

      final account = Account(
        id: 'acc-1',
        name: 'M-Pesa, cash', // contains comma
        type: 'mobile_money',
        balance: 1000000,
        createdAt: now,
        isArchived: false,
        sortOrder: 1,
        icon: 'wallet',
      );

      final category = Category(
        id: 'cat-1',
        name: 'Food',
        icon: 'cart',
        color: '#FF9800',
        type: 'expense',
        isSystem: true,
        sortOrder: 1,
        createdAt: now,
      );

      final csv = CsvHelper.convertToCsv([
        TransactionWithCategoryAndAccount(
          transaction: transaction,
          category: category,
          account: account,
        )
      ]);

      final lines = csv.split('\n');
      expect(lines.length, greaterThanOrEqualTo(2));
      
      // Verify row formatting
      final dataRow = lines[1];
      expect(dataRow, contains('tx-123'));
      expect(dataRow, contains('2026-05-21 10:00:00'));
      expect(dataRow, contains('EXPENSE'));
      expect(dataRow, contains('"M-Pesa, cash"')); // escaped comma
      expect(dataRow, contains('"Buying, ""milk"" & bread"')); // escaped quotes and comma
      expect(dataRow, contains('2500.00')); // TZS formatted
    });
  });
}
