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
    // 1. A real carrier reference is the authoritative identity of the
    //    transaction. When the parser extracted one that we have never seen,
    //    this is a new transaction and is admitted as-is.
    //
    //    The fuzzy window is deliberately NOT consulted in that case: matching on
    //    provider + type + amount within +-60s cannot tell two genuinely distinct
    //    payments apart, so it silently discarded real money movements (e.g. two
    //    same-amount transfers 30s apart, or two airtime top-ups back-to-back).
    //
    //    A reference is a sentinel when the parser could not extract a real one —
    //    any `*-REF-UNKNOWN` or `NBC-REF-*` value.
    final isSentinel =
        sms.reference.endsWith('-REF-UNKNOWN') ||
        sms.reference.startsWith('NBC-REF-');

    if (!isSentinel) {
      return _transactionRepository.transactionExistsByReference(
        sms.reference,
      );
    }

    // 2. No usable reference, so fall back to a fuzzy match on provider + type +
    //    amount within +-60s of the SMS timestamp. The window is anchored on
    //    `smsTimestamp` (the carrier's original send time, not insertion time), so
    //    re-scanning the same inbox message still matches even across isolates and
    //    cold starts, where the in-memory content-key cache is empty.
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
