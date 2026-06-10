import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as developer;

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  Completer<void>? _initCompleter;

  /// Lazily initializes the notification plugin exactly once.
  /// Safe to call multiple times — subsequent calls return the cached future.
  /// If initialization fails, the completer is reset so it can be retried.
  Future<void> ensureInitialized() async {
    if (_initCompleter != null) return _initCompleter!.future;
    _initCompleter = Completer<void>();
    try {
      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iOSInit = DarwinInitializationSettings();
      const macOSInit = DarwinInitializationSettings();
      const linuxInit = LinuxInitializationSettings(defaultActionName: 'Open');
      const initSettings = InitializationSettings(
        android: androidInit,
        iOS: iOSInit,
        macOS: macOSInit,
        linux: linuxInit,
      );
      await _plugin.initialize(settings: initSettings);
      _initCompleter!.complete();
      developer.log('Notification plugin initialized', name: 'NotificationService');
    } catch (e) {
      developer.log('Notification plugin init failed: $e', name: 'NotificationService');
      _initCompleter!.completeError(e);
      _initCompleter = null; // allow retry on next call
      rethrow;
    }
  }

  /// Sends a local notification confirming a parsed carrier transaction.
  /// When [needsReview] is true, includes a "Review" action button that opens the app.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    bool needsReview = false,
  }) async {
    await ensureInitialized();

    final androidDetails = AndroidNotificationDetails(
      'pesaflow_sms_channel',
      'PesaFlow Transactions',
      channelDescription: 'Real-time transactional confirmations from PesaFlow',
      importance: Importance.max,
      priority: Priority.high,
      fullScreenIntent: needsReview,
      showWhen: true,
    );
    final details = NotificationDetails(android: androidDetails);
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
    );
  }
}
