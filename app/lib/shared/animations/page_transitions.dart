import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/motion.dart';

/// go_router page builders with the house transitions.
abstract final class AnimatedPageTransition {
  /// Fade-through + gentle scale: for switching between top-level destinations.
  static Page<void> fadeThrough(GoRouterState state, Widget child) => CustomTransitionPage<void>(
        key: state.pageKey,
        name: state.name,
        child: child,
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 220),
        transitionsBuilder: (context, animation, secondary, child) {
          if (Motion.of(context).reduced) return child;
          final inCurve = CurvedAnimation(parent: animation, curve: const Interval(0.3, 1, curve: Curves.easeOutCubic));
          return FadeTransition(
            opacity: inCurve,
            child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(inCurve), child: child),
          );
        },
      );

  /// Shared-axis (horizontal): for drilling into details and stepping through flows.
  static Page<void> sharedAxis(GoRouterState state, Widget child) => CustomTransitionPage<void>(
        key: state.pageKey,
        name: state.name,
        child: child,
        transitionDuration: const Duration(milliseconds: 360),
        reverseTransitionDuration: const Duration(milliseconds: 280),
        transitionsBuilder: (context, animation, secondary, child) {
          if (Motion.of(context).reduced) return child;
          final rtl = Directionality.of(context) == TextDirection.rtl;
          final dir = rtl ? -1.0 : 1.0;
          final inCurve = CurvedAnimation(parent: animation, curve: Motion.standard);
          final outCurve = CurvedAnimation(parent: secondary, curve: Motion.standard);
          return SlideTransition(
            position: Tween(begin: Offset(0.08 * dir, 0), end: Offset.zero).animate(inCurve),
            child: FadeTransition(
              opacity: inCurve,
              child: SlideTransition(
                position: Tween(begin: Offset.zero, end: Offset(-0.05 * dir, 0)).animate(outCurve),
                child: FadeTransition(opacity: Tween(begin: 1.0, end: 0.6).animate(outCurve), child: child),
              ),
            ),
          );
        },
      );

  /// Rises up: for modal-feeling full screens (new booking, booking flow).
  static Page<void> rise(GoRouterState state, Widget child) => CustomTransitionPage<void>(
        key: state.pageKey,
        name: state.name,
        child: child,
        fullscreenDialog: true,
        transitionDuration: const Duration(milliseconds: 380),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        transitionsBuilder: (context, animation, secondary, child) {
          if (Motion.of(context).reduced) return child;
          final curve = CurvedAnimation(parent: animation, curve: Motion.emphasized, reverseCurve: Motion.exit);
          return FadeTransition(
            opacity: curve,
            child: SlideTransition(position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(curve), child: child),
          );
        },
      );
}
