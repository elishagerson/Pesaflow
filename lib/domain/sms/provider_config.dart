import 'parsers/sms_parser_interface.dart';
import 'parsers/mpesa_tz_parser.dart';
import 'parsers/airtel_tz_parser.dart';
import 'parsers/mixx_parser.dart';
import 'parsers/halopesa_parser.dart';
import 'parsers/bank_base.dart';
import 'parsers/selcom_pesa_parser.dart';
import 'parsers/generic_fallback_parser.dart';

/// Metadata for auto-creating a user account when an SMS arrives from an
/// unrecognised provider.
class ProviderAccountMeta {
  final String friendlyName;
  final String type; // 'mobile_money' | 'bank' | 'cash'

  const ProviderAccountMeta({required this.friendlyName, required this.type});
}

/// Registry of known SMS providers.
///
/// Each entry maps a provider identifier (returned by `ProviderMatcher`) to its
/// parser class and default account metadata.
///
/// To add support for a new provider, insert a new entry here and (if the
/// provider's SMS format is not yet covered) implement `SmsParser`.
class ProviderRegistry {
  /// Provider → parser constructor.
  static SmsParser parserFor(String provider) {
    final factory = _parsers[provider];
    if (factory != null) return factory();
    // Unknown provider — the generic fallback attempts regex-based extraction.
    return GenericFallbackParser(provider: provider);
  }

  /// Generic fallback parser for [provider], used when the primary parser
  /// returned `null` for a recognised provider.
  static SmsParser fallbackFor(String provider) =>
      GenericFallbackParser(provider: provider);

  /// Metadata used when auto-creating an account for this provider.
  static ProviderAccountMeta? accountMetaFor(String provider) =>
      _accountMeta[provider];

  static const _parsers = <String, SmsParser Function()>{
    'M-Pesa_TZ': MpesaTzParser.new,
    'AirtelMoney_TZ': AirtelTzParser.new,
    'TigoPesa_TZ': MixxParser.new,
    'Halopesa_TZ': HalopesaParser.new,
    'NMB_Bank': NmbBankParser.new,
    'CRDB_Bank': CrdbBankParser.new,
    'NBC_Bank': NbcBankParser.new,
    'SelcomPesa_TZ': SelcomPesaParser.new,
  };

  static const _accountMeta = <String, ProviderAccountMeta>{
    'M-Pesa_TZ': ProviderAccountMeta(
      friendlyName: 'M-Pesa',
      type: 'mobile_money',
    ),
    'AirtelMoney_TZ': ProviderAccountMeta(
      friendlyName: 'Airtel Money',
      type: 'mobile_money',
    ),
    'TigoPesa_TZ': ProviderAccountMeta(
      friendlyName: 'Tigo Pesa',
      type: 'mobile_money',
    ),
    'Halopesa_TZ': ProviderAccountMeta(
      friendlyName: 'Halopesa',
      type: 'mobile_money',
    ),
    'NMB_Bank': ProviderAccountMeta(friendlyName: 'NMB Bank', type: 'bank'),
    'CRDB_Bank': ProviderAccountMeta(friendlyName: 'CRDB Bank', type: 'bank'),
    'NBC_Bank': ProviderAccountMeta(friendlyName: 'NBC Bank', type: 'bank'),
    'SelcomPesa_TZ': ProviderAccountMeta(
      friendlyName: 'Selcom Pesa',
      type: 'mobile_money',
    ),
  };
}
