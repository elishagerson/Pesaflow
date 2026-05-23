class ProviderMatcher {
  /// Matches a sender shortcode or phone number to a unified Tanzanian provider string.
  /// Returns null if the sender is not a recognized carrier/bank transaction notifier.
  static String? matchProvider(String senderAddress) {
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

    // Tigo Pesa / Mixx by Yas / T-Pesa
    if (address.contains('TIGO') || 
        address.contains('TIGOPESA') || 
        address.contains('TIGO PESA') || 
        address.contains('MIXX') || 
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

    return null;
  }
}
