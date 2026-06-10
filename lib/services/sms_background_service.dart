import 'dart:async';
import 'package:flutter/services.dart';
import 'package:telephony/telephony.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as developer;
import '../domain/sms/pending_review_notifier.dart';
import '../domain/sms/sms_processor.dart';
import '../domain/sms/provider_matcher.dart';

/// Top-level VM entry point running inside a separate native background Isolate.
/// Intercepts incoming carrier transaction alerts when the app is backgrounded or closed.
@pragma('vm:entry-point')
void backgroundMessageHandler(SmsMessage message) async {
  developer.log('Background SMS received: ${message.body} from ${message.address}', name: 'SmsBackground');
  
  final body = message.body;
  final sender = message.address;
  if (body == null || sender == null) return;

  final timestamp = DateTime.fromMillisecondsSinceEpoch(
    message.date ?? DateTime.now().millisecondsSinceEpoch,
  );

  final container = ProviderContainer();
  try {
    final processor = container.read(smsProcessorProvider);
    await processor.processSms(sender, body, timestamp);
  } catch (e) {
    developer.log('Background SMS processing failure: $e', name: 'SmsBackground');
  } finally {
    container.dispose();
  }
}

final smsBackgroundServiceProvider = Provider<SmsBackgroundService>((ref) {
  final processor = ref.watch(smsProcessorProvider);

  // Wire up foreground review callback: when SMS needs category assignment,
  // push the full transaction object to pendingReviewProvider for dialog display
  processor.onReviewNeeded = (item) {
    ref.read(pendingReviewProvider.notifier).add(item);
  };

  return SmsBackgroundService(processor);
});

class SmsBackgroundService {
  final SmsProcessor _smsProcessor;
  final Telephony _telephony = Telephony.instance;
  Timer? _inboxScanTimer;
  DateTime _lastInboxScan = DateTime(2000);

  SmsBackgroundService(this._smsProcessor);

  /// Registers live foreground/background SMS listeners AND
  /// starts periodic inbox scanning as a fallback (critical for Android 14+
  /// where RECEIVE_SMS broadcast is restricted).
  Future<void> initialize() async {
    await _registerSmsListeners();
    await _scanInboxOnce();
    _startPeriodicInboxScan();
  }

  Future<void> _registerSmsListeners() async {
    try {
      // 1. Listen dynamically when the app is active (Foreground)
      _telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) async {
          developer.log('Foreground SMS received: ${message.body} from ${message.address}', name: 'SmsBackground');
          final body = message.body;
          final sender = message.address;
          if (body != null && sender != null) {
            final timestamp = DateTime.fromMillisecondsSinceEpoch(
              message.date ?? DateTime.now().millisecondsSinceEpoch,
            );
            await _smsProcessor.processSms(sender, body, timestamp);
          }
        },
        // 2. Listen dynamically when the app is closed or backgrounded (Background)
        onBackgroundMessage: backgroundMessageHandler,
        listenInBackground: true,
      );
      developer.log('SMS Broadcast Listeners registered successfully', name: 'SmsBackground');
    } catch (e) {
      developer.log('SMS Listener initialization failure: $e', name: 'SmsBackground');
    }
  }

  /// Scans inbox once on startup to catch SMS missed while the app was closed.
  Future<void> _scanInboxOnce() async {
    final now = DateTime.now();
    try {
      try {
        final bool? granted = await _telephony.requestPhoneAndSmsPermissions;
        if (granted != true) {
          developer.log('Inbox scan skipped: permissions not granted', name: 'SmsBackground');
          return;
        }
      } on MissingPluginException {
        developer.log('Telephony plugin not available — skipping inbox scan', name: 'SmsBackground');
        return;
      } catch (e) {
        developer.log('Permission request failed: $e', name: 'SmsBackground');
        return;
      }

      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      );

      int processed = 0;
      final cutoff = now.subtract(const Duration(hours: 6));
      for (final msg in messages) {
        final body = msg.body;
        final address = msg.address;
        if (body == null || address == null) continue;

        final timestamp = DateTime.fromMillisecondsSinceEpoch(msg.date ?? 0);
        if (timestamp.isBefore(cutoff)) continue;

        final provider = ProviderMatcher.matchProvider(address);
        if (provider == null) continue;

        await _smsProcessor.processSms(address, body, timestamp);
        processed++;
      }

      _lastInboxScan = now;
      developer.log('Inbox startup scan: $processed financial SMS processed', name: 'SmsBackground');
    } on MissingPluginException {
      developer.log('Telephony plugin not available — inbox scan failed', name: 'SmsBackground');
    } catch (e) {
      developer.log('Inbox startup scan failed: $e', name: 'SmsBackground');
    }
  }

  /// Periodically scans the inbox (every 5 minutes) to catch any SMS missed
  /// by the notification listener or broadcast receiver.
  void _startPeriodicInboxScan() {
    try {
      _inboxScanTimer?.cancel();
      _inboxScanTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _scanRecentInbox(),
      );
      developer.log('Periodic inbox scan timer started (every 5 min)', name: 'SmsBackground');
    } catch (e) {
      developer.log('Periodic inbox scan timer creation failed: $e', name: 'SmsBackground');
    }
  }

  Future<void> _scanRecentInbox() async {
    final now = DateTime.now();
    try {
      try {
        final bool? granted = await _telephony.requestPhoneAndSmsPermissions;
        if (granted != true) return;
      } on MissingPluginException {
        developer.log('Telephony plugin not available — skipping periodic scan', name: 'SmsBackground');
        return;
      } catch (e) {
        developer.log('Permission request failed: $e', name: 'SmsBackground');
        return;
      }

      final messages = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      );

      int processed = 0;
      for (final msg in messages) {
        final body = msg.body;
        final address = msg.address;
        if (body == null || address == null) continue;

        final timestamp = DateTime.fromMillisecondsSinceEpoch(msg.date ?? 0);
        // Only process messages newer than last scan (plus 1 min overlap)
        if (!timestamp.isAfter(_lastInboxScan.subtract(const Duration(minutes: 1)))) continue;

        final provider = ProviderMatcher.matchProvider(address);
        if (provider == null) continue;

        await _smsProcessor.processSms(address, body, timestamp);
        processed++;
      }

      _lastInboxScan = now;
      if (processed > 0) {
        developer.log('Periodic inbox scan: $processed new financial SMS processed', name: 'SmsBackground');
      }
    } on MissingPluginException {
      developer.log('Telephony plugin not available — periodic inbox scan failed', name: 'SmsBackground');
    } catch (e) {
      developer.log('Periodic inbox scan failed: $e', name: 'SmsBackground');
    }
  }

  void dispose() {
    _inboxScanTimer?.cancel();
    _inboxScanTimer = null;
  }
}
