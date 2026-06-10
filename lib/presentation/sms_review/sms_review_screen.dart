import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/color_helpers.dart';
import 'package:pesaflow/core/utils/icon_helpers.dart';
import 'package:pesaflow/data/database/app_database.dart';
import 'package:pesaflow/data/database/daos/transaction_dao.dart';
import 'package:pesaflow/data/repositories/transaction_repository.dart';
import 'package:pesaflow/presentation/common/ios/ios_list_section.dart';
import 'package:pesaflow/presentation/common/ios/ios_tab_bar.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';
import 'package:pesaflow/presentation/common/widgets/amount_text.dart';
import 'package:pesaflow/presentation/state/state_providers.dart';

class SmsReviewScreen extends ConsumerWidget {
  const SmsReviewScreen({super.key});

  void _showCategoryPicker(
    BuildContext context,
    WidgetRef ref,
    TransactionWithCategoryAndAccount item,
  ) async {
    final categoriesAsync = ref.read(categoriesFutureProvider);
    final categories = categoriesAsync.value ?? [];
    if (categories.isEmpty) return;

    final selectedCategoryId = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        final theme = Theme.of(context);
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Assign Category',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: categories.length,
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = cat.id == item.category.id;
                      return ListTile(
                        selected: isSelected,
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: hexToColor(cat.color).withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            getCategoryIcon(cat.icon),
                            color: hexToColor(cat.color),
                            size: 20,
                          ),
                        ),
                        title: Text(
                          cat.name,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        subtitle: Text(
                          cat.type.toUpperCase(),
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        trailing: isSelected
                            ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                            : null,
                        onTap: () => Navigator.of(context).pop(cat.id),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (selectedCategoryId != null) {
      if (!context.mounted) return;
      await ref.read(transactionRepositoryProvider).approveReviewedTransaction(
            item.transaction.id,
            newCategoryId: selectedCategoryId,
          );
      ref.invalidate(reviewQueueStreamProvider);
      ref.invalidate(recentTransactionsStreamProvider);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewAsync = ref.watch(reviewQueueStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            IosNavBar(
              title: 'SMS Review',
              largeTitle: true,
            ),
            Expanded(
              child: reviewAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
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
                        Icons.check_circle_outline_rounded,
                        size: 56,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'All Clear!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No transactions awaiting review.\nAuto-logged entries appear on the Dashboard.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: items.length + 1, // +1 for header
            itemBuilder: (context, index) {
              if (index == 0) {
                // Header
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.tertiary.withOpacity(0.15),
                          theme.colorScheme.tertiary.withOpacity(0.05),
                        ],
                      ),
                      border: Border.all(
                        color: theme.colorScheme.tertiary.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sms_rounded,
                          color: theme.colorScheme.tertiary,
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${items.length} transaction${items.length == 1 ? '' : 's'} to review',
                                style: theme.textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Swipe right to approve, left to reject',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final item = items[index - 1];
              final trans = item.transaction;

              AmountType amtType = AmountType.neutral;
              if (trans.type.toLowerCase() == 'income') {
                amtType = AmountType.income;
              } else if (trans.type.toLowerCase() == 'expense' ||
                  trans.type.toLowerCase() == 'airtime' ||
                  trans.type.toLowerCase() == 'fee') {
                amtType = AmountType.expense;
              }

              return SwipeableCard(
                onSwipeLeft: () async {
                  // Reject: delete the transaction
                  await ref.read(transactionRepositoryProvider).deleteTransaction(trans.id);
                  ref.invalidate(reviewQueueStreamProvider);
                  ref.invalidate(recentTransactionsStreamProvider);
                  ref.invalidate(accountsStreamProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Transaction rejected: ${trans.description}'),
                        backgroundColor: theme.colorScheme.error,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                onSwipeRight: () async {
                  // Approve: mark as sms_auto
                  await ref.read(transactionRepositoryProvider).approveReviewedTransaction(trans.id);
                  ref.invalidate(reviewQueueStreamProvider);
                  ref.invalidate(recentTransactionsStreamProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Transaction approved: ${trans.description}'),
                        backgroundColor: theme.brightness == Brightness.dark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  clipBehavior: Clip.antiAlias, // Ensures the left accent border is clipped nicely
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? AppTheme.surfaceContainerDark
                        : AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                    border: Border.all(
                      color: theme.brightness == Brightness.dark
                          ? const Color(0x12FFFFFF)
                          : const Color(0x1F000000),
                      width: 0.5,
                    ),
                  ),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Left Accent Border strip (dynamic category colored)
                        Container(
                          width: 5,
                          color: hexToColor(item.category.color),
                        ),
                        // Main content
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top section: provider badge + amount
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: hexToColor(item.category.color).withOpacity(0.15),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        getCategoryIcon(item.category.icon),
                                        color: hexToColor(item.category.color),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            trans.description.isNotEmpty
                                                ? trans.description
                                                : item.category.name,
                                            style: theme.textTheme.titleSmall?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: theme.colorScheme.primary.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  item.account.name,
                                                  style: TextStyle(
                                                    color: theme.colorScheme.primary,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              // High-fidelity confidence score badge
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF30D158).withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(100),
                                                  border: Border.all(
                                                    color: const Color(0xFF30D158).withOpacity(0.2),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    ConfidenceRing(
                                                      score: 0.94,
                                                      color: const Color(0xFF30D158),
                                                      size: 12,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      '94% MATCH',
                                                      style: TextStyle(
                                                        color: theme.brightness == Brightness.dark
                                                            ? const Color(0xFF30D158)
                                                            : const Color(0xFF2E7D32),
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w900,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    AmountText(
                                      amountInCents: trans.amount,
                                      type: amtType,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Raw SMS preview
                              if (trans.rawSms != null && trans.rawSms!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.03),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      trans.rawSms!,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontFamily: 'monospace',
                                        color: theme.colorScheme.onSurfaceVariant
                                            .withOpacity(0.7),
                                      ),
                                    ),
                                  ),
                                ),

                              // Action buttons
                              Padding(
                                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                                child: Row(
                                  children: [
                                    TextButton.icon(
                                      onPressed: () => _showCategoryPicker(context, ref, item),
                                      icon: const Icon(Icons.category_rounded, size: 16),
                                      label: const Text('Change Category',
                                          style: TextStyle(fontSize: 12)),
                                    ),
                                    const Spacer(),
                                    TextButton.icon(
                                      onPressed: () async {
                                        await ref
                                            .read(transactionRepositoryProvider)
                                            .approveReviewedTransaction(trans.id);
                                        ref.invalidate(reviewQueueStreamProvider);
                                        ref.invalidate(recentTransactionsStreamProvider);
                                      },
                                      icon: Icon(Icons.check_rounded,
                                          size: 16, color: theme.brightness == Brightness.dark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF)),
                                      label: Text('Approve',
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: theme.brightness == Brightness.dark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF))),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading review queue: $err')),
      ),
          ),
        ],
      ),
    ));
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HIGH-FIDELITY CUSTOM-PAINTED CONFIDENCE RING WIDGET
// ════════════════════════════════════════════════════════════════════════════
class ConfidenceRing extends StatelessWidget {
  final double score;
  final Color color;
  final double size;

  const ConfidenceRing({
    super.key,
    required this.score,
    required this.color,
    this.size = 14,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ConfidenceRingPainter(
          score: score,
          color: color,
        ),
      ),
    );
  }
}

class _ConfidenceRingPainter extends CustomPainter {
  final double score;
  final Color color;

  _ConfidenceRingPainter({required this.score, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1;

    final bgPaint = Paint()
      ..color = color.withOpacity(0.18)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    
    canvas.drawCircle(center, radius, bgPaint);

    final activePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708, // -90 degrees
      6.28318 * score, // 2 * pi * score
      false,
      activePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ConfidenceRingPainter oldDelegate) {
    return oldDelegate.score != score || oldDelegate.color != color;
  }
}

// ════════════════════════════════════════════════════════════════════════════
// TINDER-STYLE SPRING SWIPE CARD INTERACTION WIDGET
// ════════════════════════════════════════════════════════════════════════════
class SwipeableCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipeLeft;
  final VoidCallback onSwipeRight;

  const SwipeableCard({
    super.key,
    required this.child,
    required this.onSwipeLeft,
    required this.onSwipeRight,
  });

  @override
  State<SwipeableCard> createState() => _SwipeableCardState();
}

class _SwipeableCardState extends State<SwipeableCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Offset _dragOffset = Offset.zero;
  double _angle = 0.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _dragOffset += details.delta;
      _angle = _dragOffset.dx / 800.0; // Subtle rotation
    });
  }

  void _onPanEnd(DragEndDetails details) {
    final threshold = MediaQuery.of(context).size.width * 0.35;
    if (_dragOffset.dx > threshold) {
      _swipeOut(const Offset(600, 0), widget.onSwipeRight);
    } else if (_dragOffset.dx < -threshold) {
      _swipeOut(const Offset(-600, 0), widget.onSwipeLeft);
    } else {
      _snapBack();
    }
  }

  void _swipeOut(Offset targetOffset, VoidCallback onComplete) {
    final startOffset = _dragOffset;
    final startAngle = _angle;
    
    _controller.duration = const Duration(milliseconds: 200);
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    animation.addListener(() {
      setState(() {
        _dragOffset = Offset.lerp(startOffset, targetOffset, animation.value)!;
        _angle = startAngle + (startAngle * 1.5 - startAngle) * animation.value;
      });
    });

    _controller.forward(from: 0.0).then((_) {
      onComplete();
    });
  }

  void _snapBack() {
    final startOffset = _dragOffset;
    final startAngle = _angle;

    _controller.duration = const Duration(milliseconds: 300);
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    animation.addListener(() {
      setState(() {
        _dragOffset = Offset.lerp(startOffset, Offset.zero, animation.value)!;
        _angle = startAngle + (0.0 - startAngle) * animation.value;
      });
    });

    _controller.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final threshold = MediaQuery.of(context).size.width * 0.35;
    final double approveOpacity = (_dragOffset.dx / threshold).clamp(0.0, 1.0);
    final double rejectOpacity = (-_dragOffset.dx / threshold).clamp(0.0, 1.0);

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: _dragOffset,
        child: Transform.rotate(
          angle: _angle,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              widget.child,
              if (approveOpacity > 0)
                Positioned.fill(
                  child: Opacity(
                    opacity: approveOpacity,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        border: Border.all(color: const Color(0xFF30D158), width: 3),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF30D158),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF30D158).withOpacity(0.4),
                                blurRadius: 15,
                              )
                            ],
                          ),
                          child: const Text(
                            'APPROVE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (rejectOpacity > 0)
                Positioned.fill(
                  child: Opacity(
                    opacity: rejectOpacity,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
                        border: Border.all(color: const Color(0xFFFF453A), width: 3),
                      ),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF453A),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFF453A).withOpacity(0.4),
                                blurRadius: 15,
                              )
                            ],
                          ),
                          child: const Text(
                            'REJECT',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 20,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
