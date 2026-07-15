import 'package:flutter/material.dart';
import '../theme/app_colors_theme.dart';
import '../theme/app_typography_theme.dart';
import 'responsive.dart';

import 'package:pesaflow/core/utils/spacing.dart';

extension PesaFlowContext on BuildContext {
  ScreenSize get screenSize => getScreenSize(this);

  AppColorsTheme get appColors =>
      Theme.of(this).extension<AppColorsTheme>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppColorsTheme.dark()
          : AppColorsTheme.light());
  AppTypographyTheme get appTypography =>
      Theme.of(this).extension<AppTypographyTheme>() ??
      AppTypographyTheme.base(Theme.of(this).textTheme);

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  TextStyle ts(
    double size, {
    TextStyle? from,
    Color? color,
    FontWeight? fontWeight,
    double? letterSpacing,
    double? height,
    TextDecoration? decoration,
    FontStyle? fontStyle,
  }) {
    final t = Theme.of(this).textTheme;
    final base = switch (size) {
      10 => Theme.of(this).extension<AppTypographyTheme>()!.labelMicro,
      11 => t.labelSmall!,
      12 => t.labelMedium!,
      13 => t.bodySmall!,
      14 => t.titleSmall!,
      15 => t.bodyMedium!,
      16 => t.titleMedium!,
      17 => t.bodyLarge!,
      22 => t.titleLarge!,
      24 => t.headlineSmall!,
      28 => t.headlineMedium!,
      32 => t.headlineLarge!,
      36 => t.displaySmall!,
      45 => t.displayMedium!,
      57 => t.displayLarge!,
      _ => t.bodyMedium!,
    };
    return base.copyWith(
      fontSize: size,
      color: color,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
      height: height,
      decoration: decoration,
      fontStyle: fontStyle,
    );
  }

  bool get isCompactView {
    final s = getScreenSize(this);
    return s == ScreenSize.smallPhone || s == ScreenSize.phone;
  }

  bool get isTabletView {
    final s = getScreenSize(this);
    return s == ScreenSize.smallTablet || s == ScreenSize.largeTablet;
  }

  bool get isDesktopView => getScreenSize(this) == ScreenSize.desktop;

  double get spacing => responsiveSpacing(this);

  EdgeInsets get horizontalPadding => responsiveHorizontalPadding(this);

  EdgeInsets get cardEdgePadding => EdgeInsets.all(responsiveCardPadding(this));

  double gridColumns({
    double narrow = 1,
    double medium = 2,
    double wide = 3,
    double xwide = 4,
  }) {
    final w = MediaQuery.sizeOf(this).width;
    if (w < 600) return narrow;
    if (w < 840) return medium;
    if (w < 1200) return wide;
    return xwide;
  }

  TextStyle responsiveText(TextStyle style) {
    final scale = (MediaQuery.sizeOf(this).width / 375).clamp(0.85, 1.25);
    return style.copyWith(fontSize: (style.fontSize ?? 14) * scale);
  }

  TextStyle get displayLarge =>
      responsiveText(Theme.of(this).textTheme.displayLarge!);
  TextStyle get displayMedium =>
      responsiveText(Theme.of(this).textTheme.displayMedium!);
  TextStyle get displaySmall =>
      responsiveText(Theme.of(this).textTheme.displaySmall!);
  TextStyle get headlineLarge =>
      responsiveText(Theme.of(this).textTheme.headlineLarge!);
  TextStyle get headlineMedium =>
      responsiveText(Theme.of(this).textTheme.headlineMedium!);
  TextStyle get headlineSmall =>
      responsiveText(Theme.of(this).textTheme.headlineSmall!);
  TextStyle get titleLarge =>
      responsiveText(Theme.of(this).textTheme.titleLarge!);
  TextStyle get titleMedium =>
      responsiveText(Theme.of(this).textTheme.titleMedium!);
  TextStyle get titleSmall =>
      responsiveText(Theme.of(this).textTheme.titleSmall!);
  TextStyle get bodyLarge =>
      responsiveText(Theme.of(this).textTheme.bodyLarge!);
  TextStyle get bodyMedium =>
      responsiveText(Theme.of(this).textTheme.bodyMedium!);
  TextStyle get bodySmall =>
      responsiveText(Theme.of(this).textTheme.bodySmall!);

  void dismissKeyboard() => FocusScope.of(this).unfocus();

  InputDecoration inputDecoration({
    String? hintText,
    String? labelText,
    Widget? prefixIcon,
    Widget? suffixIcon,
    String? helperText,
    String? errorText,
    String? prefixText,
    String? suffixText,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final theme = Theme.of(this);
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      prefixIcon: prefixIcon != null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpacing12),
              child: prefixIcon,
            )
          : null,
      prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      suffixIcon: suffixIcon != null
          ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: kSpacing12),
              child: suffixIcon,
            )
          : null,
      suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      helperText: helperText,
      errorText: errorText,
      prefixText: prefixText,
      suffixText: suffixText,
      filled: true,
      fillColor: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.06),
          width: 0.8,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: theme.colorScheme.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.error, width: 1.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: theme.colorScheme.error, width: 1.5),
      ),
      contentPadding:
          contentPadding ??
          const EdgeInsets.symmetric(
            horizontal: kSpacing16,
            vertical: kSpacing14,
          ),
      labelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
      floatingLabelStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.primary,
      ),
      errorStyle: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.error,
      ),
      hintStyle: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
      ),
    );
  }

  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);
  double get keyboardInset => MediaQuery.viewInsetsOf(this).bottom;
  double get bottomInset => MediaQuery.paddingOf(this).bottom;
  double get topInset => MediaQuery.paddingOf(this).top;
}

class PageScaffold extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool resizeToAvoidBottomInset;
  final Color? backgroundColor;
  final bool dismissKeyboardOnTap;

  const PageScaffold({
    super.key,
    required this.child,
    this.padding,
    this.resizeToAvoidBottomInset = true,
    this.backgroundColor,
    this.dismissKeyboardOnTap = true,
  });

  @override
  Widget build(BuildContext context) {
    final bg = backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;
    return GestureDetector(
      onTap: dismissKeyboardOnTap ? () => context.dismissKeyboard() : null,
      child: Container(
        color: bg,
        child: SafeArea(
          child: Padding(
            padding: padding ?? context.horizontalPadding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class FormScaffold extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool resizeToAvoidBottomInset;
  final bool safeTop;

  const FormScaffold({
    super.key,
    required this.child,
    this.padding,
    this.resizeToAvoidBottomInset = true,
    this.safeTop = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.dismissKeyboard(),
      child: SafeArea(
        top: safeTop,
        bottom: false,
        child: SingleChildScrollView(
          padding: padding ?? context.horizontalPadding,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: child,
        ),
      ),
    );
  }
}

class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? borderRadius;
  final Color? color;
  final List<BoxShadow>? boxShadow;

  const ResponsiveCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius,
    this.color,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rp = responsiveCardPadding(context);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color ?? theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(borderRadius ?? 20),
        boxShadow:
            boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
      ),
      child: Padding(padding: padding ?? EdgeInsets.all(rp), child: child),
    );
  }
}
