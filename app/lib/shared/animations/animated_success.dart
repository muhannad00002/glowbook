import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/motion.dart';

/// The celebratory "✓ confirmed" moment: a ring draws itself, the check strokes in,
/// and a small burst of petals and sparkles floats outward. ~1.2s, then still.
class AnimatedSuccess extends StatefulWidget {
  const AnimatedSuccess({super.key, this.size = 132, this.celebrate = true});
  final double size;
  final bool celebrate;
  @override
  State<AnimatedSuccess> createState() => _AnimatedSuccessState();
}

class _AnimatedSuccessState extends State<AnimatedSuccess> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.of(context).reduced) {
      _c.value = 1;
    } else if (_c.value == 0) {
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Semantics(
      label: MaterialLocalizations.of(context).okButtonLabel,
      child: SizedBox.square(
        dimension: widget.size * 1.9,
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, _) => CustomPaint(
            painter: _SuccessPainter(
              t: _c.value,
              ring: scheme.primary,
              fill: scheme.primaryContainer,
              check: scheme.primary,
              confetti: [scheme.primary, scheme.secondary, scheme.tertiary, const Color(0xFFE8B4C4)],
              celebrate: widget.celebrate,
              radius: widget.size / 2,
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessPainter extends CustomPainter {
  _SuccessPainter({required this.t, required this.ring, required this.fill, required this.check, required this.confetti, required this.celebrate, required this.radius});
  final double t;
  final Color ring;
  final Color fill;
  final Color check;
  final List<Color> confetti;
  final bool celebrate;
  final double radius;

  double _seg(double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    // Soft pop-in of the disc.
    final pop = Curves.easeOutBack.transform(_seg(0, 0.35));
    canvas.drawCircle(c, radius * pop, Paint()..color = fill);

    // Ring draws around.
    final ringT = Curves.easeInOut.transform(_seg(0.1, 0.55));
    final ringPaint = Paint()
      ..color = ring
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.07
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(Rect.fromCircle(center: c, radius: radius), -math.pi / 2, 2 * math.pi * ringT, false, ringPaint);

    // Check strokes in.
    final checkT = Curves.easeOutCubic.transform(_seg(0.4, 0.75));
    if (checkT > 0) {
      final p1 = c + Offset(-radius * 0.38, radius * 0.02);
      final p2 = c + Offset(-radius * 0.1, radius * 0.3);
      final p3 = c + Offset(radius * 0.42, -radius * 0.28);
      final path = Path()..moveTo(p1.dx, p1.dy);
      final first = (checkT / 0.4).clamp(0.0, 1.0);
      path.lineTo(p1.dx + (p2.dx - p1.dx) * first, p1.dy + (p2.dy - p1.dy) * first);
      if (checkT > 0.4) {
        final second = ((checkT - 0.4) / 0.6).clamp(0.0, 1.0);
        path.lineTo(p2.dx + (p3.dx - p2.dx) * second, p2.dy + (p3.dy - p2.dy) * second);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = check
          ..style = PaintingStyle.stroke
          ..strokeWidth = radius * 0.12
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Celebration: petals + sparkles drift outward and fade.
    if (!celebrate) return;
    final burst = _seg(0.45, 1.0);
    if (burst <= 0 || burst >= 1) return;
    final ease = Curves.easeOutCubic.transform(burst);
    final fade = 1 - Curves.easeIn.transform(burst);
    const n = 14;
    for (var i = 0; i < n; i++) {
      final angle = (i / n) * 2 * math.pi + (i.isEven ? 0.12 : -0.08);
      final dist = radius * (1.15 + 0.55 * ease * (0.8 + (i % 3) * 0.15));
      final pos = c + Offset(math.cos(angle) * dist, math.sin(angle) * dist + ease * radius * 0.15);
      final color = confetti[i % confetti.length].withValues(alpha: fade);
      if (i % 3 == 0) {
        _sparkle(canvas, pos, radius * 0.09 * (1 - burst * 0.4), color);
      } else {
        canvas.save();
        canvas.translate(pos.dx, pos.dy);
        canvas.rotate(angle + burst * 2);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: radius * 0.1, height: radius * 0.17), Paint()..color = color);
        canvas.restore();
      }
    }
  }

  void _sparkle(Canvas canvas, Offset p, double r, Color color) {
    final path = Path()
      ..moveTo(p.dx, p.dy - r)
      ..quadraticBezierTo(p.dx, p.dy, p.dx + r, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r)
      ..quadraticBezierTo(p.dx, p.dy, p.dx - r, p.dy)
      ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r);
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SuccessPainter old) => old.t != t;
}
