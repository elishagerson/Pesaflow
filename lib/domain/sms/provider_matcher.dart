class ProviderMatcher {
  /// Matches a sender shortcode or phone number to a unified Tanzanian provider string.
  /// If [senderAddress] doesn't match any known provider, falls back to scanning
  /// the optional [body] for known transaction keywords (handles numeric shortcodes
  /// like NMB's 15200 that don't contain the provider name).
  static String? matchProvider(String senderAddress, {String? body}) {
    final address = senderAddress.trim().toUpperCase();

    // Selcom Pesa
    // Checked first because "SELCOMPESA" contains "MPESA" which would otherwise false-match to M-Pesa.
    if (address.contains('SELCOM')) {
      return 'SelcomPesa_TZ';
    }

    // M-Pesa (Vodacom)
    if (address.contains('M-PESA') ||
        address.contains('M_PESA') ||
        address.contains('MPESA') ||
        address.contains('VODACOM')) {
      return 'M-Pesa_TZ';
    }

    // Airtel Money
    if (address.contains('AIRTEL') ||
        address.contains('AIRTELMONEY') ||
        address.contains('AIRTEL MONEY') ||
        address.contains('AIRTEL-MONEY')) {
      return 'AirtelMoney_TZ';
    }

    // Tigo Pesa / Mixx / Yas / T-Pesa
    if (address.contains('TIGO') ||
        address.contains('TIGOPESA') ||
        address.contains('TIGO PESA') ||
        address.contains('MIXX') ||
        address.contains('YAS') ||
        address.contains('T-PESA') ||
        address.contains('TPESA')) {
      return 'TigoPesa_TZ';
    }

    // Halopesa (Halotel)
    if (address.contains('HALOPESA') ||
        address.contains('HALO PESA') ||
        address.contains('HALO')) {
      return 'Halopesa_TZ';
    }

    // NMB Bank
    if (address.contains('NMB')) {
      return 'NMB_Bank';
    }

    // CRDB Bank
    if (address.contains('CRDB')) {
      return 'CRDB_Bank';
    }

    // NBC Bank
    if (address.contains('NBC')) {
      return 'NBC_Bank';
    }

    // ── Fallback: scan body for known keywords ──
    // Handles banks that send SMS from numeric shortcodes that don't include the
    // provider name (e.g. NMB uses shortcode 15200).
    //
    // For mobile-money providers, bare keyword matching is dangerous because
    // cross-provider transactions mention the *destination* provider by name
    // (e.g. a Tigo SMS reads "You have sent TSh 20,000 to Airtel receiver").
    // We therefore check for **ownership signals** first — phrases that only
    // appear in messages *from* that provider — and fall back to bare keywords
    // only when no ownership signal fires.
    if (body != null && body.isNotEmpty) {
      final upperBody = body.toUpperCase();

      // Bank-specific keywords are already transaction indicators — safe to route.
      if (upperBody.contains('NMB KARIBU') ||
          upperBody.contains('NMB:') ||
          upperBody.contains('KIMETUMWA') ||
          upperBody.contains('KIMEWEKWA') ||
          upperBody.contains('TUMEKUTOA') ||
          upperBody.contains('AKAUNTI INAYOISHIA')) {
        return 'NMB_Bank';
      }
      if (upperBody.contains('CRDB:')) {
        return 'CRDB_Bank';
      }
      if (upperBody.contains('NBC:')) {
        return 'NBC_Bank';
      }

      // ── Ownership signals: phrases that prove the SMS was SENT BY a provider ──
      // These are checked before bare keyword matching to prevent cross-provider
      // contamination (e.g. a Tigo SMS saying "sent to M-Pesa agent" should NOT
      // match M-Pesa).

      // Selcom Pesa ownership (checked first since "SELCOMPESA" contains "MPESA")
      if (_hasOwnershipSignal(upperBody, _selcomOwnership)) {
        return 'SelcomPesa_TZ';
      }

      // TigoPesa / Mixx / Yas ownership
      if (_hasOwnershipSignal(upperBody, _tigoOwnership)) {
        return 'TigoPesa_TZ';
      }

      // M-Pesa / Vodacom ownership
      if (_hasOwnershipSignal(upperBody, _mpesaOwnership)) {
        return 'M-Pesa_TZ';
      }

      // Airtel Money ownership
      if (_hasOwnershipSignal(upperBody, _airtelOwnership)) {
        return 'AirtelMoney_TZ';
      }

      // Halopesa ownership
      if (_hasOwnershipSignal(upperBody, _halopesaOwnership)) {
        return 'Halopesa_TZ';
      }

      // ── Bare keyword fallback (requires amount pattern) ──
      // Only fires when no ownership signal matched above. The body may still
      // identify the sending provider by name alone (e.g. "MPESA" in a body
      // from an unknown shortcode). We require a financial amount pattern to
      // filter out promotional text.
      if (!_hasAmountPattern(upperBody)) return null;

      // Selcom checked first (contains "MPESA" substring)
      if (upperBody.contains('SELCOM')) {
        return 'SelcomPesa_TZ';
      }
      if (upperBody.contains('MPESA') || upperBody.contains('M-PESA')) {
        return 'M-Pesa_TZ';
      }
      if (upperBody.contains('AIRTEL')) {
        return 'AirtelMoney_TZ';
      }
      if (upperBody.contains('MIXX') ||
          upperBody.contains('TIGO') ||
          upperBody.contains('YAS PESA') ||
          upperBody.contains('YASPESA')) {
        return 'TigoPesa_TZ';
      }
      if (upperBody.contains('HALOPESA') || upperBody.contains('HALO PESA')) {
        return 'Halopesa_TZ';
      }
    }

    return null;
  }

  /// Returns true if [text] contains a recognized financial amount pattern like
  /// "TSH 500", "TZS 1,000", "TSHS 500", or "500/=".
  /// [text] should already be uppercased for consistent matching.
  static bool _hasAmountPattern(String text) {
    return RegExp(r'(?:TSH[HS]?\s|TZS\s|/=\s)').hasMatch(text);
  }

  /// Returns true if [text] contains any of the ownership signal phrases.
  static bool _hasOwnershipSignal(String text, List<String> signals) {
    return signals.any((s) => text.contains(s));
  }

  // ── Ownership signal phrases per provider ─────────────────────────────
  // These are phrases that appear ONLY in SMS messages *from* a given
  // provider, not in cross-provider recipient mentions.

  static const _selcomOwnership = [
    'SELCOM PESA',
    'SELCOMPESA',
    'SELCOM WALLET',
  ];

  static const _tigoOwnership = [
    'NEW MIXX BALANCE',       // Only Tigo/Mixx uses this
    'MIXX WALLET',
    'MIXX BY YAS',
    'TIGO PESA AIRTIME',
    'TIGO PESA BUNDLE',
    'TIGO PESA SERVICE FEE',
    'UNUNUZI WA KIFURUSHI',   // Tigo bundle purchase (Swahili)
    'CASH-IN OF',             // Tigo Cash-In format
    'BUSTISHA',               // Tigo loan product
    'NIVUSHE',                // Tigo loan product
    'MKOPO WA MIXX',          // Tigo loan product
    'MIXX MKOPO',             // Tigo loan product
    'YAS POSTPAID',           // Yas PostPaid bill
  ];

  static const _mpesaOwnership = [
    'NEW M-PESA BALANCE',      // Only in M-Pesa-sent SMS
    'NEW M PESA BALANCE',      // Variant without hyphen
    'PESA ZIMEWEKWA',          // M-Pesa Swahili deposit
    'PESA ZIMEKOPESHWA',       // M-Pesa Swahili loan
    'KODI YA KUHUDUMIA',       // M-Pesa Swahili service fee
    'M-PESA OVERDRAFT',        // M-Pesa overdraft repayment
    'LIPA KWA M-PESA',         // M-Pesa merchant payment
    'YOUR M-PESA ACCOUNT',     // Deducted from your M-Pesa account
    'FROM YOUR M-PESA',        // Deducted from your M-Pesa
  ];

  static const _airtelOwnership = [
    'AIRTEL MONEY',             // Two-word compound (not bare 'AIRTEL')
    'AIRTELMONEY',
    'AIRTEL PESA',
    'MAKATO',                   // Airtel-specific fee breakdown term
  ];

  static const _halopesaOwnership = [
    'HALOPESA',
    'HALO PESA',
    'HALOTEL',
  ];
}
