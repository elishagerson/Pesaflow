/// Returns a human-readable label like "Every week" or "Every 2 months".
String frequencyLabel(String frequency, int interval) {
  switch (frequency) {
    case 'weekly':
      return interval == 1 ? 'Every week' : 'Every $interval weeks';
    case 'biweekly':
      return interval == 1 ? 'Every 2 weeks' : 'Every ${interval * 2} weeks';
    case 'monthly':
      return interval == 1 ? 'Every month' : 'Every $interval months';
    case 'quarterly':
      return interval == 1 ? 'Every quarter' : 'Every $interval quarters';
    case 'yearly':
      return interval == 1 ? 'Every year' : 'Every $interval years';
    default:
      return frequency;
  }
}
