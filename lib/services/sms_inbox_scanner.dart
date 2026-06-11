import 'package:another_telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as developer;
import '../domain/sms/sms_processor.dart';
import '../domain/sms/provider_matcher.dart';

final smsInboxScannerProvider = Provider<SmsInboxScanner>((ref) {
  final processor = ref.watch(smsProcessorProvider);
  return SmsInboxScanner(processor);
});

class SmsInboxScanner {
  final SmsProcessor _smsProcessor;
  final Telephony _telephony = Telephony.instance;

  SmsInboxScanner(this._smsProcessor);

  /// Scans the device's inbox for historical carrier receipts in the last [daysLimit] days.
  /// Reports progress (processed, total recognized) via the [onProgress] callback.
  Future<void> scanInbox({
    int daysLimit = 30,
    required void Function(int processed, int total) onProgress,
  }) async {
    try {
      final statuses = await [
        Permission.sms,
        Permission.phone,
      ].request();
      final permissionGranted = statuses[Permission.sms]?.isGranted == true &&
                                statuses[Permission.phone]?.isGranted == true;
      if (!permissionGranted) {
        developer.log('SMS inbox scanning denied: permissions not granted', name: 'SmsInboxScanner');
        return;
      }

      // Query SMS inbox
      final List<SmsMessage> messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      );

      final cutoffDate = DateTime.now().subtract(Duration(days: daysLimit));
      
      // Filter messages by date and provider address
      final List<SmsMessage> targetMessages = [];
      for (final msg in messages) {
        final body = msg.body;
        final address = msg.address;
        if (body == null || address == null) continue;

        final timestamp = DateTime.fromMillisecondsSinceEpoch(msg.date ?? 0);
        if (timestamp.isBefore(cutoffDate)) continue;

        final provider = ProviderMatcher.matchProvider(address, body: body);
        if (provider != null) {
          targetMessages.add(msg);
        }
      }

      final total = targetMessages.length;
      developer.log('Found $total historical transactions in inbox', name: 'SmsInboxScanner');

      // Process sequentially to prevent SQLite connection locks
      for (int i = 0; i < total; i++) {
        final msg = targetMessages[i];
        final body = msg.body;
        final address = msg.address;
        if (body == null || address == null) continue;
        final timestamp = DateTime.fromMillisecondsSinceEpoch(msg.date ?? DateTime.now().millisecondsSinceEpoch);

        await _smsProcessor.processSms(address, body, timestamp);
        onProgress(i + 1, total);
      }
    } catch (e) {
      developer.log('Historical SMS scanning failure: $e', name: 'SmsInboxScanner');
    }
  }
}
