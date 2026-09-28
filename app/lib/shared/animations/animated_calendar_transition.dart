import 'package:flutter/material.dart';

import '../../core/theme/motion.dart';

/// Slides content horizontally when the calendar moves between dates: forward in
/// time slides in from the trailing edge, backward from the leading edge (and the
/// directions flip automatically in RTL).
class AnimatedCalendarTransition extends StatelessWidget {
  const AnimatedCalendarTransition({super.key, required this.dateKey, required this.forward, required this.child});

  /// Changes whenever the visible date/range changes (e.g. "2026-09-28").
  final String dateKey;
  final bool forward;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final dir = (forward ? 1.0 : -1.0) * (rtl ? -1 : 1);
    return AnimatedSwitcher(
      duration: motion.medium,
      switchInCurve: Motion.standard,
      switchOutCurve: Motion.exit,
      layoutBuilder: (current, previous) => Stack(alignment: Alignment.topCenter, children: [...previous, ?current]),
      transitionBuilder: (child, animation) {
        final incoming = child.key == ValueKey(dateKey);
        final begin = Offset(incoming ? 0.18 * dir : -0.18 * dir, 0);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: Tween(begin: begin, end: Offset.zero).animate(animation), child: child),
        );
      },
      child: KeyedSubtree(key: ValueKey(dateKey), child: SizedBox(width: double.infinity, child: child)),
    );
  }
}
