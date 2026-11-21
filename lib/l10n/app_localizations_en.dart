// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PesaFlow';

  @override
  String get cancel => 'Cancel';

  @override
  String get save => 'Save';

  @override
  String get delete => 'Delete';

  @override
  String get back => 'Back';

  @override
  String get close => 'Close';

  @override
  String get create => 'Create';

  @override
  String get edit => 'Edit';

  @override
  String get newItem => 'New';

  @override
  String get done => 'Done';

  @override
  String get skip => 'Skip';

  @override
  String get discard => 'Discard';

  @override
  String get restore => 'Restore';

  @override
  String get export => 'Export';

  @override
  String get import => 'Import';

  @override
  String get settings => 'Settings';

  @override
  String get transactions => 'Transactions';

  @override
  String get accounts => 'Accounts';

  @override
  String get budgets => 'Budgets';

  @override
  String get analytics => 'Analytics';

  @override
  String get savings => 'Savings';

  @override
  String get loans => 'Loans';

  @override
  String get recurring => 'Recurring & Bills';

  @override
  String get accounts_manager => 'Accounts Manager';

  @override
  String get add_account => 'Add Account';

  @override
  String get add_custom => 'Add Custom';

  @override
  String get add_recurring_flow => 'Add Recurring Flow';

  @override
  String get all_accounts => 'All Accounts';

  @override
  String get app_theme => 'App Theme';

  @override
  String get auto_budget_on_income => 'Auto-Budget on Income';

  @override
  String get back_2 => 'Back';

  @override
  String get backup_database => 'Backup Database';

  @override
  String get biometric_app_lock => 'Biometric App Lock';

  @override
  String get csv_spreadsheet_data => 'CSV - Spreadsheet data';

  @override
  String get cancel_2 => 'Cancel';

  @override
  String get categories_manager => 'Categories Manager';

  @override
  String get clear_search => 'Clear search';

  @override
  String get close_2 => 'Close';

  @override
  String get create_2 => 'Create';

  @override
  String get custom_range => 'Custom Range';

  @override
  String get delete_2 => 'Delete';

  @override
  String get delete_account => 'Delete Account';

  @override
  String get delete_budget_plan => 'Delete Budget Plan?';

  @override
  String get delete_budget => 'Delete Budget?';

  @override
  String get delete_loan => 'Delete Loan?';

  @override
  String get delete_recurring_flow => 'Delete Recurring Flow?';

  @override
  String get delete_savings_goal => 'Delete Savings Goal?';

  @override
  String get delete_sub_budget => 'Delete Sub-Budget?';

  @override
  String get delete_transaction => 'Delete Transaction';

  @override
  String get delete_workspace => 'Delete Workspace?';

  @override
  String get discard_2 => 'Discard';

  @override
  String get discard_changes => 'Discard Changes?';

  @override
  String get download_formatted_pdf_or_csv => 'Download formatted PDF or CSV';

  @override
  String get download_transactions_as_csv_file =>
      'Download transactions as CSV file';

  @override
  String get edit_account => 'Edit Account';

  @override
  String get edit_workspace => 'Edit Workspace';

  @override
  String get enable_rollover => 'Enable Rollover';

  @override
  String get export_2 => 'Export';

  @override
  String get export_monthly_statement => 'Export Monthly Statement';

  @override
  String get export_statement => 'Export Statement';

  @override
  String get export_to_csv => 'Export to CSV';

  @override
  String get go_home => 'Go Home';

  @override
  String get import_csv => 'Import CSV';

  @override
  String get import_transactions_from_csv_file =>
      'Import transactions from CSV file';

  @override
  String get keep_editing => 'Keep Editing';

  @override
  String get lock_screen_balance => 'Lock Screen Balance';

  @override
  String get make_a_payment => 'Make a Payment';

  @override
  String get manage_workspaces => 'Manage Workspaces';

  @override
  String get monthly => 'Monthly';

  @override
  String get monthly_income => 'Monthly Income';

  @override
  String get new_workspace => 'New Workspace';

  @override
  String get no_account_offline => 'No account (offline)';

  @override
  String get no_active_accounts => 'No active accounts.';

  @override
  String get no_categories_seeded => 'No categories seeded.';

  @override
  String get none_standalone => 'None (Standalone)';

  @override
  String get offline_privacy_guarantee => 'Offline Privacy Guarantee';

  @override
  String get open_settings => 'Open Settings';

  @override
  String get pdf_professional_report => 'PDF - Professional report';

  @override
  String get recurring_bills => 'Recurring & Bills';

  @override
  String get remind_later => 'Remind later';

  @override
  String get restore_2 => 'Restore';

  @override
  String get restore_database => 'Restore Database';

  @override
  String get restore_database_2 => 'Restore Database?';

  @override
  String get restore_failed => 'Restore Failed';

  @override
  String get run_full_pipeline => 'Run Full Pipeline';

  @override
  String get sms_auto_deduplication => 'SMS Auto-Deduplication';

  @override
  String get sms_parser_debug => 'SMS Parser Debug';

  @override
  String get save_2 => 'Save';

  @override
  String get show_decimals => 'Show Decimals';

  @override
  String get skip_2 => 'Skip';

  @override
  String get try_another_file => 'Try Another File';

  @override
  String get unlock_app => 'Unlock App';

  @override
  String deleteGroup(String groupName) {
    return 'Delete $groupName Group?';
  }

  @override
  String errorLoadingActivity(String error) {
    return 'Error loading activity: $error';
  }

  @override
  String errorLoadingTransactions(String error) {
    return 'Error loading transactions: $error';
  }

  @override
  String importTransactions(int count) {
    return 'Import $count Transactions';
  }

  @override
  String yearValue(int year) {
    return '$year';
  }
}
