import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';

/// Regression coverage for the SMS review balance-deferral contract.
///
/// A transaction parked in the review queue (`source == 'sms_reviewed'`) must
/// leave account balances completely untouched at insert time. The single
/// balance adjustment is applied later by [TransactionDao
/// .approveReviewedTransaction]. If the insert path also adjusts, approving
/// double-counts the amount; if the delete path reverses a delta that was never
/// applied, rejecting corrupts the balance in the other direction.
void main() {
  late AppDatabase db;
  late TransactionDao dao;

  const accountId = 'acct-mpesa';
  const categoryId = 'cat-food';

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    dao = TransactionDao(db);
    await db.into(db.accounts).insert(
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
    await db.into(db.categories).insert(
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

  Transaction expense({required String id, required String source}) => Transaction(
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
    source: source,
    createdAt: DateTime(2026, 1, 2, 10),
    updatedAt: DateTime(2026, 1, 2, 10),
  );

  Future<int> balance() async {
    final row = await (db.select(db.accounts)
          ..where((a) => a.id.equals(accountId)))
        .getSingle();
    return row.balance;
  }

  test('inserting a pending review transaction does not touch the balance',
      () async {
    await dao.writeTransactionWithBalanceAdjustment(
      expense(id: 'pending-1', source: 'sms_reviewed'),
    );

    expect(
      await balance(),
      100000,
      reason: 'a transaction awaiting review must not move the balance',
    );
  });

  test('inserting an auto-approved SMS transaction still adjusts the balance',
      () async {
    await dao.writeTransactionWithBalanceAdjustment(
      expense(id: 'auto-1', source: 'sms_auto'),
    );

    expect(await balance(), 75000);
  });

  test('approving a pending transaction applies the delta exactly once',
      () async {
    final tx = expense(id: 'pending-2', source: 'sms_reviewed');
    await dao.writeTransactionWithBalanceAdjustment(tx);
    expect(await balance(), 100000, reason: 'deferred at insert');

    await dao.approveReviewedTransaction(tx.id);

    expect(
      await balance(),
      75000,
      reason: '25000 must be deducted exactly once across insert + approve',
    );
  });

  test('approving twice does not deduct twice', () async {
    final tx = expense(id: 'pending-3', source: 'sms_reviewed');
    await dao.writeTransactionWithBalanceAdjustment(tx);

    await dao.approveReviewedTransaction(tx.id);
    await dao.approveReviewedTransaction(tx.id);

    expect(await balance(), 75000);
  });

  test('rejecting a pending transaction leaves the balance untouched',
      () async {
    final tx = expense(id: 'pending-4', source: 'sms_reviewed');
    await dao.writeTransactionWithBalanceAdjustment(tx);
    expect(await balance(), 100000);

    await dao.deleteTransactionWithBalanceAdjustment(tx.id);

    expect(
      await balance(),
      100000,
      reason: 'no delta was applied at insert, so none may be reversed',
    );
    final remaining = await (db.select(db.transactions)
          ..where((t) => t.id.equals(tx.id)))
        .get();
    expect(remaining, isEmpty, reason: 'the row itself must still be removed');
  });

  test('editing a pending transaction does not invent a balance delta',
      () async {
    final tx = expense(id: 'pending-5', source: 'sms_reviewed');
    await dao.writeTransactionWithBalanceAdjustment(tx);

    await dao.updateTransactionWithBalanceAdjustment(
      tx.copyWith(amount: 99000),
    );

    expect(
      await balance(),
      100000,
      reason: 'editing an unadjusted row must not reverse or apply a delta',
    );
  });
}
