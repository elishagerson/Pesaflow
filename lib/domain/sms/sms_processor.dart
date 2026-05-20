import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as developer;

import '../../data/database/app_database.dart';
import '../../data/models/sms_parsed.dart';
import '../../data/repositories/account_repository.dart';
import '../../data/repositories/transaction_repository.dart';
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

final smsProcessorProvider = Provider<SmsProcessor>((ref) {
  final accountRepo = ref.watch(accountRepositoryProvider);
  final transactionRepo = ref.watch(transactionRepositoryProvider);
  final deduplicator = ref.watch(deduplicatorProvider);
  final categorizer = ref.watch(autoCategorizerProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return SmsProcessor(
    accountRepo: accountRepo,
    transactionRepo: transactionRepo,
    deduplicator: deduplicator,
    categorizer: categorizer,
    notificationService: notificationService,
  );
});

class SmsProcessor {
  final AccountRepository _accountRepo;
  final TransactionRepository _transactionRepo;
  final Deduplicator _deduplicator;
  final AutoCategorizer _categorizer;
  final NotificationService _notificationService;

  SmsProcessor({
    required AccountRepository accountRepo,
    required TransactionRepository transactionRepo,
    required Deduplicator deduplicator,
    required AutoCategorizer categorizer,
    required NotificationService notificationService,
  })  : _accountRepo = accountRepo,
        _transactionRepo = transactionRepo,
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
          default:
            friendlyName = 'Carrier Account';
            type = 'mobile_money';
        }

        final newAccount = Account(
          id: const Uuid().v4(),
          name: friendlyName,
          type: type,
          balance: smsParsed.balanceAfter ?? 0,
          provider: provider,
          icon: type == 'bank' ? 'bank' : 'wallet',
          sortOrder: accounts.length + 1,
          isArchived: false,
          createdAt: DateTime.now(),
        );

        await _accountRepo.createAccount(newAccount);
        targetAccount = newAccount;
        developer.log('Auto-created account $friendlyName for provider $provider', name: 'SmsProcessor');
      } else if (smsParsed.balanceAfter != null) {
        // Update account balance based on current parsed balance after
        final updatedAccount = targetAccount.copyWith(
          balance: smsParsed.balanceAfter!,
        );
        await _accountRepo.updateAccount(updatedAccount);
      }

      // 7. Persist Transaction
      final isAutoApproved = catResult.confidence >= 0.90;
      final source = isAutoApproved ? 'sms_auto' : 'sms_reviewed';

      final transaction = Transaction(
        id: const Uuid().v4(),
        accountId: targetAccount.id,
        categoryId: catResult.category.id,
        amount: smsParsed.amount,
        type: smsParsed.type,
        description: smsParsed.senderOrRecipient,
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

      // 8. Trigger local notification
      final amountFormatted = 'Tsh ${(smsParsed.amount / 100).toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}';
      final alertTitle = isAutoApproved ? 'Transaction Auto-Logged' : 'Review Required';
      final alertBody = isAutoApproved
          ? '$amountFormatted ${smsParsed.type == 'income' ? 'received' : 'sent'} (${catResult.category.name}) ✓'
          : '$amountFormatted ${smsParsed.type == 'income' ? 'received' : 'sent'} — tap to review category';

      await _notificationService.showNotification(
        id: transaction.hashCode,
        title: alertTitle,
        body: alertBody,
      );

      return true;
    } catch (e, stack) {
      developer.log('SmsProcessor processing failure: $e', error: e, stackTrace: stack, name: 'SmsProcessor');
    }
    return false;
  }
}
