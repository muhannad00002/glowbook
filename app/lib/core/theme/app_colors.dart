import 'package:flutter/material.dart';

/// Glowbook palette: a warm porcelain neutral base with a rosewood-mauve primary,
/// champagne and sage accents. Pink is an accent, never the whole room.
///
/// Semantic extras (status colours, gradients, soft shadows) live in [GlowColors],
/// a ThemeExtension, so widgets never hard-code hex values.
abstract final class Palette {
  // Light
  static const porcelain = Color(0xFFFAF7F4);
  static const linen = Color(0xFFF3EEEA);
  static const sand = Color(0xFFE6DDD6);
  static const ink = Color(0xFF2A2330);
  static const inkMuted = Color(0xFF6E6470);
  static const rosewood = Color(0xFF8E4B61);
  static const rosewoodSoft = Color(0xFFF4E3E8);
  static const rosewoodDeep = Color(0xFF4A2130);
  static const champagne = Color(0xFF8A5E3B);
  static const champagneSoft = Color(0xFFF6EADF);
  static const sage = Color(0xFF4F7265);
  static const sageSoft = Color(0xFFE3EEE9);

  // Dark
  static const night = Color(0xFF151217);
  static const nightSurface = Color(0xFF1E1A21);
  static const nightRaised = Color(0xFF2A2430);
  static const nightOutline = Color(0xFF3A3240);
  static const moon = Color(0xFFF3ECEF);
  static const moonMuted = Color(0xFFB9AEB7);
  static const blush = Color(0xFFE4A9BB);
  static const blushDeep = Color(0xFF5C3042);
  static const gold = Color(0xFFE3BE98);
  static const mint = Color(0xFF9CC3B4);
}

@immutable
class StatusColors {
  const StatusColors(this.fg, this.bg);
  final Color fg;
  final Color bg;
}

@immutable
class GlowColors extends ThemeExtension<GlowColors> {
  const GlowColors({
    required this.pending,
    required this.confirmed,
    required this.arrived,
    required this.inService,
    required this.completed,
    required this.cancelled,
    required this.noShow,
    required this.heroGradient,
    required this.cardGradient,
    required this.shadow,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.success,
  });

  final StatusColors pending;
  final StatusColors confirmed;
  final StatusColors arrived;
  final StatusColors inService;
  final StatusColors completed;
  final StatusColors cancelled;
  final StatusColors noShow;
  final Gradient heroGradient;
  final Gradient cardGradient;
  final Color shadow;
  final Color shimmerBase;
  final Color shimmerHighlight;
  final Color success;

  static const light = GlowColors(
    pending: StatusColors(Color(0xFF9A6415), Color(0xFFFBF0DC)),
    confirmed: StatusColors(Palette.rosewood, Palette.rosewoodSoft),
    arrived: StatusColors(Color(0xFF5B4DB5), Color(0xFFECE9FA)),
    inService: StatusColors(Color(0xFF256B68), Color(0xFFDDF0EE)),
    completed: StatusColors(Color(0xFF356B42), Color(0xFFE2F1E5)),
    cancelled: StatusColors(Color(0xFF6E646C), Color(0xFFEFEBEE)),
    noShow: StatusColors(Color(0xFFA2324A), Color(0xFFF9E1E6)),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFF4E3E8), Color(0xFFF6EADF), Color(0xFFEFF3EE)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF9A5670), Color(0xFF7C3F55)],
    ),
    shadow: Color(0x1A4A2130),
    shimmerBase: Color(0xFFEFE8E3),
    shimmerHighlight: Color(0xFFFBF8F6),
    success: Color(0xFF356B42),
  );

  static const dark = GlowColors(
    pending: StatusColors(Color(0xFFF2C77E), Color(0xFF3B2F1C)),
    confirmed: StatusColors(Palette.blush, Palette.blushDeep),
    arrived: StatusColors(Color(0xFFBDB3FF), Color(0xFF2E2A4D)),
    inService: StatusColors(Color(0xFF8FD6CF), Color(0xFF1C3634)),
    completed: StatusColors(Color(0xFFA5D6AE), Color(0xFF1F3323)),
    cancelled: StatusColors(Color(0xFFB9AEB7), Color(0xFF2E2930)),
    noShow: StatusColors(Color(0xFFF5A3B4), Color(0xFF45222B)),
    heroGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF34222C), Color(0xFF2C2420), Color(0xFF1E2622)],
    ),
    cardGradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF6B3A4D), Color(0xFF4A2636)],
    ),
    shadow: Color(0x66000000),
    shimmerBase: Color(0xFF2A2430),
    shimmerHighlight: Color(0xFF383040),
    success: Color(0xFFA5D6AE),
  );

  StatusColors forStatus(String status) => switch (status) {
        'PENDING' => pending,
        'CONFIRMED' => confirmed,
        'ARRIVED' => arrived,
        'IN_SERVICE' => inService,
        'COMPLETED' => completed,
        'CANCELLED' => cancelled,
        'NO_SHOW' => noShow,
        _ => cancelled,
      };

  @override
  GlowColors copyWith() => this;

  @override
  GlowColors lerp(ThemeExtension<GlowColors>? other, double t) => t < 0.5 ? this : (other as GlowColors? ?? this);
}

extension GlowTheme on BuildContext {
  GlowColors get glow => Theme.of(this).extension<GlowColors>()!;
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

/// Parses "#RRGGBB" staff colours from the API.
Color hexColor(String? hex, {Color fallback = Palette.rosewood}) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return fallback;
  return Color(int.parse('FF${hex.substring(1)}', radix: 16));
}
