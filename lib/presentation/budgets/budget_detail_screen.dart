import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/budget_dao.dart';
import 'package:pesaflow/data/repositories/budget_repository.dart';
import 'package:pesaflow/domain/budget/budget_engine.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

/// Provider for loading a specific budget's full data.
final budgetDetailProvider = FutureProvider.family<BudgetWithProgress?, String>((ref, budgetId) async {
  final repo = ref.watch(budgetRepositoryProvider);
  final budget = await repo.getBudgetById(budgetId);
  if (budget == null) return null;
  final allProgress = await repo.getActiveBudgetsWithProgress();
  return allProgress.where((b) => b.budget.id == budgetId).firstOrNull;
});

final budgetPeriodsProvider = FutureProvider.family<List<BudgetPeriod>, String>((ref, budgetId) {
  final repo = ref.watch(budgetRepositoryProvider);
  return repo.getPeriodsForBudget(budgetId);
});

class BudgetDetailScreen extends ConsumerWidget {
  final String budgetId;
  const BudgetDetailScreen({required this.budgetId, super.key});

  Color _hexToColor(String hex) {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) return Color(int.parse('FF$clean', radix: 16));
    return Colors.grey;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(budgetDetailProvider(budgetId));
    final periodsAsync = ref.watch(budgetPeriodsProvider(budgetId));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Budget Details'),
        actions: [
          IconButton(icon: const Icon(Icons.edit_rounded), onPressed: () => context.go('/budgets/$budgetId/edit')),
          IconButton(
            icon: const Icon(Icons.delete_rounded),
            onPressed: () async {
              final confirm = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
                title: const Text('Delete Budget?'),
                content: const Text('This will permanently remove this budget and all its history.'),
                actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red)))],
              ));
              if (confirm == true) {
                await ref.read(budgetRepositoryProvider).deleteBudget(budgetId);
                ref.invalidate(budgetProgressProvider);
                if (context.mounted) context.pop();
              }
            },
          ),
        ],
      ),
      body: detailAsync.when(
        data: (bp) {
          if (bp == null) return const Center(child: Text('Budget not found'));
          final status = BudgetEngine.computeStatus(
            allocated: bp.currentPeriod?.allocated ?? bp.budget.amount,
            spent: bp.spentInPeriod,
            periodStart: bp.currentPeriod?.periodStart ?? bp.budget.startDate,
            periodEnd: bp.currentPeriod?.periodEnd ?? DateTime.now().add(const Duration(days: 30)),
          );
          final catColor = _hexToColor(bp.category.color);

          return SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Radial ring chart
                Center(
                  child: SizedBox(
                    height: 200, width: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(PieChartData(
                          startDegreeOffset: -90,
                          sectionsSpace: 0,
                          centerSpaceRadius: 70,
                          sections: [
                            PieChartSectionData(value: status.percentage.clamp(0.0, 1.0) * 100, color: status.isOverBudget ? theme.colorScheme.error : catColor, radius: 20, showTitle: false),
                            PieChartSectionData(value: (1.0 - status.percentage.clamp(0.0, 1.0)) * 100, color: catColor.withOpacity(0.15), radius: 20, showTitle: false),
                          ],
                        )),
                        Column(mainAxisSize: MainAxisSize.min, children: [
                          Text('${(status.percentage * 100).round()}%', style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                          Text('used', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                        ]),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Stats row
                Row(children: [
                  Expanded(child: _StatCard(label: 'Spent', amount: bp.spentInPeriod, color: status.isOverBudget ? theme.colorScheme.error : catColor, theme: theme)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(label: 'Remaining', amount: status.remaining, color: status.remaining >= 0 ? AppTheme.incomeColor : theme.colorScheme.error, theme: theme)),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(label: 'Allocated', amount: status.allocated, color: theme.colorScheme.primary, theme: theme)),
                ]),
                const SizedBox(height: 20),

                // Pace card
                Container(
                  width: double.infinity, padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: theme.brightness == Brightness.dark ? AppTheme.surfaceContainerDark : AppTheme.surfaceLight, borderRadius: BorderRadius.circular(AppTheme.radiusCard), border: Border.all(color: theme.brightness == Brightness.dark ? const Color(0x1FFFFFFF) : const Color(0x1F000000))),
                  child: Row(children: [
                    Icon(status.isOnTrack ? Icons.check_circle_rounded : Icons.warning_rounded, color: status.isOnTrack ? AppTheme.incomeColor : Colors.orange, size: 28),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(status.paceLabel, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                      Text('${status.daysLeft} days remaining in this period', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 24),

                // Period info
                Text('Period: ${bp.budget.period}', style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                Text('Rollover: ${bp.budget.rollover ? bp.budget.rolloverType : "disabled"}', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 20),

                // Historical Periods
                Text('Period History', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                periodsAsync.when(
                  data: (periods) => Column(children: periods.map((p) {
                    final pctUsed = p.allocated > 0 ? (p.spent / p.allocated * 100).round() : 0;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: theme.brightness == Brightness.dark ? AppTheme.surfaceContainerDark : AppTheme.surfaceLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: theme.brightness == Brightness.dark ? const Color(0x1FFFFFFF) : const Color(0x1F000000))),
                      child: Row(children: [
                        Icon(p.isClosed ? Icons.lock_rounded : Icons.lock_open_rounded, size: 16, color: Colors.grey),
                        const SizedBox(width: 8),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('${p.periodStart.day}/${p.periodStart.month} — ${p.periodEnd.day}/${p.periodEnd.month}/${p.periodEnd.year}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('$pctUsed% used${p.rolledFrom != null && p.rolledFrom != 0 ? " • Rolled: Tsh ${p.rolledFrom! ~/ 100}" : ""}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ])),
                        AmountText(amountInCents: p.spent, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ]),
                    );
                  }).toList()),
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Text('Error: $e'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int amount;
  final Color color;
  final ThemeData theme;
  const _StatCard({required this.label, required this.amount, required this.color, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: theme.brightness == Brightness.dark ? AppTheme.surfaceContainerDark : AppTheme.surfaceLight, borderRadius: BorderRadius.circular(AppTheme.radiusCard), border: Border.all(color: theme.brightness == Brightness.dark ? const Color(0x1FFFFFFF) : const Color(0x1F000000))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        AmountText(amountInCents: amount.abs(), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ]),
    );
  }
}
