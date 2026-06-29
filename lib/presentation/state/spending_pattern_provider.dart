import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/database/database_providers.dart';

class SpendingPattern {
  final String categoryId;
  final String categoryName;
  final int averageAmountCents;
  final int transactionCount;
  final int hourOfDay;

  SpendingPattern({
    required this.categoryId,
    required this.categoryName,
    required this.averageAmountCents,
    required this.transactionCount,
    required this.hourOfDay,
  });
}

final currentSpendingPatternProvider = FutureProvider<SpendingPattern?>((ref) async {
  final db = ref.read(databaseProvider);
  final catDao = ref.read(categoryDaoProvider);

  final now = DateTime.now();
  final currentHour = now.hour;
  final thirtyDaysAgo = now.subtract(const Duration(days: 30));

  final hourMin = (currentHour - 2).clamp(0, 23);
  final hourMax = (currentHour + 2).clamp(0, 23);

  final allTransactions = await (db.select(db.transactions)
    ..where((t) => t.createdAt.isBiggerOrEqual(Constant(thirtyDaysAgo)) & t.createdAt.isSmallerOrEqual(Constant(now))))
    .get();

  final relevant = allTransactions.where((t) {
    final txHour = t.createdAt.hour;
    return txHour >= hourMin && txHour <= hourMax;
  }).toList();

  if (relevant.isEmpty) return null;

  final byCategory = <String, List<int>>{};
  for (final tx in relevant) {
    final catId = tx.categoryId;
    byCategory.putIfAbsent(catId, () => []).add(tx.amount);
  }

  final best = byCategory.entries.reduce((a, b) => a.value.length > b.value.length ? a : b);

  final avg = best.value.fold<int>(0, (s, amount) => s + amount) ~/ best.value.length;
  final catName = (await catDao.getCategoryById(best.key))?.name ?? 'Uncategorized';

  return SpendingPattern(
    categoryId: best.key,
    categoryName: catName,
    averageAmountCents: avg,
    transactionCount: best.value.length,
    hourOfDay: currentHour,
  );
});
