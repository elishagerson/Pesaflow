import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/app_database.dart';
import '../database/daos/subscription_dao.dart';
import '../database/database_providers.dart';

class SubscriptionRepository {
  final SubscriptionDao _dao;
  SubscriptionRepository(this._dao);

  Stream<List<Subscription>> watchAll() => _dao.watchAll();
  Future<List<Subscription>> getAll() => _dao.getAll();
  Future<Subscription?> getById(String id) => _dao.getById(id);
  Future<List<Subscription>> getActive() => _dao.getActive();
  Future<List<Subscription>> getDue(DateTime asOf) => _dao.getDue(asOf);
  Future<void> createSubscription(Subscription subscription) => _dao.createSubscription(subscription);
  Future<void> updateSubscription(Subscription subscription) => _dao.updateSubscription(subscription);
  Future<void> deleteSubscription(String id) => _dao.deleteSubscription(id);
  Future<void> recordPayment(String id, int amount, DateTime paidAt) => _dao.recordPayment(id, amount, paidAt);
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  final dao = ref.watch(subscriptionDaoProvider);
  return SubscriptionRepository(dao);
});
