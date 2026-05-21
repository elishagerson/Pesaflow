import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/daos/budget_dao.dart';
import 'package:pesaflow/data/repositories/budget_repository.dart';
import 'package:pesaflow/domain/budget/budget_engine.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class BudgetListScreen extends ConsumerWidget {
  const BudgetListScreen({super.key});

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
    return Colors.grey;
  }

  IconData _getCategoryIcon(String iconName) {
    switch (iconName) {
      case 'cart': return Icons.shopping_cart_rounded;
      case 'bus': return Icons.directions_bus_rounded;
      case 'home': return Icons.home_rounded;
      case 'zap': return Icons.electric_bolt_rounded;
      case 'phone': return Icons.phone_android_rounded;
      case 'heart': return Icons.favorite_rounded;
      case 'book': return Icons.menu_book_rounded;
      case 'film': return Icons.movie_rounded;
      case 'shopping-bag': return Icons.shopping_bag_rounded;
      case 'coffee': return Icons.coffee_rounded;
      case 'send': return Icons.send_rounded;
      case 'credit-card': return Icons.credit_card_rounded;
      case 'banknote': return Icons.payments_rounded;
      case 'piggy-bank': return Icons.savings_rounded;
      case 'briefcase': return Icons.work_rounded;
      case 'store': return Icons.storefront_rounded;
      default: return Icons.category_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budgetProgressAsync = ref.watch(budgetProgressProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budgets'),
      ),
      body: budgetProgressAsync.when(
        data: (budgets) {
          if (budgets.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.pie_chart_outline_rounded,
                        size: 56,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Budgets Yet',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create envelope budgets to track spending limits on categories like Food, Transport, or Entertainment.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 28),
                    ElevatedButton.icon(
                      onPressed: () => context.go('/budgets/add'),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Create First Budget'),
                    ),
                  ],
                ),
              ),
            );
          }

          // Calculate totals
          int totalAllocated = 0;
          int totalSpent = 0;
          for (final bp in budgets) {
            totalAllocated += bp.currentPeriod?.allocated ?? bp.budget.amount;
            totalSpent += bp.spentInPeriod;
          }

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary,
                        theme.colorScheme.primary.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BUDGET OVERVIEW',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Total Spent', style: TextStyle(color: Colors.white60, fontSize: 12)),
                              const SizedBox(height: 2),
                              AmountText(
                                amountInCents: totalSpent,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('Total Allocated', style: TextStyle(color: Colors.white60, fontSize: 12)),
                              const SizedBox(height: 2),
                              AmountText(
                                amountInCents: totalAllocated,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Overall progress bar
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: totalAllocated > 0 ? (totalSpent / totalAllocated).clamp(0.0, 1.0) : 0,
                          backgroundColor: Colors.white24,
                          color: totalSpent > totalAllocated ? Colors.red[300] : Colors.white,
                          minHeight: 8,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        totalAllocated > 0
                            ? '${(totalSpent / totalAllocated * 100).round()}% used'
                            : '0% used',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Active Budgets',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                // Budget cards
                ...budgets.map((bp) {
                  final status = BudgetEngine.computeStatus(
                    allocated: bp.currentPeriod?.allocated ?? bp.budget.amount,
                    spent: bp.spentInPeriod,
                    periodStart: bp.currentPeriod?.periodStart ?? bp.budget.startDate,
                    periodEnd: bp.currentPeriod?.periodEnd ?? DateTime.now().add(const Duration(days: 30)),
                  );

                  final catColor = _hexToColor(bp.category.color);

                  return GestureDetector(
                    onTap: () => context.go('/budgets/${bp.budget.id}'),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? AppTheme.surfaceContainerDark
                            : AppTheme.surfaceLight,
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        border: Border.all(
                          color: theme.brightness == Brightness.dark
                              ? const Color(0x1FFFFFFF)
                              : const Color(0x1F000000),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: catColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  _getCategoryIcon(bp.category.icon),
                                  color: catColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      bp.budget.name,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      bp.category.name,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: status.isOverBudget
                                          ? theme.colorScheme.error.withOpacity(0.1)
                                          : status.isOnTrack
                                              ? AppTheme.incomeColor.withOpacity(0.1)
                                              : Colors.orange.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      status.paceLabel,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: status.isOverBudget
                                            ? theme.colorScheme.error
                                            : status.isOnTrack
                                                ? AppTheme.incomeColor
                                                : Colors.orange,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${status.daysLeft} days left',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          // Amount row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AmountText(
                                amountInCents: bp.spentInPeriod,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: status.isOverBudget ? theme.colorScheme.error : null,
                                ),
                              ),
                              AmountText(
                                amountInCents: status.allocated,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: status.percentage.clamp(0.0, 1.0),
                              backgroundColor: catColor.withOpacity(0.15),
                              color: status.isOverBudget ? theme.colorScheme.error : catColor,
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${(status.percentage * 100).round()}% used',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading budgets: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/budgets/add'),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Budget'),
      ),
    );
  }
}
