import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// Hero rect interpolation using an ease-out-cubic curve for a smooth
/// (non-spring) flight between the source and destination rects.
class CubicHeroRectTween extends RectTween {
  CubicHeroRectTween({required Rect super.begin, required Rect super.end});

  @override
  Rect evaluate(Animation<double> animation) {
    final double t = Curves.easeOutCubic.transform(animation.value);

    final double? left = ui.lerpDouble(begin?.left, end?.left, t);
    final double? top = ui.lerpDouble(begin?.top, end?.top, t);
    final double? right = ui.lerpDouble(begin?.right, end?.right, t);
    final double? bottom = ui.lerpDouble(begin?.bottom, end?.bottom, t);

    if (left == null || top == null || right == null || bottom == null) {
      return Rect.zero;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }
}
