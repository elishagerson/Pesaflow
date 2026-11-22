import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';

void main() {
  late AppDatabase db;
  late TransactionDao dao;
  const uuid = Uuid();

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = TransactionDao(db);

    // Create an account & category for test transactions
    await db
        .into(db.accounts)
        .insert(
          Account(
            id: 'acc1',
            name: 'M-Pesa Wallet',
            type: 'mobile_money',
            balance: 50000000,
            icon: 'phone',
            isArchived: false,
            sortOrder: 1,
            createdAt: DateTime.now(),
          ),
        );

    await db
        .into(db.categories)
        .insert(
          Category(
            id: 'cat_util',
            name: 'Utilities',
            icon: 'bolt',
            color: '#F59E0B',
            type: 'expense',
            sortOrder: 1,
            isSystem: true,
            createdAt: DateTime.now(),
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  group('Recurring Pattern Detection (findRecurringCandidates)', () {
    test('detects repeating monthly bill from past transactions', () async {
      final now = DateTime.now();

      // Seed 3 monthly Zuku Fiber payments spaced ~30 days apart
      final dates = [
        now.subtract(const Duration(days: 60)),
        now.subtract(const Duration(days: 30)),
        now.subtract(const Duration(days: 1)),
      ];

      for (final date in dates) {
        await db
            .into(db.transactions)
            .insert(
              Transaction(
                id: uuid.v4(),
                amount: 5900000, // 59,000 TZS in cents
                type: 'expense',
                categoryId: 'cat_util',
                accountId: 'acc1',
                description: 'Paid to Zuku Fiber Home Internet',
                source: 'sms_auto',
                createdAt: date,
                updatedAt: date,
              ),
            );
      }

      final candidates = await dao.findRecurringCandidates(
        minOccurrences: 2,
        lookbackDays: 90,
      );

      expect(candidates, isNotEmpty);
      final zuku = candidates.firstWhere((c) => c.keyword == 'zuku');
      expect(zuku.title, 'Zuku Fiber');
      expect(zuku.averageAmountCents, 5900000);
      expect(zuku.frequency, 'monthly');
      expect(zuku.occurrenceCount, 3);
    });

    test('excludes candidate if keyword is already tracked', () async {
      final now = DateTime.now();

      // Seed 2 LUKU payments
      await db
          .into(db.transactions)
          .insert(
            Transaction(
              id: uuid.v4(),
              amount: 5000000,
              type: 'expense',
              categoryId: 'cat_util',
              accountId: 'acc1',
              description: 'LUKU token purchase',
              source: 'sms_auto',
              createdAt: now.subtract(const Duration(days: 35)),
              updatedAt: now.subtract(const Duration(days: 35)),
            ),
          );
      await db
          .into(db.transactions)
          .insert(
            Transaction(
              id: uuid.v4(),
              amount: 5000000,
              type: 'expense',
              categoryId: 'cat_util',
              accountId: 'acc1',
              description: 'LUKU token purchase',
              source: 'sms_auto',
              createdAt: now.subtract(const Duration(days: 5)),
              updatedAt: now.subtract(const Duration(days: 5)),
            ),
          );

      // Call with 'luku' in existing keywords
      final candidates = await dao.findRecurringCandidates(
        minOccurrences: 2,
        lookbackDays: 90,
        existingKeywords: {'luku'},
      );

      // Should be excluded
      expect(candidates.any((c) => c.keyword == 'luku'), isFalse);
    });

    test(
      'getPaymentsForKeywords retrieves historical payment receipts',
      () async {
        final now = DateTime.now();

        await db
            .into(db.transactions)
            .insert(
              Transaction(
                id: uuid.v4(),
                amount: 4400000,
                type: 'expense',
                categoryId: 'cat_util',
                accountId: 'acc1',
                description: 'DStv Compact payment',
                reference: '5H8901HD',
                source: 'sms_auto',
                createdAt: now.subtract(const Duration(days: 15)),
                updatedAt: now.subtract(const Duration(days: 15)),
              ),
            );

        final receipts = await dao.getPaymentsForKeywords(['dstv']);
        expect(receipts, hasLength(1));
        expect(receipts.first.reference, '5H8901HD');
        expect(receipts.first.amount, 4400000);
      },
    );
  });
}
