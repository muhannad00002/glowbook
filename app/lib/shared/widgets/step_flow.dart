import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';

/// Animated step indicator: a progress track that fills as you move forward, with
/// step labels that light up.
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.steps, required this.current, this.onTapStep});
  final List<String> steps;
  final int current;
  final ValueChanged<int>? onTapStep;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final motion = Motion.of(context);
    return Semantics(
      label: '${current + 1} / ${steps.length}: ${steps[current]}',
      child: Column(
        children: [
          ClipRRect(
            borderRadius: Radii.pillAll,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: (current + 1) / steps.length),
              duration: motion.slow,
              curve: Motion.emphasized,
              builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 6, backgroundColor: scheme.primaryContainer),
            ),
          ),
          const SizedBox(height: Space.sm),
          ExcludeSemantics(
            child: Row(
              children: [
                for (var i = 0; i < steps.length; i++)
                  Expanded(
                    child: GestureDetector(
                      onTap: i < current && onTapStep != null ? () => onTapStep!(i) : null,
                      child: AnimatedDefaultTextStyle(
                        duration: motion.medium,
                        style: context.text.labelSmall!.copyWith(
                          color: i == current ? scheme.primary : (i < current ? scheme.onSurface : scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                          fontWeight: i == current ? FontWeight.w700 : FontWeight.w600,
                        ),
                        child: Text(steps[i], textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Slides between steps (forward from the trailing edge, back from the leading).
class StepSwitcher extends StatelessWidget {
  const StepSwitcher({super.key, required this.step, required this.forward, required this.child});
  final int step;
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
      transitionBuilder: (c, a) {
        final incoming = c.key == ValueKey(step);
        return FadeTransition(
          opacity: a,
          child: SlideTransition(
            position: Tween(begin: Offset((incoming ? 0.12 : -0.12) * dir, 0), end: Offset.zero).animate(a),
            child: c,
          ),
        );
      },
      child: KeyedSubtree(key: ValueKey(step), child: child),
    );
  }
}

/// A selectable option card (service, artist, client…).
class OptionCard extends StatelessWidget {
  const OptionCard({super.key, required this.selected, required this.onTap, required this.title, this.subtitle, this.leading, this.trailing});
  final bool selected;
  final VoidCallback onTap;
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final motion = Motion.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: InkWell(
        borderRadius: Radii.lgAll,
        onTap: onTap,
        child: AnimatedContainer(
          duration: motion.medium,
          curve: Motion.standard,
          padding: const EdgeInsets.all(Space.lg),
          decoration: BoxDecoration(
            color: selected ? scheme.primaryContainer.withValues(alpha: 0.6) : scheme.surface,
            borderRadius: Radii.lgAll,
            border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant, width: selected ? 1.6 : 1),
          ),
          child: Row(
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: Space.lg)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.titleMedium),
                    if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: context.text.bodySmall)],
                  ],
                ),
              ),
              ?trailing,
              AnimatedScale(
                scale: selected ? 1 : 0,
                duration: motion.medium,
                curve: Motion.pop,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(start: Space.sm),
                  child: Icon(Icons.check_circle_rounded, color: scheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
