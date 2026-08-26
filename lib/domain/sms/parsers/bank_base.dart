import 'dart:developer' as developer;
import '../../models/sms_parsed.dart';
import 'amount_helper.dart';
import 'sms_parser_interface.dart';

class NmbBankParser implements SmsParser {
  String _extractReference(String text) {
    // New format: "Kumb: GWX102246282556 Imethibitishwa."
    final kumbRegex = RegExp(r'Kumb:\s*(\w+)', caseSensitive: false);
    final kumbMatch = kumbRegex.firstMatch(text);
    if (kumbMatch != null) return 'NMB-${kumbMatch.group(1)}';

    // Old format: "Ref: ABC123"
    final refRegex = RegExp(r'Ref:\s*([A-Za-z0-9]+)', caseSensitive: false);
    final refMatch = refRegex.firstMatch(text);
    if (refMatch != null) return 'NMB-${refMatch.group(1)}';

    return 'NMB-REF-UNKNOWN';
  }

  int? _extractBalance(String text) {
    final regex = RegExp(
      r'Salio:\s*(?:TZS|Tsh)?\s*([\d,]+(?:\.[\d]{2})?)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      return parseAmount(match.group(1) ?? '');
    }
    return null;
  }

  @override
  SmsParsed? parse(String rawSmsBody, DateTime timestamp) {
    final text = rawSmsBody.trim();

    try {
      // ── New format patterns ──
      // Real-world NMB Tanzania SMS uses these templates (as of 2026):

      // 1. Debit (expense) — "Kimetumwa" (sent)
      // "Kumb: GWX102246282556 Imethibitishwa.\nKiasi cha TSH334,500 kimetumwa kutoka katika akaunti inayoishia na 1222 kwenda ELISHA NDUNDULU 255763559341.\nTarehe:10-06-2026 20:11:13. Teleza Kidigitali na Mshiko Fasta"
      var match = RegExp(
        r'Kiasi\s+cha\s+(?:TSH|TZS)\s*([\d,]+)\s+kimetumwa\s+kutoka\s+katika\s+akaunti\s+inayoishia\s+na\s+\d+\s+kwenda\s+(.+?)(?:\.\s|\.$|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final recipient = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        // NMB Tariff Guide (June 2026): EFT Outward to other Bank = 2,000 TZS
        // NMB to NMB (internal) = FREE. Kimetumwa to phone number = mobile money = EFT outward.
        const int nmbEftOutwardTariff = 2000;

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: recipient,
          reference: ref,
          provider: 'NMB_Bank',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
          feeAmount: nmbEftOutwardTariff,
        );
      }

      // 2. Credit (income) — "Kimewekwa" (deposited)
      // "Kiasi cha TZS 335000 kimewekwa kwenye akaunti yako inayoishia na 11222 tarehe 10-06-2026. Kama hutambui muamala huu piga 0800002002. NMB Karibu yako"
      match = RegExp(
        r'Kiasi\s+cha\s+(?:TSH|TZS)\s*([\d,]+)\s+kimewekwa\s+kwenye\s+akaunti\s+yako\s+inayoishia\s+na?\s*\d+',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: 'Deposit',
          reference: ref,
          provider: 'NMB_Bank',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 3. Credit (income) — "Umepokea" (received from person)
      // "Umepokea kiasi cha TZS 8500 kwenye akaunti yako inayoishia 11222 kutoka  5525102063444 ELISHA NDUNDULU Tar 09.06.2026 11:04:55. NMB Karibu yako"
      match = RegExp(
        r'Umepokea\s+kiasi\s+cha\s+(?:TSH|TZS)\s*([\d,]+)\s+kwenye\s+akaunti\s+yako\s+inayoishia\s+\d+\s+kutoka\s+(\d+)\s+(.+?)\s+Tar',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final senderPhone = match.group(2) ?? '';
        final senderName = (match.group(3) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: '$senderName $senderPhone',
          reference: ref,
          provider: 'NMB_Bank',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // ── Fallback: old format patterns (may still be used by some NMB channels) ──

      // 4. Old Debit — "Tumekutoa"
      // "Tumekutoa TZS 150,000.00 kwa POS/MERCHANT/0123456789 tarehe 15/05/2026. Salio: TZS 1,250,000.00"
      match = RegExp(
        r'Tumekutoa\s+(?:TZS|Tsh)?\s*([\d,]+(?:\.[\d]{2})?)\s+kwa\s+(.+?)\s+tarehe',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final merchant = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        // NMB Tariff: ATM On-Us withdrawal fees (tiered by amount)
        // Only apply if merchant mentions POS/ATM/WITHDRAWAL
        int? posFee;
        final lowerMerchant = merchant.toLowerCase();
        if (lowerMerchant.contains('pos') ||
            lowerMerchant.contains('atm') ||
            lowerMerchant.contains('withdrawal') ||
            lowerMerchant.contains('wakala') ||
            lowerMerchant.contains('agent')) {
          // Tiered fees per NMB Tariff Guide June 2026
          if (amt <= 19999) {
            posFee = 1100;
          } else if (amt <= 39999) {
            posFee = 1400;
          } else if (amt <= 99999) {
            posFee = 1600;
          } else if (amt <= 199999) {
            posFee = 1800;
          } else if (amt <= 299999) {
            posFee = 2200;
          } else if (amt <= 399999) {
            posFee = 2400;
          } else if (amt <= 499999) {
            posFee = 2700;
          } else if (amt <= 599999) {
            posFee = 2800;
          } else if (amt <= 799999) {
            posFee = 3000;
          } else {
            posFee = 4000; // 800,000 - 1,000,000
          }
        }

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: merchant,
          reference: ref,
          provider: 'NMB_Bank',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
          feeAmount: posFee,
        );
      }

      // 5. Old Credit — "Tumeongeza"
      // "Tumeongeza TZS 500,000.00 kutoka SALARY/MONTHLY tarehe 15/05/2026. Salio: TZS 1,750,000.00"
      match = RegExp(
        r'Tumeongeza\s+(?:TZS|Tsh)?\s*([\d,]+(?:\.[\d]{2})?)\s+kutoka\s+(.+?)\s+tarehe',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final source = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: source,
          reference: ref,
          provider: 'NMB_Bank',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 6. Old Fees — "Fees:"
      // "Fees: TZS 1,000.00 kwa ATM WITHDRAWAL. Salio: TZS 1,249,000.00"
      match = RegExp(
        r'Fees:\s*(?:TZS|Tsh)?\s*([\d,]+(?:\.[\d]{2})?)\s+kwa\s+(.+?)\.',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final desc = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'fee',
          senderOrRecipient: 'NMB Fee: $desc',
          reference: ref,
          provider: 'NMB_Bank',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }
    } catch (e) {
      developer.log('NmbBankParser error: $e', name: 'Parser');
    }

    return null;
  }
}

class CrdbBankParser implements SmsParser {
  String _extractReference(String text) {
    final regex = RegExp(r'Ref:\s*([A-Za-z0-9]+)', caseSensitive: false);
    final match = regex.firstMatch(text);
    return match?.group(1) ?? 'CRDB-REF-UNKNOWN';
  }

  int? _extractBalance(String text) {
    final regex = RegExp(
      r'Available:\s*(?:TZS|Tsh)?\s*([\d,]+(?:\.[\d]{2})?)',
      caseSensitive: false,
    );
    final match = regex.firstMatch(text);
    if (match != null) {
      return parseAmount(match.group(1) ?? '');
    }
    return null;
  }

  @override
  SmsParsed? parse(String rawSmsBody, DateTime timestamp) {
    final text = rawSmsBody.trim();

    try {
      // 1. Check for Withdrawal (Debit)
      // Example: "CRDB: Withdrawal TZS 200,000.00 at ATM/Arusha. Available: TZS 800,000.00. Ref: CRDB123"
      final debitRegex = RegExp(
        r'CRDB:\s*Withdrawal\s+(?:TZS|Tsh)?\s*([\d,]+(?:\.[\d]{2})?)\s+at\s+(.+?)\.',
        caseSensitive: false,
      );
      var match = debitRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final merchant = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: merchant,
          reference: ref,
          provider: 'CRDB_Bank',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 2. Check for Deposit (Credit)
      // Example: "CRDB: Deposit TZS 1,000,000.00 from MPESA. Available: TZS 1,800,000.00. Ref: CRDB456"
      final creditRegex = RegExp(
        r'CRDB:\s*Deposit\s+(?:TZS|Tsh)?\s*([\d,]+(?:\.[\d]{2})?)\s+from\s+(.+?)\.',
        caseSensitive: false,
      );
      match = creditRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final source = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: source,
          reference: ref,
          provider: 'CRDB_Bank',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 3. Transfer Sent (Expense)
      // "CRDB: Your transfer of TZS 200,000.00 to JOHN DOE has been processed. Available: TZS 600,000.00. Ref: CRDB789"
      final transferSentRegex = RegExp(
        r'CRDB:\s*(?:Your\s+)?transfer\s+of\s+(?:TZS|Tsh)?\s*([\d,]+(?:\.[\d]{2})?)\s+to\s+(.+?)\s+has\s+been\s+processed',
        caseSensitive: false,
      );
      match = transferSentRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final recipient = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: recipient,
          reference: ref,
          provider: 'CRDB_Bank',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 4. Bill Payment (Expense)
      // "CRDB: You have paid TANESCO for TZS 85,000.00. Available: TZS 515,000.00. Ref: CRDB101"
      final billPaymentRegex = RegExp(
        r'CRDB:\s*You\s+have\s+paid\s+(.+?)\s+for\s+(?:TZS|Tsh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      );
      match = billPaymentRegex.firstMatch(text);
      if (match != null) {
        final biller = (match.group(1) ?? '').trim();
        final amt = parseAmount(match.group(2) ?? '');
        if (amt <= 0) return null;
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: biller,
          reference: ref,
          provider: 'CRDB_Bank',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 5. Fee / Charges (Fee)
      // "CRDB: Your account has been charged TZS 1,500.00 for EFT OUTWARD. Available: TZS 513,500.00. Ref: CRDB202"
      final feeRegex = RegExp(
        r'CRDB:\s*(?:Your\s+account\s+has\s+been\s+)?charged\s+(?:TZS|Tsh)?\s*([\d,]+(?:\.[\d]{2})?)\s+for\s+(.+?)\.?\s*(?:Available|Ref|$)',
        caseSensitive: false,
      );
      match = feeRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final desc = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'fee',
          senderOrRecipient: 'CRDB Fee: $desc',
          reference: ref,
          provider: 'CRDB_Bank',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 6. Salary / Employer Credit (Income)
      // "CRDB: Salary credited: TZS 1,200,000.00 from TELLA LTD. Available: TZS 1,800,000.00. Ref: CRDB303"
      final salaryCreditRegex = RegExp(
        r'CRDB:\s*(?:Salary\s+credited|Salary\s+credit)[:\s]+(?:TZS|Tsh)?\s*([\d,]+(?:\.[\d]{2})?)\s+from\s+(.+?)\.?\s*(?:Available|Ref|$)',
        caseSensitive: false,
      );
      match = salaryCreditRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final employer = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: employer,
          reference: ref,
          provider: 'CRDB_Bank',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 7. Standing Order / Direct Debit (Expense)
      // "CRDB: Standing order of TZS 250,000.00 to ACME INSURANCE has been processed. Available: TZS 265,000.00. Ref: CRDB404"
      final standingOrderRegex = RegExp(
        r'CRDB:\s*Standing\s+order\s+of\s+(?:TZS|Tsh)?\s*([\d,]+(?:\.[\d]{2})?)\s+to\s+(.+?)\s+has\s+been\s+processed',
        caseSensitive: false,
      );
      match = standingOrderRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final recipient = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: recipient,
          reference: ref,
          provider: 'CRDB_Bank',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }
    } catch (e) {
      developer.log('CrdbBankParser error: $e', name: 'Parser');
    }

    return null;
  }
}

class NbcBankParser implements SmsParser {
  @override
  SmsParsed? parse(String rawSmsBody, DateTime timestamp) {
    final text = rawSmsBody.trim();

    try {
      // 1. Check for Debited
      // Example: "NBC: TZS 50,000.00 debited from acct ****1234. Desc: AIRTIME. Bal: TZS 450,000.00"
      final debitRegex = RegExp(
        r'NBC:\s*(?:TZS|Tsh)?\s*([\d,]+(?:\.[\d]{2})?)\s+debited\s+from\s+acct\s+(.+?)\.\s*Desc:\s*(.+?)\.\s*Bal:\s*(?:TZS|Tsh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      );
      var match = debitRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final acct = (match.group(2) ?? '').trim();
        final desc = (match.group(3) ?? '').trim();
        final bal = parseAmount(match.group(4) ?? '');
        final dateStr =
            '${timestamp.day.toString().padLeft(2, '0')}'
            '${timestamp.month.toString().padLeft(2, '0')}'
            '${timestamp.year}';

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: '$desc (Acct: $acct)',
          reference: 'NBC-$dateStr-$amt',
          provider: 'NBC_Bank',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 2. Check for Credited
      // Example: "NBC: TZS 300,000.00 credited to acct ****1234. Desc: SALARY. Bal: TZS 750,000.00"
      final creditRegex = RegExp(
        r'NBC:\s*(?:TZS|Tsh)?\s*([\d,]+(?:\.[\d]{2})?)\s+credited\s+to\s+acct\s+(.+?)\.\s*Desc:\s*(.+?)\.\s*Bal:\s*(?:TZS|Tsh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      );
      match = creditRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final acct = (match.group(2) ?? '').trim();
        final desc = (match.group(3) ?? '').trim();
        final bal = parseAmount(match.group(4) ?? '');
        final dateStr =
            '${timestamp.day.toString().padLeft(2, '0')}'
            '${timestamp.month.toString().padLeft(2, '0')}'
            '${timestamp.year}';

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: '$desc (Acct: $acct)',
          reference: 'NBC-$dateStr-$amt',
          provider: 'NBC_Bank',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }
    } catch (e) {
      developer.log('NbcBankParser error: $e', name: 'Parser');
    }

    return null;
  }
}
