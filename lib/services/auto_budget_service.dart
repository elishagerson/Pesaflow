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

/// Distributes [total] across [percentages] using largest-remainder method
/// so rounding errors never lose or over-allocate money.
List<int> distributeAmount(int total, List<double> percentages) {
  if (percentages.isEmpty) return [];
  final n = percentages.length;
  final raw = <int>[];
  final remainders = <int>[];
  var sum = 0;

  for (var i = 0; i < n; i++) {
    final exact = total * percentages[i];
    final floored = exact.floor();
    raw.add(floored);
    remainders.add(i);
    sum += floored;
  }

  var remainder = total - sum;
  remainders.sort((a, b) {
    final ra = total * percentages[a] - raw[a];
    final rb = total * percentages[b] - raw[b];
    return rb.compareTo(ra);
  });

  var idx = 0;
  while (remainder > 0 && idx < n) {
    raw[remainders[idx]]++;
    remainder--;
    idx++;
  }

  return raw;
}

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

  bool get isValid {
    if (subAllocations.isEmpty) return false;
    final diff = (totalSubPercentage - 1.0).abs();
    return diff < 0.001;
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'percentage': percentage,
    'subAllocations': subAllocations.map((s) => s.toJson()).toList(),
  };

  factory BudgetGroupConfig.fromJson(Map<String, dynamic> json) =>
      BudgetGroupConfig(
        name: json['name'] as String,
        percentage: (json['percentage'] as num).toDouble(),
        subAllocations:
            (json['subAllocations'] as List?)
                ?.map((s) => SubAllocation.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
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

  double get totalGroupPercentage =>
      groups.fold(0, (sum, g) => sum + g.percentage);

  bool get isValid {
    if (groups.isEmpty) return false;
    final groupDiff = (totalGroupPercentage - 1.0).abs();
    if (groupDiff >= 0.001) return false;
    return groups.every((g) => g.isValid);
  }

  List<String> get validationErrors {
    final errors = <String>[];
    if (groups.isEmpty) {
      errors.add('No budget groups defined');
      return errors;
    }
    final groupDiff = (totalGroupPercentage - 1.0).abs();
    if (groupDiff >= 0.001) {
      errors.add(
        'Group percentages sum to ${(totalGroupPercentage * 100).toStringAsFixed(1)}%, expected 100%',
      );
    }
    for (final g in groups) {
      if (g.subAllocations.isEmpty) {
        errors.add('${g.name} has no sub-allocations');
      }
      final subDiff = (g.totalSubPercentage - 1.0).abs();
      if (subDiff >= 0.001) {
        errors.add(
          '${g.name} sub-allocations sum to ${(g.totalSubPercentage * 100).toStringAsFixed(1)}%, expected 100%',
        );
      }
    }
    return errors;
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'incomeCategoryIds': incomeCategoryIds,
    'groups': groups.map((g) => g.toJson()).toList(),
    'period': period,
  };

  factory AutoBudgetConfig.fromJson(Map<String, dynamic> json) {
    bool enabled = false;
    try {
      enabled = json['enabled'] as bool? ?? false;
    } catch (_) {}
    List<String> incomeCategoryIds = [];
    try {
      incomeCategoryIds =
          (json['incomeCategoryIds'] as List?)?.cast<String>() ?? [];
    } catch (_) {}
    List<BudgetGroupConfig> groups = [];
    try {
      groups =
          (json['groups'] as List?)
              ?.map(
                (g) => BudgetGroupConfig.fromJson(g as Map<String, dynamic>),
              )
              .toList() ??
          [];
    } catch (_) {}
    String period = 'monthly';
    try {
      period = json['period'] as String? ?? 'monthly';
    } catch (_) {}
    return AutoBudgetConfig(
      enabled: enabled,
      incomeCategoryIds: incomeCategoryIds,
      groups: groups,
      period: period,
    );
  }

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
        BudgetGroupConfig(
          name: 'Mahitaji Muhimu',
          percentage: 0.50,
          subAllocations: needs,
        ),
        BudgetGroupConfig(
          name: 'Matumizi Binafsi',
          percentage: 0.30,
          subAllocations: wants,
        ),
        BudgetGroupConfig(
          name: 'Akiba & Uwekezaji',
          percentage: 0.20,
          subAllocations: savings,
        ),
      ],
    );
  }
}

/// Pre-fetched period data keyed by budget ID.
class _PeriodInfo {
  final String budgetId;
  final String categoryId;
  final String? currentPeriodId;

  const _PeriodInfo({
    required this.budgetId,
    required this.categoryId,
    this.currentPeriodId,
  });
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
      final config = AutoBudgetConfig.fromJson(jsonDecode(json));
      if (!config.isValid) {
        developer.log(
          'Auto-budget config invalid, using defaults: ${config.validationErrors}',
          name: 'AutoBudgetService',
        );
        return AutoBudgetConfig.defaults();
      }
      return config;
    } catch (e) {
      return AutoBudgetConfig.defaults();
    }
  }

  Future<void> saveConfig(AutoBudgetConfig config) async {
    if (!config.isValid) {
      throw ArgumentError('Invalid config: ${config.validationErrors}');
    }
    await _settingsRepo.setSetting(_configKey, jsonEncode(config.toJson()));
  }

  Future<List<String>> _resolveIncomeCategoryIds(
    List<String> configuredIds,
  ) async {
    if (configuredIds.isNotEmpty) return configuredIds;
    final categories = await _categoryDao.getAllCategories();
    return categories
        .where(
          (c) =>
              c.type == 'income' &&
              (c.name.toLowerCase() == 'salary' ||
                  c.name.toLowerCase() == 'business'),
        )
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

  List<SubAllocation> _resolveSubAllocations(
    List<SubAllocation> configured,
    Map<String, String> nameToId,
  ) {
    return configured.map((sub) {
      if (sub.categoryId != null) return sub;
      final id = nameToId[sub.name.toLowerCase()];
      return sub.copyWith(categoryId: id);
    }).toList();
  }

  /// Pre-fetches period data for all active budgets in a single query,
  /// returning a map of categoryId → _PeriodInfo.
  Future<Map<String, _PeriodInfo>> _buildPeriodMap(
    List<Budget> budgets,
    DateTime monthStart,
  ) async {
    final map = <String, _PeriodInfo>{};
    for (final b in budgets) {
      final period = await _budgetDao.getCurrentPeriod(b.id);
      final coversMonth =
          period != null &&
          period.periodStart.isBefore(
            monthStart.add(const Duration(days: 1)),
          ) &&
          period.periodEnd.isAfter(
            monthStart.subtract(const Duration(days: 1)),
          );
      map[b.categoryId] = _PeriodInfo(
        budgetId: b.id,
        categoryId: b.categoryId,
        currentPeriodId: coversMonth ? period.id : null,
      );
    }
    return map;
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
      final periodMap = await _buildPeriodMap(existingBudgets, startDate);

      for (final group in config.groups) {
        final groupPercentages = group.subAllocations
            .map((s) => s.percentage)
            .toList();
        final resolvedSubs = _resolveSubAllocations(
          group.subAllocations,
          nameToId,
        );
        final groupAmount = (amountCents * group.percentage).round();
        if (groupAmount <= 0) continue;

        final subAmounts = distributeAmount(groupAmount, groupPercentages);

        for (var i = 0; i < resolvedSubs.length; i++) {
          final sub = resolvedSubs[i];
          if (sub.categoryId == null) continue;
          final subAmount = subAmounts[i];
          if (subAmount <= 0) continue;

          final info = periodMap[sub.categoryId];
          final existingPeriodId = info?.currentPeriodId;

          if (existingPeriodId != null) {
            final budget = existingBudgets.firstWhere(
              (b) => b.id == info!.budgetId,
            );
            await _budgetDao.updateBudget(budget.copyWith(amount: subAmount));
            await _budgetDao.updateCurrentPeriodAllocated(budget.id, subAmount);
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
