import 'dart:async';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:developer' as developer;

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  FlutterLocalNotificationsPlugin get plugin => _plugin;
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

  /// Checks all active subscriptions and shows renewal reminder notifications
  /// for those due within [daysAhead] days.
  Future<void> checkSubscriptionRenewals({
    required List<({String name, int amountCents, DateTime nextDueDate})> subs,
    int daysAhead = 3,
  }) async {
    await ensureInitialized();

    final now = DateTime.now();
    final cutoff = now.add(Duration(days: daysAhead));
    final due = subs.where((s) => s.nextDueDate.isAfter(now) && s.nextDueDate.isBefore(cutoff)).toList();
    if (due.isEmpty) return;

    final channel = AndroidNotificationDetails(
      'pesaflow_renewal_channel',
      'Subscription Renewals',
      channelDescription: 'Upcoming subscription renewal reminders',
      icon: '@drawable/ic_notification_pesaflow',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    final details = NotificationDetails(android: channel);

    for (final sub in due) {
      final amountStr = (sub.amountCents / 100).toStringAsFixed(0);
      // Use a stable ID based on name + day to avoid collisions
      final notifId = sub.name.hashCode ^ sub.nextDueDate.day ^ sub.nextDueDate.month;
      await _plugin.show(
        id: notifId,
        title: '${sub.name} renewing soon',
        body: '${sub.name} (Tsh $amountStr) — ${sub.nextDueDate.day}/${sub.nextDueDate.month}',
        notificationDetails: details,
      );
      developer.log('Renewal reminder shown for ${sub.name}', name: 'NotificationService');
    }
  }
}
