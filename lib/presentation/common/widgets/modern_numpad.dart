import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';
import 'package:pesaflow/core/utils/pesaflow_icons.dart';
import 'package:pesaflow/core/utils/spacing.dart';
import 'package:pesaflow/presentation/common/widgets/tactile_spring_container.dart';

class ModernNumpad extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback? onDone;
  final String? doneLabel;
  final bool isDoneLoading;
  final int maxLength;

  const ModernNumpad({
    super.key,
    required this.controller,
    this.onDone,
    this.doneLabel,
    this.isDoneLoading = false,
    this.maxLength = 12,
  });

  void _onKeyPress(String value) {
    HapticFeedback.lightImpact();
    if (controller.text.length >= maxLength) return;
    
    if (controller.text == '0' && value != '.') {
      controller.text = value;
    } else {
      controller.text += value;
    }
  }

  void _onBackspace() {
    HapticFeedback.lightImpact();
    if (controller.text.isNotEmpty) {
      controller.text = controller.text.substring(0, controller.text.length - 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    Widget buildKey(String label, {VoidCallback? onTap, Widget? icon, Color? color, Color? textColor}) {
      return Expanded(
        child: Padding(
          padding: const EdgeInsets.all(kSpacing6),
          child: TactileSpringContainer(
            onTap: onTap ?? () => _onKeyPress(label),
            child: Container(
              height: 64,
              decoration: BoxDecoration(
                color: color ?? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: icon ?? Text(
                label,
                style: context.ts(24, fontWeight: FontWeight.w600, color: textColor ?? theme.colorScheme.onSurface),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(kSpacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              buildKey('1'),
              buildKey('2'),
              buildKey('3'),
            ],
          ),
          Row(
            children: [
              buildKey('4'),
              buildKey('5'),
              buildKey('6'),
            ],
          ),
          Row(
            children: [
              buildKey('7'),
              buildKey('8'),
              buildKey('9'),
            ],
          ),
          Row(
            children: [
              buildKey('00'),
              buildKey('0'),
              buildKey(
                '⌫',
                onTap: _onBackspace,
                icon: Icon(PesaFlowIcons.delete, color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
            ],
          ),
          const SizedBox(height: kSpacing12),
          if (onDone != null)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: TactileSpringContainer(
                onTap: () {
                  HapticFeedback.mediumImpact();
                  onDone!();
                },
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: isDoneLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text(
                          doneLabel ?? 'Done',
                          style: context.ts(18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}
