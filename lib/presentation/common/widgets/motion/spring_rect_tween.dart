import 'package:flutter/material.dart';

class SpringRectTween extends RectTween {
  SpringRectTween({required Rect super.begin, required Rect super.end});

  @override
  Rect evaluate(Animation<double> animation) {
    // Custom spring overshoot curve
    final double t = Curves.elasticOut.transform(animation.value);
    
    final double? left = lerpDouble(begin?.left, end?.left, t);
    final double? top = lerpDouble(begin?.top, end?.top, t);
    final double? right = lerpDouble(begin?.right, end?.right, t);
    final double? bottom = lerpDouble(begin?.bottom, end?.bottom, t);

    if (left == null || top == null || right == null || bottom == null) {
      return Rect.zero;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

  double? lerpDouble(double? a, double? b, double t) {
    if (a == null || b == null) return null;
    return a + (b - a) * t;
  }
}
