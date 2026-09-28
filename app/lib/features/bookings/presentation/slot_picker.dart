import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/animations/animated_calendar_transition.dart';
import '../../../shared/animations/animated_empty_state.dart';
import '../../../shared/animations/glow_illustration.dart';
import '../../../shared/animations/shimmer_loading.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';

/// Date strip + time grid. Every slot shown comes from the server's availability
/// engine; nothing is computed on the device.
class SlotPicker extends StatefulWidget {
  const SlotPicker({
    super.key,
    required this.timezone,
    required this.loadSlots,
    required this.onSelected,
    this.loadDays,
    this.selected,
    this.initialDate,
    this.days = 21,
    this.refreshToken = 0,
  });

  final String timezone;
  final Future<List<Slot>> Function(String date) loadSlots;
  final Future<List<DayAvailability>> Function(String from, int days)? loadDays;
  final ValueChanged<Slot?> onSelected;
  final Slot? selected;
  final String? initialDate;
  final int days;

  /// Bump to force a reload (e.g. after a "slot taken" conflict).
  final int refreshToken;

  @override
  State<SlotPicker> createState() => _SlotPickerState();
}

class _SlotPickerState extends State<SlotPicker> {
  late String _today;
  late String _date;
  bool _forward = true;
  Future<List<Slot>>? _slots;
  Map<String, DayAvailability> _summary = {};
  final _strip = ScrollController();

  @override
  void initState() {
    super.initState();
    _today = Ymd.today(widget.timezone);
    _date = widget.initialDate != null && widget.initialDate!.compareTo(_today) >= 0 ? widget.initialDate! : _today;
    _load();
    _loadSummary();
  }

  @override
  void didUpdateWidget(SlotPicker old) {
    super.didUpdateWidget(old);
    if (old.refreshToken != widget.refreshToken) {
      _load();
      _loadSummary();
    }
  }

  @override
  void dispose() {
    _strip.dispose();
    super.dispose();
  }

  void _load() => setState(() => _slots = widget.loadSlots(_date));

  Future<void> _loadSummary() async {
    if (widget.loadDays == null) return;
    try {
      final days = await widget.loadDays!(_today, widget.days);
      if (!mounted) return;
      setState(() => _summary = {for (final d in days) d.date: d});
      // Nothing left today (or on the requested day)? Jump to the first day that has room.
      final current = _summary[_date];
      if (current != null && current.slotCount == 0 && widget.selected == null) {
        final next = days.where((d) => d.slotCount > 0 && d.date.compareTo(_date) > 0).firstOrNull;
        if (next != null) _pick(next.date);
      }
    } catch (_) {
      // The strip still works without the dots.
    }
  }

  void _pick(String date) {
    if (date == _date) return;
    widget.onSelected(null);
    setState(() {
      _forward = date.compareTo(_date) > 0;
      _date = date;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _DateStrip(
          controller: _strip,
          today: _today,
          selected: _date,
          count: widget.days,
          summary: _summary,
          onPick: _pick,
        ),
        const SizedBox(height: Space.lg),
        AnimatedCalendarTransition(
          dateKey: '$_date#${widget.refreshToken}',
          forward: _forward,
          child: FutureBuilder<List<Slot>>(
            future: _slots,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) return const _SlotsSkeleton();
              if (snap.hasError) return ErrorView(error: snap.error!, onRetry: _load);
              final slots = snap.data ?? const [];
              if (slots.isEmpty) {
                return AnimatedEmptyState(art: GlowArt.calendar, title: context.l10n.noSlotsTitle, body: context.l10n.noSlotsBody, compact: true);
              }
              return _SlotGrid(slots: slots, selected: widget.selected, onSelected: widget.onSelected);
            },
          ),
        ),
      ],
    );
  }
}

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.controller, required this.today, required this.selected, required this.count, required this.summary, required this.onPick});
  final ScrollController controller;
  final String today;
  final String selected;
  final int count;
  final Map<String, DayAvailability> summary;
  final ValueChanged<String> onPick;

  @override
  Widget build(BuildContext context) {
    final locale = context.lang;
    final scheme = context.colors;
    final motion = Motion.of(context);
    return SizedBox(
      height: 84,
      child: ListView.separated(
        controller: controller,
        scrollDirection: Axis.horizontal,
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
        itemBuilder: (context, i) {
          final date = Ymd.add(today, i);
          final d = Ymd.parse(date);
          final sel = date == selected;
          final info = summary[date];
          final unavailable = info != null && (info.closed || info.slotCount == 0);
          return Semantics(
            button: true,
            selected: sel,
            label: DateFormat.MMMMEEEEd(locale).format(d),
            child: PressableScale(
              onTap: () => onPick(date),
              child: AnimatedContainer(
                duration: motion.medium,
                curve: Motion.standard,
                width: 60,
                decoration: BoxDecoration(
                  color: sel ? scheme.primary : scheme.surface,
                  borderRadius: Radii.lgAll,
                  border: Border.all(color: sel ? scheme.primary : scheme.outlineVariant),
                  boxShadow: sel ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))] : null,
                ),
                child: ExcludeSemantics(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(DateFormat.E(locale).format(d),
                          style: context.text.labelSmall?.copyWith(color: sel ? scheme.onPrimary.withValues(alpha: 0.85) : scheme.onSurfaceVariant)),
                      const SizedBox(height: 2),
                      Text(DateFormat.d(locale).format(d),
                          style: context.text.titleLarge?.copyWith(
                            color: sel ? scheme.onPrimary : (unavailable ? scheme.onSurfaceVariant.withValues(alpha: 0.5) : scheme.onSurface),
                          )),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: motion.medium,
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: info == null
                              ? Colors.transparent
                              : unavailable
                                  ? Colors.transparent
                                  : (sel ? scheme.onPrimary : scheme.tertiary),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SlotGrid extends StatelessWidget {
  const _SlotGrid({required this.slots, required this.selected, required this.onSelected});
  final List<Slot> slots;
  final Slot? selected;
  final ValueChanged<Slot?> onSelected;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final groups = <String, List<Slot>>{
      l.slotMorning: slots.where((s) => s.hour < 12).toList(),
      l.slotAfternoon: slots.where((s) => s.hour >= 12 && s.hour < 17).toList(),
      l.slotEvening: slots.where((s) => s.hour >= 17).toList(),
    }..removeWhere((_, v) => v.isEmpty);
    var index = 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm, top: Space.xs),
            child: Text(entry.key, style: context.text.labelMedium?.copyWith(color: context.colors.onSurfaceVariant)),
          ),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final s in entry.value)
                StaggeredEntrance(
                  key: ValueKey(s.start.toIso8601String()),
                  index: (index++) ~/ 3,
                  offset: 8,
                  child: _SlotChip(slot: s, selected: selected?.start == s.start, onTap: () => onSelected(s)),
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
        ],
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({required this.slot, required this.selected, required this.onTap});
  final Slot slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final motion = Motion.of(context);
    final p = slot.time.split(':').map(int.parse).toList();
    final label = DateFormat.jm(context.lang).format(DateTime(2000, 1, 1, p[0], p[1]));
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: motion.fast,
          constraints: const BoxConstraints(minWidth: 88, minHeight: 46),
          padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surface,
            borderRadius: Radii.pillAll,
            border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant),
          ),
          child: ExcludeSemantics(
            child: Text(label, textAlign: TextAlign.center, style: context.text.labelLarge?.copyWith(color: selected ? scheme.onPrimary : scheme.onSurface)),
          ),
        ),
      ),
    );
  }
}

class _SlotsSkeleton extends StatelessWidget {
  const _SlotsSkeleton();
  @override
  Widget build(BuildContext context) => ShimmerLoading(
        child: Wrap(spacing: Space.sm, runSpacing: Space.sm, children: List.generate(9, (_) => const SkeletonBox(width: 88, height: 46, radius: Radii.pill))),
      );
}
