import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sms_parsed.dart';
import '../../../data/repositories/transaction_repository.dart';

final deduplicatorProvider = Provider<Deduplicator>((ref) {
  final repo = ref.watch(transactionRepositoryProvider);
  return Deduplicator(repo);
});

class Deduplicator {
  final TransactionRepository _transactionRepository;

  Deduplicator(this._transactionRepository);

  /// Analyzes the parsed receipt and returns true if it represents a duplicate entry.
  Future<bool> isDuplicate(SmsParsed sms) async {
    // 1. Check unique carrier reference ID
    if (sms.reference != 'MPESA-REF-UNKNOWN' &&
        sms.reference != 'AIRTEL-REF-UNKNOWN' &&
        sms.reference != 'TIGO-REF-UNKNOWN' &&
        sms.reference != 'HALO-REF-UNKNOWN' &&
        sms.reference != 'NMB-REF-UNKNOWN' &&
        sms.reference != 'SELCOM-REF-UNKNOWN' &&
        !sms.reference.startsWith('NBC-REF-')) {
      final exists = await _transactionRepository.transactionExistsByReference(sms.reference);
      if (exists) return true;
    }

    // 2. Check fuzzy window: same amount, type, and provider within +-60 seconds
    final startWindow = sms.timestamp.subtract(const Duration(seconds: 60));
    final endWindow = sms.timestamp.add(const Duration(seconds: 60));

    final matches = await _transactionRepository.getTransactionsByFuzzyWindow(
      provider: sms.provider,
      type: sms.type,
      amount: sms.amount,
      start: startWindow,
      end: endWindow,
    );

    return matches.isNotEmpty;
  }
}
