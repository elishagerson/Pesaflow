import 'package:pesaflow/core/utils/haptics.dart';

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
      PesaHaptics.success();
      break;
    case HapticType.error:
      PesaHaptics.error();
      break;
    case HapticType.warning:
      PesaHaptics.medium();
      break;
    case HapticType.selection:
      PesaHaptics.selection();
      break;
    case HapticType.impact:
      PesaHaptics.light();
      break;
    case HapticType.soft:
      PesaHaptics.light();
      break;
    case HapticType.rigid:
      PesaHaptics.heavy();
      break;
  }
}

