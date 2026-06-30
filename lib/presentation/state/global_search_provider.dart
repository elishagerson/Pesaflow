import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';
import 'package:pesaflow/data/database/database_providers.dart';

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

final globalSearchProvider =
    FutureProvider.family<List<SearchResult>, String>((ref, query) async {
  if (query.trim().length < 2) return [];

  final db = ref.read(databaseProvider);
  final q = query.toLowerCase();
  final results = <SearchResult>[];

  try {
    final txns = await (db.select(db.transactions)
          ..where((t) =>
              t.description.like('%$q%') |
              t.sender.like('%$q%') |
              t.recipient.like('%$q%') |
              t.reference.like('%$q%'))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
          ..limit(6))
        .get();

    for (final t in txns) {
      final icon = switch (t.type) {
        'income' => Icons.arrow_downward_rounded,
        'expense' => Icons.arrow_upward_rounded,
        'transfer' => Icons.swap_horiz_rounded,
        _ => Icons.receipt_rounded,
      };
      final color = switch (t.type) {
        'income' => const Color(0xFF4CAF50),
        'expense' => const Color(0xFFF44336),
        _ => const Color(0xFF2196F3),
      };
      final amount = (t.amount / 100).toStringAsFixed(0);
      results.add(SearchResult(
        title: t.description,
        subtitle: 'TZS $amount · ${t.type}',
        icon: icon,
        color: color,
        route: '/transactions/${t.id}',
      ));
    }
  } catch (_) {}

  try {
    final budgets = await (db.select(db.budgets)
          ..where((b) => b.name.like('%$q%'))
          ..limit(6))
        .get();

    for (final b in budgets) {
      final amount = (b.amount / 100).toStringAsFixed(0);
      results.add(SearchResult(
        title: b.name,
        subtitle: 'Budget · TZS $amount/${b.period}',
        icon: Icons.pie_chart_rounded,
        color: const Color(0xFF4CAF50),
        route: '/budgets/${b.id}',
      ));
    }
  } catch (_) {}

  try {
    final goals = await (db.select(db.savingsGoals)
          ..where((g) => g.name.like('%$q%'))
          ..limit(6))
        .get();

    for (final g in goals) {
      final current = (g.currentAmount / 100).toStringAsFixed(0);
      final target = (g.targetAmount / 100).toStringAsFixed(0);
      final color = Color(int.parse(g.color.replaceFirst('#', '0xFF')));
      results.add(SearchResult(
        title: g.name,
        subtitle: 'Goal · TZS $current / TZS $target',
        icon: Icons.flag_rounded,
        color: color,
        route: '/savings-goals/${g.id}',
      ));
    }
  } catch (_) {}

  try {
    final loans = await (db.select(db.loans)
          ..where(
            (l) =>
                l.description.like('%$q%') | l.provider.like('%$q%'),
          )
          ..limit(6))
        .get();

    for (final l in loans) {
      final amount = (l.amount / 100).toStringAsFixed(0);
      results.add(SearchResult(
        title: l.description ?? l.provider ?? 'Loan',
        subtitle: 'Loan · TZS $amount · ${l.status}',
        icon: Icons.credit_score_rounded,
        color: l.status == 'paid'
            ? const Color(0xFF4CAF50)
            : const Color(0xFFFF9800),
        route: '/loans/${l.id}',
      ));
    }
  } catch (_) {}

  return results;
});
