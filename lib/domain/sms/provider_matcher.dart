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
    // For mobile-money provider names in body, requires a financial amount pattern
    // to avoid routing ads/promos that merely mention a provider name.
    if (body != null && body.isNotEmpty) {
      final upperBody = body.toUpperCase();

      // Bank-specific keywords are already transaction indicators — safe to route.
      if (upperBody.contains('TUMEKUTOA') || upperBody.contains('TUMEONGEZA') || upperBody.contains('FEES:')) {
        return 'NMB_Bank';
      }
      if (upperBody.contains('CRDB:')) {
        return 'CRDB_Bank';
      }
      if (upperBody.contains('NBC:')) {
        return 'NBC_Bank';
      }

      // Mobile-money body matches require a financial amount pattern to avoid
      // routing promos that casually mention a provider name.
      if (!_hasAmountPattern(upperBody)) return null;

      if (upperBody.contains('SELCOM')) {
        return 'SelcomPesa_TZ';
      }
      if (upperBody.contains('MPESA') || upperBody.contains('M-PESA')) {
        return 'M-Pesa_TZ';
      }
      if (upperBody.contains('AIRTEL')) {
        return 'AirtelMoney_TZ';
      }
      if (upperBody.contains('MIXX') || upperBody.contains('TIGO') || upperBody.contains('YAS')) {
        return 'TigoPesa_TZ';
      }
      if (upperBody.contains('HALOPESA') || upperBody.contains('HALO')) {
        return 'Halopesa_TZ';
      }
    }

    return null;
  }

  /// Returns true if [text] contains a recognized financial amount pattern like
  /// "TSH 500", "TZS 1,000", or "500/=".
  /// [text] should already be uppercased for consistent matching.
  static bool _hasAmountPattern(String text) {
    return RegExp(r'(?:TSH|TZS|/=\s)').hasMatch(text);
  }
}
