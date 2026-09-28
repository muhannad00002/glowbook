import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Hand-drawn (CustomPainter) spot illustrations — no image assets, crisp at any
/// size, and they follow the theme in light and dark.
enum GlowArt { mirror, calendar, bell, lipstick, sparkles, brush }

class GlowIllustration extends StatelessWidget {
  const GlowIllustration(this.art, {super.key, this.size = 120});
  final GlowArt art;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = context.colors;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _ArtPainter(
            art,
            primary: s.primary,
            soft: s.primaryContainer,
            accent: s.secondary,
            accentSoft: s.secondaryContainer,
            sage: s.tertiary,
            line: s.onSurface.withValues(alpha: 0.75),
            paper: s.surface,
          ),
        ),
      ),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.art, {required this.primary, required this.soft, required this.accent, required this.accentSoft, required this.sage, required this.line, required this.paper});
  final GlowArt art;
  final Color primary, soft, accent, accentSoft, sage, line, paper;

  Paint fill(Color c) => Paint()..color = c;
  Paint stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 100; // draw on a 100×100 grid
    // Backdrop blob.
    canvas.drawCircle(Offset(50 * u, 54 * u), 40 * u, fill(soft));
    canvas.drawCircle(Offset(78 * u, 26 * u), 9 * u, fill(accentSoft));
    final w = 2.4 * u;

    switch (art) {
      case GlowArt.mirror:
        final r = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(50 * u, 46 * u), width: 38 * u, height: 46 * u), Radius.circular(19 * u));
        canvas.drawRRect(r, fill(paper));
        canvas.drawRRect(r, stroke(line, w));
        canvas.drawLine(Offset(40 * u, 38 * u), Offset(46 * u, 32 * u), stroke(soft, 3 * u));
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(50 * u, 76 * u), width: 8 * u, height: 14 * u), Radius.circular(3 * u)), fill(primary));
        _smile(canvas, u, Offset(50 * u, 50 * u), w);
      case GlowArt.calendar:
        final r = RRect.fromRectAndRadius(Rect.fromLTWH(24 * u, 28 * u, 52 * u, 48 * u), Radius.circular(10 * u));
        canvas.drawRRect(r, fill(paper));
        canvas.drawRRect(RRect.fromRectAndCorners(Rect.fromLTWH(24 * u, 28 * u, 52 * u, 13 * u), topLeft: Radius.circular(10 * u), topRight: Radius.circular(10 * u)), fill(primary));
        canvas.drawRRect(r, stroke(line, w));
        canvas.drawLine(Offset(36 * u, 22 * u), Offset(36 * u, 32 * u), stroke(line, w));
        canvas.drawLine(Offset(64 * u, 22 * u), Offset(64 * u, 32 * u), stroke(line, w));
        _heart(canvas, Offset(50 * u, 60 * u), 9 * u, primary);
      case GlowArt.bell:
        final body = Path()
          ..moveTo(30 * u, 66 * u)
          ..quadraticBezierTo(34 * u, 58 * u, 34 * u, 46 * u)
          ..quadraticBezierTo(34 * u, 28 * u, 50 * u, 28 * u)
          ..quadraticBezierTo(66 * u, 28 * u, 66 * u, 46 * u)
          ..quadraticBezierTo(66 * u, 58 * u, 70 * u, 66 * u)
          ..close();
        canvas.drawPath(body, fill(paper));
        canvas.drawPath(body, stroke(line, w));
        canvas.drawCircle(Offset(50 * u, 72 * u), 5 * u, fill(primary));
        canvas.drawCircle(Offset(50 * u, 24 * u), 3 * u, fill(accent));
      case GlowArt.lipstick:
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(38 * u, 54 * u, 24 * u, 26 * u), Radius.circular(4 * u)), fill(accent));
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(41 * u, 42 * u, 18 * u, 14 * u), Radius.circular(3 * u)), fill(paper));
        final tip = Path()
          ..moveTo(43 * u, 43 * u)
          ..lineTo(43 * u, 30 * u)
          ..quadraticBezierTo(50 * u, 20 * u, 57 * u, 26 * u)
          ..lineTo(57 * u, 43 * u)
          ..close();
        canvas.drawPath(tip, fill(primary));
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(38 * u, 42 * u, 24 * u, 38 * u), Radius.circular(4 * u)), stroke(line, w));
      case GlowArt.brush:
        canvas.save();
        canvas.translate(50 * u, 52 * u);
        canvas.rotate(-math.pi / 5);
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, 14 * u), width: 8 * u, height: 36 * u), Radius.circular(4 * u)), fill(accent));
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(0, -8 * u), width: 12 * u, height: 10 * u), Radius.circular(2 * u)), fill(line));
        final bristles = Path()
          ..moveTo(-6 * u, -12 * u)
          ..quadraticBezierTo(-10 * u, -30 * u, 0, -34 * u)
          ..quadraticBezierTo(10 * u, -30 * u, 6 * u, -12 * u)
          ..close();
        canvas.drawPath(bristles, fill(primary));
        canvas.restore();
      case GlowArt.sparkles:
        _sparkle(canvas, Offset(50 * u, 50 * u), 20 * u, primary);
        _sparkle(canvas, Offset(30 * u, 32 * u), 8 * u, accent);
        _sparkle(canvas, Offset(70 * u, 70 * u), 7 * u, sage);
    }
    _sparkle(canvas, Offset(80 * u, 58 * u), 5 * u, accent);
    _sparkle(canvas, Offset(20 * u, 70 * u), 4 * u, primary);
  }

  void _smile(Canvas canvas, double u, Offset c, double w) {
    canvas.drawCircle(c + Offset(-6 * u, -4 * u), 1.6 * u, fill(line));
    canvas.drawCircle(c + Offset(6 * u, -4 * u), 1.6 * u, fill(line));
    canvas.drawArc(Rect.fromCenter(center: c + Offset(0, 1 * u), width: 10 * u, height: 8 * u), 0.2, math.pi - 0.4, false, stroke(line, w * 0.8));
    canvas.drawCircle(c + Offset(-11 * u, 2 * u), 2.6 * u, fill(soft));
    canvas.drawCircle(c + Offset(11 * u, 2 * u), 2.6 * u, fill(soft));
  }

  void _heart(Canvas canvas, Offset c, double r, Color color) {
    final p = Path()
      ..moveTo(c.dx, c.dy + r)
      ..cubicTo(c.dx - r * 1.6, c.dy - r * 0.2, c.dx - r * 0.6, c.dy - r * 1.4, c.dx, c.dy - r * 0.4)
      ..cubicTo(c.dx + r * 0.6, c.dy - r * 1.4, c.dx + r * 1.6, c.dy - r * 0.2, c.dx, c.dy + r);
    canvas.drawPath(p, fill(color));
  }

  void _sparkle(Canvas canvas, Offset p, double r, Color color) {
    final path = Path()
      ..moveTo(p.dx, p.dy - r)
      ..quadraticBezierTo(p.dx, p.dy, p.dx + r, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r)
      ..quadraticBezierTo(p.dx, p.dy, p.dx - r, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r);
    canvas.drawPath(path, fill(color));
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.art != art || old.primary != primary || old.paper != paper;
}
