import 'package:telephony/telephony.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as developer;
import '../domain/sms/pending_review_notifier.dart';
import '../domain/sms/sms_processor.dart';

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

  try {
    // Spin up an isolated ProviderContainer to access Drift DB and dependencies on this isolate
    final container = ProviderContainer();
    final processor = container.read(smsProcessorProvider);
    await processor.processSms(sender, body, timestamp);
    container.dispose();
  } catch (e) {
    developer.log('Background SMS processing failure: $e', name: 'SmsBackground');
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

  SmsBackgroundService(this._smsProcessor);

  /// Registers live foreground/background SMS listeners.
  /// Permissions are requested in main.dart before this is called.
  Future<void> initialize() async {
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
      );
      developer.log('SMS Broadcast Listeners registered successfully', name: 'SmsBackground');
    } catch (e) {
      developer.log('SMS Listener initialization failure: $e', name: 'SmsBackground');
    }
  }
}
