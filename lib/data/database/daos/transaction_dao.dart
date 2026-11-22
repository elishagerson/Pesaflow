import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/accounts_table.dart';
import '../tables/categories_table.dart';
import '../tables/transactions_table.dart';

part 'transaction_dao.g.dart';

class TransactionWithCategoryAndAccount {
  final Transaction transaction;
  final Category category;
  final Account? account;

  TransactionWithCategoryAndAccount({
    required this.transaction,
    required this.category,
    this.account,
  });
}

@DriftAccessor(tables: [Transactions, Accounts, Categories])
class TransactionDao extends DatabaseAccessor<AppDatabase>
    with _$TransactionDaoMixin {
  TransactionDao(super.db);

  /// One-shot version of [watchFilteredTransactions] — no stream overhead.
  Future<List<TransactionWithCategoryAndAccount>> getFilteredTransactions({
    String? accountId,
    String? categoryId,
    String? type,
    String? searchQuery,
    DateTime? startDate,
    DateTime? endDate,
    String? trackerId,
    int? amountMin,
    int? amountMax,
  }) async {
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      leftOuterJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
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
      query.where(
        transactions.description.like('%$searchQuery%') |
            transactions.sender.like('%$searchQuery%') |
            transactions.recipient.like('%$searchQuery%') |
            transactions.reference.like('%$searchQuery%'),
      );
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

    final rows = await query.get();
    return rows.map((row) {
      return TransactionWithCategoryAndAccount(
        transaction: row.readTable(transactions),
        category: row.readTable(categories),
        account: row.readTableOrNull(accounts),
      );
    }).toList();
  }

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
      leftOuterJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
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
      query.where(
        transactions.description.like('%$searchQuery%') |
            transactions.sender.like('%$searchQuery%') |
            transactions.recipient.like('%$searchQuery%') |
            transactions.reference.like('%$searchQuery%'),
      );
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
          account: row.readTableOrNull(accounts),
        );
      }).toList();
    });
  }

  /// Fetches the recent N transactions with category and account details.
  Stream<List<TransactionWithCategoryAndAccount>> watchRecentTransactions(
    int limit, {
    String? trackerId,
  }) {
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      leftOuterJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
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
          account: row.readTableOrNull(accounts),
        );
      }).toList();
    });
  }

  /// Inserts a transaction and adjusts the linked account(s) balance inside a transaction.
  ///
  /// NOTE: the balance is adjusted immediately for every source, including
  /// `sms_reviewed` items awaiting review. This is deliberate — a captured SMS is
  /// real money movement and the account must reflect it right away. Approval only
  /// flips `source` and re-asserts the carrier-reported balance; it must never
  /// apply a second delta (see [approveReviewedTransaction]).
  Future<void> writeTransactionWithBalanceAdjustment(
    Transaction transaction,
  ) async {
    await attachedDatabase.transaction(() async {
      // 1. Insert the transaction
      await into(transactions).insert(transaction);

      // 2. Skip balance adjustment if no account is linked
      final acctId = transaction.accountId;
      if (acctId == null) return;

      // 3. Load the linked account
      final accountQuery = select(accounts)..where((t) => t.id.equals(acctId));
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
        final destQuery = select(accounts)
          ..where((t) => t.id.equals(transaction.destinationAccountId!));
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

  /// Inserts a transaction without adjusting any account balance.
  /// Used for offline/record-only payments where no wallet should be affected.
  Future<void> insertTransactionWithoutBalanceAdjustment(
    Transaction transaction,
  ) async {
    await into(transactions).insert(transaction);
  }

  Future<void> insertTransactionsBatchWithoutBalanceAdjustment(
    List<Transaction> txs,
  ) async {
    await batch((b) {
      b.insertAll(transactions, txs, mode: InsertMode.insertOrIgnore);
    });
  }

  /// Deletes a transaction and reverses the linked account's balance adjustment inside a transaction.
  Future<void> deleteTransactionWithBalanceAdjustment(
    String transactionId,
  ) async {
    await attachedDatabase.transaction(() async {
      // 1. Fetch the transaction to know the amount and type
      final transQuery = select(transactions)
        ..where((t) => t.id.equals(transactionId));
      final transactionObj = await transQuery.getSingleOrNull();

      if (transactionObj == null) return;

      final acctId = transactionObj.accountId;
      if (acctId != null) {
        final accountQuery = select(accounts)
          ..where((t) => t.id.equals(acctId));
        final account = await accountQuery.getSingleOrNull();

        if (account != null) {
          int balanceDelta = 0;
          final type = transactionObj.type.toLowerCase();
          if (type == 'income' || type == 'loan') {
            balanceDelta = -transactionObj.amount;
          } else if (type == 'expense' || type == 'airtime' || type == 'fee') {
            balanceDelta = transactionObj.amount;
          } else if (type == 'transfer') {
            balanceDelta = transactionObj.amount;
          }

          final updatedAccount = account.copyWith(
            balance: account.balance + balanceDelta,
          );

          await update(accounts).replace(updatedAccount);
        }

        if (transactionObj.type.toLowerCase() == 'transfer' &&
            transactionObj.destinationAccountId != null) {
          final destQuery = select(accounts)
            ..where((t) => t.id.equals(transactionObj.destinationAccountId!));
          final destAccount = await destQuery.getSingleOrNull();
          if (destAccount != null) {
            final updatedDest = destAccount.copyWith(
              balance: destAccount.balance - transactionObj.amount,
            );
            await update(accounts).replace(updatedDest);
          }
        }
      }

      await (delete(
        transactions,
      )..where((t) => t.id.equals(transactionId))).go();
    });
  }

  /// Checks if a transaction with the given reference exists in the database.
  Future<bool> existsByReference(String reference) async {
    final query = select(transactions)
      ..where((t) => t.reference.equals(reference));
    final row = await query.getSingleOrNull();
    return row != null;
  }

  /// Retrieves a transaction matching the carrier reference code.
  Future<Transaction?> getTransactionByReference(String reference) {
    return (select(
      transactions,
    )..where((t) => t.reference.equals(reference))).getSingleOrNull();
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
      ..where(
        (t) =>
            t.provider.equals(provider) &
            t.type.equals(type) &
            t.amount.equals(amount) &
            t.smsTimestamp.isBiggerOrEqual(Constant(start)) &
            t.smsTimestamp.isSmallerOrEqual(Constant(end)),
      );
    return query.get();
  }

  /// Streams transactions that need user review (source = 'sms_reviewed').
  Stream<List<TransactionWithCategoryAndAccount>>
  watchReviewQueueTransactions() {
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      leftOuterJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
    ]);

    query.where(transactions.source.equals('sms_reviewed'));
    query.orderBy([OrderingTerm.desc(transactions.createdAt)]);

    return query.watch().map((rows) {
      return rows.map((row) {
        return TransactionWithCategoryAndAccount(
          transaction: row.readTable(transactions),
          category: row.readTable(categories),
          account: row.readTableOrNull(accounts),
        );
      }).toList();
    });
  }

  Future<void> updateTransactionWithBalanceAdjustment(
    Transaction updated,
  ) async {
    await attachedDatabase.transaction(() async {
      final oldQuery = select(transactions)
        ..where((t) => t.id.equals(updated.id));
      final old = await oldQuery.getSingleOrNull();
      if (old == null) {
        await into(transactions).insert(updated);
        return;
      }
      final oldAcctId = old.accountId;
      if (oldAcctId != null) {
        final acctQ = select(accounts)..where((t) => t.id.equals(oldAcctId));
        final acct = await acctQ.getSingleOrNull();
        if (acct != null) {
          final oldType = old.type.toLowerCase();
          int reverseDelta = 0;
          if (oldType == 'income' || oldType == 'loan') {
            reverseDelta = -old.amount;
          } else if (oldType == 'expense' ||
              oldType == 'airtime' ||
              oldType == 'fee') {
            reverseDelta = old.amount;
          } else if (oldType == 'transfer') {
            reverseDelta = old.amount;
          }
          await update(
            accounts,
          ).replace(acct.copyWith(balance: acct.balance + reverseDelta));
        }
      }
      if (old.type.toLowerCase() == 'transfer' &&
          old.destinationAccountId != null) {
        final destQ = select(accounts)
          ..where((t) => t.id.equals(old.destinationAccountId!));
        final dest = await destQ.getSingleOrNull();
        if (dest != null) {
          await update(
            accounts,
          ).replace(dest.copyWith(balance: dest.balance - old.amount));
        }
      }
      await update(transactions).replace(updated);
      final newAcctId = updated.accountId;
      if (newAcctId == null) return;
      final newAcctQ = select(accounts)..where((t) => t.id.equals(newAcctId));
      final newAcct = await newAcctQ.getSingleOrNull();
      if (newAcct == null) return;
      int newBalance;
      final newType = updated.type.toLowerCase();
      if (updated.balanceAfter != null) {
        newBalance = updated.balanceAfter!;
      } else {
        int delta = 0;
        if (newType == 'income' || newType == 'loan') {
          delta = updated.amount;
        } else if (newType == 'expense' ||
            newType == 'airtime' ||
            newType == 'fee') {
          delta = -updated.amount;
        } else if (newType == 'transfer') {
          delta = -updated.amount;
        }
        newBalance = newAcct.balance + delta;
      }
      await update(accounts).replace(newAcct.copyWith(balance: newBalance));
      if (newType == 'transfer' && updated.destinationAccountId != null) {
        final destQ = select(accounts)
          ..where((t) => t.id.equals(updated.destinationAccountId!));
        final dest = await destQ.getSingleOrNull();
        if (dest != null) {
          await update(
            accounts,
          ).replace(dest.copyWith(balance: dest.balance + updated.amount));
        }
      }
    });
  }

  /// Approves a reviewed transaction by updating its source to 'sms_auto',
  /// optionally changing its category, and applying the deferred balance adjustment.
  ///
  /// Idempotent with respect to balances: the deferred adjustment is applied only
  /// when the row was still awaiting review on entry. Re-approving an already
  /// approved transaction (double tap, stale batch selection) still applies the
  /// requested category change but does not move the balance again.
  Future<void> approveReviewedTransaction(
    String transactionId, {
    String? newCategoryId,
  }) async {
    await attachedDatabase.transaction(() async {
      final query = select(transactions)
        ..where((t) => t.id.equals(transactionId));
      final existing = await query.getSingleOrNull();
      if (existing == null) return;

      String? trackerId = existing.trackerId;
      if (trackerId == null) {
        final settingsQuery = db.select(db.appSettings)
          ..where((t) => t.key.equals('active_tracker_id'));
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

      // The insert path (writeTransactionWithBalanceAdjustment) already applied
      // this transaction's balance movement — including setting the carrier's
      // absolute balanceAfter as ground truth. Re-asserting balanceAfter here
      // would overwrite the current account balance with a stale value from the
      // original SMS timestamp, erasing all subsequent transaction movements
      // that have occurred since. Approval only flips the source field and
      // optionally updates the category — no balance change is needed.
    });
  }

  /// Finds the category ID of the most recent transaction that matches the description
  /// or sender/recipient to dynamically adapt auto-categorization based on past history.
  Future<List<String>> findRecentCategoriesForDescription(
    String description,
    String senderOrRecipient, {
    int limit = 3,
  }) async {
    final query = select(transactions)
      ..where(
        (t) =>
            t.description.equals(description) |
            t.sender.equals(senderOrRecipient) |
            t.recipient.equals(senderOrRecipient),
      )
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

  /// Fetches a single transaction with its category and account details by ID.
  Future<TransactionWithCategoryAndAccount?> getTransactionWithDetailsById(
    String id,
  ) async {
    final query = select(transactions).join([
      innerJoin(categories, categories.id.equalsExp(transactions.categoryId)),
      leftOuterJoin(accounts, accounts.id.equalsExp(transactions.accountId)),
    ])..where(transactions.id.equals(id));

    final row = await query.getSingleOrNull();
    if (row == null) return null;
    return TransactionWithCategoryAndAccount(
      transaction: row.readTable(transactions),
      category: row.readTable(categories),
      account: row.readTableOrNull(accounts),
    );
  }

  Future<Transaction?> findFuzzyTransferMatch({
    required String accountId,
    required String destinationAccountId,
    required int amount,
    required DateTime start,
    required DateTime end,
  }) async {
    final query = select(transactions)
      ..where(
        (t) =>
            t.type.equals('transfer') &
            t.amount.equals(amount) &
            ((t.accountId.equals(accountId) &
                    t.destinationAccountId.equals(destinationAccountId)) |
                (t.accountId.equals(destinationAccountId) &
                    t.destinationAccountId.equals(accountId))) &
            t.smsTimestamp.isBiggerOrEqual(Constant(start)) &
            t.smsTimestamp.isSmallerOrEqual(Constant(end)),
      );
    final results = await query.get();
    return results.isNotEmpty ? results.first : null;
  }

  /// Finds historical payments matching a recurring plan's keywords or description.
  Future<List<Transaction>> getPaymentsForKeywords(
    List<String> keywords, {
    String? categoryId,
    int limit = 10,
  }) async {
    if (keywords.isEmpty && categoryId == null) return [];

    final cleanKeywords = keywords
        .map((k) => k.trim().toLowerCase())
        .where((k) => k.isNotEmpty)
        .toList();

    final query = select(transactions)
      ..where((t) => t.type.equals('expense'))
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(limit * 3);

    final candidates = await query.get();

    final filtered = candidates
        .where((tx) {
          if (categoryId != null && tx.categoryId == categoryId) return true;
          final text =
              '${tx.description} ${tx.sender ?? ''} ${tx.recipient ?? ''}'
                  .toLowerCase();
          return cleanKeywords.any((kw) => text.contains(kw));
        })
        .take(limit)
        .toList();

    return filtered;
  }

  /// Automatically scans past expense transactions to detect recurring payment patterns
  /// (e.g. paying Zuku Fiber, LUKU, Rent, or DAWASA around the same cadence).
  Future<List<RecurringCandidate>> findRecurringCandidates({
    int minOccurrences = 2,
    int lookbackDays = 90,
    Set<String> existingKeywords = const {},
  }) async {
    final cutoff = DateTime.now().subtract(Duration(days: lookbackDays));

    final query = select(transactions)
      ..where(
        (t) =>
            t.type.equals('expense') &
            t.createdAt.isBiggerOrEqual(Constant(cutoff)),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]);

    final rows = await query.get();
    if (rows.length < minOccurrences) return [];

    // Group transactions by a normalized merchant key
    final Map<String, List<Transaction>> groups = {};
    for (final tx in rows) {
      final key = _extractNormalizedMerchant(tx.description, tx.recipient);
      if (key == null || key.length < 3) continue;

      // Skip if matches already tracked recurring keywords
      final isTracked = existingKeywords.any(
        (kw) => kw.isNotEmpty && (key.contains(kw) || kw.contains(key)),
      );
      if (isTracked) continue;

      groups.putIfAbsent(key, () => []).add(tx);
    }

    final List<RecurringCandidate> candidates = [];

    for (final entry in groups.entries) {
      final txs = entry.value;
      if (txs.length < minOccurrences) continue;

      // Check interval between consecutive transactions
      int totalDays = 0;
      for (int i = 1; i < txs.length; i++) {
        totalDays += txs[i].createdAt
            .difference(txs[i - 1].createdAt)
            .inDays
            .abs();
      }
      final avgInterval = totalDays / (txs.length - 1);

      String frequency = 'monthly';
      int intervalValue = 1;

      if (avgInterval >= 5 && avgInterval <= 10) {
        frequency = 'weekly';
      } else if (avgInterval >= 11 && avgInterval <= 18) {
        frequency = 'biweekly';
      } else if (avgInterval >= 22 && avgInterval <= 40) {
        frequency = 'monthly';
      } else {
        // Irregular or utility cadence (e.g., LUKU tokens bought twice a month)
        frequency = 'monthly';
      }

      final totalAmount = txs.fold<int>(0, (sum, t) => sum + t.amount);
      final avgAmount = totalAmount ~/ txs.length;

      final lastTx = txs.last;
      final suggestedNext = frequency == 'weekly'
          ? lastTx.createdAt.add(const Duration(days: 7))
          : frequency == 'biweekly'
          ? lastTx.createdAt.add(const Duration(days: 14))
          : DateTime(
              lastTx.createdAt.year,
              lastTx.createdAt.month + 1,
              lastTx.createdAt.day.clamp(1, 28),
            );

      // Clean title
      final cleanTitle = _formatMerchantTitle(lastTx.description, entry.key);

      candidates.add(
        RecurringCandidate(
          title: cleanTitle,
          averageAmountCents: avgAmount,
          frequency: frequency,
          intervalValue: intervalValue,
          categoryId: lastTx.categoryId,
          accountId: lastTx.accountId,
          keyword: entry.key,
          occurrenceCount: txs.length,
          lastDate: lastTx.createdAt,
          suggestedNextDate: suggestedNext,
        ),
      );
    }

    // Sort by latest transaction date and limit to top 5
    candidates.sort((a, b) => b.lastDate.compareTo(a.lastDate));
    return candidates.take(5).toList();
  }

  String? _extractNormalizedMerchant(String description, String? recipient) {
    String raw = (recipient != null && recipient.trim().isNotEmpty)
        ? recipient
        : description;

    raw = raw.toLowerCase().trim();

    // Strip common carrier prefixes
    raw = raw
        .replaceAll(
          RegExp(r'^(?:sent to|kwa|kwenda|paid to|payment to)\s+'),
          '',
        )
        .trim();

    // Remove phone numbers or digits
    raw = raw.replaceAll(RegExp(r'\b(?:255\d{9}|0\d{9}|\d+)\b'), '').trim();

    // Clean punctuation
    raw = raw.replaceAll(RegExp(r'[^\w\s]'), ' ').trim();

    // Common Tanzanian merchant keywords mapping
    if (raw.contains('luku') ||
        raw.contains('tanesco') ||
        raw.contains('gecl')) {
      return 'luku';
    }
    if (raw.contains('dawasa') || raw.contains('maji')) {
      return 'dawasa';
    }
    if (raw.contains('zuku')) return 'zuku';
    if (raw.contains('dstv') ||
        raw.contains('multichoice') ||
        raw.contains('gotv')) {
      return 'dstv';
    }
    if (raw.contains('azam')) return 'azam';
    if (raw.contains('startimes')) return 'startimes';
    if (raw.contains('smile')) return 'smile';
    if (raw.contains('ttcl')) return 'ttcl';
    if (raw.contains('netflix')) return 'netflix';
    if (raw.contains('spotify')) return 'spotify';
    if (raw.contains('kodi') || raw.contains('rent')) return 'rent';
    if (raw.contains('gym') || raw.contains('fitness')) return 'gym';

    final words = raw.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    if (words.isEmpty) return null;
    return words.take(2).join(' ');
  }

  String _formatMerchantTitle(String description, String key) {
    return switch (key) {
      'luku' => 'LUKU Electricity',
      'dawasa' => 'DAWASA Water',
      'zuku' => 'Zuku Fiber',
      'dstv' => 'DStv / MultiChoice',
      'azam' => 'Azam TV',
      'startimes' => 'StarTimes',
      'smile' => 'Smile 4G',
      'ttcl' => 'TTCL Fiber',
      'netflix' => 'Netflix',
      'spotify' => 'Spotify',
      'rent' => 'House Rent',
      'gym' => 'Gym Membership',
      _ =>
        description.trim().isNotEmpty
            ? description.trim()
            : key[0].toUpperCase() + key.substring(1),
    };
  }
}

/// Represents a potential recurring bill discovered from historical SMS transactions.
class RecurringCandidate {
  final String title;
  final int averageAmountCents;
  final String frequency;
  final int intervalValue;
  final String? categoryId;
  final String? accountId;
  final String keyword;
  final int occurrenceCount;
  final DateTime lastDate;
  final DateTime suggestedNextDate;

  const RecurringCandidate({
    required this.title,
    required this.averageAmountCents,
    required this.frequency,
    required this.intervalValue,
    this.categoryId,
    this.accountId,
    required this.keyword,
    required this.occurrenceCount,
    required this.lastDate,
    required this.suggestedNextDate,
  });
}
