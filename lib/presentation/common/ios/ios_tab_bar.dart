import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:flutter/physics.dart';

import 'package:pesaflow/core/theme/motion_constants.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';

class IosTabBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool minimized;

  const IosTabBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.minimized = false,
  });

  static const double navBarHeight = 72.0;
  static const double minimizedHeight = 60.0;

  @override
  State<IosTabBar> createState() => _IosTabBarState();
}

class _IosTabBarState extends State<IosTabBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _selController;
  late Animation<double> _selAnim;
  int _prevIndex = 0;

  static const double _unselectedFlex = 162;
  static const double _selectedFlex = 350;

  @override
  void initState() {
    super.initState();
    _prevIndex = widget.selectedIndex;
    _selController = AnimationController(
      vsync: this,
      value: 1.0,
      duration: MotionTokens.durationNormal,
    );
    _selAnim = const AlwaysStoppedAnimation(1.0);
  }

  @override
  void didUpdateWidget(covariant IosTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex) {
      _prevIndex = oldWidget.selectedIndex;
      _animateToTab(widget.selectedIndex);
    }
  }

  void _animateToTab(int newIndex) {
    if (context.isReducedMotion) {
      _selController.value = 1.0;
      return;
    }
    _selAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _selController, curve: Curves.easeOutCubic),
    );
    _selController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _selController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final height = widget.minimized
        ? IosTabBar.minimizedHeight
        : IosTabBar.navBarHeight;

    const tabs = [
      _TabConfig(
        routeIndex: 0,
        label: 'Home',
        icon: PesaFlowIcons.home,
        activeIcon: PesaFlowIcons.home,
      ),
      _TabConfig(
        routeIndex: 1,
        label: 'Transactions',
        icon: PesaFlowIcons.transfer,
        activeIcon: PesaFlowIcons.transfer,
      ),
      _TabConfig(
        routeIndex: 2,
        label: 'Budgets',
        icon: PesaFlowIcons.savings,
        activeIcon: PesaFlowIcons.savings,
      ),
      _TabConfig(
        routeIndex: 3,
        label: 'Analytics',
        icon: PesaFlowIcons.analytics,
        activeIcon: PesaFlowIcons.analytics,
      ),
      _TabConfig(
        routeIndex: 4,
        label: 'Account',
        icon: PesaFlowIcons.personOutline,
        activeIcon: PesaFlowIcons.person,
      ),
    ];

    // Both modes derive from the theme surface — the resolved dark surface
    // is already the correct near-black (0xFF0F0F0F).
    final navBgColor = theme.colorScheme.surface.withValues(alpha: 0.7);
    final navFgColor = theme.colorScheme.onSurface;

    return Container(
      height: height + bottomPadding + (widget.minimized ? 6 : 14),
      alignment: Alignment.bottomCenter,
      padding: EdgeInsets.only(
        bottom: bottomPadding > 0 ? bottomPadding : (widget.minimized ? 6 : 14),
        left: widget.minimized ? 24 : 16,
        right: widget.minimized ? 24 : 16,
      ),
      child: SizedBox(
        height: height,
        child: GlassCard(
          frosted: true,
          borderRadius: 100,
          backgroundColor: navBgColor,
          elevation: CardElevation.medium,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: AnimatedBuilder(
              animation: _selController,
              builder: (context, _) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: tabs.map((tab) {
                    return _buildTab(context, tab, navFgColor, theme);
                  }).toList(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTab(
    BuildContext context,
    _TabConfig tab,
    Color navFgColor,
    ThemeData theme,
  ) {
    final isSelected = tab.routeIndex == widget.selectedIndex;
    final isPrev = tab.routeIndex == _prevIndex;
    final isAnimating = _selController.isAnimating;

    // ── Flex animation (spring-driven via controller value) ──
    double flex;
    if (widget.minimized) {
      flex = 200;
    } else if (!isAnimating) {
      flex = isSelected ? _selectedFlex : _unselectedFlex;
    } else {
      final t = _selAnim.value;
      if (isSelected) {
        flex = _unselectedFlex + (_selectedFlex - _unselectedFlex) * t;
      } else if (isPrev) {
        flex = _selectedFlex + (_unselectedFlex - _selectedFlex) * t;
      } else {
        flex = _unselectedFlex;
      }
    }

    // ── Background highlight opacity (spring-driven) ──
    double bgAlpha;
    if (!isAnimating) {
      bgAlpha = isSelected ? 0.15 : 0.0;
    } else {
      final t = _selAnim.value;
      if (isSelected) {
        bgAlpha = 0.15 * t;
      } else if (isPrev) {
        bgAlpha = 0.15 * (1.0 - t);
      } else {
        bgAlpha = 0.0;
      }
    }

    // ── Icon spring bounce on selection ──
    // Scale 1.0 → 1.15 → 1.0 with spring physics
    double iconScale;
    if (!isAnimating) {
      iconScale = isSelected ? 1.0 : 1.0;
    } else if (isSelected) {
      // Bounce: overshoot to 1.15 then settle back to 1.0
      // Using a sinusoidal envelope on the spring progress
      final t = _selAnim.value;
      iconScale = 1.0 + 0.15 * t * (1.0 - t) * 4.0;
    } else {
      iconScale = 1.0;
    }

    final iconSize = isSelected ? 26.0 : 22.0;

    return Expanded(
      flex: flex.round(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: kSpacing2),
        child: Semantics(
          label: tab.label,
          button: true,
          selected: isSelected,
          child: _ElasticTabButton(
            onTap: () {
              PesaHaptics.selection();
              widget.onDestinationSelected(tab.routeIndex);
            },
            child: Container(
              height: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: navFgColor.withValues(alpha: bgAlpha),
                borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              ),
              alignment: Alignment.center,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedSwitcher(
                      duration: MotionTokens.durationExit,
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, anim) {
                        return ScaleTransition(
                          scale: Tween<double>(begin: 0.82, end: 1.0).animate(
                            CurvedAnimation(
                              parent: anim,
                              curve: Curves.easeOutCubic,
                            ),
                          ),
                          child: child,
                        );
                      },
                      child: Transform.scale(
                        scale: iconScale,
                        child: Icon(
                          isSelected ? tab.activeIcon : tab.icon,
                          key: ValueKey('${tab.routeIndex}_$isSelected'),
                          size: iconSize,
                          color: navFgColor,
                        ),
                      ),
                    ),
                    if (isSelected && !widget.minimized) ...[
                      const SizedBox(width: kSpacing8),
                      Text(
                        tab.label,
                        style: context.ts(
                          15,
                          fontWeight: FontWeight.w600,
                          color: navFgColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabConfig {
  final int routeIndex;
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _TabConfig({
    required this.routeIndex,
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}

class IosNavBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? leading;
  final List<Widget>? actions;
  final bool largeTitle;
  final bool? canPop;

  const IosNavBar({
    super.key,
    required this.title,
    this.leading,
    this.actions,
    this.largeTitle = true,
    this.canPop,
  });

  @override
  Size get preferredSize {
    if (!largeTitle) return const Size.fromHeight(56.0);
    if (leading != null || (canPop ?? false)) {
      return const Size.fromHeight(120.0);
    }
    return const Size.fromHeight(72.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final top = MediaQuery.paddingOf(context).top;

    final effectiveCanPop = canPop ?? Navigator.of(context).canPop();
    final effectiveLeading =
        leading ??
        (effectiveCanPop
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(PesaFlowIcons.back, size: 20),
                onPressed: () => Navigator.of(context).maybePop(),
              )
            : null);

    final titleStyle = context.ts(
      28,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.8,
      color: theme.colorScheme.onSurface,
    );

    return ClipRect(
      child: Container(
        padding: EdgeInsets.only(top: top),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface.withValues(alpha: 0.85),
          border: Border(
            bottom: BorderSide(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
              width: 0.5,
            ),
          ),
        ),
        child: Builder(
          builder: (context) {
            if (!largeTitle) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: kSpacing16,
                  vertical: 6,
                ),
                child: SizedBox(
                  height: 44,
                  child: Row(
                    children: [
                      effectiveLeading ?? const SizedBox(width: kSpacing48),
                      Expanded(
                        child: Text(
                          title,
                          style: context.ts(
                            15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (actions != null && actions!.isNotEmpty)
                        Row(mainAxisSize: MainAxisSize.min, children: actions!)
                      else
                        const SizedBox(width: kSpacing48),
                    ],
                  ),
                ),
              );
            }

            // Large title
            if (effectiveLeading != null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: kSpacing12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: kSpacing16),
                    child: SizedBox(
                      height: 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          effectiveLeading,
                          if (actions != null && actions!.isNotEmpty)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: actions!,
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(
                      left: kSpacing16,
                      top: kSpacing8,
                      bottom: kSpacing16,
                    ),
                    child: Text(title, style: titleStyle),
                  ),
                ],
              );
            } else {
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  kSpacing16,
                  kSpacing16,
                  kSpacing16,
                  kSpacing16,
                ),
                child: SizedBox(
                  height: 40,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(title, style: titleStyle),
                      if (actions != null && actions!.isNotEmpty)
                        Row(mainAxisSize: MainAxisSize.min, children: actions!),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }
}

class _ElasticTabButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ElasticTabButton({required this.child, required this.onTap});

  @override
  State<_ElasticTabButton> createState() => _ElasticTabButtonState();
}

class _ElasticTabButtonState extends State<_ElasticTabButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MotionTokens.durationFast,
    );
    _scale = Tween<double>(begin: 1.0, end: MotionTokens.scalePress).animate(
      _controller,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _pressDown() {
    if (context.isReducedMotion) {
      _controller.value = 1.0;
      return;
    }
    _controller.animateTo(
      1.0,
      duration: MotionTokens.durationFast,
      curve: Curves.easeOutCubic,
    );
  }

  void _release() {
    if (context.isReducedMotion) {
      _controller.value = 0.0;
      return;
    }
    // Ensure quick taps (< 50ms) show a perceptible tactile bounce —
    // same floor as TactileSpringContainer for consistent press feel.
    final startVal = _controller.value < 0.3 ? 0.3 : _controller.value;
    final simulation = SpringSimulation(
      MotionTokens.springSnappy,
      startVal,
      0.0,
      0.0,
    );
    _controller.animateWith(simulation);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _pressDown(),
      onTapUp: (_) {
        _release();
        widget.onTap();
      },
      onTapCancel: () => _release(),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.scale(
            scale: _scale.value,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}
