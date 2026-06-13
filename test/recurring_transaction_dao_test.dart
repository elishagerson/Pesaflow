import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/recurring_transaction_dao.dart';

void main() {
  late AppDatabase database;
  late RecurringTransactionDao dao;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    dao = RecurringTransactionDao(database);
  });

  tearDown(() async {
    await database.close();
  });

  RecurringTransaction _makeRecurring({
    String? id,
    String frequency = 'monthly',
    int intervalValue = 1,
    DateTime? nextDate,
    String status = 'active',
  }) {
    return RecurringTransaction(
      id: id ?? const Uuid().v4(),
      accountId: 'test_account',
      categoryId: 'test_category',
      amount: 5000000,
      type: 'expense',
      description: 'Test recurring',
      frequency: frequency,
      intervalValue: intervalValue,
      nextDate: nextDate ?? DateTime.now(),
      status: status,
      trackerId: 'default_personal',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('RecurringTransactionDao', () {
    test('inserts and retrieves a recurring transaction', () async {
      final recurring = _makeRecurring();
      await dao.insertRecurringTransaction(recurring);

      final retrieved = await dao.getById(recurring.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.amount, 5000000);
      expect(retrieved.frequency, 'monthly');
      expect(retrieved.status, 'active');
    });

    test('getAll returns all recurring transactions', () async {
      await dao.insertRecurringTransaction(_makeRecurring(frequency: 'weekly'));
      await dao.insertRecurringTransaction(_makeRecurring(frequency: 'monthly'));

      final all = await dao.getAll();
      expect(all.length, 2);
    });

    test('getDueTransactions returns only active recurring txs with nextDate <= given date', () async {
      final pastDate = DateTime.now().subtract(const Duration(days: 5));
      final futureDate = DateTime.now().add(const Duration(days: 5));

      await dao.insertRecurringTransaction(_makeRecurring(
        nextDate: pastDate,
        status: 'active',
      ));
      await dao.insertRecurringTransaction(_makeRecurring(
        nextDate: futureDate,
        status: 'active',
      ));
      await dao.insertRecurringTransaction(_makeRecurring(
        nextDate: pastDate,
        status: 'paused',
      ));

      final due = await dao.getDueTransactions(DateTime.now());
      expect(due.length, 1);
      expect(due.first.status, 'active');
    });

    test('getDueTransactions returns empty when none are due', () async {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      await dao.insertRecurringTransaction(_makeRecurring(
        nextDate: futureDate,
        status: 'active',
      ));

      final due = await dao.getDueTransactions(DateTime.now());
      expect(due, isEmpty);
    });

    test('updates a recurring transaction', () async {
      final recurring = _makeRecurring();
      await dao.insertRecurringTransaction(recurring);

      final updated = recurring.copyWith(description: const Value('New description'));
      await dao.updateRecurringTransaction(updated);

      final retrieved = await dao.getById(recurring.id);
      expect(retrieved!.description, 'New description');
    });

    test('deletes a recurring transaction', () async {
      final recurring = _makeRecurring();
      await dao.insertRecurringTransaction(recurring);
      await dao.deleteRecurringTransaction(recurring.id);

      expect(await dao.getById(recurring.id), isNull);
    });

    test('markAsProcessed updates nextDate and updatedAt', () async {
      final today = DateTime.now();
      final nextOccurrence = today.add(const Duration(days: 30));
      final recurring = _makeRecurring(nextDate: today);
      await dao.insertRecurringTransaction(recurring);

      await dao.markAsProcessed(recurring.id, nextOccurrence);

      final retrieved = await dao.getById(recurring.id);
      expect(retrieved!.nextDate.year, nextOccurrence.year);
      expect(retrieved.nextDate.month, nextOccurrence.month);
      expect(retrieved.nextDate.day, nextOccurrence.day);
    });
  });
}
