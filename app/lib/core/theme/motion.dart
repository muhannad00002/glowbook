import 'package:flutter/widgets.dart';

/// Motion tokens. Every animation in the app reads its duration through [Motion.of]
/// so the OS "reduce motion" setting collapses them to zero in one place.
class Motion {
  const Motion._(this.reduced);
  final bool reduced;

  static Motion of(BuildContext context) => Motion._(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  Duration _d(int ms) => reduced ? Duration.zero : Duration(milliseconds: ms);

  /// Taps, toggles, chips.
  Duration get fast => _d(150);

  /// Most transitions: cards, switchers, indicators.
  Duration get medium => _d(260);

  /// Page-level and celebratory moments.
  Duration get slow => _d(420);

  /// Delay between staggered list items.
  Duration stagger(int index) => reduced ? Duration.zero : Duration(milliseconds: 40 * index.clamp(0, 10));

  static const Curve standard = Curves.easeOutCubic;
  static const Curve emphasized = Curves.easeInOutCubicEmphasized;
  static const Curve pop = Curves.easeOutBack;
  static const Curve exit = Curves.easeInCubic;
}
