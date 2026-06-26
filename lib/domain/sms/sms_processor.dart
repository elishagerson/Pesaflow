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
import '../../data/repositories/subscription_repository.dart';
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
  final subscriptionRepo = ref.watch(subscriptionRepositoryProvider);
  final deduplicator = ref.watch(deduplicatorProvider);
  final categorizer = ref.watch(autoCategorizerProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return SmsProcessor(
    accountRepo: accountRepo,
    categoryRepo: categoryRepo,
    transactionRepo: transactionRepo,
    loanRepo: loanRepo,
    settingsRepo: settingsRepo,
    subscriptionRepo: subscriptionRepo,
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
  final SubscriptionRepository _subscriptionRepo;
  final Deduplicator _deduplicator;
  final AutoCategorizer _categorizer;
  final NotificationService _notificationService;
  void Function(TransactionWithCategoryAndAccount item)? onReviewNeeded;

  SmsProcessor({
    required this._accountRepo,
    required this._categoryRepo,
    required this._transactionRepo,
    required this._loanRepo,
    required this._settingsRepo,
    required this._subscriptionRepo,
    required this._deduplicator,
    required this._categorizer,
    required this._notificationService,
    this.onReviewNeeded,
  });

  /// Processes a raw incoming SMS string and timestamp.
  /// If recognized as a transaction and not a duplicate, parses, categorizes,
  /// auto-creates accounts if needed, persists, and notifies the user.
  Future<bool> processSms(String sender, String body, DateTime timestamp) async {
    String? loanId;
    try {
      // 1. Identify provider
      final provider = ProviderMatcher.matchProvider(sender, body: body);
      if (provider == null) {
        developer.log('SMS ignored: Unrecognized sender shortcode $sender', name: 'SmsProcessor');
        return false;
      }

      // 2. Select the parser via provider registry
      final parser = ProviderRegistry.parserFor(provider);

      // 3. Parse raw text — try primary parser, then generic fallback
      bool usedGenericFallback = false;
      var smsParsed = parser.parse(body, timestamp);
      if (smsParsed == null) {
        // Run the classifier before falling back — if the message is clearly
        // promo/informational, skip the fallback parser entirely.
        final classification = SmsClassifier.classify(body);
        if (!classification.isTransaction) {
          developer.log(
            'SMS rejected by classifier as ${classification.label} '
            '(confidence: ${classification.transactionConfidence.toStringAsFixed(2)}) '
            'for provider $provider — reasons: ${classification.reasons.join("; ")}',
            name: 'SmsProcessor',
          );
          return false;
        }

        developer.log('SMS: primary parser returned null for $provider — trying generic fallback', name: 'SmsProcessor');
        final fallback = ProviderRegistry.fallbackFor(provider);
        smsParsed = fallback.parse(body, timestamp);
        if (smsParsed == null) {
          developer.log('SMS ignored: all parsers failed for provider $provider', name: 'SmsProcessor');
          return false;
        }
        usedGenericFallback = true;
      }
      final sms = smsParsed;

      // 4. Check for duplicate logs
      final isDeduplicationEnabled = await _settingsRepo.getSetting('sms_auto_deduplication') != 'false';
      if (isDeduplicationEnabled) {
        final isDup = await _deduplicator.isDuplicate(sms);
        if (isDup) {
          developer.log('SMS ignored: Duplicate transaction detected. Reference: ${sms.reference}', name: 'SmsProcessor');
          return false;
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
      final providerAccounts = accounts.where((a) => a.provider == provider).toList();

      Account? targetAccount;
      if (providerAccounts.length == 1) {
        targetAccount = providerAccounts.first;
      } else if (providerAccounts.length > 1) {
        final phoneInSms = _extractPhoneNumber(sms.senderOrRecipient);
        if (phoneInSms != null) {
          for (final acc in providerAccounts) {
            if (acc.phoneNumber != null && acc.phoneNumber == phoneInSms) {
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
          balance: 0, // start with 0. We will reconcile to exact balanceAfter post-transaction!
          provider: provider,
          icon: type == 'bank' ? 'bank' : 'wallet',
          sortOrder: accounts.length + 1,
          isArchived: false,
          createdAt: DateTime.now(),
        );

        await _accountRepo.createAccount(newAccount);
        targetAccount = newAccount;
        developer.log('Auto-created account $friendlyName for provider $provider', name: 'SmsProcessor');
      }

      // 6.5 Automated transfer detection & dynamic deduplication
      String finalType = sms.type;
      String finalCategoryId = catResult.category.id;
      String finalAccountId = targetAccount.id;
      String? finalDestinationAccountId;
      String finalDescription = sms.senderOrRecipient;
      double finalConfidence = catResult.confidence;

      // Determine if the destination is one of the user's own accounts.
      // We use phone number matching (reliable) with a name-based fallback.
      Account? matchedOwnAccount;

      // 1) Phone number matching — compare extracted destination phone against account phone numbers
      final destPhone = _extractPhoneNumber(sms.senderOrRecipient);
      if (destPhone != null) {
        for (final acc in accounts) {
          if (acc.id != targetAccount.id && acc.phoneNumber != null && acc.phoneNumber == destPhone) {
            matchedOwnAccount = acc;
            break;
          }
        }
      }

      if (matchedOwnAccount != null) {
        // This is a transfer between targetAccount and matchedOwnAccount!
        finalType = 'transfer';
        finalConfidence = 1.0;

        // Fetch "Between Accounts" category
        final categories = await _categoryRepo.getAllCategories();
        final transferCat = categories.firstWhere(
          (cat) => cat.type == 'transfer' || cat.name.toLowerCase() == 'between accounts',
          orElse: () => catResult.category,
        );
        finalCategoryId = transferCat.id;

        // Determine direction:
        // If this is an income SMS (deposit/credit to targetAccount), money is coming FROM matchedOwnAccount TO targetAccount.
        // If this is an expense SMS (withdrawal/debit from targetAccount), money is going FROM targetAccount TO matchedOwnAccount.
        if (sms.type == 'income') {
          finalAccountId = matchedOwnAccount.id;
          finalDestinationAccountId = targetAccount.id;
          finalDescription = 'Transfer from ${matchedOwnAccount.name} to ${targetAccount.name}';
        } else {
          finalAccountId = targetAccount.id;
          finalDestinationAccountId = matchedOwnAccount.id;
          finalDescription = 'Transfer from ${targetAccount.name} to ${matchedOwnAccount.name}';
        }

        // Dynamic Transfer Deduplication:
        // Check if there is an existing transfer within +-90s window
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
          // Already processed via the other account's SMS alert!
          // Skip inserting a new duplicate transaction.
          developer.log('Transfer already processed via other account SMS. Skipping duplicate creation.', name: 'SmsProcessor');
          
          // Still perform balance reconciliation for the targetAccount using the ground truth from its own SMS!
          if (sms.balanceAfter != null) {
            final reconciledAccount = targetAccount.copyWith(
              balance: sms.balanceAfter!,
            );
            await _accountRepo.updateAccount(reconciledAccount);
          }
          return true;
        }
      }

      // 7. Loan handling: create loan record for loan disbursements
      final activeTrackerId = await _settingsRepo.getSetting('active_tracker_id') ?? 'default_personal';
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
        developer.log('Created loan record $loanId for ${sms.amount} cents', name: 'SmsProcessor');
      }

      // 7.5 Repayment detection: match expense to existing active loan
      if (loanId == null && (finalType == 'expense' || finalType == 'airtime' || finalType == 'fee')) {
        final textToCheck = '$finalDescription $body'.toLowerCase();
        final isLoanRepayment = textToCheck.contains('loan') ||
            textToCheck.contains('mkopo') ||
            textToCheck.contains('repayment') ||
            textToCheck.contains('lipa mkopo') ||
            textToCheck.contains('loan repayment') ||
            textToCheck.contains('bustisha') ||
            textToCheck.contains('songesha') ||
            textToCheck.contains('nivushe');
        if (isLoanRepayment) {
          final activeLoans = await _loanRepo.getActiveLoans(trackerId: activeTrackerId);
          if (activeLoans.isNotEmpty) {
            // Match by amount: exact remaining match, then nearest with remaining >= amount
            final exact = activeLoans.where((l) => l.remaining == sms.amount).toList();
            if (exact.isNotEmpty) {
              loanId = exact.first.id;
              await _loanRepo.applyPayment(exact.first.id, sms.amount);
              developer.log('Exact repayment match: loan ${exact.first.id} (remaining: ${exact.first.remaining}, paid: ${sms.amount})', name: 'SmsProcessor');
            } else {
              final candidates = activeLoans.where((l) => l.remaining >= sms.amount).toList();
              if (candidates.isNotEmpty) {
                final matched = candidates.reduce((a, b) =>
                    (a.remaining - sms.amount).abs() < (b.remaining - sms.amount).abs() ? a : b);
                loanId = matched.id;
                await _loanRepo.applyPayment(matched.id, sms.amount);
                developer.log('Approximate repayment match: loan ${matched.id} (remaining: ${matched.remaining}, paid: ${sms.amount})', name: 'SmsProcessor');
              } else {
                developer.log('No loan with remaining >= ${sms.amount} — skipping repayment link', name: 'SmsProcessor');
              }
            }
          }
        }
      }

      // 8. Persist Transaction
      // Generic fallback results always go to review regardless of keyword confidence
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
        sender: (sms.type == 'income' || sms.type == 'loan') ? sms.senderOrRecipient : null,
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

      // 8.5 Subscription matching: link expense to subscription if recipient matches keywords
      if (finalType == 'expense') {
        try {
          final activeSubs = await _subscriptionRepo.getActive();
          final textToMatch = '$finalDescription $body'.toLowerCase();
          for (final sub in activeSubs) {
            final keywords = sub.merchantKeywords.split(',').map((k) => k.trim().toLowerCase());
            if (keywords.any((k) => k.isNotEmpty && textToMatch.contains(k))) {
              await _subscriptionRepo.recordPayment(sub.id, sms.amount, DateTime.now());
              developer.log('Linked expense to subscription ${sub.name} (amount: ${sms.amount})', name: 'SmsProcessor');
              break;
            }
          }
        } catch (e) {
          developer.log('Subscription match error: $e', name: 'SmsProcessor');
        }
      }

      // Balance reconciliation is handled by [TransactionDao.writeTransactionWithBalanceAdjustment],
      // which uses [transaction.balanceAfter] as ground truth when the SMS provided it,
      // otherwise falls back to delta-based adjustment. No redundant update needed here.

      // 8. Trigger local notification (non-fatal — transaction is already saved)
      final amountFormatted = 'Tsh ${(sms.amount / 100).toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}';
      final isCredit = sms.type == 'income' || sms.type == 'loan';
      final alertTitle = isAutoApproved ? 'Transaction Auto-Logged' : 'Review Required';
      final alertBody = isAutoApproved
          ? '$amountFormatted ${isCredit ? 'received' : 'sent'} (${catResult.category.name}) ✓'
          : '$amountFormatted ${isCredit ? 'received' : 'sent'} — tap to review category';

      try {
        await _notificationService.showNotification(
          id: transaction.hashCode,
          title: alertTitle,
          body: alertBody,
          needsReview: !isAutoApproved,
        );
      } catch (e) {
        developer.log('Notification failed (transaction still saved): $e', name: 'SmsProcessor');
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

      return true;
    } catch (e, stack) {
      // Rollback orphaned loan if one was created but transaction failed
      if (loanId != null) {
        try {
          await _loanRepo.deleteLoan(loanId);
          developer.log('Rolled back orphaned loan $loanId due to processing failure', name: 'SmsProcessor');
        } catch (e) {
          developer.log('Loan rollback failed for $loanId: $e', name: 'SmsProcessor');
        }
      }
      developer.log('SmsProcessor processing failure: $e', error: e, stackTrace: stack, name: 'SmsProcessor');
    }
    return false;
  }

  /// Extracts a Tanzanian phone number (07XX/06XX/255XX) from text.
  String? _extractPhoneNumber(String text) {
    final regex = RegExp(r'(?:\+?255|0)[67]\d{8}(?!\d)');
    return regex.firstMatch(text)?.group(0);
  }
}
