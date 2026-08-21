import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/currency_formatter.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pesaflow/presentation/settings/settings_screen.dart';

class BudjetlyBalanceHeader extends StatefulWidget {
  final int balance;
  final String label;
  final int income;
  final int expense;

  const BudjetlyBalanceHeader({
    super.key,
    required this.balance,
    required this.label,
    required this.income,
    required this.expense,
  });

  @override
  State<BudjetlyBalanceHeader> createState() => _BudjetlyBalanceHeaderState();
}

class _BudjetlyBalanceHeaderState extends State<BudjetlyBalanceHeader> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _isFront = true;
  bool _isHidden = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _animation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutBack),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    HapticFeedback.lightImpact();
    if (_isFront) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
    _isFront = !_isFront;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleFlip,
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) {
          final angle = _animation.value * pi;
          final transform = Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(angle);

          // If rotated past 90 degrees (pi/2), show back side
          final isBackVisible = angle >= pi / 2;

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: isBackVisible
                ? Transform(
                    // Un-mirror the back side content
                    transform: Matrix4.identity()..rotateX(pi),
                    alignment: Alignment.center,
                    child: _buildCardSide(context, isFront: false),
                  )
                : _buildCardSide(context, isFront: true),
          );
        },
      ),
    );
  }

  Widget _buildCardSide(BuildContext context, {required bool isFront}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1C1C1E) : const Color(0xFF1C1C1E); // Always dark per screenshot

    return ClipPath(
      clipper: _TicketClipper(cutoutRadius: 12, cutoutOffset: 135),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top Section
            Container(
              height: 135,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: isFront ? _buildFrontTop(context) : _buildBackTop(context),
            ),

            // Dashed Divider
            Row(
              children: [
                const SizedBox(width: 12), // Match cutout radius
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return Flex(
                        direction: Axis.horizontal,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        mainAxisSize: MainAxisSize.max,
                        children: List.generate(
                          (constraints.constrainWidth() / 8).floor(),
                          (index) => Container(
                            width: 4,
                            height: 1,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
            ),

            // Bottom Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: isFront ? _buildBottomButtons(context) : _buildBottomButtons(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrontTop(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.label,
                style: context.ts(16, fontWeight: FontWeight.w600, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        _isHidden ? '••••••' : CurrencyFormatter.formatCents(widget.balance),
                        style: context.ts(40, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1.0),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {
            setState(() {
              _isHidden = !_isHidden;
            });
          },
          icon: Icon(
            _isHidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }

  Widget _buildBackTop(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Account Details',
          style: context.ts(16, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Total In', style: context.ts(13, color: Colors.white.withValues(alpha: 0.6))),
                const SizedBox(height: 4),
                Text(CurrencyFormatter.formatCents(widget.income), style: context.ts(18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Total Out', style: context.ts(13, color: Colors.white.withValues(alpha: 0.6))),
                const SizedBox(height: 4),
                Text(CurrencyFormatter.formatCents(widget.expense), style: context.ts(18, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ],
        )
      ],
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TactileSpringContainer(
            onTap: () {
              context.push('/transactions/add');
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(PesaFlowIcons.add, color: Colors.blueAccent, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Add Transaction', style: context.ts(14, fontWeight: FontWeight.w700, color: Colors.blueAccent)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Consumer(
            builder: (context, ref, _) {
              return TactileSpringContainer(
                onTap: () {
                  SettingsScreen.showAccountsManager(context, ref);
                },
                child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Accounts', style: context.ts(14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          );
         },
        ),
       ),
      ],
    );
  }
}

class _TicketClipper extends CustomClipper<Path> {
  final double cutoutRadius;
  final double cutoutOffset;

  _TicketClipper({required this.cutoutRadius, required this.cutoutOffset});

  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();

    // Left cutout
    final leftCutout = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(0, cutoutOffset), radius: cutoutRadius),
        -pi / 2,
        pi,
      );
    
    // Right cutout
    final rightCutout = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(size.width, cutoutOffset), radius: cutoutRadius),
        pi / 2,
        pi,
      );

    return Path.combine(
      PathOperation.difference,
      Path.combine(PathOperation.difference, path, leftCutout),
      rightCutout,
    );
  }

  @override
  bool shouldReclip(_TicketClipper oldClipper) => 
    oldClipper.cutoutRadius != cutoutRadius || oldClipper.cutoutOffset != cutoutOffset;
}
