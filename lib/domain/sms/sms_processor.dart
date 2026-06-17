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
  final loanRepo = ref.watch(loanRepositoryProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  final deduplicator = ref.watch(deduplicatorProvider);
  final categorizer = ref.watch(autoCategorizerProvider);
  final notificationService = ref.watch(notificationServiceProvider);
  return SmsProcessor(
    accountRepo: accountRepo,
    categoryRepo: categoryRepo,
    transactionRepo: transactionRepo,
    loanRepo: loanRepo,
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
  final LoanRepository _loanRepo;
  final SettingsRepository _settingsRepo;
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
    required this._deduplicator,
    required this._categorizer,
    required this._notificationService,
    this.onReviewNeeded,
  });

  /// Processes a raw incoming SMS string and timestamp.
  /// If recognized as a transaction and not a duplicate, parses, categorizes,
  /// auto-creates accounts if needed, persists, and notifies the user.
  Future<bool> processSms(String sender, String body, DateTime timestamp) async {
    try {
      // 1. Identify provider
      final provider = ProviderMatcher.matchProvider(sender, body: body);
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
      final isDeduplicationEnabled = await _settingsRepo.getSetting('sms_auto_deduplication') != 'false';
      if (isDeduplicationEnabled) {
        final isDup = await _deduplicator.isDuplicate(smsParsed);
        if (isDup) {
          developer.log('SMS ignored: Duplicate transaction detected. Reference: ${smsParsed.reference}', name: 'SmsProcessor');
          return false;
        }
      }

      // 5. Categorize transaction
      final catResult = await _categorizer.categorize(
        type: smsParsed.type,
        description: smsParsed.senderOrRecipient,
        senderOrRecipient: smsParsed.senderOrRecipient,
      );

      // 6. Find or auto-create account with provider + phone matching
      final accounts = await _accountRepo.getAllAccounts();
      final providerAccounts = accounts.where((a) => a.provider == provider).toList();

      Account? targetAccount;
      if (providerAccounts.length == 1) {
        targetAccount = providerAccounts.first;
      } else if (providerAccounts.length > 1) {
        final phoneInSms = _extractPhoneNumber(smsParsed.senderOrRecipient);
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

      // Determine if the destination is one of the user's own accounts.
      // We use phone number matching (reliable) with a name-based fallback.
      Account? matchedOwnAccount;

      // 1) Phone number matching — compare extracted destination phone against account phone numbers
      final destPhone = _extractPhoneNumber(smsParsed.senderOrRecipient);
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
        if (smsParsed.type == 'income') {
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

      // 7. Loan handling: create loan record for loan disbursements
      final activeTrackerId = await _settingsRepo.getSetting('active_tracker_id') ?? 'default_personal';
      String? loanId;
      if (finalType == 'loan') {
        loanId = const Uuid().v4();
        final loan = Loan(
          id: loanId,
          amount: smsParsed.amount,
          remaining: smsParsed.amount,
          status: 'active',
          provider: provider,
          description: finalDescription,
          sender: smsParsed.senderOrRecipient,
          reference: smsParsed.reference,
          disbursedAt: smsParsed.timestamp,
          trackerId: activeTrackerId,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _loanRepo.createLoan(loan);
        developer.log('Created loan record $loanId for ${smsParsed.amount} cents', name: 'SmsProcessor');
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
            final exact = activeLoans.where((l) => l.remaining == smsParsed.amount).toList();
            if (exact.isNotEmpty) {
              loanId = exact.first.id;
              await _loanRepo.applyPayment(exact.first.id, smsParsed.amount);
              developer.log('Exact repayment match: loan ${exact.first.id} (remaining: ${exact.first.remaining}, paid: ${smsParsed.amount})', name: 'SmsProcessor');
            } else {
              final candidates = activeLoans.where((l) => l.remaining >= smsParsed.amount).toList();
              if (candidates.isNotEmpty) {
                final matched = candidates.reduce((a, b) =>
                    (a.remaining - smsParsed.amount).abs() < (b.remaining - smsParsed.amount).abs() ? a : b);
                loanId = matched.id;
                await _loanRepo.applyPayment(matched.id, smsParsed.amount);
                developer.log('Approximate repayment match: loan ${matched.id} (remaining: ${matched.remaining}, paid: ${smsParsed.amount})', name: 'SmsProcessor');
              } else {
                developer.log('No loan with remaining >= ${smsParsed.amount} — skipping repayment link', name: 'SmsProcessor');
              }
            }
          }
        }
      }

      // 8. Persist Transaction
      final isAutoApproved = finalConfidence >= 0.90;
      final source = isAutoApproved ? 'sms_auto' : 'sms_reviewed';

      final transaction = Transaction(
        id: const Uuid().v4(),
        accountId: finalAccountId,
        destinationAccountId: finalDestinationAccountId,
        loanId: loanId,
        categoryId: finalCategoryId,
        trackerId: activeTrackerId,
        amount: smsParsed.amount,
        type: finalType,
        description: finalDescription,
        provider: smsParsed.provider,
        sender: (smsParsed.type == 'income' || smsParsed.type == 'loan') ? smsParsed.senderOrRecipient : null,
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

      // Reconcile account balance: if SMS provides balanceAfter, use it as ground truth.
      // Otherwise, ensure the DAO adjustment was applied correctly.
      if (smsParsed.balanceAfter != null) {
        // Carrier-reported balance is authoritative — always trust it
        final oldBalance = targetAccount.balance;
        final newBalance = smsParsed.balanceAfter!;
        final reconciledAccount = targetAccount.copyWith(balance: newBalance);
        await _accountRepo.updateAccount(reconciledAccount);

        // Diagnostic: log significant discrepancies for debugging
        final expectedDelta = (finalType == 'income' || finalType == 'loan')
            ? smsParsed.amount
            : (finalType == 'expense' || finalType == 'airtime' || finalType == 'fee')
                ? -smsParsed.amount
                : 0;
        final naiveBalance = oldBalance + expectedDelta;
        final drift = (naiveBalance - newBalance).abs();
        if (drift > smsParsed.amount * 0.5) {
          developer.log(
            'BalanceAfter ($newBalance) differs significantly from expected ($naiveBalance) '
            'by $drift cents (type: ${smsParsed.type}, amount: ${smsParsed.amount}) — '
            'carrier balance trusted as ground truth',
            name: 'SmsProcessor',
          );
        }

        // For transfers, also ensure the destination account is in sync
        if (finalType == 'transfer' && finalDestinationAccountId != null && finalDestinationAccountId != finalAccountId) {
          final destAccount = await _accountRepo.getAccountById(finalDestinationAccountId);
          if (destAccount != null && smsParsed.type == 'expense') {
            // The destination was credited by the DAO — verify it roughly matches
            developer.log(
              'Transfer destination ${destAccount.name} balance: ${destAccount.balance}',
              name: 'SmsProcessor',
            );
          }
        }
      } else {
        // No balanceAfter in SMS — read the latest DB balance (post-DAO adjustment)
        final currentAccount = await _accountRepo.getAccountById(targetAccount.id);
        if (currentAccount != null && finalType != 'transfer') {
          developer.log(
            'No balanceAfter — account ${currentAccount.name} balance after DAO: ${currentAccount.balance} '
            '(type: ${smsParsed.type}, amount: ${smsParsed.amount})',
            name: 'SmsProcessor',
          );
          // The DAO already adjusted the balance correctly — no further action needed
          // Only log if the adjustment seems off
          final delta = (finalType == 'income' || finalType == 'loan')
              ? smsParsed.amount
              : -smsParsed.amount;
          final expectedBalance = targetAccount.balance + delta;
          if (currentAccount.balance != expectedBalance) {
            final correctedAccount = currentAccount.copyWith(balance: expectedBalance);
            await _accountRepo.updateAccount(correctedAccount);
            developer.log('Fallback: balance corrected from ${currentAccount.balance} to $expectedBalance', name: 'SmsProcessor');
          }
        }
      }

      // 8. Trigger local notification (non-fatal — transaction is already saved)
      final amountFormatted = 'Tsh ${(smsParsed.amount / 100).toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]},")}';
      final isCredit = smsParsed.type == 'income' || smsParsed.type == 'loan';
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
      developer.log('SmsProcessor processing failure: $e', error: e, stackTrace: stack, name: 'SmsProcessor');
    }
    return false;
  }

  /// Extracts a Tanzanian phone number (07XX/06XX/255XX) from text.
  String? _extractPhoneNumber(String text) {
    final regex = RegExp(r'(?:\+?255|0)[67]\d{8}(?!\d)');
    final match = regex.firstMatch(text);
    if (match != null) return match.group(0);
    // Also try matching international format like 2557XXXXXXXX
    final intlRegex = RegExp(r'255[67]\d{8}(?!\d)');
    final intlMatch = intlRegex.firstMatch(text);
    return intlMatch?.group(0);
  }
}
