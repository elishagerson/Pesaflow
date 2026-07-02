class DateFormatter {
  static String relative(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateDay = DateTime(date.year, date.month, date.day);
    final diff = today.difference(dateDay).inDays;

    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    if (diff <= 7) {
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];
      return weekdays[date.weekday - 1];
    }
    if (diff <= 30) return '${diff ~/ 7} week${diff ~/ 7 > 1 ? 's' : ''} ago';
    if (diff <= 365) {
      return '${diff ~/ 30} month${diff ~/ 30 > 1 ? 's' : ''} ago';
    }
    return '${diff ~/ 365} year${diff ~/ 365 > 1 ? 's' : ''} ago';
  }
}
