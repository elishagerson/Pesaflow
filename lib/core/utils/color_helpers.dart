import 'package:flutter/material.dart';

/// Desaturates a color by [factor] (0.0 = original, 1.0 = fully gray).
/// Useful for muting user-defined category colors in card backgrounds
/// while keeping them vibrant in icons.
Color desaturateColor(Color color, {double factor = 0.3}) {
  final hsl = HSLColor.fromColor(color);
  final desaturated = hsl.withSaturation(
    (hsl.saturation * (1.0 - factor)).clamp(0.0, 1.0),
  );
  return desaturated.toColor();
}

Color hexToColor(String hex) {
  final clean = hex.replaceAll('#', '');
  if (clean.length == 6) {
    try {
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return Colors.grey;
    }
  }
  return Colors.grey;
}
