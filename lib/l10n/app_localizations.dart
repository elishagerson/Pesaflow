import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sw.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sw'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'PesaFlow'**
  String get appTitle;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @newItem.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newItem;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @skip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @export.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export;

  /// No description provided for @import.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get import;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @transactions.
  ///
  /// In en, this message translates to:
  /// **'Transactions'**
  String get transactions;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @budgets.
  ///
  /// In en, this message translates to:
  /// **'Budgets'**
  String get budgets;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @savings.
  ///
  /// In en, this message translates to:
  /// **'Savings'**
  String get savings;

  /// No description provided for @loans.
  ///
  /// In en, this message translates to:
  /// **'Loans'**
  String get loans;

  /// No description provided for @recurring.
  ///
  /// In en, this message translates to:
  /// **'Recurring & Bills'**
  String get recurring;

  /// No description provided for @accounts_manager.
  ///
  /// In en, this message translates to:
  /// **'Accounts Manager'**
  String get accounts_manager;

  /// No description provided for @add_account.
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get add_account;

  /// No description provided for @add_custom.
  ///
  /// In en, this message translates to:
  /// **'Add Custom'**
  String get add_custom;

  /// No description provided for @add_recurring_flow.
  ///
  /// In en, this message translates to:
  /// **'Add Recurring Flow'**
  String get add_recurring_flow;

  /// No description provided for @all_accounts.
  ///
  /// In en, this message translates to:
  /// **'All Accounts'**
  String get all_accounts;

  /// No description provided for @app_theme.
  ///
  /// In en, this message translates to:
  /// **'App Theme'**
  String get app_theme;

  /// No description provided for @auto_budget_on_income.
  ///
  /// In en, this message translates to:
  /// **'Auto-Budget on Income'**
  String get auto_budget_on_income;

  /// No description provided for @back_2.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back_2;

  /// No description provided for @backup_database.
  ///
  /// In en, this message translates to:
  /// **'Backup Database'**
  String get backup_database;

  /// No description provided for @biometric_app_lock.
  ///
  /// In en, this message translates to:
  /// **'Biometric App Lock'**
  String get biometric_app_lock;

  /// No description provided for @csv_spreadsheet_data.
  ///
  /// In en, this message translates to:
  /// **'CSV - Spreadsheet data'**
  String get csv_spreadsheet_data;

  /// No description provided for @cancel_2.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel_2;

  /// No description provided for @categories_manager.
  ///
  /// In en, this message translates to:
  /// **'Categories Manager'**
  String get categories_manager;

  /// No description provided for @clear_search.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clear_search;

  /// No description provided for @close_2.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close_2;

  /// No description provided for @create_2.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create_2;

  /// No description provided for @custom_range.
  ///
  /// In en, this message translates to:
  /// **'Custom Range'**
  String get custom_range;

  /// No description provided for @delete_2.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete_2;

  /// No description provided for @delete_account.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get delete_account;

  /// No description provided for @delete_budget_plan.
  ///
  /// In en, this message translates to:
  /// **'Delete Budget Plan?'**
  String get delete_budget_plan;

  /// No description provided for @delete_budget.
  ///
  /// In en, this message translates to:
  /// **'Delete Budget?'**
  String get delete_budget;

  /// No description provided for @delete_loan.
  ///
  /// In en, this message translates to:
  /// **'Delete Loan?'**
  String get delete_loan;

  /// No description provided for @delete_recurring_flow.
  ///
  /// In en, this message translates to:
  /// **'Delete Recurring Flow?'**
  String get delete_recurring_flow;

  /// No description provided for @delete_savings_goal.
  ///
  /// In en, this message translates to:
  /// **'Delete Savings Goal?'**
  String get delete_savings_goal;

  /// No description provided for @delete_sub_budget.
  ///
  /// In en, this message translates to:
  /// **'Delete Sub-Budget?'**
  String get delete_sub_budget;

  /// No description provided for @delete_transaction.
  ///
  /// In en, this message translates to:
  /// **'Delete Transaction'**
  String get delete_transaction;

  /// No description provided for @delete_workspace.
  ///
  /// In en, this message translates to:
  /// **'Delete Workspace?'**
  String get delete_workspace;

  /// No description provided for @discard_2.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard_2;

  /// No description provided for @discard_changes.
  ///
  /// In en, this message translates to:
  /// **'Discard Changes?'**
  String get discard_changes;

  /// No description provided for @download_formatted_pdf_or_csv.
  ///
  /// In en, this message translates to:
  /// **'Download formatted PDF or CSV'**
  String get download_formatted_pdf_or_csv;

  /// No description provided for @download_transactions_as_csv_file.
  ///
  /// In en, this message translates to:
  /// **'Download transactions as CSV file'**
  String get download_transactions_as_csv_file;

  /// No description provided for @edit_account.
  ///
  /// In en, this message translates to:
  /// **'Edit Account'**
  String get edit_account;

  /// No description provided for @edit_workspace.
  ///
  /// In en, this message translates to:
  /// **'Edit Workspace'**
  String get edit_workspace;

  /// No description provided for @enable_rollover.
  ///
  /// In en, this message translates to:
  /// **'Enable Rollover'**
  String get enable_rollover;

  /// No description provided for @export_2.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get export_2;

  /// No description provided for @export_monthly_statement.
  ///
  /// In en, this message translates to:
  /// **'Export Monthly Statement'**
  String get export_monthly_statement;

  /// No description provided for @export_statement.
  ///
  /// In en, this message translates to:
  /// **'Export Statement'**
  String get export_statement;

  /// No description provided for @export_to_csv.
  ///
  /// In en, this message translates to:
  /// **'Export to CSV'**
  String get export_to_csv;

  /// No description provided for @go_home.
  ///
  /// In en, this message translates to:
  /// **'Go Home'**
  String get go_home;

  /// No description provided for @import_csv.
  ///
  /// In en, this message translates to:
  /// **'Import CSV'**
  String get import_csv;

  /// No description provided for @import_transactions_from_csv_file.
  ///
  /// In en, this message translates to:
  /// **'Import transactions from CSV file'**
  String get import_transactions_from_csv_file;

  /// No description provided for @keep_editing.
  ///
  /// In en, this message translates to:
  /// **'Keep Editing'**
  String get keep_editing;

  /// No description provided for @lock_screen_balance.
  ///
  /// In en, this message translates to:
  /// **'Lock Screen Balance'**
  String get lock_screen_balance;

  /// No description provided for @make_a_payment.
  ///
  /// In en, this message translates to:
  /// **'Make a Payment'**
  String get make_a_payment;

  /// No description provided for @manage_workspaces.
  ///
  /// In en, this message translates to:
  /// **'Manage Workspaces'**
  String get manage_workspaces;

  /// No description provided for @monthly.
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get monthly;

  /// No description provided for @monthly_income.
  ///
  /// In en, this message translates to:
  /// **'Monthly Income'**
  String get monthly_income;

  /// No description provided for @new_workspace.
  ///
  /// In en, this message translates to:
  /// **'New Workspace'**
  String get new_workspace;

  /// No description provided for @no_account_offline.
  ///
  /// In en, this message translates to:
  /// **'No account (offline)'**
  String get no_account_offline;

  /// No description provided for @no_active_accounts.
  ///
  /// In en, this message translates to:
  /// **'No active accounts.'**
  String get no_active_accounts;

  /// No description provided for @no_categories_seeded.
  ///
  /// In en, this message translates to:
  /// **'No categories seeded.'**
  String get no_categories_seeded;

  /// No description provided for @none_standalone.
  ///
  /// In en, this message translates to:
  /// **'None (Standalone)'**
  String get none_standalone;

  /// No description provided for @offline_privacy_guarantee.
  ///
  /// In en, this message translates to:
  /// **'Offline Privacy Guarantee'**
  String get offline_privacy_guarantee;

  /// No description provided for @open_settings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get open_settings;

  /// No description provided for @pdf_professional_report.
  ///
  /// In en, this message translates to:
  /// **'PDF - Professional report'**
  String get pdf_professional_report;

  /// No description provided for @recurring_bills.
  ///
  /// In en, this message translates to:
  /// **'Recurring & Bills'**
  String get recurring_bills;

  /// No description provided for @remind_later.
  ///
  /// In en, this message translates to:
  /// **'Remind later'**
  String get remind_later;

  /// No description provided for @restore_2.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore_2;

  /// No description provided for @restore_database.
  ///
  /// In en, this message translates to:
  /// **'Restore Database'**
  String get restore_database;

  /// No description provided for @restore_database_2.
  ///
  /// In en, this message translates to:
  /// **'Restore Database?'**
  String get restore_database_2;

  /// No description provided for @restore_failed.
  ///
  /// In en, this message translates to:
  /// **'Restore Failed'**
  String get restore_failed;

  /// No description provided for @run_full_pipeline.
  ///
  /// In en, this message translates to:
  /// **'Run Full Pipeline'**
  String get run_full_pipeline;

  /// No description provided for @sms_auto_deduplication.
  ///
  /// In en, this message translates to:
  /// **'SMS Auto-Deduplication'**
  String get sms_auto_deduplication;

  /// No description provided for @sms_parser_debug.
  ///
  /// In en, this message translates to:
  /// **'SMS Parser Debug'**
  String get sms_parser_debug;

  /// No description provided for @save_2.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save_2;

  /// No description provided for @show_decimals.
  ///
  /// In en, this message translates to:
  /// **'Show Decimals'**
  String get show_decimals;

  /// No description provided for @skip_2.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skip_2;

  /// No description provided for @try_another_file.
  ///
  /// In en, this message translates to:
  /// **'Try Another File'**
  String get try_another_file;

  /// No description provided for @unlock_app.
  ///
  /// In en, this message translates to:
  /// **'Unlock App'**
  String get unlock_app;

  /// No description provided for @deleteGroup.
  ///
  /// In en, this message translates to:
  /// **'Delete {groupName} Group?'**
  String deleteGroup(String groupName);

  /// No description provided for @errorLoadingActivity.
  ///
  /// In en, this message translates to:
  /// **'Error loading activity: {error}'**
  String errorLoadingActivity(String error);

  /// No description provided for @errorLoadingTransactions.
  ///
  /// In en, this message translates to:
  /// **'Error loading transactions: {error}'**
  String errorLoadingTransactions(String error);

  /// No description provided for @importTransactions.
  ///
  /// In en, this message translates to:
  /// **'Import {count} Transactions'**
  String importTransactions(int count);

  /// No description provided for @yearValue.
  ///
  /// In en, this message translates to:
  /// **'{year}'**
  String yearValue(int year);

  /// No description provided for @enable_notification_access.
  ///
  /// In en, this message translates to:
  /// **'Enable Notification Access'**
  String get enable_notification_access;

  /// No description provided for @notification_access_body.
  ///
  /// In en, this message translates to:
  /// **'PesaFlow needs Notification Access to detect transaction SMS on Android 14+.\n\nTap \"Open Settings\" and toggle PesaFlow ON in the list.'**
  String get notification_access_body;

  /// No description provided for @dont_show_again.
  ///
  /// In en, this message translates to:
  /// **'Don\'t show again'**
  String get dont_show_again;

  /// No description provided for @app_locked_title.
  ///
  /// In en, this message translates to:
  /// **'PesaFlow Locked'**
  String get app_locked_title;

  /// No description provided for @auth_required_message.
  ///
  /// In en, this message translates to:
  /// **'Authentication required to access offline data'**
  String get auth_required_message;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sw'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sw':
      return AppLocalizationsSw();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
