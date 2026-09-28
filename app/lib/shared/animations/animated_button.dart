import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/motion.dart';

/// Wraps any tappable surface with the house press feel: a slight scale-down on
/// press and a soft springy return. Layout never shifts — only a transform.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, this.onTap, this.onLongPress, this.scale = 0.965, this.enabled = true});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  final bool enabled;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    final active = widget.enabled && (widget.onTap != null || widget.onLongPress != null);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: active ? (_) => _set(true) : null,
      onTapUp: active ? (_) => _set(false) : null,
      onTapCancel: active ? () => _set(false) : null,
      onTap: active
          ? () {
              HapticFeedback.selectionClick();
              widget.onTap?.call();
            }
          : null,
      onLongPress: widget.onLongPress,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: _down ? motion.fast : motion.medium,
        curve: _down ? Curves.easeOut : Motion.pop,
        child: widget.child,
      ),
    );
  }
}

enum GlowButtonState { idle, loading, success }

/// The primary call-to-action. Tapping runs [onPressed]; while it's in flight the
/// button morphs into a pill with breathing dots, and on success it shows a check
/// before settling back (or staying, if [keepSuccess]).
class AnimatedButton extends StatefulWidget {
  const AnimatedButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = true,
    this.tone = ButtonTone.primary,
    this.keepSuccess = false,
    this.enabled = true,
  });

  final String label;
  final IconData? icon;

  /// Return normally for success; throw to go back to idle (the caller shows the error).
  final Future<void> Function()? onPressed;
  final bool expand;
  final ButtonTone tone;
  final bool keepSuccess;
  final bool enabled;

  @override
  State<AnimatedButton> createState() => _AnimatedButtonState();
}

enum ButtonTone { primary, soft, danger }

class _AnimatedButtonState extends State<AnimatedButton> {
  GlowButtonState _state = GlowButtonState.idle;

  Future<void> _run() async {
    if (_state != GlowButtonState.idle || widget.onPressed == null) return;
    setState(() => _state = GlowButtonState.loading);
    try {
      await widget.onPressed!();
      if (!mounted) return;
      HapticFeedback.lightImpact();
      setState(() => _state = GlowButtonState.success);
      if (!widget.keepSuccess) {
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (mounted) setState(() => _state = GlowButtonState.idle);
      }
    } catch (_) {
      if (mounted) setState(() => _state = GlowButtonState.idle);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final motion = Motion.of(context);
    final (bg, fg) = switch (widget.tone) {
      ButtonTone.primary => (scheme.primary, scheme.onPrimary),
      ButtonTone.soft => (scheme.primaryContainer, scheme.onPrimaryContainer),
      ButtonTone.danger => (scheme.errorContainer, scheme.onErrorContainer),
    };
    final disabled = !widget.enabled || widget.onPressed == null;
    final busy = _state != GlowButtonState.idle;
    final success = _state == GlowButtonState.success;

    final content = AnimatedSwitcher(
      duration: motion.medium,
      switchInCurve: Motion.pop,
      transitionBuilder: (child, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.7, end: 1.0).animate(a), child: child)),
      child: switch (_state) {
        GlowButtonState.loading => _BreathingDots(key: const ValueKey('dots'), color: fg),
        GlowButtonState.success => Icon(Icons.check_rounded, key: const ValueKey('ok'), color: fg, size: 26),
        GlowButtonState.idle => Row(
            key: const ValueKey('label'),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[Icon(widget.icon, size: 20, color: fg), const SizedBox(width: 8)],
              Flexible(
                child: Text(
                  widget.label,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge?.copyWith(color: fg),
                ),
              ),
            ],
          ),
      },
    );

    return Semantics(
      button: true,
      enabled: !disabled,
      label: widget.label,
      child: LayoutBuilder(builder: (context, c) {
        final full = widget.expand && c.hasBoundedWidth ? c.maxWidth : null;
        return Align(
          widthFactor: widget.expand ? null : 1,
          child: PressableScale(
            enabled: !disabled && !busy,
            onTap: () => _run().catchError((_) {}),
            child: AnimatedContainer(
              duration: motion.medium,
              curve: Motion.emphasized,
              height: 54,
              width: busy ? 96 : full,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: disabled ? scheme.onSurface.withValues(alpha: 0.12) : (success ? context.glow.success : bg),
                borderRadius: BorderRadius.circular(999),
                boxShadow: widget.tone == ButtonTone.primary && !disabled
                    ? [BoxShadow(color: bg.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8))]
                    : null,
              ),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: disabled ? scheme.onSurface.withValues(alpha: 0.4) : fg),
                child: content,
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _BreathingDots extends StatefulWidget {
  const _BreathingDots({super.key, required this.color});
  final Color color;
  @override
  State<_BreathingDots> createState() => _BreathingDotsState();
}

class _BreathingDotsState extends State<_BreathingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final t = (math.sin((_c.value * 2 * math.pi) - i * 0.9) + 1) / 2;
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.35 + 0.65 * t), shape: BoxShape.circle),
          );
        }),
      ),
    );
  }
}

/// A tiny inline loader that isn't a spinner — for places a whole skeleton is too much.
class InlineLoader extends StatelessWidget {
  const InlineLoader({super.key});
  @override
  Widget build(BuildContext context) => _BreathingDots(color: context.colors.primary);
}
