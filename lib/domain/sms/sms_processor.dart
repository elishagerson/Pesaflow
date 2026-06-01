import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as developer;

import '../../data/database/app_database.dart';
import '../../data/database/daos/transaction_dao.dart';
import '../../data/models/sms_parsed.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/category_repository.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../data/repositories/settings_repository.dart';
import '../../services/notification_service.dart';
import '../categorization/auto_categorizer.dart';
import 'deduplicator.dart';
import 'provider_matcher.dart';
import 'parsers/sms_parser_interface.dart';
import 'parsers/mpesa_tz_parser.dart';
import 'parsers/airtel_tz_parser.dart';
import 'parsers/mixx_parser.dart';
import 'parsers/halopesa_parser.dart';
import 'parsers/bank_base.dart';
import 'parsers/selcom_pesa_parser.dart';

final smsProcessorProvider = Provider<SmsProcessor>((ref) {
  final accountRepo = ref.watch(accountRepositoryProvider);
  final categoryRepo = ref.watch(categoryRepositoryProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final deduplicator = ref.watch(deduplicatorProvider);
  final categorizer = ref.watch(autoCategorizerProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return SmsProcessor(
    accountRepo: accountRepo,
    categoryRepo: categoryRepo,
    transactionRepo: transactionRepo,
    settingsRepo: settingsRepo,
    deduplicator: deduplicator,
    categorizer: categorizer,
    notificationService: notificationService,
  );
});

class SmsProcessor {
  final AccountRepository _accountRepo;
  final CategoryRepository _categoryRepo;
  final TransactionRepository _transactionRepo;
  final SettingsRepository _settingsRepo;
  final Deduplicator _deduplicator;
  final AutoCategorizer _categorizer;
  final NotificationService _notificationService;
  void Function(TransactionWithCategoryAndAccount item)? onReviewNeeded;

  SmsProcessor({
    required AccountRepository accountRepo,
    required CategoryRepository categoryRepo,
    required TransactionRepository transactionRepo,
    required SettingsRepository settingsRepo,
    required Deduplicator deduplicator,
    required AutoCategorizer categorizer,
    required NotificationService notificationService,
    this.onReviewNeeded,
  })  : _accountRepo = accountRepo,
        _categoryRepo = categoryRepo,
        _transactionRepo = transactionRepo,
        _settingsRepo = settingsRepo,
        _deduplicator = deduplicator,
        _categorizer = categorizer,
        _notificationService = notificationService;

  /// Processes a raw incoming SMS string and timestamp.
  /// If recognized as a transaction and not a duplicate, parses, categorizes,
  /// auto-creates accounts if needed, persists, and notifies the user.
  Future<bool> processSms(String sender, String body, DateTime timestamp) async {
    try {
      // 1. Identify provider
      final provider = ProviderMatcher.matchProvider(sender);
      if (provider == null) {
        developer.log('SMS ignored: Unrecognized sender shortcode $sender', name: 'SmsProcessor');
        return false;
      }

      // 2. Select the parser
      SmsParser parser;
      switch (provider) {
        case 'M-Pesa_TZ':
          parser = MpesaTzParser();
          break;
        case 'AirtelMoney_TZ':
          parser = AirtelTzParser();
          break;
        case 'TigoPesa_TZ':
          parser = MixxParser();
          break;
        case 'Halopesa_TZ':
          parser = HalopesaParser();
          break;
        case 'NMB_Bank':
          parser = NmbBankParser();
          break;
        case 'CRDB_Bank':
          parser = CrdbBankParser();
          break;
        case 'NBC_Bank':
          parser = NbcBankParser();
          break;
        case 'SelcomPesa_TZ':
          parser = SelcomPesaParser();
          break;
        default:
          return false;
      }

      // 3. Parse raw text
      final smsParsed = parser.parse(body, timestamp);
      if (smsParsed == null) {
        developer.log('SMS ignored: Parsing failed for provider $provider', name: 'SmsProcessor');
        return false;
      }

      // 4. Check for duplicate logs
      final isDup = await _deduplicator.isDuplicate(smsParsed);
      if (isDup) {
        developer.log('SMS ignored: Duplicate transaction detected. Reference: ${smsParsed.reference}', name: 'SmsProcessor');
        return false;
      }

      // 5. Categorize transaction
      final catResult = await _categorizer.categorize(
        type: smsParsed.type,
        description: smsParsed.senderOrRecipient,
        senderOrRecipient: smsParsed.senderOrRecipient,
      );

      // 6. Find or auto-create account
      final accounts = await _accountRepo.getAllAccounts();
      Account? targetAccount;
      for (final acc in accounts) {
        if (acc.provider == provider) {
          targetAccount = acc;
          break;
        }
      }

      if (targetAccount == null) {
        // Auto-create account
        String friendlyName;
        String type;
        switch (provider) {
          case 'M-Pesa_TZ':
            friendlyName = 'M-Pesa';
            type = 'mobile_money';
            break;
          case 'AirtelMoney_TZ':
            friendlyName = 'Airtel Money';
            type = 'mobile_money';
            break;
          case 'TigoPesa_TZ':
            friendlyName = 'Tigo Pesa';
            type = 'mobile_money';
            break;
          case 'Halopesa_TZ':
            friendlyName = 'Halopesa';
            type = 'mobile_money';
            break;
          case 'NMB_Bank':
            friendlyName = 'NMB Bank';
            type = 'bank';
            break;
          case 'CRDB_Bank':
            friendlyName = 'CRDB Bank';
            type = 'bank';
            break;
          case 'NBC_Bank':
            friendlyName = 'NBC Bank';
            type = 'bank';
            break;
          case 'SelcomPesa_TZ':
            friendlyName = 'Selcom Pesa';
            type = 'mobile_money';
            break;
          default:
            friendlyName = 'Carrier Account';
            type = 'mobile_money';
        }

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
      String finalType = smsParsed.type;
      String finalCategoryId = catResult.category.id;
      String finalAccountId = targetAccount.id;
      String? finalDestinationAccountId;
      String finalDescription = smsParsed.senderOrRecipient;
      double finalConfidence = catResult.confidence;

      final textToScan = '${smsParsed.senderOrRecipient} ${body}'.toLowerCase();
      final providerKeywords = {
        'M-Pesa_TZ': ['mpesa', 'm-pesa', 'vodacom'],
        'AirtelMoney_TZ': ['airtel'],
        'TigoPesa_TZ': ['tigo', 'mixx', 'yas'],
        'Halopesa_TZ': ['halopesa', 'halo'],
        'CRDB_Bank': ['crdb'],
        'NMB_Bank': ['nmb'],
        'NBC_Bank': ['nbc'],
        'SelcomPesa_TZ': ['selcom'],
      };

      String? detectedOtherProvider;
      for (final entry in providerKeywords.entries) {
        if (entry.key == provider) continue;
        for (final keyword in entry.value) {
          if (textToScan.contains(keyword)) {
            detectedOtherProvider = entry.key;
            break;
          }
        }
        if (detectedOtherProvider != null) break;
      }

      if (detectedOtherProvider != null) {
        Account? otherAccount;
        for (final acc in accounts) {
          if (acc.provider == detectedOtherProvider) {
            otherAccount = acc;
            break;
          }
        }

        if (otherAccount != null) {
          // This is a transfer between targetAccount and otherAccount!
          finalType = 'transfer';
          finalConfidence = 1.0; // Auto-approves transfer

          // Fetch "Between Accounts" category
          final categories = await _categoryRepo.getAllCategories();
          final transferCat = categories.firstWhere(
            (cat) => cat.type == 'transfer' || cat.name.toLowerCase() == 'between accounts',
            orElse: () => catResult.category,
          );
          finalCategoryId = transferCat.id;

          // Determine direction:
          // If this is an income SMS (deposit/credit to targetAccount), money is coming FROM otherAccount TO targetAccount.
          // If this is an expense SMS (withdrawal/debit from targetAccount), money is going FROM targetAccount TO otherAccount.
          if (smsParsed.type == 'income') {
            finalAccountId = otherAccount.id;
            finalDestinationAccountId = targetAccount.id;
            finalDescription = 'Transfer from ${otherAccount.name} to ${targetAccount.name}';
          } else {
            finalAccountId = targetAccount.id;
            finalDestinationAccountId = otherAccount.id;
            finalDescription = 'Transfer from ${targetAccount.name} to ${otherAccount.name}';
          }

          // Dynamic Transfer Deduplication:
          // Check if there is an existing transfer within +-90s window
          final startWindow = smsParsed.timestamp.subtract(const Duration(seconds: 90));
          final endWindow = smsParsed.timestamp.add(const Duration(seconds: 90));
          final dupTransfer = await _transactionRepo.findFuzzyTransferMatch(
            accountId: finalAccountId,
            destinationAccountId: finalDestinationAccountId,
            amount: smsParsed.amount,
            start: startWindow,
            end: endWindow,
          );

          if (dupTransfer != null) {
            // Already processed via the other account's SMS alert!
            // Skip inserting a new duplicate transaction.
            developer.log('Transfer already processed via other account SMS. Skipping duplicate creation.', name: 'SmsProcessor');
            
            // Still perform balance reconciliation for the targetAccount using the ground truth from its own SMS!
            if (smsParsed.balanceAfter != null) {
              final reconciledAccount = targetAccount.copyWith(
                balance: smsParsed.balanceAfter!,
              );
              await _accountRepo.updateAccount(reconciledAccount);
            }
            return true;
          }
        }
      }

      // 7. Persist Transaction
      final isAutoApproved = finalConfidence >= 0.90;
      final source = isAutoApproved ? 'sms_auto' : 'sms_reviewed';
      final activeTrackerId = await _settingsRepo.getSetting('active_tracker_id') ?? 'default_personal';

      final transaction = Transaction(
        id: const Uuid().v4(),
        accountId: finalAccountId,
        destinationAccountId: finalDestinationAccountId,
        categoryId: finalCategoryId,
        trackerId: activeTrackerId,
        amount: smsParsed.amount,
        type: finalType,
        description: finalDescription,
        provider: smsParsed.provider,
        sender: smsParsed.type == 'income' ? smsParsed.senderOrRecipient : null,
        recipient: smsParsed.type == 'expense' ? smsParsed.senderOrRecipient : null,
        reference: smsParsed.reference,
        rawSms: smsParsed.rawSmsBody,
        smsTimestamp: smsParsed.timestamp,
        balanceAfter: smsParsed.balanceAfter,
        source: source,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _transactionRepo.createTransaction(transaction);

      // Reconcile account balance to the exact balanceAfter specified in the SMS,
      // resolving any double-adjustments and repairing out-of-sync balances.
      if (smsParsed.balanceAfter != null) {
        final currentAccount = await _accountRepo.getAccountById(targetAccount.id);
        if (currentAccount != null) {
          final reconciledAccount = currentAccount.copyWith(
            balance: smsParsed.balanceAfter!,
          );
          await _accountRepo.updateAccount(reconciledAccount);
        }
      }

      // 8. Trigger local notification (non-fatal — transaction is already saved)
      final amountFormatted = 'Tsh ${(smsParsed.amount / 100).toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}';
      final alertTitle = isAutoApproved ? 'Transaction Auto-Logged' : 'Review Required';
      final alertBody = isAutoApproved
          ? '$amountFormatted ${smsParsed.type == 'income' ? 'received' : 'sent'} (${catResult.category.name}) ✓'
          : '$amountFormatted ${smsParsed.type == 'income' ? 'received' : 'sent'} — tap to review category';

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
      developer.log('SmsProcessor processing failure: $e', error: e, stackTrace: stack, name: 'SmsProcessor');
    }
    return false;
  }
}
