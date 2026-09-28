import 'package:flutter/material.dart';

/// Spacing scale (4dp rhythm). Use these instead of raw numbers.
abstract final class Space {
  static const double xxs = 2;
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;

  /// Horizontal page gutter by width class.
  static double gutter(double width) => width >= 1200
      ? 40
      : width >= 840
          ? 32
          : width >= 600
              ? 24
              : 16;
}

abstract final class Radii {
  static const double sm = 10;
  static const double md = 16;
  static const double lg = 22;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius smAll = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius mdAll = BorderRadius.all(Radius.circular(md));
  static const BorderRadius lgAll = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius xlAll = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pillAll = BorderRadius.all(Radius.circular(pill));
}

/// Layout breakpoints: phone → bottom nav, tablet → rail, desktop → sidebar.
abstract final class Breakpoints {
  static const double tablet = 700;
  static const double desktop = 1100;
  static const double maxContent = 1240;
  static const double maxReading = 720;
}

abstract final class IconSizes {
  static const double sm = 18;
  static const double md = 22;
  static const double lg = 28;
}
