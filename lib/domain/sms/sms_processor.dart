import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as developer;

import '../../data/database/app_database.dart';
import '../../data/database/daos/transaction_dao.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/loan_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../data/repositories/recurring_transaction_repository.dart';
import '../../services/notification_service.dart';
import '../categorization/auto_categorizer.dart';
import 'deduplicator.dart';
import 'provider_matcher.dart';
import 'provider_config.dart';
import 'sms_classifier.dart';

final smsProcessorProvider = Provider<SmsProcessor>((ref) {
  final accountRepo = ref.watch(accountRepositoryProvider);
  final categoryRepo = ref.watch(categoryRepositoryProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  final loanRepo = ref.watch(loanRepositoryProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final recurringTransactionRepo = ref.watch(
    recurringTransactionRepositoryProvider,
  );
  final deduplicator = ref.watch(deduplicatorProvider);
  final categorizer = ref.watch(autoCategorizerProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return SmsProcessor(
    accountRepo: accountRepo,
    categoryRepo: categoryRepo,
    transactionRepo: transactionRepo,
    loanRepo: loanRepo,
    settingsRepo: settingsRepo,
    recurringTransactionRepo: recurringTransactionRepo,
    deduplicator: deduplicator,
    categorizer: categorizer,
    notificationService: notificationService,
  );
});

class SmsProcessor {
  final AccountRepository _accountRepo;
  final CategoryRepository _categoryRepo;
  final TransactionRepository _transactionRepo;
  final LoanRepository _loanRepo;
  final SettingsRepository _settingsRepo;
  final RecurringTransactionRepository _recurringTransactionRepo;
  final Deduplicator _deduplicator;
  final AutoCategorizer _categorizer;
  final NotificationService _notificationService;
  void Function(TransactionWithCategoryAndAccount item)? onReviewNeeded;

  // ── Multi-SMS coalescing buffer ──────────────────────────────────────
  // Providers sometimes dispatch multiple messages for one transaction
  // (e.g. a transfer alert + a separate fee notification).  We buffer
  // messages from the same provider inside a short debounce window,
  // concatenate them, and parse the combined text.  Individual messages
  // can trigger different parser rules (sent vs. fee) and produce
  // spurious duplicate transactions; the combined text hits the most
  // important rule first and produces a single correct result.
  final Map<String, List<_BufferedSms>> _messageBuffer = {};
  Timer? _flushTimer;
  static const _debounceWindow = Duration(milliseconds: 800);

  // ── In-memory content dedup cache ───────────────────────────────────
  // Catches the same SMS body arriving through multiple reception paths
  // (foreground listener, background handler, periodic inbox scan).
  final Set<_ContentKey> _recentContentKeys = {};
  static const _dedupCapacity = 200;

  SmsProcessor({
    required this._accountRepo,
    required this._categoryRepo,
    required this._transactionRepo,
    required this._loanRepo,
    required this._settingsRepo,
    required this._recurringTransactionRepo,
    required this._deduplicator,
    required this._categorizer,
    required this._notificationService,
    this.onReviewNeeded,
  });

  // ═════════════════════════════════════════════════════════════════════
  // PUBLIC ENTRY POINT
  // ═════════════════════════════════════════════════════════════════════

  /// Buffers the incoming SMS, coalesces multiple messages for the same
  /// transaction, then parses and persists the combined result.
  Future<bool> processSms(
    String sender,
    String body,
    DateTime timestamp,
  ) async {
    final provider = ProviderMatcher.matchProvider(sender, body: body);
    if (provider == null) {
      developer.log(
        'SMS ignored: Unrecognized sender shortcode $sender',
        name: 'SmsProcessor',
      );
      return false;
    }

    final key = _ContentKey(provider, body);

    // In-memory dedup — skip if we already buffered identical content
    if (_recentContentKeys.contains(key)) {
      developer.log(
        'SMS skipped (in-memory dedup) for $provider',
        name: 'SmsProcessor',
      );
      return false;
    }
    _recentContentKeys.add(key);
    if (_recentContentKeys.length > _dedupCapacity) {
      _recentContentKeys.clear();
    }

    _messageBuffer
        .putIfAbsent(provider, () => [])
        .add(_BufferedSms(sender: sender, body: body, timestamp: timestamp));

    _flushTimer?.cancel();
    _flushTimer = Timer(_debounceWindow, _flushBuffer);

    return true;
  }

  // ═════════════════════════════════════════════════════════════════════
  // BUFFER FLUSH
  // ═════════════════════════════════════════════════════════════════════

  void _flushBuffer() {
    final snapshot = Map<String, List<_BufferedSms>>.from(_messageBuffer);
    _messageBuffer.clear();

    for (final entry in snapshot.entries) {
      final messages = entry.value;
      if (messages.isEmpty) continue;
      final provider = entry.key;

      // Concatenate all buffered bodies — the primary parser rule fires
      // on the combined text and extracts the main transaction, while any
      // secondary fragments (fee, balance-only) blend into the context.
      final combinedBody = messages.map((e) => e.body).join('\n');
      final earliestTimestamp = messages
          .map((e) => e.timestamp)
          .reduce((a, b) => a.isBefore(b) ? a : b);

      unawaited(
        _processParsed(
          provider: provider,
          sender: messages.first.sender,
          body: combinedBody,
          timestamp: earliestTimestamp,
        ),
      );
    }
  }

  // ═════════════════════════════════════════════════════════════════════
  // CORE PROCESSING (extracted from original processSms)
  // ═════════════════════════════════════════════════════════════════════

  /// Parses, deduplicates, categorises, persists and notifies.
  /// The [provider] must already be resolved (no sender matching here).
  Future<void> _processParsed({
    required String provider,
    required String sender,
    required String body,
    required DateTime timestamp,
  }) async {
    String? loanId;
    try {
      // 2. Select the parser via provider registry
      final parser = ProviderRegistry.parserFor(provider);

      // 3. Parse raw text — try primary parser, then generic fallback
      bool usedGenericFallback = false;
      var smsParsed = parser.parse(body, timestamp);
      if (smsParsed == null) {
        final classification = SmsClassifier.classify(body);
        if (!classification.isTransaction) {
          developer.log(
            'SMS rejected by classifier as ${classification.label} '
            '(confidence: ${classification.transactionConfidence.toStringAsFixed(2)}) '
            'for provider $provider — reasons: ${classification.reasons.join("; ")}',
            name: 'SmsProcessor',
          );
          return;
        }

        developer.log(
          'SMS: primary parser returned null for $provider — trying generic fallback',
          name: 'SmsProcessor',
        );
        final fallback = ProviderRegistry.fallbackFor(provider);
        smsParsed = fallback.parse(body, timestamp);
        if (smsParsed == null) {
          developer.log(
            'SMS ignored: all parsers failed for provider $provider',
            name: 'SmsProcessor',
          );
          return;
        }
        usedGenericFallback = true;
      }
      final sms = smsParsed;

      // 3.5 Defensive classifier guard — some parsers (especially the
      //     generic fallback and broad Swahili patterns) can match promo
      //     messages that happen to contain an amount + verb.  Run the
      //     classifier on every successful parse and reject obvious promos.
      final defensiveClass = SmsClassifier.classify(body);
      if (!defensiveClass.isTransaction) {
        developer.log(
          'SMS rejected by defensive classifier: ${defensiveClass.label} '
          '(confidence: ${defensiveClass.transactionConfidence.toStringAsFixed(2)}) '
          'for provider $provider — reasons: ${defensiveClass.reasons.join("; ")}',
          name: 'SmsProcessor',
        );
        return;
      }

      // 4. Check for duplicate logs
      final isDeduplicationEnabled =
          await _settingsRepo.getSetting('sms_auto_deduplication') != 'false';
      if (isDeduplicationEnabled) {
        final isDup = await _deduplicator.isDuplicate(sms);
        if (isDup) {
          developer.log(
            'SMS ignored: Duplicate transaction detected. Reference: ${sms.reference}',
            name: 'SmsProcessor',
          );
          return;
        }
      }

      // 5. Categorize transaction
      final catResult = await _categorizer.categorize(
        type: sms.type,
        description: sms.senderOrRecipient,
        senderOrRecipient: sms.senderOrRecipient,
      );

      // 6. Find or auto-create account with provider + phone matching
      final accounts = await _accountRepo.getAllAccounts();
      final providerAccounts = accounts
          .where((a) => a.provider == provider)
          .toList();

      Account? targetAccount;
      if (providerAccounts.length == 1) {
        targetAccount = providerAccounts.first;
      } else if (providerAccounts.length > 1) {
        final phoneInSms = _extractPhoneNumber(sms.senderOrRecipient);
        if (phoneInSms != null) {
          final normalizedSmsPhone = _normalizePhone(phoneInSms);
          for (final acc in providerAccounts) {
            if (acc.phoneNumber != null &&
                _normalizePhone(acc.phoneNumber!) == normalizedSmsPhone) {
              targetAccount = acc;
              break;
            }
          }
        }
        if (targetAccount == null) {
          targetAccount = providerAccounts.first;
          developer.log(
            'Multiple accounts for provider $provider — using ${targetAccount.name} '
            '(phone: $phoneInSms vs accounts: ${providerAccounts.map((a) => '${a.name}:${a.phoneNumber}').join(', ')})',
            name: 'SmsProcessor',
          );
        }
      }

      if (targetAccount == null) {
        // Auto-create account
        final meta = ProviderRegistry.accountMetaFor(provider);
        final friendlyName = meta?.friendlyName ?? 'Carrier Account';
        final type = meta?.type ?? 'mobile_money';

        final newAccount = Account(
          id: const Uuid().v4(),
          name: friendlyName,
          type: type,
          balance: 0,
          provider: provider,
          icon: type == 'bank' ? 'bank' : 'wallet',
          sortOrder: accounts.length + 1,
          isArchived: false,
          createdAt: DateTime.now(),
        );

        await _accountRepo.createAccount(newAccount);
        targetAccount = newAccount;
        developer.log(
          'Auto-created account $friendlyName for provider $provider',
          name: 'SmsProcessor',
        );
      }

      // 6.5 Automated transfer detection & dynamic deduplication
      String finalType = sms.type;
      String finalCategoryId = catResult.category.id;
      String finalAccountId = targetAccount.id;
      String? finalDestinationAccountId;
      String finalDescription = sms.senderOrRecipient;
      double finalConfidence = catResult.confidence;

      Account? matchedOwnAccount;

      final destPhone = _extractPhoneNumber(sms.senderOrRecipient);
      if (destPhone != null) {
        final normalizedDestPhone = _normalizePhone(destPhone);
        for (final acc in accounts) {
          if (acc.id != targetAccount.id &&
              acc.phoneNumber != null &&
              _normalizePhone(acc.phoneNumber!) == normalizedDestPhone) {
            matchedOwnAccount = acc;
            break;
          }
        }
      }

      if (matchedOwnAccount != null) {
        finalType = 'transfer';
        finalConfidence = 1.0;

        final categories = await _categoryRepo.getAllCategories();
        final transferCat = categories.firstWhere(
          (cat) =>
              cat.type == 'transfer' ||
              cat.name.toLowerCase() == 'between accounts',
          orElse: () => catResult.category,
        );
        finalCategoryId = transferCat.id;

        if (sms.type == 'income') {
          finalAccountId = matchedOwnAccount.id;
          finalDestinationAccountId = targetAccount.id;
          finalDescription =
              'Transfer from ${matchedOwnAccount.name} to ${targetAccount.name}';
        } else {
          finalAccountId = targetAccount.id;
          finalDestinationAccountId = matchedOwnAccount.id;
          finalDescription =
              'Transfer from ${targetAccount.name} to ${matchedOwnAccount.name}';
        }

        final startWindow = sms.timestamp.subtract(const Duration(seconds: 90));
        final endWindow = sms.timestamp.add(const Duration(seconds: 90));
        final dupTransfer = await _transactionRepo.findFuzzyTransferMatch(
          accountId: finalAccountId,
          destinationAccountId: finalDestinationAccountId,
          amount: sms.amount,
          start: startWindow,
          end: endWindow,
        );

        if (dupTransfer != null) {
          developer.log(
            'Transfer already processed via other account SMS. Skipping duplicate creation.',
            name: 'SmsProcessor',
          );

          if (sms.balanceAfter != null) {
            final reconciledAccount = targetAccount.copyWith(
              balance: sms.balanceAfter!,
            );
            await _accountRepo.updateAccount(reconciledAccount);
          }
          return;
        }
      }

      // 7. Loan handling: create loan record for loan disbursements
      final activeTrackerId =
          await _settingsRepo.getSetting('active_tracker_id') ??
          'default_personal';
      if (finalType == 'loan') {
        loanId = const Uuid().v4();
        final loan = Loan(
          id: loanId,
          amount: sms.amount,
          remaining: sms.amount,
          status: 'active',
          provider: provider,
          description: finalDescription,
          sender: sms.senderOrRecipient,
          reference: sms.reference,
          disbursedAt: sms.timestamp,
          trackerId: activeTrackerId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _loanRepo.createLoan(loan);
        developer.log(
          'Created loan record $loanId for ${sms.amount} cents',
          name: 'SmsProcessor',
        );
      }

      // 7.5 Repayment detection: match expense to existing active loan
      if (loanId == null &&
          (finalType == 'expense' ||
              finalType == 'airtime' ||
              finalType == 'fee')) {
        final textToCheck = '$finalDescription $body'.toLowerCase();
        final isLoanRepayment =
            textToCheck.contains('loan') ||
            textToCheck.contains('mkopo') ||
            textToCheck.contains('repayment') ||
            textToCheck.contains('lipa mkopo') ||
            textToCheck.contains('loan repayment') ||
            textToCheck.contains('bustisha') ||
            textToCheck.contains('songesha') ||
            textToCheck.contains('nivushe');
        if (isLoanRepayment) {
          final activeLoans = await _loanRepo.getActiveLoans(
            trackerId: activeTrackerId,
          );
          if (activeLoans.isNotEmpty) {
            final exact = activeLoans
                .where((l) => l.remaining == sms.amount)
                .toList();
            if (exact.isNotEmpty) {
              loanId = exact.first.id;
              await _loanRepo.applyPayment(exact.first.id, sms.amount);
              developer.log(
                'Exact repayment match: loan ${exact.first.id} (remaining: ${exact.first.remaining}, paid: ${sms.amount})',
                name: 'SmsProcessor',
              );
            } else {
              final candidates = activeLoans
                  .where((l) => l.remaining >= sms.amount)
                  .toList();
              if (candidates.isNotEmpty) {
                final matched = candidates.reduce(
                  (a, b) =>
                      (a.remaining - sms.amount).abs() <
                          (b.remaining - sms.amount).abs()
                      ? a
                      : b,
                );
                loanId = matched.id;
                await _loanRepo.applyPayment(matched.id, sms.amount);
                developer.log(
                  'Approximate repayment match: loan ${matched.id} (remaining: ${matched.remaining}, paid: ${sms.amount})',
                  name: 'SmsProcessor',
                );
              } else {
                developer.log(
                  'No loan with remaining >= ${sms.amount} — skipping repayment link',
                  name: 'SmsProcessor',
                );
              }
            }
          }
        }
      }

      // 8. Persist Transaction
      if (usedGenericFallback && finalConfidence > 0.40) {
        finalConfidence = 0.40;
      }
      final isAutoApproved = finalConfidence >= 0.90;
      final source = isAutoApproved ? 'sms_auto' : 'sms_reviewed';

      final transaction = Transaction(
        id: const Uuid().v4(),
        accountId: finalAccountId,
        destinationAccountId: finalDestinationAccountId,
        loanId: loanId,
        categoryId: finalCategoryId,
        trackerId: activeTrackerId,
        amount: sms.amount,
        type: finalType,
        description: finalDescription,
        provider: sms.provider,
        sender: (sms.type == 'income' || sms.type == 'loan')
            ? sms.senderOrRecipient
            : null,
        recipient: sms.type == 'expense' ? sms.senderOrRecipient : null,
        reference: sms.reference,
        rawSms: sms.rawSmsBody,
        smsTimestamp: sms.timestamp,
        balanceAfter: sms.balanceAfter,
        source: source,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _transactionRepo.createTransaction(transaction);

      // 8.5 Recurring matching
      if (finalType == 'expense') {
        try {
          final activeRecs = await _recurringTransactionRepo
              .getActiveWithKeywords();
          final textToMatch = '$finalDescription $body'.toLowerCase();
          for (final rec in activeRecs) {
            if (rec.merchantKeywords == null) continue;
            final keywords = rec.merchantKeywords!
                .split(',')
                .map((k) => k.trim().toLowerCase());
            if (keywords.any((k) => k.isNotEmpty && textToMatch.contains(k))) {
              await _recurringTransactionRepo.recordPayment(
                rec.id,
                sms.amount,
                DateTime.now(),
              );
              developer.log(
                'Linked expense to recurring transaction ${rec.description ?? rec.id} (amount: ${sms.amount})',
                name: 'SmsProcessor',
              );
              break;
            }
          }
        } catch (e) {
          developer.log('Recurring match error: $e', name: 'SmsProcessor');
        }
      }

      // 9. Trigger local notification
      final amountFormatted =
          'Tsh ${(sms.amount / 100).toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}';
      final isCredit = sms.type == 'income' || sms.type == 'loan';
      final alertTitle = isAutoApproved
          ? 'Transaction Auto-Logged'
          : 'Review Required';
      final alertBody = isAutoApproved
          ? '$amountFormatted ${isCredit ? 'received' : 'sent'} (${catResult.category.name})'
          : '$amountFormatted ${isCredit ? 'received' : 'sent'} — tap to review category';

      try {
        await _notificationService.showNotification(
          id: transaction.hashCode,
          title: alertTitle,
          body: alertBody,
          needsReview: !isAutoApproved,
        );
      } catch (e) {
        developer.log(
          'Notification failed (transaction still saved): $e',
          name: 'SmsProcessor',
        );
      }

      // Fire callback for foreground dialog if review needed
      if (!isAutoApproved && onReviewNeeded != null) {
        final reviewItem = TransactionWithCategoryAndAccount(
          transaction: transaction,
          category: catResult.category,
          account: targetAccount,
        );
        onReviewNeeded!(reviewItem);
      }
    } catch (e, stack) {
      if (loanId != null) {
        try {
          await _loanRepo.deleteLoan(loanId);
          developer.log(
            'Rolled back orphaned loan $loanId due to processing failure',
            name: 'SmsProcessor',
          );
        } catch (e) {
          developer.log(
            'Loan rollback failed for $loanId: $e',
            name: 'SmsProcessor',
          );
        }
      }
      developer.log(
        'SmsProcessor processing failure: $e',
        error: e,
        stackTrace: stack,
        name: 'SmsProcessor',
      );
    }
  }

  /// Extracts a Tanzanian phone number from text.
  /// Supports formats: 07XXXXXXXX, 2557XXXXXXXX, +2557XXXXXXXX, and 7XXXXXXXX (subscriber only).
  String? _extractPhoneNumber(String text) {
    final regex = RegExp(r'(?:(?:\+?255|0)?[67]\d{8})(?!\d)');
    final match = regex.firstMatch(text);
    if (match == null) return null;
    return match.group(0)!.replaceAll('+', '');
  }

  /// Normalizes a Tanzanian phone number to its last 9 subscriber digits
  /// so that 0712345678, 255712345678, and 712345678 all compare equal.
  String _normalizePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 9) return digits.substring(digits.length - 9);
    return digits;
  }
}

/// A single SMS message held in the coalescing buffer.
class _BufferedSms {
  final String sender;
  final String body;
  final DateTime timestamp;

  const _BufferedSms({
    required this.sender,
    required this.body,
    required this.timestamp,
  });
}

/// Content-addressed key for the in-memory dedup cache.
/// Uses provider + full body so that two identical messages are
/// recognised as duplicates even when arriving through different paths.
class _ContentKey {
  final String provider;
  final String body;

  const _ContentKey(this.provider, this.body);

  @override
  bool operator ==(Object other) =>
      other is _ContentKey && other.provider == provider && other.body == body;

  @override
  int get hashCode => Object.hash(provider, body);
}
