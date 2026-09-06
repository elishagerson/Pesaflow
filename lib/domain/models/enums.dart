import 'package:flutter/foundation.dart';

enum TransactionType {
  income,
  expense,
  transfer,
  airtime,
  fee;

  String toDbString() => name;

  static TransactionType fromDbString(String value) {
    switch (value) {
      case 'income':
        return TransactionType.income;
      case 'expense':
        return TransactionType.expense;
      case 'transfer':
        return TransactionType.transfer;
      case 'airtime':
        return TransactionType.airtime;
      case 'fee':
        return TransactionType.fee;
      default:
        debugPrint('Unknown TransactionType: $value, defaulting to expense');
        return TransactionType.expense;
    }
  }
}

enum AccountType {
  mobileMoney,
  bank,
  cash;

  String toDbString() {
    switch (this) {
      case AccountType.mobileMoney:
        return 'mobile_money';
      case AccountType.bank:
        return 'bank';
      case AccountType.cash:
        return 'cash';
    }
  }

  static AccountType fromDbString(String value) {
    switch (value) {
      case 'mobile_money':
        return AccountType.mobileMoney;
      case 'bank':
        return AccountType.bank;
      case 'cash':
        return AccountType.cash;
      default:
        debugPrint('Unknown AccountType: $value, defaulting to cash');
        return AccountType.cash;
    }
  }
}

enum BudgetPeriod {
  weekly,
  biweekly,
  monthly,
  quarterly,
  yearly;

  String toDbString() {
    switch (this) {
      case BudgetPeriod.weekly:
        return 'weekly';
      case BudgetPeriod.biweekly:
        return 'biweekly';
      case BudgetPeriod.monthly:
        return 'monthly';
      case BudgetPeriod.quarterly:
        return 'quarterly';
      case BudgetPeriod.yearly:
        return 'yearly';
    }
  }

  static BudgetPeriod fromDbString(String value) {
    switch (value) {
      case 'weekly':
        return BudgetPeriod.weekly;
      case 'biweekly':
        return BudgetPeriod.biweekly;
      case 'monthly':
        return BudgetPeriod.monthly;
      case 'quarterly':
        return BudgetPeriod.quarterly;
      case 'yearly':
        return BudgetPeriod.yearly;
      default:
        debugPrint('Unknown BudgetPeriod: $value, defaulting to monthly');
        return BudgetPeriod.monthly;
    }
  }
}

enum TransactionSource {
  manual,
  smsAuto,
  smsReviewed;

  String toDbString() {
    switch (this) {
      case TransactionSource.manual:
        return 'manual';
      case TransactionSource.smsAuto:
        return 'sms_auto';
      case TransactionSource.smsReviewed:
        return 'sms_reviewed';
    }
  }

  static TransactionSource fromDbString(String value) {
    switch (value) {
      case 'manual':
        return TransactionSource.manual;
      case 'sms_auto':
        return TransactionSource.smsAuto;
      case 'sms_reviewed':
        return TransactionSource.smsReviewed;
      default:
        debugPrint('Unknown TransactionSource: $value, defaulting to manual');
        return TransactionSource.manual;
    }
  }
}

/// The high-level group a budget belongs to.
enum BudgetGroupType {
  needs,
  wants,
  investments,
  custom;

  String toDbString() => name;

  String get displayName => switch (this) {
    BudgetGroupType.needs => 'Needs',
    BudgetGroupType.wants => 'Wants',
    BudgetGroupType.investments => 'Investments',
    BudgetGroupType.custom => 'Custom',
  };

  static BudgetGroupType fromDbString(String value) {
    switch (value) {
      case 'needs':
        return BudgetGroupType.needs;
      case 'wants':
        return BudgetGroupType.wants;
      case 'investments':
        return BudgetGroupType.investments;
      case 'custom':
        return BudgetGroupType.custom;
      default:
        debugPrint('Unknown BudgetGroupType: $value, defaulting to custom');
        return BudgetGroupType.custom;
    }
  }
}

/// Pre-defined budgeting rules.
enum BudgetRuleType {
  rule503020,
  rule702010,
  rule602020,
  custom;

  String toDbString() => name;

  String get displayName => switch (this) {
    BudgetRuleType.rule503020 => '50 / 30 / 20',
    BudgetRuleType.rule702010 => '70 / 20 / 10',
    BudgetRuleType.rule602020 => '60 / 20 / 20',
    BudgetRuleType.custom => 'Custom Split',
  };

  String get subtitle => switch (this) {
    BudgetRuleType.rule503020 => 'The classic balanced budget rule',
    BudgetRuleType.rule702010 => 'Conservative — prioritize essentials',
    BudgetRuleType.rule602020 => 'Balanced with higher investments',
    BudgetRuleType.custom => 'Set your own percentages',
  };

  /// Returns (needs%, wants%, investments%) as decimals.
  (double, double, double) get percentages => switch (this) {
    BudgetRuleType.rule503020 => (0.50, 0.30, 0.20),
    BudgetRuleType.rule702010 => (0.70, 0.20, 0.10),
    BudgetRuleType.rule602020 => (0.60, 0.20, 0.20),
    BudgetRuleType.custom => (0.0, 0.0, 0.0),
  };

  static BudgetRuleType fromDbString(String value) {
    switch (value) {
      case 'rule503020':
        return BudgetRuleType.rule503020;
      case 'rule702010':
        return BudgetRuleType.rule702010;
      case 'rule602020':
        return BudgetRuleType.rule602020;
      case 'custom':
        return BudgetRuleType.custom;
      default:
        debugPrint('Unknown BudgetRuleType: $value, defaulting to rule503020');
        return BudgetRuleType.rule503020;
    }
  }
}
