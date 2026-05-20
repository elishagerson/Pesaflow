import '../../../data/models/sms_parsed.dart';

abstract class SmsParser {
  /// Parses the raw SMS string body and returns an [SmsParsed] object.
  /// Returns null if the receipt format does not match this parser's patterns.
  SmsParsed? parse(String rawSmsBody, DateTime timestamp);
}
