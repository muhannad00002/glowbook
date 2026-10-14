import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/motion.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import 'common.dart';

/// Customer pages never scroll. Every screen is one of these:
///   • a [FitStepPage] — header, a body that must fit, and a sticky action;
///   • lists inside it are [PagedGrid]s — they page sideways instead of scrolling;
///   • free-form content goes in a [FitBox], which scales down on very short screens.

/// One step of a customer flow, sized to the screen.
class FitStepPage extends StatelessWidget {
  const FitStepPage({
    super.key,
    required this.title,
    required this.body,
    this.step,
    this.total,
    this.subtitle,
    this.onBack,
    this.summary,
    this.action,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final int? step;
  final int? total;
  final VoidCallback? onBack;
  final Widget body;

  /// One or two lines above the action (what she has chosen so far).
  final Widget? summary;
  final Widget? action;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final g = gutterOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final motion = Motion.of(context);
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsetsDirectional.fromSTEB(Space.xs, Space.xs, g, 0),
                child: Row(
                  children: [
                    if (onBack != null) IconButton(tooltip: l.actionBack, onPressed: onBack, icon: const BackButtonIcon()) else SizedBox(width: g - Space.xs),
                    if (step != null && total != null) ...[
                      Expanded(
                        child: _Progress(step: step!, total: total!),
                      ),
                      const SizedBox(width: Space.md),
                      Text(l.flowStepOf(step! + 1, total!), style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                    ] else
                      const Spacer(),
                    ?trailing,
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(g, Space.sm, g, Space.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(title, style: context.text.headlineSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                    ),
                    if (subtitle != null && !keyboard)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: g),
                  child: body,
                ),
              ),
              if (action != null || summary != null)
                Container(
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
                    border: Border(top: BorderSide(color: context.colors.outlineVariant.withValues(alpha: 0.6))),
                    boxShadow: [BoxShadow(color: context.glow.shadow, blurRadius: 24, offset: const Offset(0, -6))],
                  ),
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.only(bottom: Space.md),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(g, Space.md, g, Space.xs),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (summary != null && !keyboard) ...[
                            AnimatedSize(
                              duration: motion.medium,
                              curve: Motion.standard,
                              alignment: Alignment.topCenter,
                              child: AnimatedSwitcher(duration: motion.medium, child: summary),
                            ),
                            if (action != null) const SizedBox(height: Space.md),
                          ],
                          if (action != null) AnimatedSwitcher(duration: motion.fast, child: action),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Progress extends StatelessWidget {
  const _Progress({required this.step, required this.total});
  final int step;
  final int total;
  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: Motion.of(context).medium,
              height: 4,
              decoration: BoxDecoration(color: i <= step ? scheme.primary : scheme.primaryContainer, borderRadius: Radii.pillAll),
            ),
          ),
        ],
      ],
    );
  }
}

/// Free-form content that must fit: shown at full size when there is room, scaled down
/// (never scrolled) on very short screens or with the keyboard up.
class FitBox extends StatelessWidget {
  const FitBox({super.key, required this.child, this.alignment = Alignment.topCenter});
  final Widget child;
  final Alignment alignment;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: SizedBox(width: box.maxWidth, child: child),
    ),
  );
}

/// A grid that fills the space it is given and pages sideways when the items don't fit —
/// so long lists (services, times) never make the screen scroll.
class PagedGrid<T> extends StatefulWidget {
  const PagedGrid({
    super.key,
    required this.items,
    required this.itemBuilder,
    required this.itemHeight,
    this.minItemWidth = 280,
    this.maxColumns = 2,
    this.spacing = Space.sm,
    this.initialIndex = 0,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final double itemHeight;
  final double minItemWidth;
  final int maxColumns;
  final double spacing;

  /// Opens on the page holding this item (e.g. the selected one).
  final int initialIndex;

  @override
  State<PagedGrid<T>> createState() => _PagedGridState<T>();
}

class _PagedGridState<T> extends State<PagedGrid<T>> {
  static const _dotsHeight = 36.0;
  PageController? _controller;
  int _page = 0;
  int _perPage = 0;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final sp = widget.spacing;
        final cols = ((box.maxWidth + sp) / (widget.minItemWidth + sp)).floor().clamp(1, widget.maxColumns);
        int rowsFor(double h) => math.max(1, ((h + sp) / (widget.itemHeight + sp)).floor());
        var rows = rowsFor(box.maxHeight);
        final needed = (widget.items.length / cols).ceil();
        if (needed > rows) rows = rowsFor(box.maxHeight - _dotsHeight);
        final perPage = rows * cols;
        final pages = math.max(1, (widget.items.length / perPage).ceil());

        // Rebuild the controller when the page size changes (rotation, keyboard).
        if (_controller == null || perPage != _perPage) {
          final keep = _perPage == 0 ? widget.initialIndex : _page * _perPage;
          _page = (keep ~/ perPage).clamp(0, pages - 1);
          _perPage = perPage;
          _controller?.dispose();
          _controller = PageController(initialPage: _page);
        }
        if (_page >= pages) _page = pages - 1;

        Widget page(int p) {
          final start = p * perPage;
          final slice = widget.items.sublist(start, math.min(start + perPage, widget.items.length));
          return Column(
            children: [
              for (var r = 0; r < rows; r++) ...[
                if (r > 0) SizedBox(height: sp),
                SizedBox(
                  height: widget.itemHeight,
                  child: Row(
                    children: [
                      for (var c = 0; c < cols; c++) ...[
                        if (c > 0) SizedBox(width: sp),
                        Expanded(child: r * cols + c < slice.length ? widget.itemBuilder(context, slice[r * cols + c]) : const SizedBox.shrink()),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        }

        return Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages,
                onPageChanged: (p) => setState(() => _page = p),
                itemBuilder: (context, p) => page(p),
              ),
            ),
            if (pages > 1)
              _Dots(
                count: pages,
                page: _page,
                onPage: (p) => _controller!.animateToPage(p, duration: Motion.of(context).medium, curve: Motion.standard),
              ),
          ],
        );
      },
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.page, required this.onPage});
  final int count;
  final int page;
  final ValueChanged<int> onPage;
  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l = context.l10n;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return SizedBox(
      height: 36,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: l.actionBack,
            visualDensity: VisualDensity.compact,
            onPressed: page > 0 ? () => onPage(page - 1) : null,
            icon: Icon(rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded),
          ),
          for (var i = 0; i < count; i++)
            AnimatedContainer(
              duration: Motion.of(context).fast,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: i == page ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(color: i == page ? scheme.primary : scheme.outlineVariant, borderRadius: Radii.pillAll),
            ),
          IconButton(
            tooltip: l.actionNext,
            visualDensity: VisualDensity.compact,
            onPressed: page < count - 1
                ? () {
                    HapticFeedback.selectionClick();
                    onPage(page + 1);
                  }
                : null,
            icon: Icon(rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

/// A full-screen message (expired link, nothing to book…) that fits like everything else.
class FitMessage extends StatelessWidget {
  const FitMessage({super.key, required this.icon, required this.title, this.body, this.action});
  final IconData icon;
  final String title;
  final String? body;
  final Widget? action;
  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: EdgeInsets.all(gutterOf(context)),
      child: Center(
        child: FitBox(
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: context.colors.primaryContainer, shape: BoxShape.circle),
                child: Icon(icon, size: 40, color: context.colors.primary),
              ),
              const SizedBox(height: Space.lg),
              Text(title, style: context.text.headlineSmall, textAlign: TextAlign.center),
              if (body != null) ...[
                const SizedBox(height: Space.sm),
                Text(
                  body!,
                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
              if (action != null) ...[const SizedBox(height: Space.xl), action!],
            ],
          ),
        ),
      ),
    ),
  );
}
