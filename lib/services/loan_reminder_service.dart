import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/repositories/loan_repository.dart';
import 'package:pesaflow/services/notification_service.dart';

final loanReminderServiceProvider = Provider<LoanReminderService>((ref) {
  return LoanReminderService(
    repository: ref.watch(loanRepositoryProvider),
    notificationService: ref.watch(notificationServiceProvider),
  );
});

class LoanReminderService {
  final LoanRepository _repository;
  final NotificationService _notificationService;
  int _notificationCounter = 3000;

  LoanReminderService({
    required this._repository,
    required this._notificationService,
  });

  Future<void> checkLoanDueDates() async {
    try {
      final loans = await _repository.getActiveLoans();
      final now = DateTime.now();

      for (final loan in loans) {
        if (loan.remaining <= 0) continue;
        if (loan.dueAt == null) continue;

        final dueAt = loan.dueAt!;
        final daysUntilDue = dueAt.difference(now).inDays;

        if (daysUntilDue < 0) {
          await _sendOverdueNotification(loan, now, dueAt);
        } else if (daysUntilDue <= 3) {
          await _sendUpcomingNotification(loan, dueAt);
        }
      }
    } catch (e) {
      developer.log(
        'Loan due date check failed: $e',
        name: 'LoanReminder',
      );
    }
  }

  Future<void> _sendOverdueNotification(
    Loan loan,
    DateTime now,
    DateTime dueAt,
  ) async {
    final overdueDays = now.difference(dueAt).inDays;
    final name = loan.description ?? 'Loan';
    final amountStr = (loan.remaining / 100).toStringAsFixed(0);

    _notificationCounter++;
    await _notificationService.showNotification(
      id: _notificationCounter,
      title: 'Overdue: $name',
      body: '$name is $overdueDays day${overdueDays == 1 ? '' : 's'} overdue. '
          'Outstanding: Tsh $amountStr',
    );
    developer.log(
      'Overdue loan reminder sent: $name',
      name: 'LoanReminder',
    );
  }

  Future<void> _sendUpcomingNotification(Loan loan, DateTime dueAt) async {
    final name = loan.description ?? 'Loan';
    final amountStr = (loan.remaining / 100).toStringAsFixed(0);
    final dueDateStr = '${dueAt.day}/${dueAt.month}';

    _notificationCounter++;
    await _notificationService.showNotification(
      id: _notificationCounter,
      title: 'Loan due soon: $name',
      body: '$name (Tsh $amountStr) is due on $dueDateStr',
    );
    developer.log(
      'Upcoming loan reminder sent: $name',
      name: 'LoanReminder',
    );
  }
}
