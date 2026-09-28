import 'package:flutter/material.dart';

import '../../core/theme/motion.dart';
import '../../core/utils/format.dart';

/// Counts up from the previous value (0 on first build) to [value].
class AnimatedCounter extends StatelessWidget {
  const AnimatedCounter({super.key, required this.value, this.format, this.style});

  final num value;
  final String Function(num value)? format;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: motion.reduced ? Duration.zero : const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) {
        final shown = value is int ? v.round() : v;
        return Text(format?.call(shown) ?? context.fmt.number(shown), style: style, maxLines: 1, overflow: TextOverflow.ellipsis);
      },
    );
  }
}
