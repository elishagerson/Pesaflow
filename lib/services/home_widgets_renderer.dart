import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pesaflow/core/theme/app_colors_theme.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/presentation/state/spending_heatmap_provider.dart';
import 'package:pesaflow/data/database/app_database.dart' as db;
import 'package:pesaflow/data/database/daos/transaction_dao.dart';

class HomeWidgetsRenderer {
  static final GlobalKey heatmapKey = GlobalKey();
  static final GlobalKey safeToSpendKey = GlobalKey();
  static final GlobalKey quickTemplatesKey = GlobalKey();
  static final GlobalKey recentTransactionsKey = GlobalKey();

  /// Captures the widget referenced by [key] and sends it to the Android widget named [widgetName].
  static Future<void> captureAndUpdate({
    required GlobalKey key,
    required String imageKey,
    required String widgetName,
  }) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Use a high pixel ratio of 3.0 so the widgets remain crisp when resized
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        final tempDir = await getTemporaryDirectory();
        final file = File('${tempDir.path}/$imageKey.png');
        await file.writeAsBytes(pngBytes);

        // Update home_widget preferences
        await HomeWidget.saveWidgetData<String>(imageKey, file.path);
        await HomeWidget.updateWidget(
          name: widgetName,
          androidName: widgetName,
        );
      }
    } catch (_) {
      // Gracefully handle any capture exceptions (e.g. frame not fully laid out yet)
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 1. SPENDING HEATMAP WIDGET (4x2 layout size: 340 x 180)
// ─────────────────────────────────────────────────────────────────────────────
class WidgetHeatmap extends StatelessWidget {
  final HeatmapData data;
  final ThemeData theme;

  const WidgetHeatmap({super.key, required this.data, required this.theme});

  Color _getCellColor(int amount, int maxExpense, AppColorsTheme appColors) {
    if (amount == 0) {
      return appColors.surfaceLow;
    }
    if (maxExpense <= 0) {
      return appColors.expenseColor.withValues(alpha: 0.15);
    }
    final ratio = amount / maxExpense;
    if (ratio <= 0.25) {
      return appColors.expenseColor.withValues(alpha: 0.25);
    } else if (ratio <= 0.50) {
      return appColors.expenseColor.withValues(alpha: 0.50);
    } else if (ratio <= 0.75) {
      return appColors.expenseColor.withValues(alpha: 0.75);
    } else {
      return appColors.expenseColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    final appColors = theme.extension<AppColorsTheme>()!;
    final totalStr = NumberFormat.simpleCurrency(name: 'TZS ', decimalDigits: 0).format(data.totalExpenditure);

    // Calculate grid start date (aligning Sundays)
    final startDayOfWeek = data.startDate.weekday;
    final daysToSubtract = startDayOfWeek == 7 ? 0 : startDayOfWeek;
    final gridStartDate = data.startDate.subtract(Duration(days: daysToSubtract));

    final weeks = <List<DateTime>>[];
    for (int w = 0; w < 20; w++) {
      final weekDays = <DateTime>[];
      for (int d = 0; d < 7; d++) {
        weekDays.add(gridStartDate.add(Duration(days: w * 7 + d)));
      }
      weeks.add(weekDays);
    }

    return Theme(
      data: theme,
      child: Container(
        width: 340,
        height: 180,
        padding: const EdgeInsets.all(kSpacing16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SPENDING ACTIVITY',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ),
                Text(
                  totalStr,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: appColors.expenseColor,
                  ),
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              height: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: weeks.map((week) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: week.map((day) {
                      final dayKey = DateFormat('yyyy-MM-dd').format(day);
                      final snapshot = data.snapshots[dayKey];
                      final amount = snapshot?.totalExpense ?? 0;
                      final cellColor = _getCellColor(amount, data.maxExpense, appColors);

                      return Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: cellColor,
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      );
                    }).toList(),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2. SAFE TO SPEND WIDGET (2x2 layout size: 180 x 180)
// ─────────────────────────────────────────────────────────────────────────────
class WidgetSafeToSpend extends StatelessWidget {
  final int remainingCents;
  final int limitCents;
  final double percentage; // spent percentage (0.0 to 1.0)
  final ThemeData theme;

  const WidgetSafeToSpend({
    super.key,
    required this.remainingCents,
    required this.limitCents,
    required this.percentage,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final appColors = theme.extension<AppColorsTheme>()!;
    final remainingStr = NumberFormat.simpleCurrency(name: 'Tsh ', decimalDigits: 0).format(remainingCents / 100);
    final limitStr = NumberFormat.simpleCurrency(name: 'Limit: Tsh ', decimalDigits: 0).format(limitCents / 100);

    return Theme(
      data: theme,
      child: Container(
        width: 180,
        height: 180,
        padding: const EdgeInsets.all(kSpacing16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SAFE-TO-SPEND',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const SizedBox(height: kSpacing12),
            Text(
              remainingStr,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(100),
              child: LinearProgressIndicator(
                value: percentage.clamp(0.0, 1.0),
                minHeight: 8,
                backgroundColor: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(
                  percentage >= 1.0
                      ? appColors.expenseColor
                      : theme.colorScheme.primary,
                ),
              ),
            ),
            const SizedBox(height: kSpacing12),
            Text(
              limitStr,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 3. QUICK ACTION TEMPLATES WIDGET (4x2 layout size: 340 x 180)
// ─────────────────────────────────────────────────────────────────────────────
class WidgetQuickTemplates extends StatelessWidget {
  final List<Map<String, dynamic>> templates;
  final ThemeData theme;

  const WidgetQuickTemplates({super.key, required this.templates, required this.theme});

  @override
  Widget build(BuildContext context) {
    final list = templates.take(4).toList();

    return Theme(
      data: theme,
      child: Container(
        width: 340,
        height: 180,
        padding: const EdgeInsets.all(kSpacing16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'QUICK TEMPLATES',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const Spacer(),
            if (list.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No templates created yet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                height: 100,
                child: GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 3.5,
                  ),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final t = list[index];
                    final displayName = t['name']?.isNotEmpty == true
                        ? t['name']
                        : (t['description']?.isNotEmpty == true ? t['description'] : 'Template');

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            PesaFlowIcons.bookmark,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: kSpacing8),
                          Expanded(
                            child: Text(
                              displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 4. RECENT TRANSACTIONS WIDGET (4x2 layout size: 340 x 180)
// ─────────────────────────────────────────────────────────────────────────────
class WidgetRecentTransactions extends StatelessWidget {
  final List<TransactionWithCategoryAndAccount> transactions;
  final ThemeData theme;

  const WidgetRecentTransactions({super.key, required this.transactions, required this.theme});

  @override
  Widget build(BuildContext context) {
    final appColors = theme.extension<AppColorsTheme>()!;
    final list = transactions.take(3).toList();

    return Theme(
      data: theme,
      child: Container(
        width: 340,
        height: 180,
        padding: const EdgeInsets.all(kSpacing16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'RECENT ACTIVITY',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            ),
            const Spacer(),
            if (list.isEmpty)
              Expanded(
                child: Center(
                  child: Text(
                    'No transactions logged yet',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              )
            else
              Column(
                children: list.map((tx) {
                  final isExpense = tx.transaction.type.toLowerCase() == 'expense';
                  final amountSign = isExpense ? '-' : '+';
                  final amountColor = isExpense ? appColors.expenseColor : appColors.incomeColor;
                  final amountStr = NumberFormat.simpleCurrency(name: 'Tsh ', decimalDigits: 0).format(tx.transaction.amountCents / 100);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tx.transaction.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                                ),
                              ),
                              Text(
                                tx.category.name,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '$amountSign$amountStr',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: amountColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
