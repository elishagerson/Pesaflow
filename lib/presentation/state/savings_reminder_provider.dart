import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/data/database/database_providers.dart';
import 'package:pesaflow/services/notification_service.dart';
import 'package:pesaflow/services/savings_reminder_service.dart';
import 'active_tracker_provider.dart';

final savingsReminderServiceProvider = Provider<SavingsReminderService>((ref) {
  return SavingsReminderService(
    dao: ref.watch(savingsGoalsDaoProvider),
    notificationService: ref.watch(notificationServiceProvider),
    trackerIdProvider: ref.watch(activeTrackerIdProvider),
  );
});
