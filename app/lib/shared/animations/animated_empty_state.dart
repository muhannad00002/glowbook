import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import 'glow_illustration.dart';

/// Friendly empty state: a gently floating illustration, a title, a line of copy and
/// an optional action.
class AnimatedEmptyState extends StatefulWidget {
  const AnimatedEmptyState({super.key, required this.art, required this.title, this.body, this.action, this.compact = false});
  final GlowArt art;
  final String title;
  final String? body;
  final Widget? action;
  final bool compact;

  @override
  State<AnimatedEmptyState> createState() => _AnimatedEmptyStateState();
}

class _AnimatedEmptyStateState extends State<AnimatedEmptyState> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.of(context).reduced) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.compact ? 96.0 : 140.0;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xl),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: Motion.of(context).slow,
          curve: Motion.standard,
          builder: (context, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 12 * (1 - t)), child: child)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _c,
                  builder: (_, child) {
                    final a = _c.value * 2 * math.pi;
                    return Transform.translate(
                      offset: Offset(0, math.sin(a) * 6),
                      child: Transform.rotate(angle: math.sin(a + 1) * 0.03, child: child),
                    );
                  },
                  child: RepaintBoundary(child: GlowIllustration(widget.art, size: size)),
                ),
                SizedBox(height: widget.compact ? Space.md : Space.xl),
                Text(widget.title, textAlign: TextAlign.center, style: widget.compact ? context.text.titleMedium : context.text.headlineSmall),
                if (widget.body != null) ...[
                  const SizedBox(height: Space.sm),
                  Text(widget.body!, textAlign: TextAlign.center, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                ],
                if (widget.action != null) ...[const SizedBox(height: Space.xl), widget.action!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
