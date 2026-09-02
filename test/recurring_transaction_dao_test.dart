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

  RecurringTransaction makeRecurring({
    String? id,
    String frequency = 'monthly',
    int intervalValue = 1,
    DateTime? nextDate,
    String status = 'active',
    DateTime? endDate,
    int amount = 5000000,
  }) {
    return RecurringTransaction(
      id: id ?? const Uuid().v4(),
      accountId: 'test_account',
      categoryId: 'test_category',
      amount: amount,
      type: 'expense',
      description: 'Test recurring',
      frequency: frequency,
      intervalValue: intervalValue,
      nextDate: nextDate ?? DateTime.now(),
      endDate: endDate,
      status: status,
      trackerId: 'default_personal',
      totalPaid: 0,
      paymentCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('RecurringTransactionDao', () {
    test('inserts and retrieves a recurring transaction', () async {
      final recurring = makeRecurring();
      await dao.insertRecurringTransaction(recurring);

      final retrieved = await dao.getById(recurring.id);
      expect(retrieved, isNotNull);
      expect(retrieved!.amount, 5000000);
      expect(retrieved.frequency, 'monthly');
      expect(retrieved.status, 'active');
    });

    test('getAll returns all recurring transactions', () async {
      await dao.insertRecurringTransaction(makeRecurring(frequency: 'weekly'));
      await dao.insertRecurringTransaction(makeRecurring(frequency: 'monthly'));

      final all = await dao.getAll();
      expect(all.length, 2);
    });

    test('getDueTransactions returns only active recurring txs with nextDate <= given date', () async {
      final pastDate = DateTime.now().subtract(const Duration(days: 5));
      final futureDate = DateTime.now().add(const Duration(days: 5));

      await dao.insertRecurringTransaction(makeRecurring(
        nextDate: pastDate,
        status: 'active',
      ));
      await dao.insertRecurringTransaction(makeRecurring(
        nextDate: futureDate,
        status: 'active',
      ));
      await dao.insertRecurringTransaction(makeRecurring(
        nextDate: pastDate,
        status: 'paused',
      ));

      final due = await dao.getDueTransactions(DateTime.now());
      expect(due.length, 1);
      expect(due.first.status, 'active');
    });

    test('getDueTransactions returns empty when none are due', () async {
      final futureDate = DateTime.now().add(const Duration(days: 30));
      await dao.insertRecurringTransaction(makeRecurring(
        nextDate: futureDate,
        status: 'active',
      ));

      final due = await dao.getDueTransactions(DateTime.now());
      expect(due, isEmpty);
    });

    test('updates a recurring transaction', () async {
      final recurring = makeRecurring();
      await dao.insertRecurringTransaction(recurring);

      final updated = recurring.copyWith(description: const Value('New description'));
      await dao.updateRecurringTransaction(updated);

      final retrieved = await dao.getById(recurring.id);
      expect(retrieved!.description, 'New description');
    });

    test('deletes a recurring transaction', () async {
      final recurring = makeRecurring();
      await dao.insertRecurringTransaction(recurring);
      await dao.deleteRecurringTransaction(recurring.id);

      expect(await dao.getById(recurring.id), isNull);
    });

    test('markAsProcessed updates nextDate and updatedAt', () async {
      final today = DateTime.now();
      final nextOccurrence = today.add(const Duration(days: 30));
      final recurring = makeRecurring(nextDate: today);
      await dao.insertRecurringTransaction(recurring);

      await dao.markAsProcessed(recurring.id, nextOccurrence);

      final retrieved = await dao.getById(recurring.id);
      expect(retrieved!.nextDate.year, nextOccurrence.year);
      expect(retrieved.nextDate.month, nextOccurrence.month);
      expect(retrieved.nextDate.day, nextOccurrence.day);
    });
  });

  group('recordPayment advances nextDate correctly', () {
    test('monthly: Jan 31 + 1mo = Feb 28 (non-leap)', () async {
      final jan31 = DateTime(2025, 1, 31);
      final r = makeRecurring(nextDate: jan31, frequency: 'monthly');
      await dao.insertRecurringTransaction(r);

      await dao.recordPayment(r.id, 1000, DateTime(2025, 1, 31));

      final result = await dao.getById(r.id);
      expect(result!.nextDate, DateTime(2025, 2, 28));
    });

    test('monthly: Jan 31 + 1mo = Feb 29 (leap year)', () async {
      final jan31 = DateTime(2024, 1, 31);
      final r = makeRecurring(nextDate: jan31, frequency: 'monthly');
      await dao.insertRecurringTransaction(r);

      await dao.recordPayment(r.id, 1000, DateTime(2024, 1, 31));

      final result = await dao.getById(r.id);
      expect(result!.nextDate, DateTime(2024, 2, 29));
    });

    test('monthly: Mar 31 + 1mo = Apr 30', () async {
      final mar31 = DateTime(2025, 3, 31);
      final r = makeRecurring(nextDate: mar31, frequency: 'monthly');
      await dao.insertRecurringTransaction(r);

      await dao.recordPayment(r.id, 1000, DateTime(2025, 3, 31));

      final result = await dao.getById(r.id);
      expect(result!.nextDate, DateTime(2025, 4, 30));
    });

    test('quarterly: Jan 31 + 3mo = Apr 30', () async {
      final jan31 = DateTime(2025, 1, 31);
      final r = makeRecurring(nextDate: jan31, frequency: 'quarterly');
      await dao.insertRecurringTransaction(r);

      await dao.recordPayment(r.id, 1000, DateTime(2025, 1, 31));

      final result = await dao.getById(r.id);
      expect(result!.nextDate, DateTime(2025, 4, 30));
    });

    test('monthly interval=2: Jan 15 + 2mo = Mar 15', () async {
      final jan15 = DateTime(2025, 1, 15);
      final r = makeRecurring(nextDate: jan15, frequency: 'monthly', intervalValue: 2);
      await dao.insertRecurringTransaction(r);

      await dao.recordPayment(r.id, 1000, DateTime(2025, 1, 15));

      final result = await dao.getById(r.id);
      expect(result!.nextDate, DateTime(2025, 3, 15));
    });

    test('weekly: +7 days', () async {
      final monday = DateTime(2025, 6, 2);
      final r = makeRecurring(nextDate: monday, frequency: 'weekly');
      await dao.insertRecurringTransaction(r);

      await dao.recordPayment(r.id, 1000, DateTime(2025, 6, 2));

      final result = await dao.getById(r.id);
      expect(result!.nextDate, DateTime(2025, 6, 9));
    });

    test('biweekly: +14 days', () async {
      final start = DateTime(2025, 6, 1);
      final r = makeRecurring(nextDate: start, frequency: 'biweekly');
      await dao.insertRecurringTransaction(r);

      await dao.recordPayment(r.id, 1000, DateTime(2025, 6, 1));

      final result = await dao.getById(r.id);
      expect(result!.nextDate, DateTime(2025, 6, 15));
    });

    test('yearly: Feb 29 (leap) + 1yr = Feb 28 (non-leap)', () async {
      final feb29 = DateTime(2024, 2, 29);
      final r = makeRecurring(nextDate: feb29, frequency: 'yearly');
      await dao.insertRecurringTransaction(r);

      await dao.recordPayment(r.id, 1000, DateTime(2024, 2, 29));

      final result = await dao.getById(r.id);
      expect(result!.nextDate, DateTime(2025, 2, 28));
    });

    test('yearly: Feb 28 (non-leap) + 1yr = Feb 28', () async {
      final feb28 = DateTime(2025, 2, 28);
      final r = makeRecurring(nextDate: feb28, frequency: 'yearly');
      await dao.insertRecurringTransaction(r);

      await dao.recordPayment(r.id, 1000, DateTime(2025, 2, 28));

      final result = await dao.getById(r.id);
      expect(result!.nextDate, DateTime(2026, 2, 28));
    });
  });

  group('endDate enforcement', () {
    test('recordPayment returns false when endDate has passed', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
      final r = makeRecurring(
        nextDate: yesterday,
        endDate: twoDaysAgo,
      );
      await dao.insertRecurringTransaction(r);

      final result = await dao.recordPayment(r.id, 1000, DateTime.now());
      expect(result, isFalse);

      final check = await dao.getById(r.id);
      expect(check!.totalPaid, 0);
      expect(check.paymentCount, 0);
    });

    test('recordPayment accepts payment when nextDate equals endDate (last occurrence)', () async {
      final today = DateTime.now();
      final r = makeRecurring(
        nextDate: today,
        endDate: today,
      );
      await dao.insertRecurringTransaction(r);

      final result = await dao.recordPayment(r.id, 1000, today);
      expect(result, isTrue);

      final check = await dao.getById(r.id);
      expect(check!.totalPaid, 1000);
    });

    test('recordPayment advances when nextDate is before endDate', () async {
      final tomorrow = DateTime.now().add(const Duration(days: 1));
      final nextWeek = DateTime.now().add(const Duration(days: 7));
      final r = makeRecurring(
        nextDate: tomorrow,
        endDate: nextWeek,
        frequency: 'weekly',
      );
      await dao.insertRecurringTransaction(r);

      final result = await dao.recordPayment(r.id, 1000, tomorrow);
      expect(result, isTrue);

      final check = await dao.getById(r.id);
      expect(check!.totalPaid, 1000);
    });

    test('recordPayment sets status to cancelled when nextDate would pass endDate', () async {
      final endDate = DateTime(2025, 7, 15);
      final r = makeRecurring(
        nextDate: DateTime(2025, 7, 10),
        endDate: endDate,
        frequency: 'monthly',
      );
      await dao.insertRecurringTransaction(r);

      await dao.recordPayment(r.id, 1000, DateTime(2025, 7, 10));

      final check = await dao.getById(r.id);
      expect(check!.status, 'cancelled');
    });

    test('getDueTransactions still returns items whose endDate has passed', () async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final r = makeRecurring(
        nextDate: yesterday,
        endDate: yesterday,
        status: 'active',
      );
      await dao.insertRecurringTransaction(r);

      final due = await dao.getDueTransactions(DateTime.now());
      expect(due.length, 1);
    });
  });

  group('duplicate payment prevention', () {
    test('recordPayment rejects duplicate within 30 minutes', () async {
      final r = makeRecurring(nextDate: DateTime.now());
      await dao.insertRecurringTransaction(r);

      await dao.recordPayment(r.id, 1000, DateTime.now());
      final second = await dao.recordPayment(r.id, 1000, DateTime.now());
      expect(second, isFalse);

      final check = await dao.getById(r.id);
      expect(check!.paymentCount, 1);
    });

    test('recordPayment accepts payment after 30 minutes', () async {
      final r = makeRecurring(nextDate: DateTime.now());
      await dao.insertRecurringTransaction(r);

      await dao.recordPayment(r.id, 1000, DateTime.now());
      final later = DateTime.now().add(const Duration(minutes: 31));
      final second = await dao.recordPayment(r.id, 1000, later);
      expect(second, isTrue);

      final check = await dao.getById(r.id);
      expect(check!.paymentCount, 2);
    });
  });

  group('toggleStatus', () {
    test('toggles active to paused', () async {
      final r = makeRecurring(status: 'active');
      await dao.insertRecurringTransaction(r);

      await dao.toggleStatus(r.id);

      final check = await dao.getById(r.id);
      expect(check!.status, 'paused');
    });

    test('toggles paused to active', () async {
      final r = makeRecurring(status: 'paused');
      await dao.insertRecurringTransaction(r);

      await dao.toggleStatus(r.id);

      final check = await dao.getById(r.id);
      expect(check!.status, 'active');
    });
  });
}
