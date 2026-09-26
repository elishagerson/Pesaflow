import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/analytics_dao.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/repositories/analytics_repository.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/domain/models/sms_parsed.dart';
import 'package:pesaflow/domain/sms/deduplicator.dart';

/// Characterises the fuzzy-window dedup: same provider + type + amount within
/// +-60s of the original SMS timestamp is treated as a duplicate.
void main() {
  late AppDatabase db;
  late TransactionRepository repo;
  late Deduplicator dedup;

  const accountId = 'acct-mpesa';
  const categoryId = 'cat-food';
  final t0 = DateTime(2026, 3, 1, 9, 0, 0);

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    await db.into(db.accounts).insert(
      Account(
        id: accountId,
        name: 'M-Pesa',
        type: 'mobile_money',
        balance: 1000000,
        provider: 'M-Pesa_TZ',
        icon: 'wallet',
        sortOrder: 0,
        isArchived: false,
        createdAt: t0,
      ),
    );
    await db.into(db.categories).insert(
      Category(
        id: categoryId,
        name: 'Food',
        type: 'expense',
        color: '#FF9800',
        icon: 'restaurant',
        isSystem: false,
        sortOrder: 0,
        createdAt: t0,
      ),
    );
    repo = TransactionRepository(
      TransactionDao(db),
      null,
      AnalyticsRepository(AnalyticsDao(db)),
    );
    dedup = Deduplicator(repo);
  });

  tearDown(() async => db.close());

  Future<void> insertExisting({
    required String id,
    required String reference,
    int amount = 100000,
    required DateTime smsTimestamp,
  }) async {
    await repo.createTransaction(
      Transaction(
        id: id,
        accountId: accountId,
        categoryId: categoryId,
        trackerId: 'default_personal',
        amount: amount,
        type: 'expense',
        description: 'Transfer out',
        reference: reference,
        provider: 'M-Pesa_TZ',
        smsTimestamp: smsTimestamp,
        source: 'sms_auto',
        createdAt: smsTimestamp,
        updatedAt: smsTimestamp,
      ),
    );
  }

  SmsParsed sms({
    required String reference,
    required DateTime timestamp,
    int amount = 100000,
  }) => SmsParsed(
    reference: reference,
    amount: amount,
    type: 'expense',
    senderOrRecipient: 'N/A',
    provider: 'M-Pesa_TZ',
    timestamp: timestamp,
    rawSmsBody: 'raw body',
  );

  group('reference check', () {
    test('flags a genuine repeat of the same reference', () async {
      await insertExisting(
        id: 'a',
        reference: 'MPX-111',
        smsTimestamp: t0,
      );
      expect(
        await dedup.isDuplicate(sms(reference: 'MPX-111', timestamp: t0)),
        isTrue,
      );
    });

    test('allows a new reference 10 minutes later', () async {
      await insertExisting(
        id: 'a',
        reference: 'MPX-111',
        smsTimestamp: t0,
      );
      expect(
        await dedup.isDuplicate(
          sms(
            reference: 'MPX-222',
            timestamp: t0.add(const Duration(minutes: 10)),
          ),
        ),
        isFalse,
      );
    });
  });

  group('fuzzy window must not discard distinct payments', () {
    test(
      'a second DISTINCT same-amount transfer 30s later is admitted',
      () async {
        await insertExisting(
          id: 'a',
          reference: 'MPX-111',
          smsTimestamp: t0,
        );

        // Genuinely different reference, different money movement, 30s apart.
        final isDup = await dedup.isDuplicate(
          sms(reference: 'MPX-999', timestamp: t0.add(const Duration(seconds: 30))),
        );

        expect(
          isDup,
          isFalse,
          reason:
              'MPX-999 was never seen, so it is a genuinely new payment and must '
              'not be discarded just because an unrelated same-amount transfer '
              'happened to land 30s earlier.',
        );
      },
    );

    test('two identical airtime top-ups 20s apart are both kept', () async {
      await insertExisting(
        id: 'a',
        reference: 'MPX-111',
        amount: 5000,
        smsTimestamp: t0,
      );
      expect(
        await dedup.isDuplicate(
          sms(
            reference: 'MPX-777',
            amount: 5000,
            timestamp: t0.add(const Duration(seconds: 20)),
          ),
        ),
        isFalse,
        reason:
            'Buying two bundles back-to-back must not silently lose one of them.',
      );
    });

    test('a different amount in the same window is not a duplicate', () async {
      await insertExisting(
        id: 'a',
        reference: 'MPX-111',
        smsTimestamp: t0,
      );
      expect(
        await dedup.isDuplicate(
          sms(
            reference: 'MPX-888',
            amount: 73500,
            timestamp: t0.add(const Duration(seconds: 20)),
          ),
        ),
        isFalse,
      );
    });

    test('same amount after the window is not a duplicate', () async {
      await insertExisting(
        id: 'a',
        reference: 'MPX-111',
        smsTimestamp: t0,
      );
      expect(
        await dedup.isDuplicate(
          sms(
            reference: 'MPX-999',
            timestamp: t0.add(const Duration(seconds: 61)),
          ),
        ),
        isFalse,
      );
    });
  });

  group('sentinel references', () {
    test('are still protected by the fuzzy window', () async {
      await insertExisting(
        id: 'a',
        reference: 'XXXX-REF-UNKNOWN',
        smsTimestamp: t0,
      );
      expect(
        await dedup.isDuplicate(
          sms(reference: 'XXXX-REF-UNKNOWN', timestamp: t0),
        ),
        isTrue,
        reason:
            'Re-scanning the same message keeps its original smsTimestamp, so '
            'the fuzzy window still catches it even without a real reference.',
      );
    });
  });
}
