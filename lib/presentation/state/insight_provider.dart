import 'package:flutter/material.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/data/database/database_providers.dart';

class InsightData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const InsightData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });
}

final dynamicInsightsProvider = FutureProvider<List<InsightData>>((ref) async {
  final transactionDao = ref.watch(transactionDaoProvider);
  final now = DateTime.now();
  final startOfMonth = DateTime(now.year, now.month, 1);
  final startOfLastMonth = DateTime(now.year, now.month - 1, 1);

  final thisMonthTxns = await transactionDao
      .watchFilteredTransactions(startDate: startOfMonth, endDate: now)
      .first;

  final lastMonthTxns = await transactionDao
      .watchFilteredTransactions(
        startDate: startOfLastMonth,
        endDate: startOfMonth,
      )
      .first;

  if (thisMonthTxns.isEmpty && lastMonthTxns.isEmpty) {
    return [];
  }

  final thisExpenses = thisMonthTxns
      .where((r) => r.transaction.type == 'expense')
      .toList();
  final lastExpenses = lastMonthTxns
      .where((r) => r.transaction.type == 'expense')
      .toList();

  final insights = <InsightData>[];

  // 1. Top merchant — most frequently visited this month by description
  final merchantCounts = <String, int>{};
  for (final row in thisExpenses) {
    final desc = row.transaction.description.trim();
    if (desc.isNotEmpty) {
      merchantCounts[desc] = (merchantCounts[desc] ?? 0) + 1;
    }
  }
  if (merchantCounts.isNotEmpty) {
    final top = merchantCounts.entries.reduce(
      (a, b) => a.value > b.value ? a : b,
    );
    insights.add(
      InsightData(
        title: top.key,
        subtitle: 'Visited ${top.value} times this month',
        icon: PesaFlowIcons.transactions,
        color: const Color(0xFF0F4C5C),
      ),
    );
  }

  // 2. Category spending change vs last month
  final catThis = <String, int>{};
  for (final row in thisExpenses) {
    catThis[row.category.name] =
        (catThis[row.category.name] ?? 0) + row.transaction.amount;
  }
  final catLast = <String, int>{};
  for (final row in lastExpenses) {
    catLast[row.category.name] =
        (catLast[row.category.name] ?? 0) + row.transaction.amount;
  }

  String? topChangeCat;
  int maxChange = 0;
  for (final entry in catThis.entries) {
    final prev = catLast[entry.key] ?? 0;
    final change = (entry.value - prev).abs();
    if (change > maxChange) {
      maxChange = change;
      topChangeCat = entry.key;
    }
  }
  if (topChangeCat != null && (catLast[topChangeCat] ?? 0) > 0) {
    final prev = catLast[topChangeCat]!;
    final curr = catThis[topChangeCat]!;
    final pct = ((curr - prev) / prev * 100).round();
    if (pct != 0) {
      insights.add(
        InsightData(
          title: topChangeCat,
          subtitle: pct > 0
              ? '$pct% higher than last month'
              : '${pct.abs()}% lower than last month',
          icon: curr > prev ? PesaFlowIcons.income : PesaFlowIcons.expense,
          color: curr > prev
              ? const Color(0xFFEF4444)
              : const Color(0xFF10B981),
        ),
      );
    }
  }

  // 3. Total spending vs last month
  final thisTotal = thisExpenses.fold<int>(
    0,
    (s, t) => s + t.transaction.amount,
  );
  final lastTotal = lastExpenses.fold<int>(
    0,
    (s, t) => s + t.transaction.amount,
  );
  if (lastTotal > 0) {
    final pct = ((thisTotal - lastTotal) / lastTotal * 100).round();
    if (pct.abs() >= 5) {
      insights.add(
        InsightData(
          title: 'Spending ${pct > 0 ? 'up' : 'down'} ${pct.abs()}%',
          subtitle:
              '${CurrencyFormatter.formatCents(lastTotal)} \u2192 ${CurrencyFormatter.formatCents(thisTotal)}',
          icon: pct > 0 ? PesaFlowIcons.income : PesaFlowIcons.expense,
          color: pct > 0 ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        ),
      );
    }
  } else if (thisTotal > 0) {
    insights.add(
      InsightData(
        title: CurrencyFormatter.formatCents(thisTotal),
        subtitle: 'Total spending this month',
        icon: PesaFlowIcons.expense,
        color: const Color(0xFF0F4C5C),
      ),
    );
  }

  // 4. Daily average spending
  final daysPassed = now.difference(startOfMonth).inDays + 1;
  if (daysPassed > 0 && thisExpenses.isNotEmpty) {
    final daily = thisTotal ~/ daysPassed;
    insights.add(
      InsightData(
        title: '${CurrencyFormatter.formatCents(daily)} / day',
        subtitle: 'Average daily spending this month',
        icon: PesaFlowIcons.calendar,
        color: const Color(0xFF6366F1),
      ),
    );
  }

  // 5. Top category this month
  if (catThis.isNotEmpty) {
    final top = catThis.entries.reduce((a, b) => a.value > b.value ? a : b);
    final pct = thisTotal > 0 ? (top.value * 100 ~/ thisTotal) : 0;
    insights.add(
      InsightData(
        title: top.key,
        subtitle:
            '${CurrencyFormatter.formatCents(top.value)} \u2014 $pct% of spending',
        icon: PesaFlowIcons.target,
        color: const Color(0xFF0F4C5C),
      ),
    );
  }

  return insights.take(5).toList();
});
