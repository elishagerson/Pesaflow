import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/app_database.dart';
import '../../data/database/daos/transaction_dao.dart';

class PendingReviewNotifier extends StateNotifier<TransactionWithCategoryAndAccount?> {
  PendingReviewNotifier() : super(null);

  void add(TransactionWithCategoryAndAccount item) {
    state = item;
  }

  void clear() {
    state = null;
  }
}

final pendingReviewProvider = StateNotifierProvider<PendingReviewNotifier, TransactionWithCategoryAndAccount?>((ref) {
  return PendingReviewNotifier();
});
