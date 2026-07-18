import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/data/database/database_providers.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';

class SearchResult {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;

  SearchResult({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.route,
  });
}

final globalSearchProvider = FutureProvider.family<List<SearchResult>, String>((
  ref,
  query,
) async {
  if (query.trim().length < 2) return [];

  final db = ref.read(databaseProvider);
  final q = query.toLowerCase();
  final results = <SearchResult>[];

  try {
    final txns =
        await (db.select(db.transactions)
              ..where(
                (t) =>
                    t.description.like('%$q%') |
                    t.sender.like('%$q%') |
                    t.recipient.like('%$q%') |
                    t.reference.like('%$q%'),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
              ..limit(6))
            .get();

    for (final t in txns) {
      final icon = switch (t.type) {
        'income' => PesaFlowIcons.arrowDown,
        'expense' => PesaFlowIcons.arrowUp,
        'transfer' => PesaFlowIcons.transfer,
        _ => PesaFlowIcons.transactions,
      };
      final color = switch (t.type) {
        'income' => AppTheme.incomeColor,
        'expense' => AppTheme.expenseColor,
        _ => AppTheme.transferColor,
      };
      final amount = (t.amount / 100).toStringAsFixed(0);
      results.add(
        SearchResult(
          title: t.description,
          subtitle: 'TZS $amount · ${t.type}',
          icon: icon,
          color: color,
          route: '/transactions/${t.id}',
        ),
      );
    }
  } catch (_) {}

  try {
    final budgets =
        await (db.select(db.budgets)
              ..where((b) => b.name.like('%$q%'))
              ..limit(6))
            .get();

    for (final b in budgets) {
      final amount = (b.amount / 100).toStringAsFixed(0);
      results.add(
        SearchResult(
          title: b.name,
          subtitle: 'Budget · TZS $amount/${b.period}',
          icon: PesaFlowIcons.budgets,
          color: AppTheme.incomeColor,
          route: '/budgets/${b.id}',
        ),
      );
    }
  } catch (_) {}

  try {
    final goals =
        await (db.select(db.savingsGoals)
              ..where((g) => g.name.like('%$q%'))
              ..limit(6))
            .get();

    for (final g in goals) {
      final current = (g.currentAmount / 100).toStringAsFixed(0);
      final target = (g.targetAmount / 100).toStringAsFixed(0);
      final color = Color(int.parse(g.color.replaceFirst('#', '0xFF')));
      results.add(
        SearchResult(
          title: g.name,
          subtitle: 'Goal · TZS $current / TZS $target',
          icon: PesaFlowIcons.goal,
          color: color,
          route: '/savings-goals/${g.id}',
        ),
      );
    }
  } catch (_) {}

  try {
    final loans =
        await (db.select(db.loans)
              ..where(
                (l) => l.description.like('%$q%') | l.provider.like('%$q%'),
              )
              ..limit(6))
            .get();

    for (final l in loans) {
      final amount = (l.amount / 100).toStringAsFixed(0);
      results.add(
        SearchResult(
          title: l.description ?? l.provider ?? 'Loan',
          subtitle: 'Loan · TZS $amount · ${l.status}',
          icon: PesaFlowIcons.creditScore,
          color: l.status == 'paid'
              ? AppTheme.incomeColor
              : AppTheme.transferColor,
          route: '/loans/${l.id}',
        ),
      );
    }
  } catch (_) {}

  return results;
});
