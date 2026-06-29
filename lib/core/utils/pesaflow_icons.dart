import 'package:flutter/material.dart';

/// Branded icon set for PesaFlow.
/// Single source of truth — never use raw `Icons.xxx` in screens.
class PesaFlowIcons {
  PesaFlowIcons._();

  // Navigation
  static const IconData dashboard = Icons.compass_dashboard_outlined;
  static const IconData transactions = Icons.receipt_long_outlined;
  static const IconData budgets = Icons.pie_chart_outline;
  static const IconData savings = Icons.savings_outlined;
  static const IconData loans = Icons.account_balance_outlined;
  static const IconData subscriptions = Icons.repeat_outlined;
  static const IconData settings = Icons.tune_outlined;
  static const IconData analytics = Icons.insights_outlined;

  // Actions
  static const IconData add = Icons.add_circle_outline;
  static const IconData edit = Icons.edit_outlined;
  static const IconData delete = Icons.delete_outline;
  static const IconData close = Icons.close;
  static const IconData back = Icons.arrow_back_ios_new_outlined;
  static const IconData more = Icons.more_horiz_outlined;
  static const IconData search = Icons.search_outlined;
  static const IconData filter = Icons.tune_outlined;
  static const IconData share = Icons.ios_share_outlined;
  static const IconData upload = Icons.cloud_upload_outlined;
  static const IconData download = Icons.cloud_download_outlined;

  // Finance
  static const IconData income = Icons.trending_up_rounded;
  static const IconData expense = Icons.trending_down_rounded;
  static const IconData transfer = Icons.swap_horiz_rounded;
  static const IconData wallet = Icons.account_balance_wallet_outlined;
  static const IconData cash = Icons.monetization_on_outlined;
  static const IconData card = Icons.credit_card_outlined;
  static const IconData percent = Icons.percent_outlined;
  static const IconData chart = Icons.bar_chart_rounded;
  static const IconData goal = Icons.flag_outlined;
  static const IconData target = Icons.track_changes_outlined;

  // Status
  static const IconData success = Icons.check_circle_rounded;
  static const IconData error = Icons.error_outline_rounded;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData info = Icons.info_outline_rounded;
  static const IconData empty = Icons.inbox_outlined;

  // Communication
  static const IconData notification = Icons.notifications_outlined;
  static const IconData lock = Icons.lock_outlined;
  static const IconData biometric = Icons.fingerprint_outlined;
  static const IconData sync = Icons.sync_outlined;
  static const IconData offline = Icons.wifi_off_outlined;

  // Misc
  static const IconData calendar = Icons.calendar_month_outlined;
  static const IconData sort = Icons.sort_outlined;
  static const IconData pdf = Icons.picture_as_pdf_outlined;
  static const IconData csv = Icons.table_chart_outlined;
  static const IconData backup = Icons.backup_outlined;
  static const IconData lightMode = Icons.light_mode_outlined;
  static const IconData darkMode = Icons.dark_mode_outlined;
}
