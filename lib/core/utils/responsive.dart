import 'package:flutter/material.dart';

enum ScreenSize { smallPhone, phone, smallTablet, largeTablet, desktop }

ScreenSize getScreenSize(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < 360) return ScreenSize.smallPhone;
  if (w < 600) return ScreenSize.phone;
  if (w < 840) return ScreenSize.smallTablet;
  if (w < 1200) return ScreenSize.largeTablet;
  return ScreenSize.desktop;
}

bool isCompact(BuildContext context) {
  final s = getScreenSize(context);
  return s == ScreenSize.smallPhone || s == ScreenSize.phone;
}

bool isTablet(BuildContext context) {
  final s = getScreenSize(context);
  return s == ScreenSize.smallTablet || s == ScreenSize.largeTablet;
}

bool isDesktop(BuildContext context) =>
    getScreenSize(context) == ScreenSize.desktop;

double responsiveValue(
  BuildContext context, {
  required double compact,
  double? tablet,
  double? desktop,
}) {
  final s = getScreenSize(context);
  if (desktop != null && s == ScreenSize.desktop) return desktop;
  if (tablet != null &&
      (s == ScreenSize.smallTablet || s == ScreenSize.largeTablet))
    return tablet;
  return compact;
}

double responsiveSpacing(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < 360) return 12;
  if (w < 600) return 16;
  if (w < 840) return 20;
  if (w < 1200) return 24;
  return 32;
}

double responsiveCardPadding(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < 360) return 12;
  if (w < 600) return 16;
  return 20;
}

double responsiveGridColumns(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < 600) return 1;
  if (w < 840) return 2;
  if (w < 1200) return 3;
  return 4;
}

int responsiveAccountColumns(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  if (w < 400) return 1;
  if (w < 600) return 2;
  if (w < 900) return 3;
  return 4;
}

double responsiveFontSize(BuildContext context, {required double base}) {
  final w = MediaQuery.sizeOf(context).width;
  final scale = w / 375;
  final clamped = scale.clamp(0.85, 1.25);
  return base * clamped;
}

EdgeInsets responsiveHorizontalPadding(BuildContext context) {
  final s = getScreenSize(context);
  switch (s) {
    case ScreenSize.smallPhone:
      return const EdgeInsets.symmetric(horizontal: 12);
    case ScreenSize.phone:
      return const EdgeInsets.symmetric(horizontal: 16);
    case ScreenSize.smallTablet:
      return const EdgeInsets.symmetric(horizontal: 24);
    case ScreenSize.largeTablet:
      return const EdgeInsets.symmetric(horizontal: 32);
    case ScreenSize.desktop:
      return EdgeInsets.symmetric(
        horizontal: MediaQuery.sizeOf(context).width * 0.15,
      );
  }
}

double responsiveMaxContentWidth(BuildContext context) {
  final s = getScreenSize(context);
  if (s == ScreenSize.desktop) return 900;
  if (s == ScreenSize.largeTablet) return 720;
  if (s == ScreenSize.smallTablet) return 600;
  return double.infinity;
}

class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  const ResponsiveCenter({super.key, required this.child, this.maxWidth});

  @override
  Widget build(BuildContext context) {
    final mw = maxWidth ?? responsiveMaxContentWidth(context);
    if (mw >= MediaQuery.sizeOf(context).width) return child;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mw),
        child: child,
      ),
    );
  }
}

class ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double? childFlex;
  const ResponsiveRow({
    super.key,
    required this.children,
    this.spacing = 16,
    this.childFlex,
  });

  @override
  Widget build(BuildContext context) {
    if (isCompact(context)) {
      return Column(children: children);
    }
    if (children.isEmpty) return const SizedBox.shrink();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children.map((c) {
        final flex = childFlex ?? (1.0 / children.length);
        return Expanded(
          flex: (flex * 100).round(),
          child: Padding(
            padding: EdgeInsets.only(left: spacing / 2, right: spacing / 2),
            child: c,
          ),
        );
      }).toList(),
    );
  }
}
