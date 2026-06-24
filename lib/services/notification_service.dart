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
      const androidInit = AndroidInitializationSettings('@drawable/ic_notification_pesaflow');
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
      icon: '@drawable/ic_notification_pesaflow',
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

  /// Schedules a renewal reminder notification for a subscription.
  /// [daysBefore] controls how many days before the due date the notification fires.
  Future<void> scheduleRenewalReminder({
    required String subId,
    required String subName,
    required int amountCents,
    required DateTime nextDueDate,
    int daysBefore = 3,
  }) async {
    await ensureInitialized();

    final reminderDate = nextDueDate.subtract(Duration(days: daysBefore));
    final now = DateTime.now();
    if (reminderDate.isBefore(now)) return;

    final amountStr = (amountCents / 100).toStringAsFixed(0);
    final androidChannel = AndroidNotificationDetails(
      'pesaflow_renewal_channel',
      'Subscription Renewals',
      channelDescription: 'Upcoming subscription renewal reminders',
      icon: '@drawable/ic_notification_pesaflow',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    final details = NotificationDetails(android: androidChannel);

    await _plugin.schedule(
      id: subId.hashCode,
      title: '$subName renewing soon',
      body: '$subName (Tsh $amountStr) renews on ${nextDueDate.day}/${nextDueDate.month}/${nextDueDate.year}',
      scheduledDate: reminderDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
    developer.log('Scheduled renewal reminder for $subName on $reminderDate', name: 'NotificationService');
  }

  /// Cancels a scheduled renewal notification for a subscription.
  Future<void> cancelRenewalReminder(String subId) async {
    await _plugin.cancel(subId.hashCode);
  }
}
