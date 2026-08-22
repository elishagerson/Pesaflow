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
          padding: const EdgeInsets.all(kSpacing4),
          child: TactileSpringContainer(
            onTap: onTap ?? () => _onKeyPress(label),
            child: Container(
              height: 80,
              decoration: BoxDecoration(
                color: color ?? theme.colorScheme.onSurface.withValues(alpha: 0.04),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: icon ?? Text(
                label,
                style: context.ts(36, fontWeight: FontWeight.w400, color: textColor ?? theme.colorScheme.onSurface),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(kSpacing16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: 0.5),
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
              buildKey('⌫', onTap: _onBackspace, icon: Icon(PesaFlowIcons.delete, color: theme.colorScheme.onSurfaceVariant)),
              buildKey('0'),
              // Integrated Save Button
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(kSpacing4),
                  child: TactileSpringContainer(
                    onTap: () {
                      if (onDone != null && !isDoneLoading) {
                        HapticFeedback.mediumImpact();
                        onDone!();
                      }
                    },
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [theme.colorScheme.primary, theme.colorScheme.tertiary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      alignment: Alignment.center,
                      child: isDoneLoading
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.check, size: 36, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + kSpacing16),
        ],
      ),
    );
  }
}
