import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/database/daos/budget_dao.dart';
import '../data/database/daos/category_dao.dart';
import '../data/database/database_providers.dart';
import '../data/repositories/budget_repository.dart';
import '../data/repositories/settings_repository.dart';

final autoBudgetServiceProvider = Provider<AutoBudgetService>((ref) {
  final budgetRepo = ref.watch(budgetRepositoryProvider);
  final budgetDao = ref.watch(budgetDaoProvider);
  final categoryDao = ref.watch(categoryDaoProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return AutoBudgetService(budgetRepo, budgetDao, categoryDao, settingsRepo);
});

class SubAllocation {
  final String name;
  final double percentage;
  final String? categoryId;

  const SubAllocation({
    required this.name,
    required this.percentage,
    this.categoryId,
  });

  SubAllocation copyWith({String? categoryId}) => SubAllocation(
    name: name,
    percentage: percentage,
    categoryId: categoryId ?? this.categoryId,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'percentage': percentage,
    if (categoryId != null) 'categoryId': categoryId,
  };

  factory SubAllocation.fromJson(Map<String, dynamic> json) => SubAllocation(
    name: json['name'] as String,
    percentage: (json['percentage'] as num).toDouble(),
    categoryId: json['categoryId'] as String?,
  );
}

class BudgetGroupConfig {
  final String name;
  final double percentage;
  final List<SubAllocation> subAllocations;

  const BudgetGroupConfig({
    required this.name,
    required this.percentage,
    required this.subAllocations,
  });

  double get totalSubPercentage =>
      subAllocations.fold(0, (sum, s) => sum + s.percentage);

  Map<String, dynamic> toJson() => {
    'name': name,
    'percentage': percentage,
    'subAllocations': subAllocations.map((s) => s.toJson()).toList(),
  };

  factory BudgetGroupConfig.fromJson(Map<String, dynamic> json) =>
    BudgetGroupConfig(
      name: json['name'] as String,
      percentage: (json['percentage'] as num).toDouble(),
      subAllocations: (json['subAllocations'] as List?)
          ?.map((s) => SubAllocation.fromJson(s as Map<String, dynamic>))
          .toList() ?? [],
    );
}

class AutoBudgetConfig {
  final bool enabled;
  final List<String> incomeCategoryIds;
  final List<BudgetGroupConfig> groups;
  final String period;

  const AutoBudgetConfig({
    required this.enabled,
    required this.incomeCategoryIds,
    required this.groups,
    this.period = 'monthly',
  });

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'incomeCategoryIds': incomeCategoryIds,
    'groups': groups.map((g) => g.toJson()).toList(),
    'period': period,
  };

  factory AutoBudgetConfig.fromJson(Map<String, dynamic> json) =>
    AutoBudgetConfig(
      enabled: json['enabled'] as bool? ?? false,
      incomeCategoryIds: (json['incomeCategoryIds'] as List?)?.cast<String>() ?? [],
      groups: (json['groups'] as List?)
          ?.map((g) => BudgetGroupConfig.fromJson(g as Map<String, dynamic>))
          .toList() ?? [],
      period: json['period'] as String? ?? 'monthly',
    );

  static AutoBudgetConfig defaults() {
    const needs = [
      SubAllocation(name: 'Rent', percentage: 0.38),
      SubAllocation(name: 'Food & Groceries', percentage: 0.25),
      SubAllocation(name: 'Transport', percentage: 0.20),
      SubAllocation(name: 'Utilities', percentage: 0.10),
      SubAllocation(name: 'Health', percentage: 0.07),
    ];
    const wants = [
      SubAllocation(name: 'Airtime & Data', percentage: 0.167),
      SubAllocation(name: 'Shopping', percentage: 0.30),
      SubAllocation(name: 'Entertainment', percentage: 0.20),
      SubAllocation(name: 'Other', percentage: 0.333),
    ];
    const savings = [
      SubAllocation(name: 'Savings', percentage: 0.50),
      SubAllocation(name: 'Loans', percentage: 0.25),
      SubAllocation(name: 'Other', percentage: 0.25),
    ];
    return const AutoBudgetConfig(
      enabled: false,
      incomeCategoryIds: [],
      period: 'monthly',
      groups: [
        BudgetGroupConfig(name: 'Mahitaji Muhimu', percentage: 0.50, subAllocations: needs),
        BudgetGroupConfig(name: 'Matumizi Binafsi', percentage: 0.30, subAllocations: wants),
        BudgetGroupConfig(name: 'Akiba & Uwekezaji', percentage: 0.20, subAllocations: savings),
      ],
    );
  }
}

class AutoBudgetService {
  final BudgetRepository _budgetRepo;
  final BudgetDao _budgetDao;
  final CategoryDao _categoryDao;
  final SettingsRepository _settingsRepo;

  AutoBudgetService(
    this._budgetRepo,
    this._budgetDao,
    this._categoryDao,
    this._settingsRepo,
  );

  static const _configKey = 'auto_budget_config';

  Future<AutoBudgetConfig> getConfig() async {
    final json = await _settingsRepo.getSetting(_configKey);
    if (json == null) return AutoBudgetConfig.defaults();
    try {
      return AutoBudgetConfig.fromJson(jsonDecode(json));
    } catch (e) {
      return AutoBudgetConfig.defaults();
    }
  }

  Future<void> saveConfig(AutoBudgetConfig config) async {
    await _settingsRepo.setSetting(_configKey, jsonEncode(config.toJson()));
  }

  Future<List<String>> _resolveIncomeCategoryIds(List<String> configuredIds) async {
    if (configuredIds.isNotEmpty) return configuredIds;
    final categories = await _categoryDao.getAllCategories();
    return categories
        .where((c) =>
            c.type == 'income' &&
            (c.name.toLowerCase() == 'salary' ||
             c.name.toLowerCase() == 'business'))
        .map((c) => c.id)
        .toList();
  }

  Future<Map<String, String>> _buildCategoryNameToIdMap() async {
    final categories = await _categoryDao.getAllCategories();
    final map = <String, String>{};
    for (final cat in categories) {
      map[cat.name.toLowerCase()] = cat.id;
    }
    return map;
  }

  Future<List<SubAllocation>> _resolveSubAllocations(
    List<SubAllocation> configured,
    Map<String, String> nameToId,
  ) async {
    return configured.map((sub) {
      if (sub.categoryId != null) return sub;
      final id = nameToId[sub.name.toLowerCase()];
      return sub.copyWith(categoryId: id);
    }).toList();
  }

  Future<void> checkAndCreateAutoBudgets(Transaction transaction) async {
    try {
      final config = await getConfig();
      if (!config.enabled) return;
      if (transaction.type.toLowerCase() != 'income') return;

      final incomeCategoryIds = await _resolveIncomeCategoryIds(
        config.incomeCategoryIds,
      );
      if (incomeCategoryIds.isEmpty) return;
      if (!incomeCategoryIds.contains(transaction.categoryId)) return;

      final nameToId = await _buildCategoryNameToIdMap();
      final amountCents = transaction.amount;
      final now = transaction.createdAt;
      final startDate = DateTime(now.year, now.month, 1);
      final existingBudgets = await _budgetDao.getAllActiveBudgets();

      for (final group in config.groups) {
        final groupAmount = (amountCents * group.percentage).round();
        if (groupAmount <= 0) continue;

        final resolvedSubs = await _resolveSubAllocations(
          group.subAllocations,
          nameToId,
        );

        for (final sub in resolvedSubs) {
          if (sub.categoryId == null) continue;
          final subAmount = (groupAmount * sub.percentage).round();
          if (subAmount <= 0) continue;

          Budget? existing;
          for (final b in existingBudgets) {
            if (b.categoryId == sub.categoryId) {
              final period = await _budgetDao.getCurrentPeriod(b.id);
              if (period != null &&
                  period.periodStart.isBefore(
                      startDate.add(const Duration(days: 1))) &&
                  period.periodEnd.isAfter(
                      startDate.subtract(const Duration(days: 1)))) {
                existing = b;
                break;
              }
            }
          }

          if (existing != null) {
            await _budgetDao.updateBudget(
              existing.copyWith(amount: subAmount),
            );
            await _budgetDao.updateCurrentPeriodAllocated(
              existing.id,
              subAmount,
            );
          } else {
            await _budgetRepo.createBudget(
              name: '${group.name} — ${sub.name}',
              categoryId: sub.categoryId!,
              period: config.period,
              amount: subAmount,
              rollover: true,
              rolloverType: 'all',
              startDate: startDate,
              notificationThreshold: 0.8,
            );
          }
        }
      }

      developer.log(
        'Auto-budget created for income TSh ${(amountCents / 100).toStringAsFixed(0)}',
        name: 'AutoBudgetService',
      );
    } catch (e) {
      developer.log('Auto-budget error: $e', name: 'AutoBudgetService');
    }
  }
}
