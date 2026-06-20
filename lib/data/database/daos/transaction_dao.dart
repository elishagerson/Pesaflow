import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/accounts_table.dart';
import '../tables/categories_table.dart';
import '../tables/transactions_table.dart';

part 'transaction_dao.g.dart';

class TransactionWithCategoryAndAccount {
  final Transaction transaction;
  final Category category;
  final Account account;

  TransactionWithCategoryAndAccount({
    required this.transaction,
    required this.category,
    required this.account,
  });
}

@DriftAccessor(tables: [Transactions, Accounts, Categories])
class TransactionDao extends DatabaseAccessor<AppDatabase> with _$TransactionDaoMixin {
  TransactionDao(super.db);

  /// Streams filtered transactions with full category and account details.
  Stream<List<TransactionWithCategoryAndAccount>> watchFilteredTransactions({
    String? accountId,
    String? categoryId,
    String? type,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    String? trackerId,
    int? amountMin,
    int? amountMax,
  }) {
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      innerJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
    ]);

    if (accountId != null) {
      query.where(transactions.accountId.equals(accountId));
    }
    if (categoryId != null) {
      query.where(transactions.categoryId.equals(categoryId));
    }
    if (type != null && type != 'All') {
      query.where(transactions.type.equals(type.toLowerCase()));
    }
    if (trackerId != null) {
      query.where(transactions.trackerId.equals(trackerId));
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      query.where(transactions.description.like('%$searchQuery%') |
                  transactions.sender.like('%$searchQuery%') |
                  transactions.recipient.like('%$searchQuery%') |
                  transactions.reference.like('%$searchQuery%'));
    }
    if (startDate != null) {
      query.where(transactions.createdAt.isBiggerOrEqual(Constant(startDate)));
    }
    if (endDate != null) {
      query.where(transactions.createdAt.isSmallerOrEqual(Constant(endDate)));
    }
    if (amountMin != null) {
      query.where(transactions.amount.isBiggerOrEqual(Constant(amountMin)));
    }
    if (amountMax != null) {
      query.where(transactions.amount.isSmallerOrEqual(Constant(amountMax)));
    }

    query.orderBy([OrderingTerm.desc(transactions.createdAt)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithCategoryAndAccount(
          transaction: row.readTable(transactions),
          category: row.readTable(categories),
          account: row.readTable(accounts),
        );
      }).toList();
    });
  }

  /// Fetches the recent N transactions with category and account details.
  Stream<List<TransactionWithCategoryAndAccount>> watchRecentTransactions(int limit, {String? trackerId}) {
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      innerJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
    ]);

    if (trackerId != null) {
      query.where(transactions.trackerId.equals(trackerId));
    }

    query.orderBy([OrderingTerm.desc(transactions.createdAt)]);
    query.limit(limit);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithCategoryAndAccount(
          transaction: row.readTable(transactions),
          category: row.readTable(categories),
          account: row.readTable(accounts),
        );
      }).toList();
    });
  }

  /// Inserts a transaction and adjusts the linked account(s) balance inside a transaction.
  Future<void> writeTransactionWithBalanceAdjustment(Transaction transaction) async {
    await attachedDatabase.transaction(() async {
      // 1. Insert the transaction
      await into(transactions).insert(transaction);

      // 2. Load the linked account
      final accountQuery = select(accounts)..where((t) => t.id.equals(transaction.accountId));
      final account = await accountQuery.getSingleOrNull();
      if (account == null) return;

      // 3. Compute new balance
      // If the SMS provided a carrier-reported balanceAfter, use it as ground truth.
      // Otherwise compute the delta from the transaction type.
      int newBalance;
      final type = transaction.type.toLowerCase();

      if (transaction.balanceAfter != null) {
        newBalance = transaction.balanceAfter!;
      } else {
        int balanceDelta = 0;
        if (type == 'income' || type == 'loan') {
          balanceDelta = transaction.amount;
        } else if (type == 'expense' || type == 'airtime' || type == 'fee') {
          balanceDelta = -transaction.amount;
        } else if (type == 'transfer') {
          balanceDelta = -transaction.amount;
        }
        newBalance = account.balance + balanceDelta;
      }

      final updatedAccount = account.copyWith(balance: newBalance);

      // 4. Update the source account balance
      await update(accounts).replace(updatedAccount);

      // 5. For transfers, also credit the destination account
      if (type == 'transfer' && transaction.destinationAccountId != null) {
        final destQuery = select(accounts)..where((t) => t.id.equals(transaction.destinationAccountId!));
        final destAccount = await destQuery.getSingleOrNull();
        if (destAccount != null) {
          // For transfers, always use delta for the destination (no carrier balance available).
          final updatedDest = destAccount.copyWith(
            balance: destAccount.balance + transaction.amount,
          );
          await update(accounts).replace(updatedDest);
        }
      }
    });
  }

  /// Deletes a transaction and reverses the linked account's balance adjustment inside a transaction.
  Future<void> deleteTransactionWithBalanceAdjustment(String transactionId) async {
    await attachedDatabase.transaction(() async {
      // 1. Fetch the transaction to know the amount and type
      final transQuery = select(transactions)..where((t) => t.id.equals(transactionId));
      final transactionObj = await transQuery.getSingleOrNull();

      if (transactionObj == null) return;

      // 2. Load the linked account
      final accountQuery = select(accounts)..where((t) => t.id.equals(transactionObj.accountId));
      final account = await accountQuery.getSingleOrNull();

      if (account != null) {
        // 3. Compute reversed balance
        int balanceDelta = 0;
        final type = transactionObj.type.toLowerCase();
        if (type == 'income' || type == 'loan') {
          // Subtract original added income
          balanceDelta = -transactionObj.amount;
        } else if (type == 'expense' || type == 'airtime' || type == 'fee') {
          // Add back subtracted expense
          balanceDelta = transactionObj.amount;
        } else if (type == 'transfer') {
          // Add back amount deducted from source
          balanceDelta = transactionObj.amount;
        }

        final updatedAccount = account.copyWith(
          balance: account.balance + balanceDelta,
        );

        // 4. Update the account
        await update(accounts).replace(updatedAccount);
      }

      // 5. For transfers, also reverse the destination credit
      if (transactionObj.type.toLowerCase() == 'transfer' && transactionObj.destinationAccountId != null) {
        final destQuery = select(accounts)..where((t) => t.id.equals(transactionObj.destinationAccountId!));
        final destAccount = await destQuery.getSingleOrNull();
        if (destAccount != null) {
          final updatedDest = destAccount.copyWith(
            balance: destAccount.balance - transactionObj.amount,
          );
          await update(accounts).replace(updatedDest);
        }
      }

      // 6. Delete the transaction
      await (delete(transactions)..where((t) => t.id.equals(transactionId))).go();
    });
  }

  /// Checks if a transaction with the given reference exists in the database.
  Future<bool> existsByReference(String reference) async {
    final query = select(transactions)..where((t) => t.reference.equals(reference));
    final row = await query.getSingleOrNull();
    return row != null;
  }

  /// Finds transactions matching exact amount, provider, and type within a time window.
  Future<List<Transaction>> getFuzzyMatches({
    required String provider,
    required String type,
    required int amount,
    required DateTime start,
    required DateTime end,
  }) async {
    final query = select(transactions)
      ..where((t) => t.provider.equals(provider) & 
                     t.type.equals(type) & 
                     t.amount.equals(amount) & 
                     t.createdAt.isBiggerOrEqual(Constant(start)) & 
                     t.createdAt.isSmallerOrEqual(Constant(end)));
    return query.get();
  }

  /// Streams transactions that need user review (source = 'sms_reviewed').
  Stream<List<TransactionWithCategoryAndAccount>> watchReviewQueueTransactions() {
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      innerJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
    ]);

    query.where(transactions.source.equals('sms_reviewed'));
    query.orderBy([OrderingTerm.desc(transactions.createdAt)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithCategoryAndAccount(
          transaction: row.readTable(transactions),
          category: row.readTable(categories),
          account: row.readTable(accounts),
        );
      }).toList();
    });
  }

  /// Approves a reviewed transaction by updating its source to 'sms_auto'
  /// and optionally changing its category.
  Future<void> approveReviewedTransaction(String transactionId, {String? newCategoryId}) async {
    final query = select(transactions)..where((t) => t.id.equals(transactionId));
    final existing = await query.getSingleOrNull();
    if (existing == null) return;

    String? trackerId = existing.trackerId;
    if (trackerId == null) {
      final settingsQuery = db.select(db.appSettings)..where((t) => t.key.equals('active_tracker_id'));
      final setting = await settingsQuery.getSingleOrNull();
      trackerId = setting?.value ?? 'default_personal';
    }

    final updated = existing.copyWith(
      source: 'sms_auto',
      categoryId: newCategoryId ?? existing.categoryId,
      trackerId: Value(trackerId),
      updatedAt: DateTime.now(),
    );
    await update(transactions).replace(updated);
  }

  /// Finds the category ID of the most recent transaction that matches the description
  /// or sender/recipient to dynamically adapt auto-categorization based on past history.
  Future<List<String>> findRecentCategoriesForDescription(String description, String senderOrRecipient, {int limit = 3}) async {
    final query = select(transactions)
      ..where((t) => t.description.equals(description) |
                     t.sender.equals(senderOrRecipient) |
                     t.recipient.equals(senderOrRecipient))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit);
    final rows = await query.get();
    return rows.map((r) => r.categoryId).toList();
  }

  /// Finds an existing transfer transaction between two accounts with the exact same amount
  /// within a specific time window.
  Future<Transaction?> getTransactionById(String id) async {
    final query = select(transactions)..where((t) => t.id.equals(id));
    return query.getSingleOrNull();
  }

  Future<Transaction?> findFuzzyTransferMatch({
    required String accountId,
    required String destinationAccountId,
    required int amount,
    required DateTime start,
    required DateTime end,
  }) async {
    final query = select(transactions)
      ..where((t) => t.type.equals('transfer') &
                     t.amount.equals(amount) &
                     ((t.accountId.equals(accountId) & t.destinationAccountId.equals(destinationAccountId)) |
                      (t.accountId.equals(destinationAccountId) & t.destinationAccountId.equals(accountId))) &
                     t.smsTimestamp.isBiggerOrEqual(Constant(start)) &
                     t.smsTimestamp.isSmallerOrEqual(Constant(end)));
    final results = await query.get();
    return results.isNotEmpty ? results.first : null;
  }
}

