import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:pesaflow/services/notification_service.dart';
import 'dart:developer' as developer;

final lockScreenServiceProvider = Provider<LockScreenService>((ref) {
  final notifService = ref.watch(notificationServiceProvider);
  return LockScreenService(notifService);
});

class LockScreenService {
  final NotificationService _notifService;
  bool _hasBalanceNotification = false;

  static const int _notificationId = 9001;

  LockScreenService(this._notifService);

  Future<void> ensureInitialized() => _notifService.ensureInitialized();

  Future<void> showBalanceNotification(int totalCents, {required bool isEnabled}) async {
    if (!isEnabled) {
      await removeBalanceNotification();
      return;
    }
    await ensureInitialized();

    final formatted = NumberFormat('#,###').format(totalCents ~/ 100);

    final androidDetails = AndroidNotificationDetails(
      'pesaflow_balance_channel',
      'Account Balance',
      channelDescription: 'Current PesaFlow account balance',
      icon: '@drawable/ic_notification_pesaflow',
      importance: Importance.low,
      priority: Priority.min,
      ongoing: true,
      showWhen: false,
      visibility: NotificationVisibility.public,
    );
    final details = NotificationDetails(android: androidDetails);

    try {
      final plugin = _notifService.plugin;
      await plugin.show(
        id: _notificationId,
        title: 'PesaFlow Balance',
        body: 'Tsh $formatted',
        notificationDetails: details,
      );
      _hasBalanceNotification = true;
      developer.log('Balance notification shown: Tsh $formatted', name: 'LockScreenService');
    } catch (e) {
      developer.log('Failed to show balance notification: $e', name: 'LockScreenService');
    }
  }

  Future<void> removeBalanceNotification() async {
    if (!_hasBalanceNotification) return;
    try {
      final plugin = _notifService.plugin;
      await plugin.cancel(id: _notificationId);
      _hasBalanceNotification = false;
      developer.log('Balance notification removed', name: 'LockScreenService');
    } catch (e) {
      developer.log('Failed to remove balance notification: $e', name: 'LockScreenService');
    }
  }
}
