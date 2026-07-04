import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';

import 'package:pesaflow/core/utils/spacing.dart';

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
              left: kSpacing16,
              bottom: kSpacing6,
              top: kSpacing24,
            ),
            child: Text(
              header!,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                letterSpacing: 0.3,
              ),
            ),
          ),
        GlassCard(
          margin: margin ?? const EdgeInsets.symmetric(horizontal: kSpacing16),
          padding: EdgeInsets.zero,
          frosted: true,
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
                      indent: row is IosListRow ? row.indent ?? 56 : 56,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.07,
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
          if (leading != null) ...[leading!, const SizedBox(width: kSpacing14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle.merge(
                  style: theme.textTheme.bodyLarge!,
                  child: title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: kSpacing2),
                  DefaultTextStyle.merge(
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
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
              Icons.chevron_right_rounded,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
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
    final c = color ?? context.appColors.incomeColor;

    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: kSpacing16,
        horizontal: kSpacing12,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
      ),
      child: Column(
        children: [
          Icon(icon, color: c, size: 22),
          const SizedBox(height: kSpacing8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: kSpacing2),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}
