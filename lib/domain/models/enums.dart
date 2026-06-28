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
