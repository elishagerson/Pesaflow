import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/daos/transaction_dao.dart';

class PendingReviewNotifier
    extends Notifier<TransactionWithCategoryAndAccount?> {
  @override
  TransactionWithCategoryAndAccount? build() {
    return null;
  }

  void add(TransactionWithCategoryAndAccount item) {
    state = item;
  }

  void clear() {
    state = null;
  }
}

final pendingReviewProvider =
    NotifierProvider<PendingReviewNotifier, TransactionWithCategoryAndAccount?>(
      () {
        return PendingReviewNotifier();
      },
    );
