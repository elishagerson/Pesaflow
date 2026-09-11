import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';

import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/core/utils/haptics.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';

class IosListSection extends StatelessWidget {
  final String? header;
  final List<Widget> rows;
  final EdgeInsetsGeometry? margin;

  const IosListSection({
    super.key,
    this.header,
    required this.rows,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(
              left: kSpacing20,
              right: kSpacing20,
              bottom: kSpacing8,
              top: kSpacing20,
            ),
            child: Text(
              header!,
              style: context.ts(
                12,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary.withValues(alpha: 0.85),
                letterSpacing: 0.6,
              ),
            ),
          ),
        GlassCard(
          margin: margin ?? const EdgeInsets.symmetric(horizontal: kSpacing16),
          padding: EdgeInsets.zero,
          elevation: CardElevation.low,
          borderRadius: AppTheme.radiusCard,
          child: Column(
            children: List.generate(rows.length, (index) {
              final row = rows[index];
              final isLast = index == rows.length - 1;
              return Column(
                children: [
                  row,
                  if (!isLast)
                    Divider(
                      height: 0.5,
                      thickness: 0.5,
                      indent: row is IosListRow ? row.indent ?? 64 : 64,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.06,
                      ),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class IosListRow extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final double? indent;
  final Color? tintColor;

  const IosListRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.indent,
    this.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: kSpacing16,
        vertical: kSpacing12,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: kSpacing12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(
                  style: context.ts(
                    15,
                    fontWeight: FontWeight.w500,
                    color: theme.colorScheme.onSurface,
                  ),
                  child: title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: kSpacing2),
                  DefaultTextStyle.merge(
                    style: context.ts(
                      12,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                    ),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: kSpacing8),
            trailing!,
          ] else if (onTap != null)
            Icon(
              PesaFlowIcons.chevronRight,
              size: 18,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.40),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            PesaHaptics.light();
            onTap!();
          },
          highlightColor: theme.colorScheme.onSurface.withValues(alpha: 0.04),
          splashColor: theme.colorScheme.onSurface.withValues(alpha: 0.065),
          child: content,
        ),
      );
    }
    return content;
  }
}

class IosToggleRow extends IosListRow {
  final bool value;
  final ValueChanged<bool> onChanged;

  const IosToggleRow({
    super.key,
    super.leading,
    required super.title,
    super.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return IosListRow(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: Transform.scale(
        scale: 0.85,
        child: CupertinoSwitch(
          value: value,
          activeTrackColor: Theme.of(context).colorScheme.primary,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class IosNavigationRow extends IosListRow {
  const IosNavigationRow({
    super.key,
    super.leading,
    required super.title,
    super.subtitle,
    super.onTap,
    super.tintColor,
  });

  @override
  Widget build(BuildContext context) {
    return IosListRow(
      leading: leading,
      title: title,
      subtitle: subtitle,
      onTap: onTap,
      tintColor: tintColor,
    );
  }
}

class IosMetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  const IosMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: kSpacing14,
        horizontal: kSpacing10,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.28),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: context.isDark ? 0.2 : 0.03,
            ),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: c.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppTheme.radiusCompact),
            ),
            child: Icon(icon, color: c, size: 16),
          ),
          const SizedBox(height: kSpacing8),
          Text(
            value,
            style: context.ts(
              17,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: kSpacing2),
          Text(
            label,
            style: context.ts(
              11,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
