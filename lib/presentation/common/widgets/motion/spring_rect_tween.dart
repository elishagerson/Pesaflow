import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class SpringRectTween extends RectTween {
  SpringRectTween({required Rect super.begin, required Rect super.end});

  @override
  Rect evaluate(Animation<double> animation) {
    // Custom spring overshoot curve
    final double t = Curves.elasticOut.transform(animation.value);

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
