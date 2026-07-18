import 'dart:developer' as developer;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import 'package:pesaflow/services/notification_service.dart';

final backgroundSchedulerProvider = Provider<BackgroundSchedulerService>((ref) {
  return BackgroundSchedulerService(ref);
});

class BackgroundSchedulerService {
  final Ref _ref;
  BackgroundSchedulerService(this._ref);

  static const _reminderChannelId = 'pesaflow_reminder_channel';
  static const _reminderChannelName = 'PesaFlow Reminders';
  static const _reminderChannelDesc =
      'Scheduled reminders for budgets, savings, and finances';

  static const int _dailySpendingId = 5001;
  static const int _budgetCheckId = 5002;
  static const int _savingsCheckId = 5003;

  AndroidNotificationDetails get _androidDetails =>
      const AndroidNotificationDetails(
        _reminderChannelId,
        _reminderChannelName,
        channelDescription: _reminderChannelDesc,
        icon: '@drawable/ic_notification_pesaflow',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      );

  NotificationDetails get _details =>
      NotificationDetails(android: _androidDetails);

  /// Cancels all existing scheduled notifications and re-schedules them
  /// based on current data. Call on every app launch.
  Future<void> scheduleAll() async {
    tz.initializeTimeZones();

    final notifService = _ref.read(notificationServiceProvider);
    await notifService.ensureInitialized();
    final plugin = notifService.plugin;

    await plugin.cancelAll();
    developer.log('Cancelled all scheduled notifications', name: 'Scheduler');

    await _scheduleDailySpendingReminder(plugin);
    await _scheduleBudgetCheckReminder(plugin);
    await _scheduleSavingsReminder(plugin);

    developer.log(
      'All scheduled notifications re-registered',
      name: 'Scheduler',
    );
  }

  /// 8pm daily — "Have you tracked your expenses today?"
  Future<void> _scheduleDailySpendingReminder(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await plugin.zonedSchedule(
      id: _dailySpendingId,
      title: 'Daily spending check',
      body: 'Have you tracked your expenses today?',
      scheduledDate: scheduled,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
    developer.log(
      'Scheduled daily spending reminder at 8pm',
      name: 'Scheduler',
    );
  }

  /// Mon-Fri 9am — "Check your budget progress"
  Future<void> _scheduleBudgetCheckReminder(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    final now = tz.TZDateTime.now(tz.local);
    // Find next weekday at 9am
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 9);
    while (scheduled.isBefore(now) || _isWeekend(scheduled)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await plugin.zonedSchedule(
      id: _budgetCheckId,
      title: 'Budget check reminder',
      body: 'Check your budget progress for this week',
      scheduledDate: scheduled,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
    developer.log(
      'Scheduled budget check reminder (weekdays 9am)',
      name: 'Scheduler',
    );
  }

  /// Sunday 10am — "Time to review your savings goals"
  Future<void> _scheduleSavingsReminder(
    FlutterLocalNotificationsPlugin plugin,
  ) async {
    final now = tz.TZDateTime.now(tz.local);
    // Find next Sunday at 10am
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 10);
    while (scheduled.isBefore(now) || scheduled.weekday != DateTime.sunday) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    await plugin.zonedSchedule(
      id: _savingsCheckId,
      title: 'Savings check reminder',
      body: 'Time to review your savings goals',
      scheduledDate: scheduled,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
    developer.log(
      'Scheduled savings reminder (Sundays 10am)',
      name: 'Scheduler',
    );
  }

  bool _isWeekend(tz.TZDateTime dt) =>
      dt.weekday == DateTime.saturday || dt.weekday == DateTime.sunday;
}
