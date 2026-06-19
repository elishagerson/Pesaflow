import 'dart:developer' as developer;
import 'package:drift/drift.dart';
import '../app_database.dart';

class SubscriptionDao {
  final AppDatabase db;
  SubscriptionDao(this.db);

  Stream<List<Subscription>> watchAll() => db.select(db.subscriptions).watch();

  Future<List<Subscription>> getAll() => db.select(db.subscriptions).get();

  Future<Subscription?> getById(String id) =>
      (db.select(db.subscriptions)..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<List<Subscription>> getActive() =>
      (db.select(db.subscriptions)..where((t) => t.status.equals('active'))).get();

  Future<List<Subscription>> getDue(DateTime asOf) =>
      (db.select(db.subscriptions)
            ..where((t) => t.status.equals('active') & t.nextDueDate.isSmallerOrEqual(Constant(asOf))))
          .get();

  Future<void> createSubscription(Subscription subscription) async {
    await db.into(db.subscriptions).insert(subscription);
  }

  Future<void> updateSubscription(Subscription subscription) async {
    await db.update(db.subscriptions).replace(subscription);
  }

  Future<void> deleteSubscription(String id) async {
    await (db.delete(db.subscriptions)..where((t) => t.id.equals(id))).go();
  }

  Future<void> recordPayment(String id, int amount, DateTime paidAt) async {
    final sub = await getById(id);
    if (sub == null) return;

    final nextDue = _advanceDate(sub.nextDueDate, sub.frequency, sub.intervalValue);
    await (db.update(db.subscriptions)..where((t) => t.id.equals(id))).write(
      SubscriptionsCompanion(
        lastPaidDate: Value(paidAt),
        totalPaid: Value(sub.totalPaid + amount),
        paymentCount: Value(sub.paymentCount + 1),
        nextDueDate: Value(nextDue),
        updatedAt: Value(DateTime.now()),
      ),
    );
    developer.log('Recorded payment for subscription ${sub.name}: +$amount (total: ${sub.totalPaid + amount})', name: 'SubscriptionDao');
  }

  DateTime _advanceDate(DateTime from, String frequency, int interval) {
    switch (frequency) {
      case 'weekly':
        return DateTime(from.year, from.month, from.day + 7 * interval);
      case 'biweekly':
        return DateTime(from.year, from.month, from.day + 14 * interval);
      case 'monthly':
        return DateTime(from.year, from.month + interval, from.day);
      case 'quarterly':
        return DateTime(from.year, from.month + 3 * interval, from.day);
      case 'yearly':
        return DateTime(from.year + interval, from.month, from.day);
      default:
        return DateTime(from.year, from.month + interval, from.day);
    }
  }
}
