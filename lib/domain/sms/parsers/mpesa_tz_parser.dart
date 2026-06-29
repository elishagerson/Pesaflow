import 'dart:developer' as developer;
import '../../models/sms_parsed.dart';
import 'amount_helper.dart';
import 'sms_parser_interface.dart';

class MpesaTzParser implements SmsParser {
  String _extractReference(String text) {
    // Swahili: Rej: XXXXX
    final rejRegex = RegExp(r'Rej:\s*([A-Za-z0-9]+)', caseSensitive: false);
    final match = rejRegex.firstMatch(text);
    if (match != null) return match.group(1) ?? '';

    // English: reference word before "Confirmed."
    final engRefRegex = RegExp(r'(\w+)\s+Confirmed\.', caseSensitive: false);
    final engMatch = engRefRegex.firstMatch(text);
    if (engMatch != null) return engMatch.group(1) ?? '';

    return 'MPESA-REF-UNKNOWN';
  }

  int? _extractBalance(String text) {
    // Swahili: Salio: Tsh XXX
    final salioRegex = RegExp(
      r'Salio:\s*(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
      caseSensitive: false,
    );
    final match = salioRegex.firstMatch(text);
    if (match != null) {
      return parseAmount(match.group(1) ?? '');
    }

    // English: "New M-PESA balance is Tsh XXX" or "Balance is Tsh XXX"
    final engBalRegex = RegExp(
      r'(?:New\s+M[- ]?PESA\s+)?Balance\s+is\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
      caseSensitive: false,
    );
    final engMatch = engBalRegex.firstMatch(text);
    if (engMatch != null) {
      return parseAmount(engMatch.group(1) ?? '');
    }

    return null;
  }

  @override
  SmsParsed? parse(String rawSmsBody, DateTime timestamp) {
    final text = rawSmsBody.trim();

    try {
      // 1. Check for Received Money (Income)
      // Example: "Pesa zimewekwa Tsh 50,000.00 na John Doe tarehe 15/5/2026... Rej: P65AB. Salio: Tsh 250,000.00"
      final receivedRegex = RegExp(
        r'(?:Pesa zimewekwa|Umepokea|Umepewa)\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:na|kutoka kwa|kutoka)\s+(.+?)(?:\.|\s+tarehe|\s+Rej|\s+Salio|$)',
        caseSensitive: false,
      );
      var match = receivedRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        final sender = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: sender,
          reference: ref,
          provider: 'M-Pesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 2. Check for Sent Money (Expense)
      // Example: "Umetuma Tsh 30,000.00 kwa Jane Doe tarehe 15/5/2026... Rej: P65XYZ. Salio: Tsh 220,000.00"
      final sentRegex = RegExp(
        r'Umetuma\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:kwa|kwenda)\s+(.+?)(?:\.|\s+tarehe|\s+Rej|\s+Salio|$)',
        caseSensitive: false,
      );
      match = sentRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        final recipient = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: recipient,
          reference: ref,
          provider: 'M-Pesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 3. Check for Airtime purchase (Expense/Airtime)
      // Example: "Umenunua airtime Tsh 5,000.00 kwa 0712345678 tarehe 15/5/2026. Rej: A65ABC. Salio: Tsh 215,000.00"
      final airtimeRegex = RegExp(
        r'Umenunua\s+airtime\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      );
      match = airtimeRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'airtime',
          senderOrRecipient: 'Vodacom Airtime',
          reference: ref,
          provider: 'M-Pesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 4. Check for service fee / carrier deduction (Expense/Fee)
      // Example: "Kodi ya kuhudumia Tsh 500.00 tarehe 15/5/2026. Salio: Tsh 214,500.00"
      final feeRegex = RegExp(
        r'Kodi\s+ya\s+kuhudumia\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      );
      match = feeRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'fee',
          senderOrRecipient: 'Vodacom Service Fee',
          reference: ref,
          provider: 'M-Pesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 5. Check for Loan disbursement (Income — money received as loan)
      // Example (Swahili): "Pesa zimekopeshwa Tsh 100,000.00. Maliza ndani ya siku 30. Rej: P65ABC. Salio: Tsh 250,000.00"
      // Example (English): "You have received a loan of Tsh 100,000.00. Pay within 30 days. Ref: P65ABC. New M-PESA balance is Tsh 250,000.00"
      final loanRegex = RegExp(
        r'(?:Pesa zimekopeshwa|Umekopeshwa|Umekopwa|received a loan|loan of)\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      );
      match = loanRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'loan',
          senderOrRecipient: 'Mobile Money Loan',
          reference: ref,
          provider: 'M-Pesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // ========== English-format patterns (Vodacom Tanzania) ==========

      // 5. English: Received Money (Income)
      // Example: "Z10DN636 Confirmed.You have received Tsh50,000 from FREDRICK KIMARO on 27/1/14 at 1:19 PM New M-PESA balance is Tsh214,676"
      // Also: "DFDFI1D6RN confirmed. You have received a payment of Tsh26,000.00 from 922749 - TIPS-Mixx By Yas on 13/6/26 at 5:48 pm."
      final engReceivedRegex = RegExp(
        r'Confirmed\.\s*You have received\s+(?:a payment of\s+)?(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+from\s+(.+?)(?:\.|\s+on|\s+New M[- ]?PESA|$)',
        caseSensitive: false,
      );
      match = engReceivedRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        final sender = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: sender,
          reference: ref,
          provider: 'M-Pesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 6. English: Sent Money (Expense)
      // Example: "Z10DN636 Confirmed.You have sent Tsh30,000 to JANE DOE on 27/1/14 at 1:19 PM New M-PESA balance is Tsh184,676"
      final engSentRegex = RegExp(
        r'Confirmed\.\s*You have sent\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+to\s+(.+?)(?:\.|\s+on|\s+New M[- ]?PESA|$)',
        caseSensitive: false,
      );
      match = engSentRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        final recipient = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: recipient,
          reference: ref,
          provider: 'M-Pesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 6a. English: Sent Money — modern format (Expense)
      // Example: "DF3FI18H5B Confirmed. Tsh150,000.00 sent to TIPS-SELCOM MF for account 255763559341 on 3/6/26 at 2:04 pm Total fee Tsh3,500.00. Balance is Tsh2,561.00"
      final engSentModernRegex = RegExp(
        r'Confirmed\.\s*(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+sent\s+to\s+(.+?)(?:\s+for account|\s+on|\.?\s*Total fee|\s*Balance|$)',
        caseSensitive: false,
      );
      match = engSentModernRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        final recipient = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: recipient,
          reference: ref,
          provider: 'M-Pesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 7. English: Paid Bills (Expense)
      // Example: "Z10DN636 Confirmed.You have paid Tsh100,000 to ZESA BILLS on 27/1/14 at 1:19 PM New M-PESA balance is Tsh79,676"
      final engPaidRegex = RegExp(
        r'Confirmed\.\s*You have paid\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+to\s+(.+?)(?:\.|\s+on|\s+New M[- ]?PESA|$)',
        caseSensitive: false,
      );
      match = engPaidRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        final payee = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: payee,
          reference: ref,
          provider: 'M-Pesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 8. English: Airtime Purchase (Expense/Airtime)
      // Example: "Z10DN636 Confirmed.You have bought airtime of Tsh5,000 on 27/1/14 at 1:19 PM New M-PESA balance is Tsh74,676"
      final engAirtimeRegex = RegExp(
        r'Confirmed\.\s*You have bought airtime of\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      );
      match = engAirtimeRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'airtime',
          senderOrRecipient: 'Vodacom Airtime',
          reference: ref,
          provider: 'M-Pesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 9. English: Transaction Fee (Expense/Fee)
      // Example: "Transaction cost Tsh500 on 27/1/14 at 1:19 PM New M-PESA balance is Tsh74,176"
      final engFeeRegex = RegExp(
        r'Transaction cost\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      );
      match = engFeeRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'fee',
          senderOrRecipient: 'Vodacom Service Fee',
          reference: ref,
          provider: 'M-Pesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 9a. English: Overdraft Repayment (Expense)
      // Example: "DFDFI1D4UA Confirmed. Tsh5,698.00 has been deducted from your M-Pesa account on 13/6/26 at 2:26 pm as a repayment of M-Pesa Overdraft service. New M-Pesa balance is Tsh36,577.00."
      final engOverdraftRegex = RegExp(
        r'Confirmed\.\s*(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+has been deducted from your M[- ]?PESA account.+?as a repayment of\s+(.+?)(?:\.|$)',
        caseSensitive: false,
      );
      match = engOverdraftRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1) ?? '');
        final service = (match.group(2) ?? '').trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: service,
          reference: ref,
          provider: 'M-Pesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }
    } catch (e) {
      developer.log('MpesaTzParser error: $e', name: 'Parser');
    }

    return null;
  }
}
