import 'package:flutter/services.dart';

enum HapticType { success, error, warning, selection, impact }

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
  }
}
