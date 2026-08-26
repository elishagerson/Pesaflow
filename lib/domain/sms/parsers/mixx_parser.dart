import 'dart:developer' as developer;
import '../../models/sms_parsed.dart';
import 'amount_helper.dart';
import 'sms_parser_interface.dart';

class MixxParser implements SmsParser {
  // Known TigoPesa/Mixx loan product names (lowercase for matching)
  static const _loanProducts = {
    'bustisha',
    'nivushe',
    'nivushe plus',
    'mkopo wa mixx',
    'mixx mkopo',
    'mkopo',
  };

  static bool _isLoanProduct(String name) {
    final lower = name.toLowerCase();
    return _loanProducts.any((p) => lower.contains(p));
  }

  String _extractReference(String text) {
    // Swahili: Kumbukumbu no. / Kumbukumbu, Rej, TxnID/TxnId
    final swaRegex = RegExp(
      r'(?:Kumbukumbu\s+no\.?|Kumbukumbu|Rej|TxnID|TxnId|Marejeleo):?\s*([A-Za-z0-9]+)',
      caseSensitive: false,
    );
    var match = swaRegex.firstMatch(text);
    if (match != null) return match.group(1) ?? '';

    // Reference code before "Confirmed." or "confirmed." (English)
    final confirmedRegex = RegExp(r'([A-Z0-9]{6,})\s+[Cc]onfirmed\.?');
    match = confirmedRegex.firstMatch(text);
    if (match != null) return match.group(1) ?? '';

    return 'TIGO-REF-UNKNOWN';
  }

  int? _extractFee(String text) {
    // Swahili: "Ada: TZS 300", "Ada Tsh 180"
    final swaRegex = RegExp(
      r'Ada\s*:\s*(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
      caseSensitive: false,
    );
    final swaMatch = swaRegex.firstMatch(text);
    if (swaMatch != null) {
      return parseAmount(swaMatch.group(1) ?? '');
    }

    // English: "Fee: TZS 300" or "Total fee Tsh3,500.00"
    final engRegex = RegExp(
      r'(?:Total\s+)?Fee\s*:\s*(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
      caseSensitive: false,
    );
    final engMatch = engRegex.firstMatch(text);
    if (engMatch != null) {
      return parseAmount(engMatch.group(1) ?? '');
    }

    // "Total Charges TSh 300" or "Charges TSh 540"
    final chargesRegex = RegExp(
      r'(?:Total\s+)?Charges?\s*:\s*(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
      caseSensitive: false,
    );
    final chargesMatch = chargesRegex.firstMatch(text);
    if (chargesMatch != null) {
      return parseAmount(chargesMatch.group(1) ?? '');
    }

    // "Service fee: TZS 300" or "Service fee TZS 100"
    final svcRegex = RegExp(
      r'Service\s+fee\s*:\s*(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
      caseSensitive: false,
    );
    final svcMatch = svcRegex.firstMatch(text);
    if (svcMatch != null) {
      return parseAmount(svcMatch.group(1) ?? '');
    }

    return null;
  }

  int? _extractBalance(String text) {
    // Swahili: Salio jipya ni / Salio
    final swaRegex = RegExp(
      r'(?:Salio jipya ni|Salio)\s*:?\s*(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
      caseSensitive: false,
    );
    var match = swaRegex.firstMatch(text);
    if (match != null) {
      return parseAmount(match.group(1) ?? '');
    }

    // English: New balance is / Balance is / New Mixx balance is / Updated balance is
    final engRegex = RegExp(
      r'(?:New\s+(?:Mixx\s+)?balance is|Balance is|Updated balance is)\s*(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
      caseSensitive: false,
    );
    match = engRegex.firstMatch(text);
    if (match != null) {
      return parseAmount(match.group(1) ?? '');
    }

    // English: abbreviated balance-first format, e.g. "New Bal TSh 200."
    // Modern Mixx by Yas messages put the balance right at the start.
    final balFirstRegex = RegExp(
      r'(?<!(?:outstanding\s+|(?:Your\s+)?outstanding\s+))\b(?:New\s+)?Bal(?:ance)?[.:]?\s*(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
      caseSensitive: false,
    );
    match = balFirstRegex.firstMatch(text);
    if (match != null) {
      return parseAmount(match.group(1) ?? '');
    }

    // Generic: "Balance: TSh X" (standalone)
    final genericRegex = RegExp(
      r'(?<!(?:outstanding|(?:Your\s+)?outstanding))\bBalance\s*:\s*(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
      caseSensitive: false,
    );
    match = genericRegex.firstMatch(text);
    if (match != null) {
      return parseAmount(match.group(1) ?? '');
    }

    return null;
  }

  @override
  SmsParsed? parse(String rawSmsBody, DateTime timestamp) {
    final text = rawSmsBody.trim();

    try {
      // ── SWAHILI PATTERNS ──────────────────────────────────────────────

      // 1a. Swahili Received Money (Income)
      // "Umepokea TZS 25,000.00 kutoka kwa 0712345678. Kumbukumbu: MX789012. Salio: TZS 150,000.00"
      var match = RegExp(
        r'Umepokea\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:kutoka kwa|kutoka)\s+(.+?)(?:\.|\s+Kumbukumbu|\s+Rej|\s+Salio|\s+tarehe|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        return _buildIncome(match, text, timestamp);
      }

      // 1b. Swahili Received — Umewekwa / Zimewekwa (money deposited)
      // "Umewekwa TZS 50,000.00 na JOHN DOE. Kumbukumbu: MX789012. Salio: TZS 200,000"
      // "Zimewekwa TZS 30,000.00 na 0712345678. Kumbukumbu: MX789012. Salio: TZS 180,000"
      match = RegExp(
        r'(?:Umewekwa|Zimewekwa|Umepewa)\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:na|kutoka kwa|kutoka)\s+(.+?)(?:\.|\s+Kumbukumbu|\s+Rej|\s+Salio|\s+tarehe|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        return _buildIncome(match, text, timestamp);
      }

      // 2. Swahili Sent Money (Expense)
      // "Umetuma TZS 15,000.00 kwa 0765432198. Kumbukumbu: MX210987. Salio: TZS 135,000.00"
      match = RegExp(
        r'Umetuma\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:kwa|kwenda)\s+(.+?)(?:\.|\s+Kumbukumbu|\s+Rej|\s+Salio|\s+tarehe|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        return _buildExpense(match, text, timestamp);
      }

      // 2b. Swahili Transferred — Umehamisha/Umehamishia (alternative sent wording)
      // "Umehamisha TZS 10,000 kwenda 0712345678. Kumbukumbu: MX789012. Salio: TZS 50,000"
      match = RegExp(
        r'Umehamisha(?:ia)?\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:kwa|kwenda)\s+(.+?)(?:\.|\s+Kumbukumbu|\s+Rej|\s+Salio|\s+tarehe|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        return _buildExpense(match, text, timestamp);
      }

      // 3. Swahili Payment Completed (Expense) — e.g. Nivushe Plus, Bustisha etc.
      // "Malipo yamekamilika kwenda Nivushe Plus, Kiasi Tsh645,728. Salio jipya ni Tsh 47,272. Ada Tsh 0. VAT TSh 0. Kumbukumbu no.26394529507543."
      match = RegExp(
        r'Malipo yamekamilika kwenda (.+?),\s*Kiasi\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(2) ?? '');
        if (amt <= 0) return null;
        final recipient = (match.group(1) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: recipient,
          reference: ref,
          provider: 'TigoPesa_TZ',
          balanceAfter: bal,
          feeAmount: _extractFee(text),
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 4a. Bundle/Package purchase (Expense/Airtime)
      // "Ununuzi wa kifurushi TZS 3,000.00. Salio: TZS 132,000.00"
      match = RegExp(
        r'Ununuzi\s+wa\s+kifurushi\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        return _buildAirtime(match, text, timestamp, 'Tigo Pesa Bundle');
      }

      // 4b. Airtime purchase — Swahili alternative
      // "Umenunua airtime TZS 5,000. Salio: TZS 195,000"
      match = RegExp(
        r'Umenunua\s+airtime\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        return _buildAirtime(match, text, timestamp, 'Tigo Pesa Airtime');
      }

      // 5. Swahili Fee/Charge — Tumekutoa (We have deducted)
      // "Tumekutoa TZS 2,000 kwa ada ya huduma. Salio: TZS 198,000"
      match = RegExp(
        r'Tumekutoa\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'fee',
          senderOrRecipient: 'Tigo Pesa Service Fee',
          reference: ref,
          provider: 'TigoPesa_TZ',
          balanceAfter: bal,
          feeAmount: _extractFee(text),
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 6. Swahili — received a loan
      // "Umekopeshwa TZS 100,000. Maliza ndani ya siku 30. Rej: MX789012. Salio: TZS 200,000"
      match = RegExp(
        r'(?:Umekopeshwa|Umekopwa|Umepewa mkopo)\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'loan',
          senderOrRecipient: 'Mobile Money Loan',
          reference: ref,
          provider: 'TigoPesa_TZ',
          balanceAfter: bal,
          feeAmount: _extractFee(text),
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // ── ENGLISH PATTERNS ───────────────────────────────────────────────

      // 7. English Received — Confirmed prefix (like M-Pesa)
      // "ABC123DF Confirmed. You have received TZS 25,000.00 from JOHN DOE on 15/06/26. New balance is TZS 150,000.00"
      match = RegExp(
        r'[A-Z0-9]+\s+[Cc]onfirmed\.\s*You have received\s+(?:a payment of\s+)?(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+from\s+(.+?)(?:\.|\s+on|\s+New\s+(?:Mixx\s+)?balance|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final sender = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);
        final isLoan = _isLoanProduct(sender);

        return SmsParsed(
          amount: amt,
          type: isLoan ? 'loan' : 'income',
          senderOrRecipient: sender,
          reference: ref,
          provider: 'TigoPesa_TZ',
          balanceAfter: bal,
          feeAmount: _extractFee(text),
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 8. English Received Money (without Confirmed prefix)
      // "You have received TZS 25,000.00 from 0712345678. TxnID: MX789012. Balance: TZS 150,000.00"
      match = RegExp(
        r'You have received\s+(?:a payment of\s+)?(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+from\s+(.+?)(?:\.|\s+TxnID|\s+TxnId|\s+Balance|\s+New\s+balance|\s+Updated balance|\s+on|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final sender = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);
        final isLoan = _isLoanProduct(sender);

        return SmsParsed(
          amount: amt,
          type: isLoan ? 'loan' : 'income',
          senderOrRecipient: sender,
          reference: ref,
          provider: 'TigoPesa_TZ',
          balanceAfter: bal,
          feeAmount: _extractFee(text),
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 9. English Credited (wallet deposit)
      // "Your Mixx wallet has been credited with TZS 500,000.00 from 0712345678 on 15/06/26."
      match = RegExp(
        r'(?:Your\s+)?(?:Mixx|Tigo|wallet)\s*(?:wallet\s+)?has been credited (?:with|from)\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:from|with)\s+(.+?)(?:\.|\s+on|\s+Ref|\s+TxnID|\s+Balance|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final sender = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: sender,
          reference: ref,
          provider: 'TigoPesa_TZ',
          balanceAfter: bal,
          feeAmount: _extractFee(text),
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 10. English Sent — Confirmed prefix
      // "ABC123DF Confirmed. You have sent TSh 20,000 to STEPHAN MWAKALASYA on 3/6/26. New balance is TSh 311,708."
      match = RegExp(
        r'[A-Z0-9]+\s+[Cc]onfirmed\.\s*You have sent\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+to\s+(.+?)(?:\.|\s+on|\s+New\s+(?:Mixx\s+)?balance|\s+Charges|\s+TxnID|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        return _buildExpense(match, text, timestamp);
      }

      // 10b. English Sent — modern "Confirmed. TSh X sent to Y"
      // "ABC123DF Confirmed. Tsh 150,000.00 sent to TIPS-Mixx By Yas for account 255763559341 on 3/6/26."
      match = RegExp(
        r'[A-Z0-9]+\s+[Cc]onfirmed\.\s*(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+sent\s+to\s+(.+?)(?:\s+for account|\s+on|\.?\s*Total fee|\s*Balance|\s*New\s+(?:Mixx\s+)?balance|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        return _buildExpense(match, text, timestamp);
      }

      // 11. English Sent Money (without Confirmed prefix)
      // "You have sent TSh 20,000 to Airtel receiver STEPHAN MWAKALASYA - 255787273486. Charges TSh 540."
      match = RegExp(
        r'You have sent\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+to\s+(.+?)(?:\.|\s+Charges|\s+New\s+(?:Mixx\s+)?balance|\s+TxnID|\s+TxnId|\s+Updated balance|\s+on|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        return _buildExpense(match, text, timestamp);
      }

      // 12. English "Money sent successfully to" (modern Mixx by Yas format)
      // Balance appears first, amount uses "Amt" label
      // Example: "New Bal TSh 200. Money sent successfully to Sporty Bet, Biller Code: 190190, Ref No: 255675259341.Amt TSh 7,500, Total Charges TSh 300.(Fees TSh 0, Levy TSh 0), VAT TSh 46.TxnID: 26693868497442."
      match = RegExp(
        r'Money sent successfully to\s+(.+?)[,\.].*?Amt\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
        dotAll: true,
      ).firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(2) ?? '');
        if (amt <= 0) return null;
        final recipient = (match.group(1) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: recipient,
          reference: ref,
          provider: 'TigoPesa_TZ',
          balanceAfter: bal,
          feeAmount: _extractFee(text),
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 13. English You have paid (payment to merchant)
      // "You have paid TSh 30,000 to Merchant XYZ. New balance is TSh 120,000"
      match = RegExp(
        r'You have paid\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+to\s+(.+?)(?:\.|\s+on|\s+New\s+(?:Mixx\s+)?balance|\s+Balance|$)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        return _buildExpense(match, text, timestamp);
      }

      // 13. English Paid Balance (loan repayment)
      // "You have successfully paid your Bustisha Balance by TSh 117,904.55. Your outstanding balance: TSh 8,330.60."
      match = RegExp(
        r'You have successfully paid your (.+?)\s+Balance\s+by\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(2) ?? '');
        if (amt <= 0) return null;
        final recipient = (match.group(1) ?? '').trim();
        final ref = _extractReference(text);
        // Balance in loan repayment SMS is the loan balance, NOT wallet balance
        final int? bal = null;

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: recipient,
          reference: ref,
          provider: 'TigoPesa_TZ',
          balanceAfter: bal,
          feeAmount: _extractFee(text),
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 14. English Cash-In (Agent Deposit)
      // "Cash-In of TSh 143,000 from Agent - ELIZA NYONDO is successful. New balance is TSh 143,000."
      match = RegExp(
        r'Cash-In of\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+from\s+(.+?)\s+is successful',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        if (amt <= 0) return null;
        final sender = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: sender,
          reference: ref,
          provider: 'TigoPesa_TZ',
          balanceAfter: bal,
          feeAmount: _extractFee(text),
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 15. English Withdrawal (Cash withdrawal from agent)
      // "Withdrawal of TSh 50,000 from Agent - JANE DOE is successful. New balance is TSh 100,000."
      match = RegExp(
        r'Withdrawal\s+of\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+from\s+(.+?)\s+is successful',
        caseSensitive: false,
      ).firstMatch(text);
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
          provider: 'TigoPesa_TZ',
          balanceAfter: bal,
          feeAmount: _extractFee(text),
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 16. English Airtime purchase (Confirmed prefix)
      // "ABC123DF Confirmed. You have bought airtime of TSh 5,000 on 15/06/26. New balance is TSh 195,000"
      match = RegExp(
        r'[A-Z0-9]+\s+[Cc]onfirmed\.\s*You have bought airtime of\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      ).firstMatch(text);
      if (match != null) {
        return _buildAirtime(match, text, timestamp, 'Tigo Pesa Airtime');
      }
    } catch (e) {
      developer.log('MixxParser error: $e', name: 'Parser');
    }

    return null;
  }

  SmsParsed? _buildIncome(Match match, String text, DateTime timestamp) {
    final amt = parseAmount(match.group(1) ?? '');
    if (amt <= 0) return null;
    final sender = (match.group(2) ?? '').trim();
    final ref = _extractReference(text);
    final bal = _extractBalance(text);
    final isLoan = _isLoanProduct(sender);

    return SmsParsed(
      amount: amt,
      type: isLoan ? 'loan' : 'income',
      senderOrRecipient: sender,
      reference: ref,
      provider: 'TigoPesa_TZ',
      balanceAfter: bal,
      feeAmount: _extractFee(text),
      timestamp: timestamp,
      rawSmsBody: text,
    );
  }

  SmsParsed? _buildExpense(Match match, String text, DateTime timestamp) {
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
      provider: 'TigoPesa_TZ',
      balanceAfter: bal,
      feeAmount: _extractFee(text),
      timestamp: timestamp,
      rawSmsBody: text,
    );
  }

  SmsParsed? _buildAirtime(
    Match match,
    String text,
    DateTime timestamp,
    String label,
  ) {
    final amt = parseAmount(match.group(1) ?? '');
    if (amt <= 0) return null;
    final ref = _extractReference(text);
    final bal = _extractBalance(text);

    return SmsParsed(
      amount: amt,
      type: 'airtime',
      senderOrRecipient: label,
      reference: ref,
      provider: 'TigoPesa_TZ',
      balanceAfter: bal,
      feeAmount: _extractFee(text),
      timestamp: timestamp,
      rawSmsBody: text,
    );
  }
}
