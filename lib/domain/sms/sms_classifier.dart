import 'dart:developer' as developer;
import 'dart:math' as math;

/// Classification result from the SMS classifier.
class SmsClassification {
  /// 'transaction', 'promo', or 'informational'
  final String label;

  /// 0.0 – 1.0 confidence that this is a genuine transaction.
  /// Higher = more likely to be a real transaction.
  final double transactionConfidence;

  /// Human-readable reasons explaining the classification decision.
  /// Each entry is a signal that contributed to the score.
  final List<String> reasons;

  const SmsClassification({
    required this.label,
    required this.transactionConfidence,
    required this.reasons,
  });

  bool get isTransaction => label == 'transaction';
  bool get isPromo => label == 'promo';
  bool get isInformational => label == 'informational';

  @override
  String toString() =>
      'SmsClassification($label, confidence: ${transactionConfidence.toStringAsFixed(2)}, reasons: $reasons)';
}

/// Lightweight signal-based classifier that scores an SMS across multiple
/// dimensions to determine whether it is a genuine transaction receipt,
/// a promotional / marketing message, or an informational / service message.
///
/// Each signal contributes a weighted score. The final normalised score
/// is mapped to a classification label.
///
/// This replaces the earlier keyword-blocklist approach with a more nuanced
/// model that can explain *why* an SMS was rejected.
class SmsClassifier {
  const SmsClassifier._();

  /// Classifies the raw SMS body text.
  ///
  /// Returns a [SmsClassification] with label, confidence, and reasons.
  static SmsClassification classify(String rawBody) {
    final text = rawBody.trim();
    final lower = text.toLowerCase();
    final reasons = <String>[];

    // ── Accumulate weighted score ──
    // Positive score = transaction signal
    // Negative score = promo / non-transaction signal
    double score = 0.0;

    // ════════════════════════════════════════════
    //  PROMO / NON-TRANSACTION SIGNALS (negative)
    // ════════════════════════════════════════════

    // Signal: Contains URLs (strong promo indicator)
    if (_hasUrl(lower)) {
      score -= 3.0;
      reasons.add('Contains URL (www/http) → promo');
    }

    // Signal: Contains dial / USSD codes
    if (_hasDialCode(lower)) {
      score -= 2.5;
      reasons.add('Contains dial/USSD code → promo');
    }

    // Signal: Promotional language (weighted by specificity)
    final promoHits = _countPromoSignals(lower);
    if (promoHits.score > 0) {
      score -= promoHits.score;
      reasons.add(
        'Promo language (${promoHits.matches.join(", ")}) → −${promoHits.score.toStringAsFixed(1)}',
      );
    }

    // Signal: Excessive exclamation marks (promo urgency)
    final exclamationCount = '!'.allMatches(text).length;
    if (exclamationCount >= 2) {
      score -= 1.5;
      reasons.add(
        'Multiple exclamation marks ($exclamationCount) → promo urgency',
      );
    }

    // Signal: Message is very long (receipts are typically < 250 chars, promos are longer)
    if (text.length > 350) {
      score -= 1.0;
      reasons.add('Long message (${text.length} chars) → more likely promo');
    }

    // Signal: All-caps ratio (promos tend to shout)
    final upperCount = text.runes.where((r) => r >= 65 && r <= 90).length;
    final alphaCount = text.runes
        .where((r) => (r >= 65 && r <= 90) || (r >= 97 && r <= 122))
        .length;
    if (alphaCount > 20) {
      final capsRatio = upperCount / alphaCount;
      if (capsRatio > 0.60) {
        score -= 1.0;
        reasons.add(
          'High caps ratio (${(capsRatio * 100).toStringAsFixed(0)}%) → promo style',
        );
      }
    }

    // ════════════════════════════════════════════
    //  TRANSACTION SIGNALS (positive)
    // ════════════════════════════════════════════

    // Signal: Has a transaction reference pattern (strongest signal)
    if (_hasReferencePattern(text)) {
      score += 4.0;
      reasons.add('Has transaction reference pattern → receipt');
    }

    // Signal: Has a balance-after pattern
    if (_hasBalancePattern(lower)) {
      score += 3.0;
      reasons.add('Has balance-after pattern → receipt');
    }

    // Signal: Has "Confirmed" keyword (carrier confirmation) — English + Swahili
    if (lower.contains('confirmed') || lower.contains('imethibitishwa')) {
      score += 2.5;
      reasons.add('Contains "Confirmed/imethibitishwa" → receipt');
    }

    // Signal: Contains strong transaction verbs (Swahili + English)
    final txnVerbHits = _countTransactionVerbs(lower);
    if (txnVerbHits.score > 0) {
      score += txnVerbHits.score;
      reasons.add(
        'Transaction verbs (${txnVerbHits.matches.join(", ")}) → +${txnVerbHits.score.toStringAsFixed(1)}',
      );
    }

    // Signal: Contains a date/time pattern near an amount (receipt structure)
    if (_hasDateTimeNearAmount(text)) {
      score += 1.5;
      reasons.add('Date/time near amount → structured receipt');
    }

    // Signal: Message is short and structured (typical receipt length)
    if (text.length < 200 && text.length > 30) {
      score += 0.5;
      reasons.add(
        'Short structured message (${text.length} chars) → receipt-like',
      );
    }

    // Signal: Contains a currency-prefixed amount
    if (_hasCurrencyAmount(lower)) {
      score += 1.0;
      reasons.add('Has currency-prefixed amount → financial');
    }

    // ════════════════════════════════════════════
    //  CLASSIFICATION DECISION
    // ════════════════════════════════════════════

    // Normalise score to 0–1 confidence using sigmoid-like mapping.
    // score > 0 → transaction-leaning, score < 0 → promo-leaning.
    final confidence = _sigmoid(score);

    String label;
    if (confidence >= 0.65) {
      label = 'transaction';
    } else if (confidence <= 0.35) {
      label = 'promo';
    } else {
      label = 'informational';
    }

    final result = SmsClassification(
      label: label,
      transactionConfidence: confidence,
      reasons: reasons,
    );

    developer.log('SmsClassifier: $result', name: 'Classifier');
    return result;
  }

  // ── Signal detectors ──

  static bool _hasUrl(String lower) {
    return lower.contains('www.') ||
        lower.contains('http://') ||
        lower.contains('https://') ||
        RegExp(r'\.[a-z]{2,4}/').hasMatch(lower); // e.g., ".co.tz/"
  }

  static bool _hasDialCode(String lower) {
    return RegExp(r'(?:dial|bonyeza|piga)\s*\*').hasMatch(lower) ||
        RegExp(r'\*\d{3,}[#*]').hasMatch(lower); // USSD pattern like *150*00#
  }

  static _SignalHits _countPromoSignals(String lower) {
    const promoWords = <String, double>{
      // Strong promo indicators (2.0 each)
      'bonus': 2.0,
      'jackpot': 2.0,
      'tombola': 2.0,
      'ushinde': 2.0, // "win"
      'bahati': 2.0, // "luck/lottery"
      'cashback': 2.0,
      'cash back': 2.0,
      'free trial': 2.0,
      'promotion': 2.0,
      'campaign': 2.0,

      // Medium promo indicators (1.5 each)
      'offer': 1.5,
      'bure': 1.5, // "free"
      'shangwe': 1.5, // "celebration/promo"
      'subscribe': 1.5,
      'jiandikishe': 1.5, // "register"
      'data bundle': 1.5,
      'pakiti': 1.5, // "bundle/package"
      // Mild promo indicators (1.0 each)
      'upgrade': 1.0,
      'hamia': 1.0, // "switch to"
      'download': 1.0,
      'install': 1.0,
      'click': 1.0,
      'tembelea': 1.0, // "visit"
    };

    double totalScore = 0;
    final matches = <String>[];
    for (final entry in promoWords.entries) {
      if (lower.contains(entry.key)) {
        totalScore += entry.value;
        matches.add(entry.key);
      }
    }
    return _SignalHits(score: totalScore, matches: matches);
  }

  static _SignalHits _countTransactionVerbs(String lower) {
    const txnVerbs = <String, double>{
      // Strong transaction verbs (2.0 each)
      'umepokea': 2.0, // "you have received"
      'umetuma': 2.0, // "you have sent"
      'umepewa': 2.0, // "you have been given"
      'zimewekwa': 2.0, // "have been deposited"
      'tumekutoa': 2.0, // "we have deducted"
      'tumeongeza': 2.0, // "we have added"
      'umekopeshwa': 2.0, // "you have been loaned"
      // Medium transaction verbs (1.5 each)
      'you have received': 1.5,
      'you have sent': 1.5,
      'you have paid': 1.5,
      'you have bought': 1.5,
      'has been deducted': 1.5,
      'payment from': 1.5,
      'payment to': 1.5,

      // Mild transaction indicators (1.0 each)
      'sent to': 1.0,
      'received from': 1.0,
      'cash-in': 1.0,
      'cash in': 1.0,
      'withdrawal': 1.0,
    };

    double totalScore = 0;
    final matches = <String>[];
    for (final entry in txnVerbs.entries) {
      if (lower.contains(entry.key)) {
        totalScore += entry.value;
        matches.add(entry.key);
      }
    }
    return _SignalHits(score: totalScore, matches: matches);
  }

  static bool _hasReferencePattern(String text) {
    // Labelled reference: Rej:, Ref:, TxnID:, etc.
    if (RegExp(
      r'(?:Rej|Ref|TxnID|TxnId|Transaction|Kumbukumbu|ID)[:\s]+[A-Za-z0-9]{4,}',
      caseSensitive: false,
    ).hasMatch(text)) {
      return true;
    }
    // Reference before "Confirmed."
    if (RegExp(r'[A-Za-z0-9]{6,}\s+[Cc]onfirmed').hasMatch(text)) {
      return true;
    }
    // Reference before Swahili "Imethibitishwa" (Confirmed)
    if (RegExp(r'[A-Za-z0-9]{6,}\s+[Ii]methibitishwa').hasMatch(text)) {
      return true;
    }
    return false;
  }

  static bool _hasBalancePattern(String lower) {
    return RegExp(
      r'(?:salio|balance|new balance|bal)[:\s]',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  static bool _hasDateTimeNearAmount(String text) {
    // Matches patterns like "on 15/5/2026 at 1:19 PM" or "tarehe 15/5/2026"
    if (RegExp(
      r'(?:on|tarehe)\s+\d{1,2}/\d{1,2}/\d{2,4}',
      caseSensitive: false,
    ).hasMatch(text)) {
      return true;
    }
    // ISO date format: "tarehe 2026-07-02 18:21:44" or "on 2026-07-02"
    if (RegExp(
      r'(?:on|tarehe)\s+\d{4}-\d{2}-\d{2}',
      caseSensitive: false,
    ).hasMatch(text)) {
      return true;
    }
    return false;
  }

  static bool _hasCurrencyAmount(String lower) {
    return RegExp(
      r'(?:tsh|tzs|tsh|tshs)\s*[\d,]+',
      caseSensitive: false,
    ).hasMatch(lower);
  }

  /// Sigmoid function mapping raw score to 0–1 range.
  /// k controls steepness (how quickly it transitions).
  static double _sigmoid(double x, {double k = 0.5}) {
    return 1.0 / (1.0 + math.exp(-k * x));
  }
}

class _SignalHits {
  final double score;
  final List<String> matches;
  const _SignalHits({required this.score, required this.matches});
}
