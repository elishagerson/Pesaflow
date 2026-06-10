import 'package:flutter/material.dart';

IconData getCategoryIcon(String iconName) {
  switch (iconName) {
    case 'briefcase':
      return Icons.work_rounded;
    case 'store':
      return Icons.storefront_rounded;
    case 'cart':
      return Icons.shopping_cart_rounded;
    case 'bus':
      return Icons.directions_bus_rounded;
    case 'home':
      return Icons.home_rounded;
    case 'zap':
      return Icons.electric_bolt_rounded;
    case 'phone':
      return Icons.phone_android_rounded;
    case 'heart':
      return Icons.favorite_rounded;
    case 'book':
      return Icons.menu_book_rounded;
    case 'film':
      return Icons.movie_rounded;
    case 'shopping-bag':
      return Icons.shopping_bag_rounded;
    case 'coffee':
      return Icons.coffee_rounded;
    case 'send':
      return Icons.send_rounded;
    case 'credit-card':
      return Icons.credit_card_rounded;
    case 'banknote':
      return Icons.payments_rounded;
    case 'piggy-bank':
      return Icons.savings_rounded;
    case 'arrow-left-right':
      return Icons.compare_arrows_rounded;
    case 'plus-circle':
      return Icons.add_circle_outline_rounded;
    default:
      return Icons.add_circle_outline_rounded;
  }
}

IconData getGoalIcon(String iconName) {
  switch (iconName) {
    case 'savings':
      return Icons.savings_rounded;
    case 'laptop':
      return Icons.laptop_chromebook_rounded;
    case 'flight':
      return Icons.flight_takeoff_rounded;
    case 'home':
      return Icons.home_rounded;
    case 'car':
      return Icons.directions_car_rounded;
    case 'school':
      return Icons.school_rounded;
    case 'heart':
      return Icons.favorite_rounded;
    case 'gift':
      return Icons.card_giftcard_rounded;
    default:
      return Icons.savings_rounded;
  }
}

IconData getAccountIcon(String iconStr) {
  switch (iconStr) {
    case 'phone-android':
      return Icons.phone_android_rounded;
    case 'account-balance':
      return Icons.account_balance_rounded;
    case 'wallet':
      return Icons.account_balance_wallet_rounded;
    default:
      return Icons.account_balance_wallet_rounded;
  }
}

IconData getTrackerIcon(String iconName) {
  switch (iconName) {
    case 'briefcase':
      return Icons.work_rounded;
    case 'home':
      return Icons.home_rounded;
    case 'person':
      return Icons.person_rounded;
    case 'flight':
      return Icons.flight_takeoff_rounded;
    case 'shopping_cart':
      return Icons.shopping_cart_rounded;
    case 'payments':
      return Icons.payments_rounded;
    default:
      return Icons.folder_rounded;
  }
}
