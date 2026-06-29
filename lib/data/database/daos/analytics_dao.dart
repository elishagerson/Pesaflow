import 'dart:convert';
import 'package:drift/drift.dart';
import '../app_database.dart';
import '../tables/transactions_table.dart';
import '../tables/categories_table.dart';
import '../tables/daily_snapshots_table.dart';
import '../tables/monthly_snapshots_table.dart';

part 'analytics_dao.g.dart';

/// Category spending data for charts.
class CategorySpending {
  final String categoryId;
  final String categoryName;
  final String categoryColor;
  final String categoryIcon;
  final int amount;

  CategorySpending({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
    required this.amount,
  });
}

@DriftAccessor(
  tables: [Transactions, Categories, DailySnapshots, MonthlySnapshots],
)
class AnalyticsDao extends DatabaseAccessor<AppDatabase>
    with _$AnalyticsDaoMixin {
  AnalyticsDao(super.db);

  /// Computes and upserts a daily snapshot for the given date string (e.g. "2026-05-15").
  Future<void> upsertDailySnapshot(
    String dateStr,
    DateTime dayStart,
    DateTime dayEnd,
  ) async {
    // Sum income (exclude loan disbursements)
    final incomeQuery = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(
        transactions.type.equals('income') &
            transactions.createdAt.isBiggerOrEqual(Constant(dayStart)) &
            transactions.createdAt.isSmallerOrEqual(Constant(dayEnd)),
      );
    final incomeResult = await incomeQuery.getSingle();
    final totalIncome = incomeResult.read(transactions.amount.sum()) ?? 0;

    // Sum expenses (loan repayments ARE expenses, but loan disbursements are not income)
    final expenseQuery = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(
        (transactions.type.equals('expense') |
                transactions.type.equals('airtime') |
                transactions.type.equals('fee')) &
            transactions.createdAt.isBiggerOrEqual(Constant(dayStart)) &
            transactions.createdAt.isSmallerOrEqual(Constant(dayEnd)),
      );
    final expenseResult = await expenseQuery.getSingle();
    final totalExpense = expenseResult.read(transactions.amount.sum()) ?? 0;

    // Category breakdown
    final catQuery =
        select(transactions).join([
          innerJoin(
            categories,
            categories.id.equalsExp(transactions.categoryId),
          ),
        ])..where(
          transactions.createdAt.isBiggerOrEqual(Constant(dayStart)) &
              transactions.createdAt.isSmallerOrEqual(Constant(dayEnd)),
        );
    final catRows = await catQuery.get();

    final Map<String, int> byCat = {};
    for (final row in catRows) {
      final tx = row.readTable(transactions);
      final catId = tx.categoryId;
      byCat[catId] = (byCat[catId] ?? 0) + tx.amount;
    }

    final dow = dayStart.weekday; // 1=Mon, 7=Sun
    final weekend = dow == 6 || dow == 7;

    await into(dailySnapshots).insertOnConflictUpdate(
      DailySnapshot(
        date: dateStr,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        netCashflow: totalIncome - totalExpense,
        byCategory: jsonEncode(byCat),
        dayOfWeek: dow,
        isWeekend: weekend,
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Computes and upserts a monthly snapshot for the given year-month (e.g. "2026-05").
  Future<void> upsertMonthlySnapshot(
    String yearMonth,
    DateTime monthStart,
    DateTime monthEnd,
  ) async {
    // Sum income (exclude loan disbursements)
    final incomeQuery = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(
        transactions.type.equals('income') &
            transactions.createdAt.isBiggerOrEqual(Constant(monthStart)) &
            transactions.createdAt.isSmallerOrEqual(Constant(monthEnd)),
      );
    final incomeResult = await incomeQuery.getSingle();
    final totalIncome = incomeResult.read(transactions.amount.sum()) ?? 0;

    // Sum expenses
    final expenseQuery = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(
        (transactions.type.equals('expense') |
                transactions.type.equals('airtime') |
                transactions.type.equals('fee')) &
            transactions.createdAt.isBiggerOrEqual(Constant(monthStart)) &
            transactions.createdAt.isSmallerOrEqual(Constant(monthEnd)),
      );
    final expenseResult = await expenseQuery.getSingle();
    final totalExpense = expenseResult.read(transactions.amount.sum()) ?? 0;

    // Category breakdown
    final catQuery =
        select(transactions).join([
          innerJoin(
            categories,
            categories.id.equalsExp(transactions.categoryId),
          ),
        ])..where(
          transactions.createdAt.isBiggerOrEqual(Constant(monthStart)) &
              transactions.createdAt.isSmallerOrEqual(Constant(monthEnd)),
        );
    final catRows = await catQuery.get();

    final Map<String, int> byCat = {};
    final Map<String, int> byDay = {};
    final Map<String, int> merchantCount = {};

    for (final row in catRows) {
      final tx = row.readTable(transactions);
      byCat[tx.categoryId] = (byCat[tx.categoryId] ?? 0) + tx.amount;

      final dayKey = tx.createdAt.day.toString();
      byDay[dayKey] = (byDay[dayKey] ?? 0) + tx.amount;

      if (tx.recipient != null && tx.recipient!.isNotEmpty) {
        merchantCount[tx.recipient!] = (merchantCount[tx.recipient!] ?? 0) + 1;
      }
      if (tx.sender != null && tx.sender!.isNotEmpty) {
        merchantCount[tx.sender!] = (merchantCount[tx.sender!] ?? 0) + 1;
      }
    }

    // Top merchants by frequency
    final sortedMerchants = merchantCount.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topMerchants = Map.fromEntries(sortedMerchants.take(5));

    final daysInMonth = monthEnd.difference(monthStart).inDays + 1;
    final avgDaily = daysInMonth > 0 ? totalExpense / daysInMonth : 0.0;

    await into(monthlySnapshots).insertOnConflictUpdate(
      MonthlySnapshot(
        yearMonth: yearMonth,
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        netSavings: totalIncome - totalExpense,
        byCategory: jsonEncode(byCat),
        byDay: jsonEncode(byDay),
        avgDailySpend: avgDaily,
        topMerchants: jsonEncode(topMerchants),
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Fetches daily snapshots for a date range.
  Future<List<DailySnapshot>> getDailySnapshots(
    String startDate,
    String endDate,
  ) {
    return (select(dailySnapshots)
          ..where(
            (d) =>
                d.date.isBiggerOrEqualValue(startDate) &
                d.date.isSmallerOrEqualValue(endDate),
          )
          ..orderBy([(d) => OrderingTerm.asc(d.date)]))
        .get();
  }

  /// Fetches the last N monthly snapshots.
  Future<List<MonthlySnapshot>> getMonthlySnapshots(int count) {
    return (select(monthlySnapshots)
          ..orderBy([(m) => OrderingTerm.desc(m.yearMonth)])
          ..limit(count))
        .get();
  }

  /// Gets top spending categories for a given month, with category metadata.
  Future<List<CategorySpending>> getTopCategoriesForMonth(
    DateTime monthStart,
    DateTime monthEnd,
    int limit,
  ) async {
    final query = selectOnly(transactions)
      ..addColumns([transactions.categoryId, transactions.amount.sum()])
      ..where(
        (transactions.type.equals('expense') |
                transactions.type.equals('airtime') |
                transactions.type.equals('fee')) &
            transactions.createdAt.isBiggerOrEqual(Constant(monthStart)) &
            transactions.createdAt.isSmallerOrEqual(Constant(monthEnd)),
      )
      ..groupBy([transactions.categoryId])
      ..orderBy([OrderingTerm.desc(transactions.amount.sum())])
      ..limit(limit);

    final results = await query.get();

    final List<CategorySpending> spending = [];
    for (final row in results) {
      final catId = row.read(transactions.categoryId);
      if (catId == null) continue;
      final amount = row.read(transactions.amount.sum()) ?? 0;
      final cat = await (select(
        categories,
      )..where((c) => c.id.equals(catId))).getSingleOrNull();
      if (cat != null) {
        spending.add(
          CategorySpending(
            categoryId: catId,
            categoryName: cat.name,
            categoryColor: cat.color,
            categoryIcon: cat.icon,
            amount: amount,
          ),
        );
      }
    }
    return spending;
  }

  /// Gets total income and expense for a specific month range.
  Future<Map<String, int>> getMonthTotals(
    DateTime monthStart,
    DateTime monthEnd,
  ) async {
    final incomeQuery = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(
        transactions.type.equals('income') &
            transactions.createdAt.isBiggerOrEqual(Constant(monthStart)) &
            transactions.createdAt.isSmallerOrEqual(Constant(monthEnd)),
      );
    final incomeResult = await incomeQuery.getSingle();
    final totalIncome = incomeResult.read(transactions.amount.sum()) ?? 0;

    final expenseQuery = selectOnly(transactions)
      ..addColumns([transactions.amount.sum()])
      ..where(
        (transactions.type.equals('expense') |
                transactions.type.equals('airtime') |
                transactions.type.equals('fee')) &
            transactions.createdAt.isBiggerOrEqual(Constant(monthStart)) &
            transactions.createdAt.isSmallerOrEqual(Constant(monthEnd)),
      );
    final expenseResult = await expenseQuery.getSingle();
    final totalExpense = expenseResult.read(transactions.amount.sum()) ?? 0;

    return {'income': totalIncome, 'expense': totalExpense};
  }
}
