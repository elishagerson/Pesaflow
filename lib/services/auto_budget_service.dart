import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database/app_database.dart';
import '../data/database/daos/budget_dao.dart';
import '../data/database/daos/category_dao.dart';
import '../data/database/database_providers.dart';
import '../data/repositories/budget_repository.dart';
import '../data/repositories/settings_repository.dart';

/// Provider for the auto-budget service.
final autoBudgetServiceProvider = Provider<AutoBudgetService>((ref) {
  final budgetRepo = ref.watch(budgetRepositoryProvider);
  final budgetDao = ref.watch(budgetDaoProvider);
  final categoryDao = ref.watch(categoryDaoProvider);
  final settingsRepo = ref.watch(settingsRepositoryProvider);
  return AutoBudgetService(budgetRepo, budgetDao, categoryDao, settingsRepo);
});

/// Configuration for a single budget group in the auto-budget split.
class BudgetGroupConfig {
  final String name;
  final double percentage;
  final List<String> categoryIds;

  const BudgetGroupConfig({
    required this.name,
    required this.percentage,
    required this.categoryIds,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'percentage': percentage,
    'categoryIds': categoryIds,
  };

  factory BudgetGroupConfig.fromJson(Map<String, dynamic> json) =>
    BudgetGroupConfig(
      name: json['name'] as String,
      percentage: (json['percentage'] as num).toDouble(),
      categoryIds: (json['categoryIds'] as List).cast<String>(),
    );
}

/// The auto-budget split configuration.
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

  /// Default 50/30/20 configuration with placeholder category IDs.
  /// The actual category IDs are resolved at runtime.
  static AutoBudgetConfig defaults() => const AutoBudgetConfig(
    enabled: false,
    incomeCategoryIds: [], // Resolved at runtime to Salary + Business
    period: 'monthly',
    groups: [
      BudgetGroupConfig(
        name: 'Needs',
        percentage: 0.50,
        categoryIds: [], // Resolved at runtime
      ),
      BudgetGroupConfig(
        name: 'Wants',
        percentage: 0.30,
        categoryIds: [], // Resolved at runtime
      ),
      BudgetGroupConfig(
        name: 'Savings & Debt',
        percentage: 0.20,
        categoryIds: [], // Resolved at runtime
      ),
    ],
  );
}

/// Service that manages automatic budget creation when income is logged.
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

  /// Loads the auto-budget configuration from settings.
  Future<AutoBudgetConfig> getConfig() async {
    final json = await _settingsRepo.getSetting(_configKey);
    if (json == null) return AutoBudgetConfig.defaults();
    try {
      return AutoBudgetConfig.fromJson(jsonDecode(json));
    } catch (e) {
      return AutoBudgetConfig.defaults();
    }
  }

  /// Saves the auto-budget configuration to settings.
  Future<void> saveConfig(AutoBudgetConfig config) async {
    await _settingsRepo.setSetting(_configKey, jsonEncode(config.toJson()));
  }

  /// Resolves the default income category IDs (Salary + Business) if none configured.
  Future<List<String>> _resolveIncomeCategoryIds(
    List<String> configuredIds,
  ) async {
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

  /// Resolves the default category group IDs based on category names.
  /// Maps existing categories to Needs/Wants/Savings groups.
  Future<Map<String, List<String>>> _resolveGroupCategoryIds() async {
    final categories = await _categoryDao.getAllCategories();
    final needs = <String>[];
    final wants = <String>[];
    final savings = <String>[];

    for (final cat in categories) {
      if (cat.type != 'expense') continue;
      final name = cat.name.toLowerCase();
      // Needs: essential living expenses
      if (name == 'food & groceries' ||
          name == 'rent' ||
          name == 'utilities' ||
          name == 'transport' ||
          name == 'health' ||
          name == 'airtime & data' ||
          name == 'education') {
        needs.add(cat.id);
      }
      // Wants: discretionary spending
      else if (name == 'entertainment' ||
          name == 'shopping' ||
          name == 'eating out') {
        wants.add(cat.id);
      }
      // Savings & Debt: financial obligations
      else if (name == 'savings' ||
          name == 'loans' ||
          name == 'bank fees' ||
          name == 'atm withdrawal' ||
          name == 'mobile money transfer') {
        savings.add(cat.id);
      }
    }

    return {'needs': needs, 'wants': wants, 'savings': savings};
  }

  /// Checks if auto-budget should run for this transaction, and if so,
  /// creates or updates the budgets for the current period.
  ///
  /// Call this after every income transaction is saved.
  Future<void> checkAndCreateAutoBudgets(Transaction transaction) async {
    try {
      final config = await getConfig();
      if (!config.enabled) return;

      // Only auto-budget for income transactions
      if (transaction.type.toLowerCase() != 'income') return;

      final incomeCategoryIds = await _resolveIncomeCategoryIds(
        config.incomeCategoryIds,
      );
      if (incomeCategoryIds.isEmpty) return;

      // Check if this income category is in the configured list
      if (!incomeCategoryIds.contains(transaction.categoryId)) return;

      final groupCategoryIds = await _resolveGroupCategoryIds();
      final amountCents = transaction.amount;
      final now = transaction.createdAt;
      final startDate = DateTime(now.year, now.month, 1);

      // Resolve group category IDs from config or defaults
      final resolvedGroups = <BudgetGroupConfig>[];
      for (final group in config.groups) {
        List<String> catIds;
        if (group.categoryIds.isNotEmpty) {
          catIds = group.categoryIds;
        } else {
          // Resolve from defaults based on group name
          final name = group.name.toLowerCase();
          if (name.contains('need')) {
            catIds = groupCategoryIds['needs'] ?? [];
          } else if (name.contains('want')) {
            catIds = groupCategoryIds['wants'] ?? [];
          } else if (name.contains('saving') || name.contains('debt')) {
            catIds = groupCategoryIds['savings'] ?? [];
          } else {
            catIds = [];
          }
        }
        resolvedGroups.add(BudgetGroupConfig(
          name: group.name,
          percentage: group.percentage,
          categoryIds: catIds,
        ));
      }

      // Create or update budgets for each group
      for (final group in resolvedGroups) {
        if (group.categoryIds.isEmpty) continue;

        final groupAmount = (amountCents * group.percentage).round();
        if (groupAmount <= 0) continue;

        // Use the first category in the group as the budget's categoryId
        // (the spending calculation already handles sub-categories)
        final primaryCategoryId = group.categoryIds.first;

        // Find existing budget for this category in the current period
        final existingBudgets = await _budgetDao.getAllActiveBudgets();
        Budget? existingBudget;
        for (final b in existingBudgets) {
          if (b.categoryId == primaryCategoryId) {
            final period = await _budgetDao.getCurrentPeriod(b.id);
            if (period != null &&
                period.periodStart.isBefore(startDate.add(const Duration(days: 1))) &&
                period.periodEnd.isAfter(startDate.subtract(const Duration(days: 1)))) {
              existingBudget = b;
              break;
            }
          }
        }

        if (existingBudget != null) {
          // Update existing budget's allocated amount
          final period = await _budgetDao.getCurrentPeriod(existingBudget.id);
          if (period != null) {
            await _budgetDao.updateBudget(
              existingBudget.copyWith(amount: groupAmount),
            );
            await _budgetDao.updateCurrentPeriodAllocated(
              existingBudget.id,
              groupAmount,
            );
          }
        } else {
          // Create new budget with first period
          await _budgetRepo.createBudget(
            name: '${group.name} (${(group.percentage * 100).round()}%)',
            categoryId: primaryCategoryId,
            period: config.period,
            amount: groupAmount,
            rollover: true,
            rolloverType: 'all',
            startDate: startDate,
            notificationThreshold: 0.8,
          );
        }
      }

      developer.log(
        'Auto-budget created for income ${transaction.amount} cents',
        name: 'AutoBudgetService',
      );
    } catch (e) {
      developer.log(
        'Auto-budget error: $e',
        name: 'AutoBudgetService',
      );
    }
  }
}
