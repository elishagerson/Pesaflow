import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';

/// Regression coverage for SMS-review balance handling.
///
/// Capturing an SMS moves money immediately, so the balance is adjusted at insert
/// time for every source. Approval therefore must NOT apply a second delta — doing
/// so double-counts the amount. The one thing approval still legitimately does is
/// re-assert a carrier-reported `balanceAfter`, because that is an absolute
/// ground-truth value rather than a delta.
void main() {
  late AppDatabase db;
  late TransactionDao dao;

  const accountId = 'acct-mpesa';
  const categoryId = 'cat-food';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = TransactionDao(db);
    await db
        .into(db.accounts)
        .insert(
          Account(
            id: accountId,
            name: 'M-Pesa',
            type: 'mobile_money',
            balance: 100000,
            provider: 'M-Pesa_TZ',
            icon: 'wallet',
            sortOrder: 0,
            isArchived: false,
            createdAt: DateTime(2026, 1, 1),
          ),
        );
    await db
        .into(db.categories)
        .insert(
          Category(
            id: categoryId,
            name: 'Food',
            type: 'expense',
            color: '#FF9800',
            icon: 'restaurant',
            isSystem: false,
            sortOrder: 0,
            createdAt: DateTime(2026, 1, 1),
          ),
        );
  });

  tearDown(() async => db.close());

  Transaction expense({
    required String id,
    required String source,
    int? balanceAfter,
  }) => Transaction(
    id: id,
    accountId: accountId,
    categoryId: categoryId,
    trackerId: 'default_personal',
    amount: 25000,
    type: 'expense',
    description: 'Lunch',
    reference: 'REF-$id',
    rawSms: 'raw body',
    smsTimestamp: DateTime(2026, 1, 2, 10),
    balanceAfter: balanceAfter,
    source: source,
    createdAt: DateTime(2026, 1, 2, 10),
    updatedAt: DateTime(2026, 1, 2, 10),
  );

  Future<int> balance() async {
    final row = await (db.select(
      db.accounts,
    )..where((a) => a.id.equals(accountId))).getSingle();
    return row.balance;
  }

  test(
    'capturing a pending review transaction moves the balance immediately',
    () async {
      await dao.writeTransactionWithBalanceAdjustment(
        expense(id: 'pending-1', source: 'sms_reviewed'),
      );

      expect(
        await balance(),
        75000,
        reason:
            'a captured SMS is real money movement and must show up at once',
      );
    },
  );

  test(
    'capturing an auto-approved SMS transaction moves the balance',
    () async {
      await dao.writeTransactionWithBalanceAdjustment(
        expense(id: 'auto-1', source: 'sms_auto'),
      );

      expect(await balance(), 75000);
    },
  );

  test('approving does not deduct a second time', () async {
    final tx = expense(id: 'pending-2', source: 'sms_reviewed');
    await dao.writeTransactionWithBalanceAdjustment(tx);
    expect(await balance(), 75000, reason: 'deducted once at capture');

    await dao.approveReviewedTransaction(tx.id);

    expect(
      await balance(),
      75000,
      reason: 'approval must not apply the delta again',
    );
  });

  test('approving twice does not deduct twice', () async {
    final tx = expense(id: 'pending-3', source: 'sms_reviewed');
    await dao.writeTransactionWithBalanceAdjustment(tx);

    await dao.approveReviewedTransaction(tx.id);
    await dao.approveReviewedTransaction(tx.id);

    expect(await balance(), 75000);
  });

  test('approving re-asserts the carrier-reported balance', () async {
    final tx = expense(
      id: 'pending-4',
      source: 'sms_reviewed',
      balanceAfter: 42000,
    );
    await dao.writeTransactionWithBalanceAdjustment(tx);
    expect(await balance(), 42000, reason: 'carrier ground truth wins');

    await dao.approveReviewedTransaction(tx.id);

    expect(
      await balance(),
      42000,
      reason: 're-asserting an absolute balance is idempotent',
    );
  });

  test('approving still applies a category change', () async {
    const other = 'cat-transport';
    await db
        .into(db.categories)
        .insert(
          Category(
            id: other,
            name: 'Transport',
            type: 'expense',
            color: '#2196F3',
            icon: 'car',
            isSystem: false,
            sortOrder: 1,
            createdAt: DateTime(2026, 1, 1),
          ),
        );
    final tx = expense(id: 'pending-5', source: 'sms_reviewed');
    await dao.writeTransactionWithBalanceAdjustment(tx);

    await dao.approveReviewedTransaction(tx.id, newCategoryId: other);

    final row = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(tx.id))).getSingle();
    expect(row.categoryId, other);
    expect(row.source, 'sms_auto');
  });

  test('rejecting a captured transaction reverses the balance', () async {
    final tx = expense(id: 'pending-6', source: 'sms_reviewed');
    await dao.writeTransactionWithBalanceAdjustment(tx);
    expect(await balance(), 75000);

    await dao.deleteTransactionWithBalanceAdjustment(tx.id);

    expect(
      await balance(),
      100000,
      reason: 'reversing must undo the delta applied at capture',
    );
    final remaining = await (db.select(
      db.transactions,
    )..where((t) => t.id.equals(tx.id))).get();
    expect(remaining, isEmpty);
  });
}
