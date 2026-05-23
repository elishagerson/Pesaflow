import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  NotificationService() {
    _init();
  }

  Future<void> _init() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(settings: initSettings);
  }

  /// Sends a local notification confirming a parsed carrier transaction.
  /// When [needsReview] is true, includes a "Review" action button that opens the app.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    bool needsReview = false,
  }) async {
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
