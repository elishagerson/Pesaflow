import 'dart:math';
import 'package:flutter/material.dart';

class PesaFlowIllustration extends StatelessWidget {
  final double size;
  final Color primaryColor;
  final Color accentColor;
  final CustomPainter painter;

  const PesaFlowIllustration({
    super.key,
    this.size = 120,
    Color? color,
    Color? accentColor,
    required this.painter,
  }) : primaryColor = color ?? const Color(0xFF0F4C5C),
       accentColor = accentColor ?? const Color(0xFFD4942D);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: painter, size: Size(size, size)),
    );
  }

  static const Color _teal = Color(0xFF0F4C5C);
  static const Color _gold = Color(0xFFD4942D);

  factory PesaFlowIllustration.emptyTransactions({
    double size = 120,
    Color? color,
  }) {
    final p = color ?? _teal;
    return PesaFlowIllustration(
      size: size,
      color: color,
      painter: _TransactionsPainter(p, _gold),
    );
  }

  factory PesaFlowIllustration.emptyBudgets({double size = 120, Color? color}) {
    final p = color ?? _teal;
    return PesaFlowIllustration(
      size: size,
      color: color,
      painter: _BudgetsPainter(p, _gold),
    );
  }

  factory PesaFlowIllustration.emptyGoals({double size = 120, Color? color}) {
    final p = color ?? _teal;
    return PesaFlowIllustration(
      size: size,
      color: color,
      painter: _GoalsPainter(p, _gold),
    );
  }

  factory PesaFlowIllustration.emptyLoans({double size = 120, Color? color}) {
    final p = color ?? _teal;
    return PesaFlowIllustration(
      size: size,
      color: color,
      painter: _LoansPainter(p, _gold),
    );
  }

  factory PesaFlowIllustration.emptySubscriptions({
    double size = 120,
    Color? color,
  }) {
    final p = color ?? _teal;
    return PesaFlowIllustration(
      size: size,
      color: color,
      painter: _SubscriptionsPainter(p, _gold),
    );
  }
}

// ─── Transactions (Wallet / Receipt) ─────────────────────────────────────────

class _TransactionsPainter extends CustomPainter {
  _TransactionsPainter(this.primary, this.accent);
  final Color primary;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, h * 0.54),
        width: w * 0.5,
        height: h * 0.7,
      ),
      const Radius.circular(10),
    );

    canvas.drawRRect(rrect, Paint()..color = primary.withValues(alpha: 0.08));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = primary.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final linePaint = Paint()
      ..color = primary.withValues(alpha: 0.18)
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(w * 0.33, h * 0.30 + i * (h * 0.12), w * 0.34, 3.5),
          const Radius.circular(2),
        ),
        linePaint,
      );
    }

    final zigzag = Paint()
      ..color = accent.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final zx = w * 0.3;
    final zy = h * 0.72;
    final path = Path()..moveTo(zx, zy);
    for (int i = 0; i < 4; i++) {
      path.relativeLineTo(7, 5);
      path.relativeLineTo(7, -5);
    }
    canvas.drawPath(path, zigzag);

    canvas.drawCircle(
      Offset(w * 0.7, h * 0.22),
      9,
      Paint()..color = accent.withValues(alpha: 0.15),
    );
    canvas.drawCircle(
      Offset(w * 0.7, h * 0.22),
      9,
      Paint()
        ..color = accent.withValues(alpha: 0.4)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      Offset(w * 0.7, h * 0.22),
      4,
      Paint()..color = accent.withValues(alpha: 0.5),
    );
  }

  @override
  bool shouldRepaint(_TransactionsPainter old) =>
      old.primary != primary || old.accent != accent;
}

// ─── Budgets (Progress gauge) ────────────────────────────────────────────────

class _BudgetsPainter extends CustomPainter {
  _BudgetsPainter(this.primary, this.accent);
  final Color primary;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h * 0.6;
    final radius = w * 0.38;

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      pi,
      pi,
      false,
      Paint()
        ..color = primary.withValues(alpha: 0.1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: radius),
      pi,
      pi * 0.65,
      false,
      Paint()
        ..color = accent.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );

    final angle = pi + pi * 0.65;
    final nl = radius * 0.85;
    canvas.drawLine(
      Offset(cx, cy),
      Offset(cx + cos(angle) * nl, cy + sin(angle) * nl),
      Paint()
        ..color = primary
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = primary);

    for (int i = 0; i < 5; i++) {
      final a = pi + pi * (i / 4);
      final r1 = radius - 6;
      final r2 = radius + 6;
      canvas.drawLine(
        Offset(cx + cos(a) * r1, cy + sin(a) * r1),
        Offset(cx + cos(a) * r2, cy + sin(a) * r2),
        Paint()
          ..color = primary.withValues(alpha: 0.3)
          ..strokeWidth = 1.5,
      );
    }
  }

  @override
  bool shouldRepaint(_BudgetsPainter old) =>
      old.primary != primary || old.accent != accent;
}

// ─── Goals (Target / Bullseye) ───────────────────────────────────────────────

class _GoalsPainter extends CustomPainter {
  _GoalsPainter(this.primary, this.accent);
  final Color primary;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    canvas.drawCircle(
      Offset(cx, cy),
      w * 0.4,
      Paint()..color = accent.withValues(alpha: 0.1),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      w * 0.4,
      Paint()
        ..color = accent.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.drawCircle(
      Offset(cx, cy),
      w * 0.27,
      Paint()..color = primary.withValues(alpha: 0.1),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      w * 0.27,
      Paint()
        ..color = primary.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    canvas.drawCircle(
      Offset(cx, cy),
      w * 0.14,
      Paint()..color = accent.withValues(alpha: 0.2),
    );
    canvas.drawCircle(
      Offset(cx, cy),
      w * 0.14,
      Paint()
        ..color = accent.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final crossPaint = Paint()
      ..color = primary.withValues(alpha: 0.2)
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(w * 0.15, cy), Offset(w * 0.85, cy), crossPaint);
    canvas.drawLine(Offset(cx, h * 0.15), Offset(cx, h * 0.85), crossPaint);

    canvas.drawCircle(Offset(cx, cy), 4, Paint()..color = accent);
  }

  @override
  bool shouldRepaint(_GoalsPainter old) =>
      old.primary != primary || old.accent != accent;
}

// ─── Loans (Document / Contract) ─────────────────────────────────────────────

class _LoansPainter extends CustomPainter {
  _LoansPainter(this.primary, this.accent);
  final Color primary;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(cx, h * 0.5),
        width: w * 0.48,
        height: h * 0.72,
      ),
      const Radius.circular(8),
    );

    canvas.drawRRect(rrect, Paint()..color = primary.withValues(alpha: 0.07));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = primary.withValues(alpha: 0.2)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(w * 0.33, h * 0.25, w * 0.3, 4),
        const Radius.circular(2),
      ),
      Paint()..color = primary.withValues(alpha: 0.25),
    );

    for (int i = 0; i < 3; i++) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            w * 0.33,
            h * 0.37 + i * (h * 0.09),
            w * 0.24 + (i == 2 ? 0 : w * 0.06),
            3,
          ),
          const Radius.circular(1.5),
        ),
        Paint()..color = primary.withValues(alpha: 0.15),
      );
    }

    final sigPaint = Paint()
      ..color = primary.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final sx = w * 0.33;
    final sy = h * 0.72;
    final sigPath = Path()..moveTo(sx, sy);
    for (int i = 0; i < 6; i++) {
      sigPath.relativeCubicTo(3, -3, 5, 3, 8, 0);
    }
    canvas.drawPath(sigPath, sigPaint);

    canvas.drawCircle(
      Offset(w * 0.68, h * 0.76),
      12,
      Paint()..color = accent.withValues(alpha: 0.15),
    );
    canvas.drawCircle(
      Offset(w * 0.68, h * 0.76),
      12,
      Paint()
        ..color = accent.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final checkPaint = Paint()
      ..color = accent.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final chk = Path()
      ..moveTo(w * 0.64, h * 0.76)
      ..lineTo(w * 0.67, h * 0.79)
      ..lineTo(w * 0.72, h * 0.73);
    canvas.drawPath(chk, checkPaint);
  }

  @override
  bool shouldRepaint(_LoansPainter old) =>
      old.primary != primary || old.accent != accent;
}

// ─── Subscriptions (Recurring / Refresh) ─────────────────────────────────────

class _SubscriptionsPainter extends CustomPainter {
  _SubscriptionsPainter(this.primary, this.accent);
  final Color primary;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;
    final r = w * 0.34;

    canvas.drawCircle(
      Offset(cx, cy),
      r + 6,
      Paint()..color = primary.withValues(alpha: 0.06),
    );

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      -pi * 0.1,
      pi * 1.2,
      false,
      Paint()
        ..color = primary.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    final angle1 = -pi * 0.1 + pi * 1.2;
    final hx1 = cx + cos(angle1) * r;
    final hy1 = cy + sin(angle1) * r;
    final headPaint = Paint()..color = primary.withValues(alpha: 0.45);
    final head1 = Path()
      ..moveTo(hx1, hy1)
      ..lineTo(hx1 - cos(angle1 - 0.4) * 10, hy1 - sin(angle1 - 0.4) * 10)
      ..lineTo(hx1 - cos(angle1 + 0.4) * 10, hy1 - sin(angle1 + 0.4) * 10)
      ..close();
    canvas.drawPath(head1, headPaint);

    canvas.drawArc(
      Rect.fromCircle(center: Offset(cx, cy), radius: r),
      pi - pi * 0.1,
      pi * 1.2,
      false,
      Paint()
        ..color = accent.withValues(alpha: 0.45)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );

    final angle2 = pi - pi * 0.1 + pi * 1.2;
    final hx2 = cx + cos(angle2) * r;
    final hy2 = cy + sin(angle2) * r;
    final headPaint2 = Paint()..color = accent.withValues(alpha: 0.45);
    final head2 = Path()
      ..moveTo(hx2, hy2)
      ..lineTo(hx2 - cos(angle2 - 0.4) * 10, hy2 - sin(angle2 - 0.4) * 10)
      ..lineTo(hx2 - cos(angle2 + 0.4) * 10, hy2 - sin(angle2 + 0.4) * 10)
      ..close();
    canvas.drawPath(head2, headPaint2);

    canvas.drawCircle(
      Offset(cx, cy),
      4,
      Paint()..color = primary.withValues(alpha: 0.3),
    );
  }

  @override
  bool shouldRepaint(_SubscriptionsPainter old) =>
      old.primary != primary || old.accent != accent;
}
