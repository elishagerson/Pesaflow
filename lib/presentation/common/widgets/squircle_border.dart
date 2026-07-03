import 'dart:math';
import 'package:flutter/material.dart';

/// A custom package-free ShapeBorder implementing smooth continuous squircle corners (iOS-style).
class SquircleBorder extends ShapeBorder {
  final BorderSide side;
  final double borderRadius;

  const SquircleBorder({
    this.side = BorderSide.none,
    this.borderRadius = 12.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.all(side.width);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return _getPath(rect.deflate(side.width));
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return _getPath(rect);
  }

  Path _getPath(Rect rect) {
    final Path path = Path();
    final double r = min(borderRadius, min(rect.width / 2, rect.height / 2));
    if (r <= 0) {
      path.addRect(rect);
      return path;
    }

    final double left = rect.left;
    final double top = rect.top;
    final double right = rect.right;
    final double bottom = rect.bottom;

    // Standard iOS squircle ratio approximate control points.
    // Standard circle uses 0.552, iOS squircle uses custom transition offsets.
    final double offset = r * 0.44; 

    path.moveTo(left + r, top);
    
    // Top-Right Corner
    path.lineTo(right - r, top);
    path.cubicTo(right - offset, top, right, top + offset, right, top + r);

    // Bottom-Right Corner
    path.lineTo(right, bottom - r);
    path.cubicTo(right, bottom - offset, right - offset, bottom, right - r, bottom);

    // Bottom-Left Corner
    path.lineTo(left + r, bottom);
    path.cubicTo(left + offset, bottom, left, bottom - offset, left, bottom - r);

    // Top-Left Corner
    path.lineTo(left, top + r);
    path.cubicTo(left, top + offset, left + offset, top, left + r, top);

    path.close();
    return path;
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    if (side.style != BorderStyle.none) {
      final Paint paint = side.toPaint();
      final Path path = getOuterPath(rect, textDirection: textDirection);
      canvas.drawPath(path, paint);
    }
  }

  @override
  ShapeBorder scale(double t) {
    return SquircleBorder(
      side: side.scale(t),
      borderRadius: borderRadius * t,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SquircleBorder) return false;
    return other.side == side && other.borderRadius == borderRadius;
  }

  @override
  int get hashCode => Object.hash(side, borderRadius);
}
