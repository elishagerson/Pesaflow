import 'package:flutter_test/flutter_test.dart';
import 'package:pesaflow/domain/sms/parsers/mpesa_tz_parser.dart';
import 'package:pesaflow/domain/sms/parsers/airtel_tz_parser.dart';
import 'package:pesaflow/domain/sms/parsers/mixx_parser.dart';
import 'package:pesaflow/domain/sms/parsers/halopesa_parser.dart';
import 'package:pesaflow/domain/sms/parsers/bank_base.dart';
import 'package:pesaflow/domain/sms/parsers/selcom_pesa_parser.dart';
import 'package:pesaflow/domain/sms/provider_matcher.dart';
import 'package:pesaflow/domain/sms/parsers/sms_parser_interface.dart';
import 'fixtures/sms_corpus.dart';

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

    test('matches Tigo/Mixx/Yas shortcodes', () {
      expect(ProviderMatcher.matchProvider('TIGO'), 'TigoPesa_TZ');
      expect(ProviderMatcher.matchProvider('MIXX'), 'TigoPesa_TZ');
      expect(ProviderMatcher.matchProvider('YAS'), 'TigoPesa_TZ');
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

    // === English-format tests (Vodacom Tanzania) ===

    test('ENGLISH: parses received money (income)', () {
      const sms =
          'Z10DN636 Confirmed.You have received Tsh50,000 from FREDRICK KIMARO on 27/1/14 at 1:19 PM New M-PESA balance is Tsh214,676';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 5000000); // 50,000 * 100
      expect(result.senderOrRecipient, 'FREDRICK KIMARO');
      expect(result.reference, 'Z10DN636');
      expect(result.provider, 'M-Pesa_TZ');
      expect(result.balanceAfter, 21467600); // 214,676 * 100
    });

    test('ENGLISH: parses sent money (expense)', () {
      const sms =
          'AB12CD34 Confirmed.You have sent Tsh30,000 to JANE DOE on 27/1/14 at 1:19 PM New M-PESA balance is Tsh184,676';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'expense');
      expect(result.amount, 3000000);
      expect(result.senderOrRecipient, 'JANE DOE');
      expect(result.reference, 'AB12CD34');
      expect(result.balanceAfter, 18467600);
    });

    test('ENGLISH: parses paid bills (expense)', () {
      const sms =
          'EF56GH78 Confirmed.You have paid Tsh100,000 to ZESA BILLS on 27/1/14 at 1:19 PM New M-PESA balance is Tsh79,676';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'expense');
      expect(result.amount, 10000000);
      expect(result.senderOrRecipient, 'ZESA BILLS');
      expect(result.reference, 'EF56GH78');
      expect(result.balanceAfter, 7967600);
    });

    test('ENGLISH: parses airtime purchase', () {
      const sms =
          'IJ90KL12 Confirmed.You have bought airtime of Tsh5,000 on 27/1/14 at 1:19 PM New M-PESA balance is Tsh74,676';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'airtime');
      expect(result.amount, 500000);
      expect(result.reference, 'IJ90KL12');
      expect(result.balanceAfter, 7467600);
    });

    test('ENGLISH: parses transaction fee', () {
      const sms =
          'Transaction cost Tsh500 on 27/1/14 at 1:19 PM New M-PESA balance is Tsh74,176';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'fee');
      expect(result.amount, 50000);
      expect(result.balanceAfter, 7417600);
    });

    test('Swahili format without tarehe', () {
      const sms =
          'Pesa zimewekwa Tsh 50,000.00 na John Doe. Rej: P65AB1C2D. Salio: Tsh 250,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 5000000);
      expect(result.senderOrRecipient, 'John Doe');
      expect(result.reference, 'P65AB1C2D');
      expect(result.balanceAfter, 25000000);
    });

    test('ENGLISH format with dashed dates', () {
      const sms =
          'Z10DN636 Confirmed.You have received Tsh50,000 from FREDRICK KIMARO on 2026-05-15 at 14:30 New M-PESA balance is Tsh214,676';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 5000000);
      expect(result.senderOrRecipient, 'FREDRICK KIMARO');
      expect(result.reference, 'Z10DN636');
      expect(result.balanceAfter, 21467600);
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

    test('ENGLISH: parses received money', () {
      const sms =
          'You have received TZS 45,000.00 from 0712345678. TxnID: AT123456. Balance: TZS 300,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 4500000);
      expect(result.senderOrRecipient, '0712345678');
      expect(result.reference, 'AT123456');
      expect(result.balanceAfter, 30000000);
    });

    test('ENGLISH: parses sent money', () {
      const sms =
          'You have sent TZS 20,000.00 to 0765432198. TxnID: AT654321. Balance: TZS 280,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'expense');
      expect(result.amount, 2000000);
      expect(result.senderOrRecipient, '0765432198');
      expect(result.reference, 'AT654321');
      expect(result.balanceAfter, 28000000);
    });

    test('ENGLISH: parses agent deposit', () {
      const sms =
          'You have deposited TZS 100,000.00 to Airtel Money. Balance: TZS 380,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 10000000);
      expect(result.senderOrRecipient, 'Airtel Money Agent Deposit');
      expect(result.balanceAfter, 38000000);
    });

    test('robust name extraction in Swahili', () {
      const sms =
          'Umepokea Tsh 45,000.00 kutoka kwa JOHN DOE tarehe 15/05/2026. Rej: AT123456. Salio: Tsh 300,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.senderOrRecipient, 'JOHN DOE');
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

    // === English-format tests (Mixx by Yas) ===

    test('ENGLISH: parses sent money (expense)', () {
      const sms =
          'You have sent TSh 20,000 to Airtel receiver STEPHAN MWAKALASYA - 255787273486. Charges TSh 540. VAT TSh 82. New balance is TSh 311,708. TxnID: 26706282103620. 22/05/26 18:19 Please wait for confirmation.';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'expense');
      expect(result.amount, 2000000);
      expect(result.senderOrRecipient, 'Airtel receiver STEPHAN MWAKALASYA - 255787273486');
      expect(result.reference, '26706282103620');
      expect(result.provider, 'TigoPesa_TZ');
      expect(result.balanceAfter, 31170800);
    });

    test('ENGLISH: parses cash-in (income)', () {
      const sms =
          'Cash-In of TSh 143,000 from Agent - ELIZA  NYONDO is successful. New balance is TSh 143,000. TxnId: 26694528075313. 22/05/26 15:48.';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 14300000);
      expect(result.senderOrRecipient, 'Agent - ELIZA  NYONDO');
      expect(result.reference, '26694528075313');
      expect(result.provider, 'TigoPesa_TZ');
      expect(result.balanceAfter, 14300000);
    });

    test('ENGLISH: parses received money with TZS', () {
      const sms =
          'You have received TZS 25,000.00 from 0712345678. TxnID: MX789012. Balance: TZS 150,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 2500000);
      expect(result.senderOrRecipient, '0712345678');
      expect(result.reference, 'MX789012');
      expect(result.balanceAfter, 15000000);
    });

    test('robust name extraction in Swahili received', () {
      const sms =
          'Umepokea TZS 25,000.00 kutoka kwa JOHN DOE tarehe 15/05/2026. Kumbukumbu: MX789012. Salio: TZS 150,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.senderOrRecipient, 'JOHN DOE');
    });

    test('parses Malipo yamekamilika kwenda (Nivushe Plus)', () {
      const sms =
          'Malipo yamekamilika kwenda Nivushe Plus, Kiasi Tsh645,728. Salio jipya ni Tsh 47,272. Ada Tsh 0. VAT TSh 0. Kumbukumbu no.26394529507543. 21/05/26 16:25.';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'expense');
      expect(result.amount, 64572800);
      expect(result.senderOrRecipient, 'Nivushe Plus');
      expect(result.reference, '26394529507543');
      expect(result.provider, 'TigoPesa_TZ');
      expect(result.balanceAfter, 4727200);
    });

    test('parses paid balance (Bustisha loan repayment)', () {
      const sms =
          'You have successfully paid your Bustisha Balance by TSh 117,904.55. Your outstanding balance: TSh 8,330.60. New balance: TSh 0. TxnID: 26794215512428. Loan ID: 202606081844181845670752806590. 10/06/26 10:38.';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'expense');
      expect(result.amount, 11790455);
      expect(result.senderOrRecipient, 'Bustisha');
      expect(result.reference, '26794215512428');
      expect(result.provider, 'TigoPesa_TZ');
      expect(result.balanceAfter, isNull); // loan balance, not wallet balance
    });

    test('parses Malipo with Kumbukumbu no. reference', () {
      const sms =
          'Malipo yamekamilika kwenda Nivushe Plus, Kiasi Tsh645,728. Salio jipya ni Tsh 47,272. Ada Tsh 0. VAT TSh 0. Kumbukumbu no.26394529507543. 21/05/26 16:25.';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.reference, '26394529507543');
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

    test('ENGLISH: parses received money', () {
      const sms =
          'You have received TZS 10,000.00 from 0621234567. Ref: HP12345. Balance: TZS 50,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 1000000);
      expect(result.senderOrRecipient, '0621234567');
      expect(result.reference, 'HP12345');
      expect(result.balanceAfter, 5000000);
    });

    test('ENGLISH: parses sent money', () {
      const sms =
          'You have sent TZS 5,000.00 to 0627654321. Ref: HP54321. Balance: TZS 45,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'expense');
      expect(result.amount, 500000);
      expect(result.senderOrRecipient, '0627654321');
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

    // === English-format tests (real Selcom Pesa) ===

    test('ENGLISH: parses received money (income)', () {
      const sms =
          '0517EQMYW Confirmed. You have received TZS 473,000.00 from ELISHA NDUNDULU - Mixx by Yas (255675259341) on 2026-05-17 17:57:46. Updated balance is TZS 477,319.85. Help 0800 714 888 / 0800 784 888';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 47300000);
      expect(result.senderOrRecipient, 'ELISHA NDUNDULU - Mixx by Yas (255675259341)');
      expect(result.reference, '0517EQMYW');
      expect(result.provider, 'SelcomPesa_TZ');
      expect(result.balanceAfter, 47731985);
    });

    test('ENGLISH: parses sent money (expense)', () {
      const sms =
          '0517EQN0Z Accepted. You have sent TZS 477,000.00 to PARTS AND COMPONENTS MBEYA - 19938686 on 2026-05-17 17:58:34. Charge is FREE. Transaction 13 of 150-Hello Mwezi. Updated balance is TZS 319.85. Help 0800 714 888 / 0800 784 888';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'expense');
      expect(result.amount, 47700000);
      expect(result.senderOrRecipient, 'PARTS AND COMPONENTS MBEYA - 19938686');
      expect(result.reference, '0517EQN0Z');
      expect(result.provider, 'SelcomPesa_TZ');
      expect(result.balanceAfter, 31985);
    });

    test('Swahili/Fallback: parses with special characters in sender name', () {
      const sms =
          'Tsh 50,000.00 credited from ELISHA NDUNDULU - Mixx by Yas (255675259341). Ref: S78AB1C2D. Balance: Tsh 100,000.00';
      final result = parser.parse(sms, now);

      expect(result, isNotNull);
      expect(result!.type, 'income');
      expect(result.amount, 5000000);
      expect(result.senderOrRecipient, 'ELISHA NDUNDULU - Mixx by Yas (255675259341)');
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

  // ===========================================================================
  // Corpus-driven regression tests
  // ===========================================================================
  group('SmsCorpus', () {
    /// Maps provider strings to their parsers.
    SmsParser _parserFor(String provider) {
      switch (provider) {
        case 'M-Pesa_TZ':
          return MpesaTzParser();
        case 'AirtelMoney_TZ':
          return AirtelTzParser();
        case 'TigoPesa_TZ':
          return MixxParser();
        case 'Halopesa_TZ':
          return HalopesaParser();
        case 'NMB_Bank':
          return NmbBankParser();
        case 'CRDB_Bank':
          return CrdbBankParser();
        case 'NBC_Bank':
          return NbcBankParser();
        case 'SelcomPesa_TZ':
          return SelcomPesaParser();
        default:
          throw ArgumentError('Unknown provider: $provider');
      }
    }

    for (final entry in smsCorpus) {
      test(entry.label, () {
        final provider = ProviderMatcher.matchProvider(entry.sender);

        if (entry.expect.expectsNull) {
          if (provider == null) {
            return; // unrecognized sender = null, correct
          }
          final parser = _parserFor(provider);
          expect(parser.parse(entry.body, entry.timestamp), isNull,
              reason: 'Expected null for "${entry.label}"');
          return;
        }

        expect(provider, isNotNull,
            reason: 'No provider matched sender "${entry.sender}" for "${entry.label}"');
        final parser = _parserFor(provider!);
        final result = parser.parse(entry.body, entry.timestamp);

        expect(result, isNotNull,
            reason: 'Parser returned null for "${entry.label}"');
        if (result == null) return;

        if (entry.expect.amount != null) {
          expect(result.amount, entry.expect.amount,
              reason: 'amount mismatch for "${entry.label}"');
        }
        if (entry.expect.type != null) {
          expect(result.type, entry.expect.type,
              reason: 'type mismatch for "${entry.label}"');
        }
        if (entry.expect.senderOrRecipient != null) {
          expect(result.senderOrRecipient, entry.expect.senderOrRecipient,
              reason: 'senderOrRecipient mismatch for "${entry.label}"');
        }
        if (entry.expect.reference != null) {
          expect(result.reference, entry.expect.reference,
              reason: 'reference mismatch for "${entry.label}"');
        }
        if (entry.expect.balanceAfter != null) {
          expect(result.balanceAfter, entry.expect.balanceAfter,
              reason: 'balanceAfter mismatch for "${entry.label}"');
        }
      });
    }
  });
}
