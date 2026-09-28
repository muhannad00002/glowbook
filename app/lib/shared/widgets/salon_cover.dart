import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Salon artwork: the cover photo when there is one, otherwise a soft gradient with
/// the salon's monogram and a scatter of sparkles, seeded by name so each salon
/// gets its own consistent look.
class SalonCover extends StatelessWidget {
  const SalonCover({super.key, required this.name, this.imageUrl, this.height = 160, this.radius = 0, this.monogramSize = 56});
  final String name;
  final String? imageUrl;
  final double height;
  final double radius;
  final double monogramSize;

  static const _palettes = [
    [Color(0xFFF4E3E8), Color(0xFFE9CFD8), Color(0xFFF6EADF)],
    [Color(0xFFF6EADF), Color(0xFFEBD9C6), Color(0xFFF3E6EA)],
    [Color(0xFFE3EEE9), Color(0xFFF1E6DD), Color(0xFFF4E3E8)],
    [Color(0xFFECE6F4), Color(0xFFF4E3E8), Color(0xFFF6EFE8)],
  ];
  static const _darkPalettes = [
    [Color(0xFF3A2430), Color(0xFF2E1F28), Color(0xFF33291F)],
    [Color(0xFF33291F), Color(0xFF2B2320), Color(0xFF34232D)],
    [Color(0xFF1F2E29), Color(0xFF2A241F), Color(0xFF34232D)],
    [Color(0xFF2B2538), Color(0xFF34232D), Color(0xFF2A251F)],
  ];

  @override
  Widget build(BuildContext context) {
    final seed = name.codeUnits.fold<int>(0, (a, b) => a + b);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final colors = (dark ? _darkPalettes : _palettes)[seed % _palettes.length];
    final initial = name.trim().isEmpty ? '·' : name.trim().characters.first.toUpperCase();

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: imageUrl != null
            ? Image.network(imageUrl!, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox())
            : DecoratedBox(
                decoration: BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: colors)),
                child: CustomPaint(
                  painter: _SparklePainter(seed, context.colors.primary.withValues(alpha: dark ? 0.35 : 0.25)),
                  child: Center(
                    child: ExcludeSemantics(
                      child: Text(
                        initial,
                        style: context.text.displayLarge?.copyWith(
                          fontSize: monogramSize,
                          color: context.colors.primary.withValues(alpha: dark ? 0.8 : 0.55),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  _SparklePainter(this.seed, this.color);
  final int seed;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed);
    final paint = Paint()..color = color;
    for (var i = 0; i < 9; i++) {
      final p = Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height);
      final r = 3 + rnd.nextDouble() * 7;
      final path = Path()
        ..moveTo(p.dx, p.dy - r)
        ..quadraticBezierTo(p.dx, p.dy, p.dx + r, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy + r)
        ..quadraticBezierTo(p.dx, p.dy, p.dx - r, p.dy)
        ..quadraticBezierTo(p.dx, p.dy, p.dx, p.dy - r);
      canvas.drawPath(path, paint);
    }
    // A soft arc, like light on a compact mirror.
    canvas.drawArc(
      Rect.fromCircle(center: Offset(size.width * 0.85, size.height * 1.1), radius: size.height * 0.9),
      math.pi,
      math.pi / 2,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.seed != seed || old.color != color;
}
