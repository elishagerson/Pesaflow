/// Real-world SMS corpus for regression testing.
///
/// Each entry represents an anonymized SMS from a Tanzanian mobile-money
/// or bank provider.  Messages are drawn from production traffic and capture
/// real formatting quirks (whitespace, punctuation, date styles, mixed
/// Swahili/English, fee/VAT lines, etc.).
///
/// Usage:
/// ```dart
/// import 'fixtures/sms_corpus.dart';
/// final entry = smsCorpus['mpesa_received_sw'];
/// final result = MpesaTzParser().parse(entry.body, entry.timestamp);
/// expect(result!.amount, entry.expect.amount);
/// ```
class SmsCorpusEntry {
  final String label;
  final String sender;
  final String body;
  final DateTime timestamp;
  final SmsExpectation expect;

  const SmsCorpusEntry({
    required this.label,
    required this.sender,
    required this.body,
    required this.timestamp,
    required this.expect,
  });
}

class SmsExpectation {
  final int? amount; // cents
  final String? type;
  final String? senderOrRecipient;
  final String? reference;
  final int? balanceAfter;
  final bool expectsNull;

  const SmsExpectation({
    this.amount,
    this.type,
    this.senderOrRecipient,
    this.reference,
    this.balanceAfter,
    this.expectsNull = false,
  });
}

final List<SmsCorpusEntry> smsCorpus = [
  // =========================================================================
  // M-Pesa (Vodacom) — Swahili
  // =========================================================================
  SmsCorpusEntry(
    label: 'mpesa_received_sw',
    sender: 'M-PESA',
    body: 'Pesa zimewekwa Tsh 50,000.00 na John Doe tarehe 15/5/2026 saa 14:30. Rej: P65AB1C2D. Salio: Tsh 250,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 5000000,
      type: 'income',
      senderOrRecipient: 'John Doe',
      reference: 'P65AB1C2D',
      balanceAfter: 25000000,
    ),
  ),
  SmsCorpusEntry(
    label: 'mpesa_sent_sw',
    sender: 'M-PESA',
    body: 'Umetuma Tsh 30,000.00 kwa Jane Doe tarehe 15/5/2026 saa 10:00. Rej: P65XYZ123. Salio: Tsh 220,000.00',
    timestamp: DateTime(2026, 5, 15, 10, 0),
    expect: SmsExpectation(
      amount: 3000000,
      type: 'expense',
      senderOrRecipient: 'Jane Doe',
      reference: 'P65XYZ123',
      balanceAfter: 22000000,
    ),
  ),
  SmsCorpusEntry(
    label: 'mpesa_airtime_sw',
    sender: 'M-PESA',
    body: 'Umenunua airtime Tsh 5,000.00 kwa 0712345678 tarehe 15/5/2026. Rej: A65ABC. Salio: Tsh 215,000.00',
    timestamp: DateTime(2026, 5, 15, 12, 0),
    expect: SmsExpectation(
      amount: 500000,
      type: 'airtime',
      senderOrRecipient: 'Vodacom Airtime',
      reference: 'A65ABC',
      balanceAfter: 21500000,
    ),
  ),
  SmsCorpusEntry(
    label: 'mpesa_fee_sw',
    sender: 'M-PESA',
    body: 'Kodi ya kuhudumia Tsh 500.00 tarehe 15/5/2026. Salio: Tsh 214,500.00',
    timestamp: DateTime(2026, 5, 15, 12, 0),
    expect: SmsExpectation(
      amount: 50000,
      type: 'fee',
      senderOrRecipient: 'Vodacom Service Fee',
      reference: 'MPESA-REF-UNKNOWN',
      balanceAfter: 21450000,
    ),
  ),
  SmsCorpusEntry(
    label: 'mpesa_loan_sw',
    sender: 'M-PESA',
    body: 'Pesa zimekopeshwa Tsh 100,000.00. Maliza ndani ya siku 30. Rej: P65ABC. Salio: Tsh 250,000.00',
    timestamp: DateTime(2026, 5, 15, 12, 0),
    expect: SmsExpectation(
      amount: 10000000,
      type: 'income',
      senderOrRecipient: 'Mobile Money Loan',
      reference: 'P65ABC',
      balanceAfter: 25000000,
    ),
  ),
  SmsCorpusEntry(
    label: 'mpesa_received_no_tarehe',
    sender: 'M-PESA',
    body: 'Pesa zimewekwa Tsh 50,000.00 na John Doe. Rej: P65AB1C2D. Salio: Tsh 250,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 5000000,
      type: 'income',
      senderOrRecipient: 'John Doe',
      reference: 'P65AB1C2D',
      balanceAfter: 25000000,
    ),
  ),

  // =========================================================================
  // M-Pesa (Vodacom) — English
  // =========================================================================
  SmsCorpusEntry(
    label: 'mpesa_received_en',
    sender: 'M-PESA',
    body: 'Z10DN636 Confirmed.You have received Tsh50,000 from FREDRICK KIMARO on 27/1/14 at 1:19 PM New M-PESA balance is Tsh214,676',
    timestamp: DateTime(2014, 1, 27, 13, 19),
    expect: SmsExpectation(
      amount: 5000000,
      type: 'income',
      senderOrRecipient: 'FREDRICK KIMARO',
      reference: 'Z10DN636',
      balanceAfter: 21467600,
    ),
  ),
  SmsCorpusEntry(
    label: 'mpesa_sent_en',
    sender: 'M-PESA',
    body: 'AB12CD34 Confirmed.You have sent Tsh30,000 to JANE DOE on 27/1/14 at 1:19 PM New M-PESA balance is Tsh184,676',
    timestamp: DateTime(2014, 1, 27, 13, 19),
    expect: SmsExpectation(
      amount: 3000000,
      type: 'expense',
      senderOrRecipient: 'JANE DOE',
      reference: 'AB12CD34',
      balanceAfter: 18467600,
    ),
  ),
  SmsCorpusEntry(
    label: 'mpesa_bill_payment_en',
    sender: 'M-PESA',
    body: 'EF56GH78 Confirmed.You have paid Tsh100,000 to ZESA BILLS on 27/1/14 at 1:19 PM New M-PESA balance is Tsh79,676',
    timestamp: DateTime(2014, 1, 27, 13, 19),
    expect: SmsExpectation(
      amount: 10000000,
      type: 'expense',
      senderOrRecipient: 'ZESA BILLS',
      reference: 'EF56GH78',
      balanceAfter: 7967600,
    ),
  ),
  SmsCorpusEntry(
    label: 'mpesa_airtime_en',
    sender: 'M-PESA',
    body: 'IJ90KL12 Confirmed.You have bought airtime of Tsh5,000 on 27/1/14 at 1:19 PM New M-PESA balance is Tsh74,676',
    timestamp: DateTime(2014, 1, 27, 13, 19),
    expect: SmsExpectation(
      amount: 500000,
      type: 'airtime',
      senderOrRecipient: 'Vodacom Airtime',
      reference: 'IJ90KL12',
      balanceAfter: 7467600,
    ),
  ),
  SmsCorpusEntry(
    label: 'mpesa_fee_en',
    sender: 'M-PESA',
    body: 'Transaction cost Tsh500 on 27/1/14 at 1:19 PM New M-PESA balance is Tsh74,176',
    timestamp: DateTime(2014, 1, 27, 13, 19),
    expect: SmsExpectation(
      amount: 50000,
      type: 'fee',
      senderOrRecipient: 'Vodacom Service Fee',
      reference: 'MPESA-REF-UNKNOWN',
      balanceAfter: 7417600,
    ),
  ),
  SmsCorpusEntry(
    label: 'mpesa_received_dashed_date',
    sender: 'M-PESA',
    body: 'Z10DN636 Confirmed.You have received Tsh50,000 from FREDRICK KIMARO on 2026-05-15 at 14:30 New M-PESA balance is Tsh214,676',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 5000000,
      type: 'income',
      senderOrRecipient: 'FREDRICK KIMARO',
      reference: 'Z10DN636',
      balanceAfter: 21467600,
    ),
  ),
  SmsCorpusEntry(
    label: 'mpesa_loan_en',
    sender: 'M-PESA',
    body: 'P65DEF Confirmed.You have received a loan of Tsh 100,000.00. Pay within 30 days. New M-PESA balance is Tsh 250,000.00',
    timestamp: DateTime(2026, 5, 15, 12, 0),
    expect: SmsExpectation(
      amount: 10000000,
      type: 'income',
      senderOrRecipient: 'Mobile Money Loan',
      reference: 'P65DEF',
      balanceAfter: 25000000,
    ),
  ),

  // =========================================================================
  // Airtel Money Tanzania — Swahili
  // =========================================================================
  SmsCorpusEntry(
    label: 'airtel_received_sw',
    sender: 'AIRTEL',
    body: 'Umepokea Tsh 45,000.00 kutoka kwa 0712345678. Rej: AT123456. Salio: Tsh 300,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 4500000,
      type: 'income',
      senderOrRecipient: '0712345678',
      reference: 'AT123456',
      balanceAfter: 30000000,
    ),
  ),
  SmsCorpusEntry(
    label: 'airtel_sent_sw',
    sender: 'AIRTEL',
    body: 'Umetuma Tsh 20,000.00 kwa 0765432198. Rej: AT654321. Salio: Tsh 280,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 2000000,
      type: 'expense',
      senderOrRecipient: '0765432198',
      reference: 'AT654321',
      balanceAfter: 28000000,
    ),
  ),
  SmsCorpusEntry(
    label: 'airtel_deposit_sw',
    sender: 'AIRTEL',
    body: 'Umeweka Tsh 100,000.00 kwenye Airtel Money. Salio: Tsh 380,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 10000000,
      type: 'income',
      senderOrRecipient: 'Airtel Money Agent Deposit',
      balanceAfter: 38000000,
    ),
  ),
  SmsCorpusEntry(
    label: 'airtel_received_with_date_sw',
    sender: 'AIRTEL',
    body: 'Umepokea Tsh 45,000.00 kutoka kwa JOHN DOE tarehe 15/05/2026. Rej: AT123456. Salio: Tsh 300,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 4500000,
      type: 'income',
      senderOrRecipient: 'JOHN DOE',
      reference: 'AT123456',
      balanceAfter: 30000000,
    ),
  ),

  // =========================================================================
  // Airtel Money Tanzania — English
  // =========================================================================
  SmsCorpusEntry(
    label: 'airtel_received_en',
    sender: 'AIRTEL',
    body: 'You have received TZS 45,000.00 from 0712345678. TxnID: AT123456. Balance: TZS 300,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 4500000,
      type: 'income',
      senderOrRecipient: '0712345678',
      reference: 'AT123456',
      balanceAfter: 30000000,
    ),
  ),
  SmsCorpusEntry(
    label: 'airtel_sent_en',
    sender: 'AIRTEL',
    body: 'You have sent TZS 20,000.00 to 0765432198. TxnID: AT654321. Balance: TZS 280,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 2000000,
      type: 'expense',
      senderOrRecipient: '0765432198',
      reference: 'AT654321',
      balanceAfter: 28000000,
    ),
  ),
  SmsCorpusEntry(
    label: 'airtel_deposit_en',
    sender: 'AIRTEL',
    body: 'You have deposited TZS 100,000.00 to Airtel Money. Balance: TZS 380,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 10000000,
      type: 'income',
      senderOrRecipient: 'Airtel Money Agent Deposit',
      balanceAfter: 38000000,
    ),
  ),

  // =========================================================================
  // Tigo Pesa / Mixx by Yas — Swahili
  // =========================================================================
  SmsCorpusEntry(
    label: 'mixx_received_sw',
    sender: 'MIXX',
    body: 'Umepokea TZS 25,000.00 kutoka kwa 0712345678. Kumbukumbu: MX789012. Salio: TZS 150,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 2500000,
      type: 'income',
      senderOrRecipient: '0712345678',
      reference: 'MX789012',
      balanceAfter: 15000000,
    ),
  ),
  SmsCorpusEntry(
    label: 'mixx_sent_sw',
    sender: 'MIXX',
    body: 'Umetuma TZS 15,000.00 kwa 0765432198. Kumbukumbu: MX210987. Salio: TZS 135,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 1500000,
      type: 'expense',
      reference: 'MX210987',
      balanceAfter: 13500000,
    ),
  ),
  SmsCorpusEntry(
    label: 'mixx_bundle_sw',
    sender: 'MIXX',
    body: 'Ununuzi wa kifurushi TZS 3,000.00. Salio: TZS 132,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 300000,
      type: 'airtime',
      senderOrRecipient: 'Tigo Pesa Bundle',
      balanceAfter: 13200000,
    ),
  ),
  SmsCorpusEntry(
    label: 'mixx_received_with_date_sw',
    sender: 'MIXX',
    body: 'Umepokea TZS 25,000.00 kutoka kwa JOHN DOE tarehe 15/05/2026. Kumbukumbu: MX789012. Salio: TZS 150,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 2500000,
      type: 'income',
      senderOrRecipient: 'JOHN DOE',
      reference: 'MX789012',
      balanceAfter: 15000000,
    ),
  ),
  // Nivushe Plus repayment via Mixx (real-world)
  SmsCorpusEntry(
    label: 'mixx_malipo_nivushe',
    sender: 'MIXX',
    body: 'Malipo yamekamilika kwenda Nivushe Plus, Kiasi Tsh645,728. Salio jipya ni Tsh 47,272. Ada Tsh 0. VAT TSh 0. Kumbukumbu no.26394529507543. 21/05/26 16:25.',
    timestamp: DateTime(2026, 5, 21, 16, 25),
    expect: SmsExpectation(
      amount: 64572800,
      type: 'expense',
      senderOrRecipient: 'Nivushe Plus',
      reference: '26394529507543',
      balanceAfter: 4727200,
    ),
  ),

  // =========================================================================
  // Tigo Pesa / Mixx by Yas — English
  // =========================================================================
  SmsCorpusEntry(
    label: 'mixx_sent_en',
    sender: 'MIXX',
    body: 'You have sent TSh 20,000 to Airtel receiver STEPHAN MWAKALASYA - 255787273486. Charges TSh 540. VAT TSh 82. New balance is TSh 311,708. TxnID: 26706282103620. 22/05/26 18:19 Please wait for confirmation.',
    timestamp: DateTime(2026, 5, 22, 18, 19),
    expect: SmsExpectation(
      amount: 2000000,
      type: 'expense',
      senderOrRecipient: 'Airtel receiver STEPHAN MWAKALASYA - 255787273486',
      reference: '26706282103620',
      balanceAfter: 31170800,
    ),
  ),
  SmsCorpusEntry(
    label: 'mixx_cashin_en',
    sender: 'MIXX',
    body: 'Cash-In of TSh 143,000 from Agent - ELIZA  NYONDO is successful. New balance is TSh 143,000. TxnId: 26694528075313. 22/05/26 15:48.',
    timestamp: DateTime(2026, 5, 22, 15, 48),
    expect: SmsExpectation(
      amount: 14300000,
      type: 'income',
      senderOrRecipient: 'Agent - ELIZA  NYONDO',
      reference: '26694528075313',
      balanceAfter: 14300000,
    ),
  ),
  SmsCorpusEntry(
    label: 'mixx_received_en',
    sender: 'MIXX',
    body: 'You have received TZS 25,000.00 from 0712345678. TxnID: MX789012. Balance: TZS 150,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 2500000,
      type: 'income',
      senderOrRecipient: '0712345678',
      reference: 'MX789012',
      balanceAfter: 15000000,
    ),
  ),
  // Bustisha loan repayment via Mixx (real-world)
  SmsCorpusEntry(
    label: 'mixx_paid_bustisha_balance',
    sender: 'MIXX',
    body: 'You have successfully paid your Bustisha Balance by TSh 117,904.55. Your outstanding balance: TSh 8,330.60. New balance: TSh 0. TxnID: 26794215512428. Loan ID: 202606081844181845670752806590. 10/06/26 10:38.',
    timestamp: DateTime(2026, 6, 10, 10, 38),
    expect: SmsExpectation(
      amount: 11790455,
      type: 'expense',
      senderOrRecipient: 'Bustisha',
      reference: '26794215512428',
      // balanceAfter is null — "New balance" in this SMS is the loan balance
    ),
  ),

  // =========================================================================
  // Halopesa (Halotel)
  // =========================================================================
  SmsCorpusEntry(
    label: 'halopesa_received_sw',
    sender: 'HALOPESA',
    body: 'Umepokea TZS 10,000.00 kutoka kwa 0621234567. Rej: HP12345. Salio: TZS 50,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 1000000,
      type: 'income',
      senderOrRecipient: '0621234567',
      reference: 'HP12345',
      balanceAfter: 5000000,
    ),
  ),
  SmsCorpusEntry(
    label: 'halopesa_sent_sw',
    sender: 'HALOPESA',
    body: 'Umetuma TZS 5,000.00 kwa 0627654321. Rej: HP54321. Salio: TZS 45,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 500000,
      type: 'expense',
      reference: 'HP54321',
      balanceAfter: 4500000,
    ),
  ),
  SmsCorpusEntry(
    label: 'halopesa_received_en',
    sender: 'HALOPESA',
    body: 'You have received TZS 10,000.00 from 0621234567. Ref: HP12345. Balance: TZS 50,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 1000000,
      type: 'income',
      senderOrRecipient: '0621234567',
      reference: 'HP12345',
      balanceAfter: 5000000,
    ),
  ),
  SmsCorpusEntry(
    label: 'halopesa_sent_en',
    sender: 'HALOPESA',
    body: 'You have sent TZS 5,000.00 to 0627654321. Ref: HP54321. Balance: TZS 45,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 500000,
      type: 'expense',
      senderOrRecipient: '0627654321',
      reference: 'HP54321',
      balanceAfter: 4500000,
    ),
  ),

  // =========================================================================
  // Selcom Pesa
  // =========================================================================
  SmsCorpusEntry(
    label: 'selcom_received_en',
    sender: 'SELCOM',
    body: '0517EQMYW Confirmed. You have received TZS 473,000.00 from ELISHA NDUNDULU - Mixx by Yas (255675259341) on 2026-05-17 17:57:46. Updated balance is TZS 477,319.85. Help 0800 714 888 / 0800 784 888',
    timestamp: DateTime(2026, 5, 17, 17, 57),
    expect: SmsExpectation(
      amount: 47300000,
      type: 'income',
      senderOrRecipient: 'ELISHA NDUNDULU - Mixx by Yas (255675259341)',
      reference: '0517EQMYW',
      balanceAfter: 47731985,
    ),
  ),
  SmsCorpusEntry(
    label: 'selcom_sent_en',
    sender: 'SELCOM',
    body: '0517EQN0Z Accepted. You have sent TZS 477,000.00 to PARTS AND COMPONENTS MBEYA - 19938686 on 2026-05-17 17:58:34. Charge is FREE. Transaction 13 of 150-Hello Mwezi. Updated balance is TZS 319.85. Help 0800 714 888 / 0800 784 888',
    timestamp: DateTime(2026, 5, 17, 17, 58),
    expect: SmsExpectation(
      amount: 47700000,
      type: 'expense',
      senderOrRecipient: 'PARTS AND COMPONENTS MBEYA - 19938686',
      reference: '0517EQN0Z',
      balanceAfter: 31985,
    ),
  ),
  SmsCorpusEntry(
    label: 'selcom_received_sw',
    sender: 'SELCOM',
    body: 'Umepokea Tsh 50,000.00 kutoka kwa John Doe tarehe 15/5/2026 saa 14:30. Ref: S78AB1C2D. Salio: Tsh 100,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 5000000,
      type: 'income',
      senderOrRecipient: 'John Doe',
      reference: 'S78AB1C2D',
      balanceAfter: 10000000,
    ),
  ),

  // =========================================================================
  // NMB Bank
  // =========================================================================
  SmsCorpusEntry(
    label: 'nmb_debit',
    sender: 'NMB',
    body: 'Tumekutoa TZS 150,000.00 kwa POS/MERCHANT/0123456789 tarehe 15/05/2026. Salio: TZS 1,250,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 15000000,
      type: 'expense',
      senderOrRecipient: 'POS/MERCHANT/0123456789',
      balanceAfter: 125000000,
    ),
  ),
  SmsCorpusEntry(
    label: 'nmb_credit',
    sender: 'NMB',
    body: 'Tumeongeza TZS 500,000.00 kutoka SALARY/MONTHLY tarehe 15/05/2026. Salio: TZS 1,750,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 50000000,
      type: 'income',
      senderOrRecipient: 'SALARY/MONTHLY',
      balanceAfter: 175000000,
    ),
  ),
  SmsCorpusEntry(
    label: 'nmb_fee',
    sender: 'NMB',
    body: 'Fees: TZS 1,000.00 kwa ATM WITHDRAWAL. Salio: TZS 1,249,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 100000,
      type: 'fee',
      balanceAfter: 124900000,
    ),
  ),

  // =========================================================================
  // CRDB Bank
  // =========================================================================
  SmsCorpusEntry(
    label: 'crdb_withdrawal',
    sender: 'CRDB',
    body: 'CRDB: Withdrawal TZS 200,000.00 at ATM/Arusha. Available: TZS 800,000.00. Ref: CRDB123',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 20000000,
      type: 'expense',
      senderOrRecipient: 'ATM/Arusha',
      reference: 'CRDB123',
      balanceAfter: 80000000,
    ),
  ),
  SmsCorpusEntry(
    label: 'crdb_deposit',
    sender: 'CRDB',
    body: 'CRDB: Deposit TZS 1,000,000.00 from MPESA. Available: TZS 1,800,000.00. Ref: CRDB456',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 100000000,
      type: 'income',
      senderOrRecipient: 'MPESA',
      reference: 'CRDB456',
      balanceAfter: 180000000,
    ),
  ),

  // =========================================================================
  // NBC Bank
  // =========================================================================
  SmsCorpusEntry(
    label: 'nbc_debit',
    sender: 'NBC',
    body: 'NBC: TZS 50,000.00 debited from acct ****1234. Desc: AIRTIME. Bal: TZS 450,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 5000000,
      type: 'expense',
      balanceAfter: 45000000,
    ),
  ),
  SmsCorpusEntry(
    label: 'nbc_credit',
    sender: 'NBC',
    body: 'NBC: TZS 300,000.00 credited to acct ****1234. Desc: SALARY. Bal: TZS 750,000.00',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(
      amount: 30000000,
      type: 'income',
      balanceAfter: 75000000,
    ),
  ),

  // =========================================================================
  // Promotional / non-transaction messages (should all return null)
  // =========================================================================
  SmsCorpusEntry(
    label: 'promo_mpesa',
    sender: 'M-PESA',
    body: 'Karibu M-PESA! Tuma pesa kwa urahisi na usalama. Piga *150*00# kwa huduma.',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(expectsNull: true),
  ),
  SmsCorpusEntry(
    label: 'promo_airtel',
    sender: 'AIRTEL',
    body: 'Airtel rewards! Pata data bure kwa kupiga simu zaidi.',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(expectsNull: true),
  ),
  SmsCorpusEntry(
    label: 'promo_tigo',
    sender: 'TIGO',
    body: 'Tigo nafuu! Pata dakika 100 kwa Tsh 500 tu.',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(expectsNull: true),
  ),
  SmsCorpusEntry(
    label: 'promo_generic',
    sender: 'SPAM',
    body: 'Congratulations! You have won a free iPhone! Click here to claim.',
    timestamp: DateTime(2026, 5, 15, 14, 30),
    expect: SmsExpectation(expectsNull: true),
  ),
];
