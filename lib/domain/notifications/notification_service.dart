import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/services/notification_service.dart' as svc;

extension OverdueLoanNotifier on svc.NotificationService {
  Future<void> checkOverdueLoans(List<Loan> activeLoans) async {
    final now = DateTime.now();
    for (final loan in activeLoans) {
      if (loan.dueAt != null && loan.dueAt!.isBefore(now)) {
        await showNotification(
          id: 'overdue_${loan.id}'.hashCode,
          title: 'Loan Payment Overdue',
          body: '${loan.description ?? loan.sender ?? 'Loan'} was due ${_daysAgo(loan.dueAt!, now)}',
          needsReview: true,
        );
      }
    }
  }

  String _daysAgo(DateTime due, DateTime now) {
    final days = now.difference(due).inDays;
    if (days == 0) return 'today';
    if (days == 1) return 'yesterday';
    return '$days days ago';
  }
}
