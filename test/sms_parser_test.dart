import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/domain/sms/parsers/mpesa_tz_parser.dart';
import 'package:pesaflow/domain/sms/parsers/airtel_tz_parser.dart';
import 'package:pesaflow/domain/sms/parsers/mixx_parser.dart';
import 'package:pesaflow/domain/sms/parsers/halopesa_parser.dart';
import 'package:pesaflow/domain/sms/parsers/bank_base.dart';
import 'package:pesaflow/domain/sms/parsers/selcom_pesa_parser.dart';
import 'package:pesaflow/domain/sms/provider_matcher.dart';

void main() {
  final now = DateTime(2026, 5, 15, 14, 30);

  // ===========================================================================
  // Provider Matcher Tests
  // ===========================================================================
  group('ProviderMatcher', () {
    test('matches M-Pesa shortcodes', () {
      expect(ProviderMatcher.matchProvider('M-PESA'), 'M-Pesa_TZ');
      expect(ProviderMatcher.matchProvider('VODACOM'), 'M-Pesa_TZ');
      expect(ProviderMatcher.matchProvider('m-pesa'), 'M-Pesa_TZ');
      expect(ProviderMatcher.matchProvider('MPESA'), 'M-Pesa_TZ');
    });

    test('matches Airtel Money shortcodes', () {
      expect(ProviderMatcher.matchProvider('AIRTEL'), 'AirtelMoney_TZ');
      expect(ProviderMatcher.matchProvider('AIRTEL MONEY'), 'AirtelMoney_TZ');
      expect(ProviderMatcher.matchProvider('Airtel'), 'AirtelMoney_TZ');
    });

    test('matches Tigo/Mixx shortcodes', () {
      expect(ProviderMatcher.matchProvider('TIGO'), 'TigoPesa_TZ');
      expect(ProviderMatcher.matchProvider('MIXX'), 'TigoPesa_TZ');
      expect(ProviderMatcher.matchProvider('T-PESA'), 'TigoPesa_TZ');
    });

    test('matches Halopesa shortcodes', () {
      expect(ProviderMatcher.matchProvider('HALOPESA'), 'Halopesa_TZ');
      expect(ProviderMatcher.matchProvider('HALO'), 'Halopesa_TZ');
    });

    test('matches bank shortcodes', () {
      expect(ProviderMatcher.matchProvider('NMB'), 'NMB_Bank');
      expect(ProviderMatcher.matchProvider('CRDB'), 'CRDB_Bank');
      expect(ProviderMatcher.matchProvider('NBC'), 'NBC_Bank');
    });

    test('matches Selcom shortcodes', () {
      expect(ProviderMatcher.matchProvider('SELCOM'), 'SelcomPesa_TZ');
      expect(ProviderMatcher.matchProvider('SelcomPesa'), 'SelcomPesa_TZ');
    });

    test('returns null for unrecognized senders', () {
      expect(ProviderMatcher.matchProvider('SPAM'), isNull);
      expect(ProviderMatcher.matchProvider('+255712345678'), isNull);
      expect(ProviderMatcher.matchProvider('MARKETING'), isNull);
    });
  });

  // ===========================================================================
  // M-Pesa Tanzania Parser Tests
  // ===========================================================================
  group('MpesaTzParser', () {
    final parser = MpesaTzParser();

    test('parses received money (income)', () {
      const sms =
          'Pesa zimewekwa Tsh 50,000.00 na John Doe tarehe 15/5/2026 saa 14:30. Rej: P65AB1C2D. Salio: Tsh 250,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 5000000); // 50,000.00 * 100
      expect(result.senderOrRecipient, 'John Doe');
      expect(result.reference, 'P65AB1C2D');
      expect(result.provider, 'M-Pesa_TZ');
      expect(result.balanceAfter, 25000000); // 250,000.00 * 100
    });

    test('parses sent money (expense)', () {
      const sms =
          'Umetuma Tsh 30,000.00 kwa Jane Doe tarehe 15/5/2026 saa 10:00. Rej: P65XYZ123. Salio: Tsh 220,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'expense');
      expect(result.amount, 3000000); // 30,000.00 * 100
      expect(result.senderOrRecipient, 'Jane Doe');
      expect(result.reference, 'P65XYZ123');
      expect(result.balanceAfter, 22000000); // 220,000.00 * 100
    });

    test('parses airtime purchase', () {
      const sms =
          'Umenunua airtime Tsh 5,000.00 kwa 0712345678 tarehe 15/5/2026. Rej: A65ABC. Salio: Tsh 215,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'airtime');
      expect(result.amount, 500000); // 5,000.00 * 100
      expect(result.reference, 'A65ABC');
      expect(result.balanceAfter, 21500000);
    });

    test('parses service fee', () {
      const sms =
          'Kodi ya kuhudumia Tsh 500.00 tarehe 15/5/2026. Salio: Tsh 214,500.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'fee');
      expect(result.amount, 50000); // 500.00 * 100
      expect(result.balanceAfter, 21450000);
    });

    test('returns null for unrecognized SMS', () {
      const sms = 'Habari! Jiunge na promo yetu ya wiki hii.';
      final result = parser.parse(sms, now);
      expect(result, isNull);
    });

    test('handles amounts without decimals', () {
      const sms =
          'Pesa zimewekwa Tsh 10,000 na Ali Hassan tarehe 15/5/2026 saa 09:00. Rej: PABC123. Salio: Tsh 60,000';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.amount, 1000000); // 10,000 * 100
      expect(result.balanceAfter, 6000000);
    });
  });

  // ===========================================================================
  // Airtel Money Tanzania Parser Tests
  // ===========================================================================
  group('AirtelTzParser', () {
    final parser = AirtelTzParser();

    test('parses received money', () {
      const sms =
          'Umepokea Tsh 45,000.00 kutoka kwa 0712345678. Rej: AT123456. Salio: Tsh 300,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 4500000);
      expect(result.senderOrRecipient, '0712345678');
      expect(result.reference, 'AT123456');
      expect(result.balanceAfter, 30000000);
    });

    test('parses sent money', () {
      const sms =
          'Umetuma Tsh 20,000.00 kwa 0765432198. Rej: AT654321. Salio: Tsh 280,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'expense');
      expect(result.amount, 2000000);
      expect(result.senderOrRecipient, '0765432198');
      expect(result.reference, 'AT654321');
      expect(result.balanceAfter, 28000000);
    });

    test('parses agent deposit', () {
      const sms =
          'Umeweka Tsh 100,000.00 kwenye Airtel Money. Salio: Tsh 380,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 10000000);
      expect(result.senderOrRecipient, 'Airtel Money Agent Deposit');
      expect(result.balanceAfter, 38000000);
    });

    test('returns null for unrecognized SMS', () {
      const sms = 'Airtel rewards! Pata data bure.';
      final result = parser.parse(sms, now);
      expect(result, isNull);
    });
  });

  // ===========================================================================
  // Tigo Pesa / Mixx Parser Tests
  // ===========================================================================
  group('MixxParser', () {
    final parser = MixxParser();

    test('parses received money', () {
      const sms =
          'Umepokea TZS 25,000.00 kutoka kwa 0712345678. Kumbukumbu: MX789012. Salio: TZS 150,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 2500000);
      expect(result.senderOrRecipient, '0712345678');
      expect(result.reference, 'MX789012');
      expect(result.provider, 'TigoPesa_TZ');
      expect(result.balanceAfter, 15000000);
    });

    test('parses sent money', () {
      const sms =
          'Umetuma TZS 15,000.00 kwa 0765432198. Kumbukumbu: MX210987. Salio: TZS 135,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'expense');
      expect(result.amount, 1500000);
      expect(result.reference, 'MX210987');
      expect(result.balanceAfter, 13500000);
    });

    test('parses bundle/package purchase', () {
      const sms =
          'Ununuzi wa kifurushi TZS 3,000.00. Salio: TZS 132,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'airtime');
      expect(result.amount, 300000);
      expect(result.balanceAfter, 13200000);
    });
  });

  // ===========================================================================
  // Halopesa Parser Tests
  // ===========================================================================
  group('HalopesaParser', () {
    final parser = HalopesaParser();

    test('parses received money', () {
      const sms =
          'Umepokea TZS 10,000.00 kutoka kwa 0621234567. Rej: HP12345. Salio: TZS 50,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 1000000);
      expect(result.reference, 'HP12345');
      expect(result.provider, 'Halopesa_TZ');
      expect(result.balanceAfter, 5000000);
    });

    test('parses sent money', () {
      const sms =
          'Umetuma TZS 5,000.00 kwa 0627654321. Rej: HP54321. Salio: TZS 45,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'expense');
      expect(result.amount, 500000);
      expect(result.reference, 'HP54321');
      expect(result.balanceAfter, 4500000);
    });
  });

  // ===========================================================================
  // NMB Bank Parser Tests
  // ===========================================================================
  group('NmbBankParser', () {
    final parser = NmbBankParser();

    test('parses debit (POS/merchant payment)', () {
      const sms =
          'Tumekutoa TZS 150,000.00 kwa POS/MERCHANT/0123456789 tarehe 15/05/2026. Salio: TZS 1,250,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'expense');
      expect(result.amount, 15000000);
      expect(result.senderOrRecipient, 'POS/MERCHANT/0123456789');
      expect(result.provider, 'NMB_Bank');
      expect(result.balanceAfter, 125000000);
    });

    test('parses credit (salary deposit)', () {
      const sms =
          'Tumeongeza TZS 500,000.00 kutoka SALARY/MONTHLY tarehe 15/05/2026. Salio: TZS 1,750,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 50000000);
      expect(result.senderOrRecipient, 'SALARY/MONTHLY');
      expect(result.balanceAfter, 175000000);
    });

    test('parses fees (ATM withdrawal fee)', () {
      const sms =
          'Fees: TZS 1,000.00 kwa ATM WITHDRAWAL. Salio: TZS 1,249,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'fee');
      expect(result.amount, 100000);
      expect(result.senderOrRecipient, contains('ATM WITHDRAWAL'));
      expect(result.balanceAfter, 124900000);
    });
  });

  // ===========================================================================
  // CRDB Bank Parser Tests
  // ===========================================================================
  group('CrdbBankParser', () {
    final parser = CrdbBankParser();

    test('parses withdrawal (debit)', () {
      const sms =
          'CRDB: Withdrawal TZS 200,000.00 at ATM/Arusha. Available: TZS 800,000.00. Ref: CRDB123';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'expense');
      expect(result.amount, 20000000);
      expect(result.senderOrRecipient, 'ATM/Arusha');
      expect(result.reference, 'CRDB123');
      expect(result.provider, 'CRDB_Bank');
      expect(result.balanceAfter, 80000000);
    });

    test('parses deposit (credit)', () {
      const sms =
          'CRDB: Deposit TZS 1,000,000.00 from MPESA. Available: TZS 1,800,000.00. Ref: CRDB456';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 100000000);
      expect(result.senderOrRecipient, 'MPESA');
      expect(result.reference, 'CRDB456');
      expect(result.balanceAfter, 180000000);
    });
  });

  // ===========================================================================
  // NBC Bank Parser Tests
  // ===========================================================================
  group('NbcBankParser', () {
    final parser = NbcBankParser();

    test('parses debit (expense)', () {
      const sms =
          'NBC: TZS 50,000.00 debited from acct ****1234. Desc: AIRTIME. Bal: TZS 450,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'expense');
      expect(result.amount, 5000000);
      expect(result.senderOrRecipient, contains('AIRTIME'));
      expect(result.provider, 'NBC_Bank');
      expect(result.balanceAfter, 45000000);
    });

    test('parses credit (income)', () {
      const sms =
          'NBC: TZS 300,000.00 credited to acct ****1234. Desc: SALARY. Bal: TZS 750,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 30000000);
      expect(result.senderOrRecipient, contains('SALARY'));
      expect(result.balanceAfter, 75000000);
    });
  });

  // ===========================================================================
  // Selcom Pesa Parser Tests
  // ===========================================================================
  group('SelcomPesaParser', () {
    final parser = SelcomPesaParser();

    test('parses received money (income)', () {
      const sms =
          'Umepokea Tsh 50,000.00 kutoka kwa John Doe tarehe 15/5/2026 saa 14:30. Ref: S78AB1C2D. Salio: Tsh 100,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 5000000);
      expect(result.senderOrRecipient, 'John Doe');
      expect(result.reference, 'S78AB1C2D');
      expect(result.provider, 'SelcomPesa_TZ');
      expect(result.balanceAfter, 10000000);
    });

    test('parses sent money (expense)', () {
      const sms =
          'Umetuma Tsh 25,000.00 kwa Jane Doe tarehe 15/5/2026 saa 15:00. Ref: S78XYZ987. Salio: Tsh 75,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'expense');
      expect(result.amount, 2500000);
      expect(result.senderOrRecipient, 'Jane Doe');
      expect(result.reference, 'S78XYZ987');
      expect(result.balanceAfter, 7500000);
    });
  });

  // ===========================================================================
  // Edge Case & Cross-Parser Tests
  // ===========================================================================
  group('Edge Cases', () {
    test('all parsers return null for empty string', () {
      expect(MpesaTzParser().parse('', now), isNull);
      expect(AirtelTzParser().parse('', now), isNull);
      expect(MixxParser().parse('', now), isNull);
      expect(HalopesaParser().parse('', now), isNull);
      expect(NmbBankParser().parse('', now), isNull);
      expect(CrdbBankParser().parse('', now), isNull);
      expect(NbcBankParser().parse('', now), isNull);
      expect(SelcomPesaParser().parse('', now), isNull);
    });

    test('all parsers return null for promotional messages', () {
      const promo = 'Congratulations! You have won a free iPhone! Click here to claim.';
      expect(MpesaTzParser().parse(promo, now), isNull);
      expect(AirtelTzParser().parse(promo, now), isNull);
      expect(MixxParser().parse(promo, now), isNull);
      expect(HalopesaParser().parse(promo, now), isNull);
      expect(NmbBankParser().parse(promo, now), isNull);
      expect(CrdbBankParser().parse(promo, now), isNull);
      expect(NbcBankParser().parse(promo, now), isNull);
      expect(SelcomPesaParser().parse(promo, now), isNull);
    });

    test('M-Pesa parser handles large amounts correctly', () {
      const sms =
          'Pesa zimewekwa Tsh 5,500,000.00 na Corporate Ltd tarehe 15/5/2026 saa 14:30. Rej: PBIG999. Salio: Tsh 6,000,000.00';
      final result = MpesaTzParser().parse(sms, now);

      expect(result, isNotNull);
      expect(result!.amount, 550000000); // 5,500,000.00 * 100
      expect(result.balanceAfter, 600000000);
    });

    test('amounts stored as integer cents avoid floating-point errors', () {
      // 15.25 TZS should be exactly 1525 cents
      final parser = MpesaTzParser();
      // Test the internal parsing through a constructed SMS
      const sms =
          'Kodi ya kuhudumia Tsh 15.25 tarehe 15/5/2026. Salio: Tsh 999.75';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.amount, 1525);
      expect(result.balanceAfter, 99975);
    });
  });
}
