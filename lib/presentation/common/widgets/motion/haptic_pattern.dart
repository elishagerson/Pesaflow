import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:pesaflow/core/utils/context_extensions.dart';

enum HapticType {
  /// Confirm a successful action (save, approve).
  success,

  /// Signal a destructive or failed action (delete, error).
  error,

  /// Caution or heads-up feedback.
  warning,

  /// Lightweight tap acknowledgement (navigation, selection).
  selection,

  /// Standard tap impact.
  impact,

  /// Minimal click — tab switches, toggles.
  soft,

  /// Firm double-click — delete confirmations, irreversible actions.
  rigid,
}

void triggerHaptic(HapticType type) {
  switch (type) {
    case HapticType.success:
      HapticFeedback.mediumImpact();
      break;
    case HapticType.error:
      HapticFeedback.heavyImpact();
      break;
    case HapticType.warning:
      HapticFeedback.mediumImpact();
      break;
    case HapticType.selection:
      HapticFeedback.selectionClick();
      break;
    case HapticType.impact:
      HapticFeedback.lightImpact();
      break;
    case HapticType.soft:
      HapticFeedback.selectionClick();
      break;
    case HapticType.rigid:
      HapticFeedback.lightImpact();
      Future.delayed(const Duration(milliseconds: 50), () {
        HapticFeedback.lightImpact();
      });
      break;
  }
}

/// Fires haptic only if the user hasn't enabled reduced motion.
///
/// Use when haptic is paired with an animation that gets skipped
/// under reduced motion — the haptic alone without the visual context
/// can be confusing.
void triggerHapticIf(BuildContext context, HapticType type) {
  if (context.isReducedMotion) return;
  triggerHaptic(type);
}
