import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/errors/api_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../animations/animated_button.dart';
import '../animations/animated_empty_state.dart';
import '../animations/glow_illustration.dart';
import '../animations/shimmer_loading.dart';

/// Surface card with a soft shadow; tappable cards get the press-scale feel.
class GlowCard extends StatelessWidget {
  const GlowCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(Space.lg), this.gradient, this.color, this.radius = Radii.lg, this.elevated = true});
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? color;
  final double radius;
  final bool elevated;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? scheme.surface) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: gradient == null ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)) : null,
        boxShadow: elevated ? [BoxShadow(color: context.glow.shadow, blurRadius: 20, spreadRadius: -6, offset: const Offset(0, 8))] : null,
      ),
      child: child,
    );
    if (onTap == null) return card;
    return PressableScale(
      onTap: onTap,
      child: Material(type: MaterialType.transparency, child: card),
    );
  }
}

/// Status pill whose colours cross-fade when the status changes.
class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.dense = false});
  final String status;
  final bool dense;

  static IconData iconFor(String s) => switch (s) {
        'PENDING' => Icons.hourglass_top_rounded,
        'CONFIRMED' => Icons.check_circle_outline_rounded,
        'ARRIVED' => Icons.waving_hand_outlined,
        'IN_SERVICE' => Icons.brush_outlined,
        'COMPLETED' => Icons.favorite_rounded,
        'CANCELLED' => Icons.close_rounded,
        'NO_SHOW' => Icons.event_busy_outlined,
        _ => Icons.circle_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.glow.forStatus(status);
    final motion = Motion.of(context);
    return AnimatedContainer(
      duration: motion.medium,
      curve: Motion.standard,
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 3 : 5),
      decoration: BoxDecoration(color: c.bg, borderRadius: Radii.pillAll),
      child: AnimatedSwitcher(
        duration: motion.medium,
        transitionBuilder: (child, a) => FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.85, end: 1.0).animate(a), child: child)),
        child: Row(
          key: ValueKey(status),
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(iconFor(status), size: dense ? 12 : 14, color: c.fg),
            const SizedBox(width: 4),
            Text(context.fmt.statusLabel(status), style: (dense ? context.text.labelSmall : context.text.labelMedium)?.copyWith(color: c.fg)),
          ],
        ),
      ),
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, this.color, this.size = 44, this.photoUrl});
  final String name;
  final Color? color;
  final double size;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final base = color ?? context.colors.primary;
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = (parts.first.isNotEmpty ? parts.first.characters.first : '') + (parts.length > 1 && parts.last.isNotEmpty ? parts.last.characters.first : '');
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [base.withValues(alpha: 0.22), base.withValues(alpha: 0.38)]),
          image: photoUrl != null ? DecorationImage(image: NetworkImage(photoUrl!), fit: BoxFit.cover) : null,
        ),
        alignment: Alignment.center,
        child: photoUrl != null
            ? null
            : Text(
                initials.toUpperCase(),
                style: context.text.labelLarge?.copyWith(
                  fontSize: size * 0.36,
                  color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Color.lerp(base, Colors.black, 0.35),
                ),
              ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.action, this.onAction, this.trailing});
  final String title;
  final String? action;
  final VoidCallback? onAction;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md, top: Space.sm),
      child: Row(
        children: [
          Expanded(child: Semantics(header: true, child: Text(title, style: context.text.titleLarge))),
          ?trailing,
          if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
        ],
      ),
    );
  }
}

/// Centers and caps content width on large screens with a responsive gutter.
class ContentWidth extends StatelessWidget {
  const ContentWidth({super.key, required this.child, this.maxWidth = Breakpoints.maxContent});
  final Widget child;
  final double maxWidth;
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(constraints: BoxConstraints(maxWidth: maxWidth), child: child),
      );
}

double gutterOf(BuildContext context) => Space.gutter(MediaQuery.sizeOf(context).width);

/// AsyncValue → skeleton / friendly error / data, with a smooth cross-fade.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, this.loading, this.onRetry});
  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    final Widget child = value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: (d) => KeyedSubtree(key: const ValueKey('data'), child: data(d)),
      loading: () => KeyedSubtree(key: const ValueKey('loading'), child: loading ?? const SkeletonList()),
      error: (e, _) => KeyedSubtree(key: const ValueKey('error'), child: ErrorView(error: e, onRetry: onRetry)),
    );
    return AnimatedSwitcher(duration: motion.medium, child: child);
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});
  final Object error;
  final VoidCallback? onRetry;
  @override
  Widget build(BuildContext context) {
    final offline = error is ApiException && (error as ApiException).offline;
    return AnimatedEmptyState(
      art: offline ? GlowArt.bell : GlowArt.mirror,
      title: offline ? context.l10n.errorOffline : context.fmt.error(error),
      action: onRetry == null
          ? null
          : OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: Text(context.l10n.actionRetry)),
      compact: true,
    );
  }
}

void showGlowSnack(BuildContext context, String message, {String? actionLabel, VoidCallback? onAction, bool error = false}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Row(children: [
        Icon(error ? Icons.error_outline_rounded : Icons.auto_awesome_rounded, size: 18, color: context.colors.onInverseSurface),
        const SizedBox(width: Space.sm),
        Expanded(child: Text(message)),
      ]),
      duration: Duration(seconds: actionLabel != null ? 6 : 3),
      action: actionLabel != null ? SnackBarAction(label: actionLabel, onPressed: onAction ?? () {}) : null,
    ));
}

/// Runs [fn]; on failure shows the server's message and rethrows (so an
/// [AnimatedButton] returns to idle).
Future<T> guard<T>(BuildContext context, Future<T> Function() fn) async {
  try {
    return await fn();
  } catch (e) {
    if (context.mounted) showGlowSnack(context, context.fmt.error(e), error: true);
    rethrow;
  }
}

/// A compact labelled stat used on dashboards and profiles.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, this.icon, this.tint});
  final String label;
  final Widget value;
  final IconData? icon;
  final Color? tint;
  @override
  Widget build(BuildContext context) {
    final color = tint ?? context.colors.primary;
    return GlowCard(
      padding: const EdgeInsets.all(Space.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: Radii.smAll),
              child: Icon(icon, size: 18, color: color),
            ),
          if (icon != null) const SizedBox(height: Space.md),
          DefaultTextStyle.merge(style: context.text.headlineSmall, child: value),
          const SizedBox(height: 2),
          Text(label, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class RatingStars extends StatelessWidget {
  const RatingStars({super.key, required this.rating, this.size = 16});
  final double rating;
  final double size;
  @override
  Widget build(BuildContext context) {
    final color = context.colors.secondary;
    return Semantics(
      label: '${rating.toStringAsFixed(1)} / 5',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(5, (i) {
            final v = rating - i;
            return Icon(v >= 0.75 ? Icons.star_rounded : v >= 0.25 ? Icons.star_half_rounded : Icons.star_outline_rounded, size: size, color: color);
          }),
        ),
      ),
    );
  }
}

/// A loading placeholder for small inline areas.
class LoadingPad extends StatelessWidget {
  const LoadingPad({super.key});
  @override
  Widget build(BuildContext context) => const Padding(padding: EdgeInsets.all(Space.xl), child: Center(child: InlineLoader()));
}
