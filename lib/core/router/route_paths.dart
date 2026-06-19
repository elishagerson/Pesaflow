/// Central source of truth for all route path patterns.
///
/// Use [pathFor] to build absolute paths and [GoRouterState.params] / [optParam]
/// in route builders to access path parameters with proper null safety.
class RoutePaths {
  RoutePaths._();

  // Onboarding
  static const onboarding = '/onboarding';

  // Main shell tabs
  static const dashboard = '/';
  static const transactions = '/transactions';
  static const budgets = '/budgets';
  static const analytics = '/analytics';
  static const settings = '/settings';

  // Dashboard nested
  static const loans = '/loans';
  static const loanAdd = '/loans/add';
  static String loanDetail(String id) => '/loans/$id';
  static const recurring = '/recurring';
  static const recurringAdd = '/recurring/add';
  static String recurringEdit(String id) => '/recurring/$id/edit';
  static const subscriptions = '/subscriptions';
  static const subscriptionAdd = '/subscriptions/add';
  static String subscriptionEdit(String id) => '/subscriptions/$id/edit';

  // Transactions nested
  static const transactionAdd = '/transactions/add';
  static String transactionEdit(String id) => '/transactions/edit/$id';

  // Budgets nested
  static const budgetAdd = '/budgets/add';
  static String budgetDetail(String id) => '/budgets/$id';
  static String budgetEdit(String id) => '/budgets/$id/edit';

  // Full-screen
  static const smsReview = '/sms-review';
}
