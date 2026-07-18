import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';

IconData getCategoryIcon(String iconName) {
  switch (iconName) {
    case 'briefcase':
      return PesaFlowIcons.work;
    case 'store':
      return PesaFlowIcons.store;
    case 'cart':
      return PesaFlowIcons.cart;
    case 'bus':
      return PesaFlowIcons.bus;
    case 'home':
      return PesaFlowIcons.home;
    case 'zap':
      return PesaFlowIcons.bolt;
    case 'phone':
      return PesaFlowIcons.phone;
    case 'heart':
      return PesaFlowIcons.heart;
    case 'book':
      return PesaFlowIcons.book;
    case 'film':
      return PesaFlowIcons.movie;
    case 'shopping-bag':
      return PesaFlowIcons.shoppingBag;
    case 'coffee':
      return PesaFlowIcons.coffee;
    case 'send':
      return PesaFlowIcons.send;
    case 'credit-card':
      return PesaFlowIcons.card;
    case 'banknote':
      return PesaFlowIcons.payments;
    case 'piggy-bank':
      return PesaFlowIcons.savings;
    case 'arrow-left-right':
      return PesaFlowIcons.compareArrows;
    case 'plus-circle':
      return PesaFlowIcons.add;
    default:
      return PesaFlowIcons.add;
  }
}

IconData getGoalIcon(String iconName) {
  switch (iconName) {
    case 'savings':
      return PesaFlowIcons.savings;
    case 'laptop':
      return PesaFlowIcons.laptop;
    case 'flight':
      return PesaFlowIcons.flight;
    case 'home':
      return PesaFlowIcons.home;
    case 'car':
      return PesaFlowIcons.car;
    case 'school':
      return PesaFlowIcons.school;
    case 'heart':
      return PesaFlowIcons.heart;
    case 'gift':
      return PesaFlowIcons.gift;
    default:
      return PesaFlowIcons.savings;
  }
}

IconData getAccountIcon(String iconStr) {
  switch (iconStr) {
    case 'phone-android':
      return PesaFlowIcons.phone;
    case 'account-balance':
      return PesaFlowIcons.loans;
    case 'wallet':
      return PesaFlowIcons.wallet;
    default:
      return PesaFlowIcons.wallet;
  }
}

IconData getTrackerIcon(String iconName) {
  switch (iconName) {
    case 'briefcase':
      return PesaFlowIcons.work;
    case 'home':
      return PesaFlowIcons.home;
    case 'person':
      return PesaFlowIcons.person;
    case 'flight':
      return PesaFlowIcons.flight;
    case 'shopping_cart':
      return PesaFlowIcons.cart;
    case 'payments':
      return PesaFlowIcons.payments;
    default:
      return PesaFlowIcons.folder;
  }
}
