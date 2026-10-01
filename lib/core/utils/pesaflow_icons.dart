import 'package:flutter/material.dart';

/// Branded icon set for PesaFlow.
/// Single source of truth — never use raw `Icons.xxx` in screens.
///
/// All icons use `_rounded` (filled) variants for maximum visibility at small
/// sizes on both light and dark backgrounds. Outlined/stroked variants are
/// intentionally avoided — they render as thin 1px paths that disappear on
/// dark surfaces.
class PesaFlowIcons {
  PesaFlowIcons._();

  // Navigation
  static const IconData dashboard = Icons.dashboard_rounded;
  static const IconData transactions = Icons.receipt_long_rounded;
  static const IconData budgets = Icons.pie_chart_rounded;
  static const IconData savings = Icons.savings_rounded;
  static const IconData loans = Icons.account_balance_rounded;
  static const IconData subscriptions = Icons.repeat_rounded;
  static const IconData settings = Icons.tune_rounded;
  static const IconData analytics = Icons.leaderboard_rounded;

  // Actions
  static const IconData add = Icons.add_circle_rounded;
  static const IconData edit = Icons.edit_rounded;
  static const IconData delete = Icons.delete_rounded;
  static const IconData close = Icons.close;
  static const IconData back = Icons.arrow_back_ios_new_rounded;
  static const IconData more = Icons.more_horiz_rounded;
  static const IconData search = Icons.search_rounded;
  static const IconData menu = Icons.menu_rounded;
  static const IconData filter = Icons.tune_rounded;
  static const IconData visibility = Icons.visibility_rounded;
  static const IconData visibilityOff = Icons.visibility_off_rounded;
  static const IconData share = Icons.ios_share_rounded;
  static const IconData upload = Icons.cloud_upload_rounded;
  static const IconData download = Icons.cloud_download_rounded;

  // Finance
  static const IconData income = Icons.trending_up_rounded;
  static const IconData expense = Icons.trending_down_rounded;
  static const IconData transfer = Icons.swap_horiz_rounded;
  static const IconData wallet = Icons.account_balance_wallet_rounded;
  static const IconData cash = Icons.monetization_on_rounded;
  static const IconData card = Icons.credit_card_rounded;
  static const IconData percent = Icons.percent_rounded;
  static const IconData chart = Icons.bar_chart_rounded;
  static const IconData goal = Icons.flag_rounded;
  static const IconData celebration = Icons.celebration_rounded;
  static const IconData target = Icons.track_changes_rounded;

  // Status
  static const IconData success = Icons.check_circle_rounded;
  static const IconData error = Icons.error_rounded;
  static const IconData warning = Icons.warning_amber_rounded;
  static const IconData info = Icons.info_rounded;
  static const IconData empty = Icons.inbox_rounded;

  // Communication
  static const IconData notification = Icons.notifications_rounded;
  static const IconData lock = Icons.lock_rounded;
  static const IconData biometric = Icons.fingerprint_rounded;
  static const IconData sync = Icons.sync_rounded;
  static const IconData offline = Icons.wifi_off_rounded;

  // Misc
  static const IconData calendar = Icons.calendar_month_rounded;
  static const IconData sort = Icons.sort_rounded;
  static const IconData pdf = Icons.picture_as_pdf_rounded;
  static const IconData csv = Icons.table_chart_rounded;
  static const IconData backup = Icons.backup_rounded;
  static const IconData lightbulb = Icons.lightbulb_rounded;
  static const IconData lightMode = Icons.light_mode_rounded;
  static const IconData darkMode = Icons.dark_mode_rounded;
  static const IconData phone = Icons.phone_rounded;
  static const IconData category = Icons.category_rounded;
  static const IconData security = Icons.shield_rounded;
  static const IconData unlock = Icons.lock_open_rounded;
  static const IconData pin = Icons.password_rounded;
  static const IconData sms = Icons.sms_rounded;
  static const IconData themeMode = Icons.brightness_medium_rounded;
  static const IconData file = Icons.insert_drive_file_rounded;
  static const IconData chevronRight = Icons.chevron_right_rounded;
  static const IconData restore = Icons.history_rounded;

  // Directions / Arrows
  static const IconData arrowUp = Icons.arrow_upward_rounded;
  static const IconData arrowDown = Icons.arrow_downward_rounded;
  static const IconData arrowForward = Icons.arrow_forward_rounded;
  static const IconData arrowOutward = Icons.arrow_outward_rounded;
  static const IconData chevronDown = Icons.keyboard_arrow_down_rounded;
  static const IconData chevronUp = Icons.keyboard_arrow_up_rounded;

  // Confirm / Status
  static const IconData check = Icons.check_rounded;
  static const IconData cancel = Icons.cancel_rounded;
  static const IconData clear = Icons.clear_rounded;
  static const IconData remove = Icons.remove_rounded;
  static const IconData block = Icons.block_rounded;
  static const IconData pause = Icons.pause_rounded;

  // Content / Actions
  static const IconData copy = Icons.copy_rounded;
  static const IconData bookmark = Icons.bookmark_border_rounded;
  static const IconData bookmarkFilled = Icons.bookmark_rounded;
  static const IconData message = Icons.message_rounded;
  static const IconData description = Icons.description_rounded;
  static const IconData clearAll = Icons.clear_all_rounded;
  static const IconData selectAll = Icons.done_all_rounded;
  static const IconData deselect = Icons.remove_done_rounded;

  // Goal / Lifestyle
  static const IconData home = Icons.home_rounded;
  static const IconData car = Icons.directions_car_rounded;
  static const IconData school = Icons.school_rounded;
  static const IconData heart = Icons.favorite_rounded;
  static const IconData flight = Icons.flight_takeoff_rounded;
  static const IconData laptop = Icons.laptop_chromebook_rounded;
  static const IconData business = Icons.business_rounded;
  static const IconData hospital = Icons.local_hospital_rounded;
  static const IconData gift = Icons.card_giftcard_rounded;

  // Finance / Tags
  static const IconData tag = Icons.tag_rounded;
  static const IconData creditScore = Icons.credit_score_rounded;
  static const IconData money = Icons.money_rounded;
  static const IconData payment = Icons.payment_rounded;
  static const IconData speed = Icons.speed_rounded;
  static const IconData label = Icons.label_rounded;
  static const IconData schedule = Icons.schedule_rounded;

  // People
  static const IconData person = Icons.person_rounded;
  static const IconData personOutline = Icons.person_outline_rounded;

  // Misc
  static const IconData history = Icons.history_rounded;
  static const IconData dateRange = Icons.date_range_rounded;
  static const IconData calendarToday = Icons.calendar_today_rounded;
  static const IconData gridView = Icons.grid_view_rounded;
  static const IconData filterAlt = Icons.filter_alt_rounded;
  static const IconData bolt = Icons.bolt_rounded;
  static const IconData key = Icons.key_rounded;
  static const IconData linkOff = Icons.link_off_rounded;
  static const IconData palette = Icons.palette_rounded;
  static const IconData replay = Icons.replay_rounded;
  static const IconData upcoming = Icons.upcoming_rounded;
  static const IconData wifi = Icons.wifi_rounded;
  static const IconData backspace = Icons.backspace_rounded;

  // Icon helpers / categories
  static const IconData work = Icons.work_rounded;
  static const IconData store = Icons.storefront_rounded;
  static const IconData cart = Icons.shopping_cart_rounded;
  static const IconData bus = Icons.directions_bus_rounded;
  static const IconData book = Icons.menu_book_rounded;
  static const IconData movie = Icons.movie_rounded;
  static const IconData shoppingBag = Icons.shopping_bag_rounded;
  static const IconData coffee = Icons.coffee_rounded;
  static const IconData send = Icons.send_rounded;
  static const IconData payments = Icons.payments_rounded;
  static const IconData compareArrows = Icons.compare_arrows_rounded;
  static const IconData folder = Icons.folder_rounded;
  static const IconData title = Icons.title_rounded;
  static const IconData emergency = Icons.emergency_rounded;
  static const IconData charity = Icons.volunteer_activism_rounded;
  static const IconData community = Icons.groups_rounded;
  static const IconData personalCare = Icons.spa_rounded;
  static const IconData family = Icons.family_restroom_rounded;
  static const IconData maintenance = Icons.handyman_rounded;
  static const IconData insurance = Icons.verified_user_rounded;
  static const IconData digitalSubscriptions = Icons.subscriptions_rounded;
  static const IconData vehicle = Icons.local_gas_station_rounded;
  static const IconData travel = Icons.beach_access_rounded;
  static const IconData fitness = Icons.fitness_center_rounded;
  static const IconData childcare = Icons.child_care_rounded;
  static const IconData electronics = Icons.devices_rounded;
  static const IconData pets = Icons.pets_rounded;
  static const IconData legal = Icons.gavel_rounded;
  static const IconData hobbies = Icons.palette_rounded;
  static const IconData fines = Icons.report_problem_rounded;
}
