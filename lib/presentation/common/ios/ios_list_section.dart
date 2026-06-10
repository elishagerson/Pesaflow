import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/core/theme/app_theme.dart';
import 'package:pesaflow/presentation/common/widgets/glass_card.dart';

class IosListSection extends StatelessWidget {
  final String? header;
  final List<IosListRow> rows;
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
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 6, top: 24),
            child: Text(
              header!.toUpperCase(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                letterSpacing: 0.5,
              ),
            ),
          ),
        GlassCard(
          margin: margin ?? const EdgeInsets.symmetric(horizontal: 16),
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
                      indent: row.indent ?? 56,
                      color: isDark ? const Color(0x12FFFFFF) : const Color(0x0F000000),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 14),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DefaultTextStyle(
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w400,
                    fontSize: 17,
                  ) ?? const TextStyle(fontSize: 17, fontWeight: FontWeight.w400),
                  child: title,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  DefaultTextStyle(
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    child: subtitle!,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ] else if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark(context) ? Colors.grey[500] : Colors.grey[400],
            ),
        ],
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap!();
        },
        child: content,
      );
    }
    return content;
  }

  bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;
}

class IosToggleRow extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const IosToggleRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
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
          activeColor: Theme.of(context).colorScheme.primary,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class IosNavigationRow extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final VoidCallback? onTap;
  final Color? tintColor;

  const IosNavigationRow({
    super.key,
    this.leading,
    required this.title,
    this.subtitle,
    this.onTap,
    this.tintColor,
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
    final isDark = theme.brightness == Brightness.dark;
    final c = color ?? (isDark ? const Color(0xFF00E5FF) : const Color(0xFF0A84FF));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.surfaceHighDark : AppTheme.surfaceLight,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        border: Border.all(
          color: isDark ? const Color(0x12FFFFFF) : const Color(0x0F000000),
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: c, size: 22),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 18,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}
