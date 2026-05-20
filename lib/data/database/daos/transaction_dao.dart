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
  Stream<List<TransactionWithCategoryAndAccount>> watchRecentTransactions(int limit) {
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      innerJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
    ]);

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

  /// Inserts a transaction and adjusts the linked account's balance inside a transaction.
  Future<void> writeTransactionWithBalanceAdjustment(Transaction transaction) async {
    await attachedDatabase.transaction(() async {
      // 1. Insert the transaction
      await into(transactions).insert(transaction);

      // 2. Load the linked account
      final accountQuery = select(accounts)..where((t) => t.id.equals(transaction.accountId));
      final account = await accountQuery.getSingle();

      // 3. Compute new balance
      int balanceDelta = 0;
      final type = transaction.type.toLowerCase();
      if (type == 'income') {
        balanceDelta = transaction.amount;
      } else if (type == 'expense' || type == 'airtime' || type == 'fee') {
        balanceDelta = -transaction.amount;
      }

      final updatedAccount = account.copyWith(
        balance: account.balance + balanceDelta,
      );

      // 4. Update the account balance
      await update(accounts).replace(updatedAccount);
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
        if (type == 'income') {
          // Subtract original added income
          balanceDelta = -transactionObj.amount;
        } else if (type == 'expense' || type == 'airtime' || type == 'fee') {
          // Add back subtracted expense
          balanceDelta = transactionObj.amount;
        }

        final updatedAccount = account.copyWith(
          balance: account.balance + balanceDelta,
        );

        // 4. Update the account
        await update(accounts).replace(updatedAccount);
      }

      // 5. Delete the transaction
      await (delete(transactions)..where((t) => t.id.equals(transactionId))).go();
    });
  }
}
