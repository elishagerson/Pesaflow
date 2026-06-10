import 'dart:developer' as developer;
import '../../../data/models/sms_parsed.dart';
import 'amount_helper.dart';
import 'sms_parser_interface.dart';

class MixxParser implements SmsParser {
  String _extractReference(String text) {
    final swaRegex = RegExp(r'(?:Kumbukumbu\s+no\.?|Kumbukumbu|Rej|TxnID|TxnId):?\s*([A-Za-z0-9]+)', caseSensitive: false);
    final match = swaRegex.firstMatch(text);
    return match?.group(1) ?? 'TIGO-REF-UNKNOWN';
  }

  int? _extractBalance(String text) {
    final swaRegex = RegExp(
      r'(?:Salio jipya ni|Salio|New balance is|New balance|(?<!outstanding )Balance|\bBal\b)\s*:?\s*(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)', 
      caseSensitive: false
    );
    final match = swaRegex.firstMatch(text);
    if (match != null) {
      return parseAmount(match.group(1)!);
    }
    return null;
  }

  @override
  SmsParsed? parse(String rawSmsBody, DateTime timestamp) {
    final text = rawSmsBody.trim();

    try {
      // 1. Swahili Received Money (Income)
      // Example: "Umepokea TZS 25,000.00 kutoka kwa 0712345678. Kumbukumbu: MX789012. Salio: TZS 150,000.00"
      final receivedRegex = RegExp(
        r'Umepokea\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:kutoka kwa|kutoka)\s+(.+?)(?:\.|\s+Kumbukumbu|\s+Rej|\s+Salio|\s+tarehe|$)',
        caseSensitive: false,
      );
      var match = receivedRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1)!);
        final sender = match.group(2)!.trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: sender,
          reference: ref,
          provider: 'TigoPesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 2. English Received Money (Income)
      // Example: "You have received TZS 25,000.00 from 0712345678. TxnID: MX789012. Balance: TZS 150,000.00"
      final engReceivedRegex = RegExp(
        r'You have received\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+from\s+(.+?)(?:\.|\s+TxnID|\s+TxnId|\s+Balance|\s+on|$)',
        caseSensitive: false,
      );
      match = engReceivedRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1)!);
        final sender = match.group(2)!.trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: sender,
          reference: ref,
          provider: 'TigoPesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 3. Swahili Sent Money (Expense)
      // Example: "Umetuma TZS 15,000.00 kwa 0765432198. Kumbukumbu: MX210987. Salio: TZS 135,000.00"
      final sentRegex = RegExp(
        r'Umetuma\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+(?:kwa|kwenda)\s+(.+?)(?:\.|\s+Kumbukumbu|\s+Rej|\s+Salio|\s+tarehe|$)',
        caseSensitive: false,
      );
      match = sentRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1)!);
        final recipient = match.group(2)!.trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: recipient,
          reference: ref,
          provider: 'TigoPesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 4. Swahili Payment Completed (Expense) — e.g. Nivushe Plus, Bustisha etc.
      // Example: "Malipo yamekamilika kwenda Nivushe Plus, Kiasi Tsh645,728. Salio jipya ni Tsh 47,272. Ada Tsh 0. VAT TSh 0. Kumbukumbu no.26394529507543."
      final malipoRegex = RegExp(
        r'Malipo yamekamilika kwenda (.+?),\s*Kiasi\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      );
      match = malipoRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(2)!);
        final recipient = match.group(1)!.trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: recipient,
          reference: ref,
          provider: 'TigoPesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 5. Bundle/Package purchase (Expense/Airtime)
      // Example: "Ununuzi wa kifurushi TZS 3,000.00. Salio: TZS 132,000.00"
      final bundleRegex = RegExp(
        r'Ununuzi\s+wa\s+kifurushi\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      );
      match = bundleRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1)!);
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'airtime',
          senderOrRecipient: 'Tigo Pesa Bundle',
          reference: ref,
          provider: 'TigoPesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 6. English Sent Money (Expense)
      // Example: "You have sent TSh 20,000 to Airtel receiver STEPHAN MWAKALASYA - 255787273486. Charges TSh 540. VAT TSh 82. New balance is TSh 311,708. TxnID: 26706282103620."
      final engSentRegex = RegExp(
        r'You have sent\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+to\s+(.+?)(?:\.|\s+Charges|\s+New balance|\s+TxnID|\s+on|$)',
        caseSensitive: false,
      );
      match = engSentRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1)!);
        final recipient = match.group(2)!.trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: recipient,
          reference: ref,
          provider: 'TigoPesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 6. English Payment Completed (Expense) — e.g. Bustisha loan repayment
      // Example: "You have successfully paid your Bustisha Balance by TSh 117,904.55. Your outstanding balance: TSh 8,330.60. New balance: TSh 0. TxnID: 26794215512428. Loan ID: 202606081844181845670752806590."
      final paidBalanceRegex = RegExp(
        r'You have successfully paid your (.+?)\s+Balance\s+by\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)',
        caseSensitive: false,
      );
      match = paidBalanceRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(2)!);
        final recipient = match.group(1)!.trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'expense',
          senderOrRecipient: recipient,
          reference: ref,
          provider: 'TigoPesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }

      // 7. English Cash-In (Income / Agent Deposit)
      // Example: "Cash-In of TSh 143,000 from Agent - ELIZA  NYONDO is successful. New balance is TSh 143,000. TxnId: 26694528075313."
      final engCashInRegex = RegExp(
        r'Cash-In of\s+(?:Tsh|TZS|TSh)?\s*([\d,]+(?:\.[\d]{2})?)\s+from\s+(.+?)\s+is successful',
        caseSensitive: false,
      );
      match = engCashInRegex.firstMatch(text);
      if (match != null) {
        final amt = parseAmount(match.group(1)!);
        final sender = match.group(2)!.trim();
        final ref = _extractReference(text);
        final bal = _extractBalance(text);

        return SmsParsed(
          amount: amt,
          type: 'income',
          senderOrRecipient: sender,
          reference: ref,
          provider: 'TigoPesa_TZ',
          balanceAfter: bal,
          timestamp: timestamp,
          rawSmsBody: text,
        );
      }
    } catch (e) {
      developer.log('MixxParser error: $e', name: 'Parser');
    }

    return null;
  }
}
