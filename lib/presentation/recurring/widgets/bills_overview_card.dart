import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/common/widgets/pesa_surface.dart';
import 'package:pesaflow/presentation/recurring/utils/recurring_schedule_helpers.dart';

/// Hero card for the Bills view showing upcoming bills due before payday,
/// current vs. post-bills balance, and a step-down balance projection chart.
class BillsOverviewCard extends StatelessWidget {
  final ClassifiedBills classified;
  final int currentBalanceCents;
  final DateTime? nextPayday;

  const BillsOverviewCard({
    super.key,
    required this.classified,
    required this.currentBalanceCents,
    required this.nextPayday,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final toPayBills = classified.toPayBeforePayday;
    final toPayCents = classified.toPayTotalCents;
    final afterBillsCents = currentBalanceCents - toPayCents;
    final isCovered = afterBillsCents >= 0;

    final now = dateOnly(DateTime.now());
    final endDate = nextPayday != null && !dateOnly(nextPayday!).isBefore(now)
        ? dateOnly(nextPayday!)
        : now.add(const Duration(days: 6));

    final stepPoints = buildBalanceStepPoints(
      currentBalanceCents: currentBalanceCents,
      bills: toPayBills,
      start: now,
      end: endDate,
    );

    final statusPillColor = isCovered
        ? context.appColors.incomeColor
        : context.appColors.expenseColor;

    final subtitleText = classified.hasPaydayAnchor
        ? 'due before payday'
        : 'due in the next 7 days';

    final billCount = toPayBills.length;
    final billCountLabel = billCount == 1
        ? '1 bill to pay'
        : '$billCount bills to pay';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        kSpacing16,
        kSpacing12,
        kSpacing16,
        kSpacing8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.only(bottom: kSpacing12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bills',
                  style: context.ts(
                    24,
                    fontWeight: FontWeight.w800,
                    color: onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  subtitleText,
                  style: context.ts(
                    16,
                    fontWeight: FontWeight.w500,
                    color: context.appColors.textMedium,
                  ),
                ),
              ],
            ),
          ),

          // Hero Card
          PesaSurface.bleed(
            fill: theme.colorScheme.surfaceContainerHigh,
            radius: AppTheme.radiusDialog,
            padding: const EdgeInsets.all(kSpacing20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Amount to pay',
                  style: context.ts(
                    12,
                    fontWeight: FontWeight.w600,
                    color: context.appColors.textMedium,
                  ),
                ),
                const SizedBox(height: kSpacing4),
                AmountText(
                  amountInCents: toPayCents,
                  animate: true,
                  style: context.ts(
                    32,
                    fontWeight: FontWeight.w900,
                    color: onSurface,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: kSpacing2),
                Text(
                  billCountLabel,
                  style: context.ts(
                    13,
                    fontWeight: FontWeight.w700,
                    color: billCount > 0
                        ? context.appColors.warningColor
                        : context.appColors.incomeColor,
                  ),
                ),
                const SizedBox(height: kSpacing16),

                // Balance today vs. after bills
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        '${CurrencyFormatter.formatCompact(currentBalanceCents)} today',
                        style: context.ts(
                          12,
                          fontWeight: FontWeight.w600,
                          color: context.appColors.textMedium,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: kSpacing8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: kSpacing12,
                        vertical: kSpacing5,
                      ),
                      decoration: BoxDecoration(
                        color: statusPillColor,
                        borderRadius: BorderRadius.circular(
                          AppTheme.radiusPill,
                        ),
                      ),
                      child: Text(
                        '${CurrencyFormatter.formatCompact(afterBillsCents)} after bills',
                        style: context.ts(
                          11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: kSpacing12),

                // Step-down balance projection chart
                Semantics(
                  label:
                      'Projected balance step chart from ${CurrencyFormatter.formatCompact(currentBalanceCents)} today to ${CurrencyFormatter.formatCompact(afterBillsCents)} after $billCount bills.',
                  child: SizedBox(
                    height: 112,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _BillsStepChartPainter(
                        points: stepPoints,
                        start: now,
                        end: endDate,
                        initialBalanceCents: currentBalanceCents,
                        lineColor: statusPillColor,
                        labelColor: onSurface,
                        mutedColor: context.appColors.textMedium,
                        axisColor: context.appColors.hairline,
                        labelStyle: context.ts(
                          11,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                        axisStyle: context.ts(
                          10,
                          fontWeight: FontWeight.w500,
                          color: context.appColors.textMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BillsStepChartPainter extends CustomPainter {
  final List<BalanceStepPoint> points;
  final DateTime start;
  final DateTime end;
  final int initialBalanceCents;
  final Color lineColor;
  final Color labelColor;
  final Color mutedColor;
  final Color axisColor;
  final TextStyle labelStyle;
  final TextStyle axisStyle;

  _BillsStepChartPainter({
    required this.points,
    required this.start,
    required this.end,
    required this.initialBalanceCents,
    required this.lineColor,
    required this.labelColor,
    required this.mutedColor,
    required this.axisColor,
    required this.labelStyle,
    required this.axisStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double topPad = 14;
    const double bottomAxisHeight = 22;
    const double labelDropClearance = 18;
    final chartHeight =
        (size.height - topPad - bottomAxisHeight - labelDropClearance).clamp(
          24.0,
          size.height,
        );
    final totalDays = end.difference(start).inDays.clamp(1, 365);

    // Compute min/max balance for Y scaling.
    int minBal = initialBalanceCents;
    int maxBal = initialBalanceCents;
    for (final p in points) {
      if (p.balanceAfterCents < minBal) minBal = p.balanceAfterCents;
      if (p.balanceAfterCents > maxBal) maxBal = p.balanceAfterCents;
    }
    final range = (maxBal - minBal).abs();
    final effectiveRange = range == 0 ? 1 : range;

    double xForDate(DateTime d) {
      final days = d.difference(start).inDays.clamp(0, totalDays);
      return (days / totalDays) * size.width;
    }

    double yForBalance(int cents) {
      if (range == 0) return topPad + chartHeight * 0.25;
      final norm = (maxBal - cents) / effectiveRange;
      return topPad + norm * (chartHeight * 0.85);
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.miter;

    final path = Path();
    final fillPath = Path();

    double prevX = 0;
    double prevY = yForBalance(initialBalanceCents);
    path.moveTo(prevX, prevY);
    fillPath.moveTo(prevX, topPad + chartHeight + 6);
    fillPath.lineTo(prevX, prevY);

    final dropLabels = <({double x, double y, int dropCents})>[];

    for (final p in points) {
      final x = xForDate(p.date);
      final nextY = yForBalance(p.balanceAfterCents);

      if (x > prevX) {
        path.lineTo(x, prevY);
        fillPath.lineTo(x, prevY);
      }
      if (nextY != prevY) {
        path.lineTo(x, nextY);
        fillPath.lineTo(x, nextY);
      }
      if (p.dropCents > 0) {
        dropLabels.add((x: x, y: nextY, dropCents: p.dropCents));
      }
      prevX = x;
      prevY = nextY;
    }

    if (prevX < size.width) {
      path.lineTo(size.width, prevY);
      fillPath.lineTo(size.width, prevY);
    }

    final chartBottom = topPad + chartHeight + 6;
    fillPath.lineTo(size.width, chartBottom);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.14),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, topPad, size.width, chartHeight + 6));

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, linePaint);

    // Draw drop labels (-amount) at each step-down.
    double lastLabelRight = -100;
    for (final drop in dropLabels) {
      final text = '-${CurrencyFormatter.formatCompact(drop.dropCents)}';
      final tp = TextPainter(
        text: TextSpan(text: text, style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      var dx = drop.x - tp.width / 2;
      dx = dx.clamp(0.0, (size.width - tp.width).clamp(0.0, size.width));
      if (dx < lastLabelRight + 4) {
        // Avoid overlapping adjacent drop labels.
        continue;
      }
      final dy = (drop.y + 4).clamp(topPad, chartBottom - 2);
      tp.paint(canvas, Offset(dx, dy));
      lastLabelRight = dx + tp.width;
    }

    // Baseline divider above weekday labels.
    final axisY = size.height - bottomAxisHeight;
    canvas.drawLine(
      Offset(0, axisY),
      Offset(size.width, axisY),
      Paint()
        ..color = axisColor
        ..strokeWidth = 0.8,
    );

    // Draw up to 6 evenly-spaced weekday labels along the bottom.
    final tickCount = totalDays < 6 ? totalDays + 1 : 6;
    final dayFormat = DateFormat('EEE');
    for (int i = 0; i < tickCount; i++) {
      final dayOffset = tickCount == 1
          ? 0
          : ((i / (tickCount - 1)) * totalDays).round();
      final tickDate = start.add(Duration(days: dayOffset));
      final tp = TextPainter(
        text: TextSpan(text: dayFormat.format(tickDate), style: axisStyle),
        textDirection: TextDirection.ltr,
      )..layout();

      final rawX = tickCount == 1
          ? 0.0
          : (dayOffset / totalDays) * size.width - tp.width / 2;
      final dx = rawX.clamp(
        0.0,
        (size.width - tp.width).clamp(0.0, size.width),
      );
      tp.paint(canvas, Offset(dx, axisY + 5));
    }
  }

  @override
  bool shouldRepaint(covariant _BillsStepChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.initialBalanceCents != initialBalanceCents ||
        oldDelegate.lineColor != lineColor;
  }
}
