import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/animations/animated_empty_state.dart';
import '../../../shared/animations/glow_illustration.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/presentation/auth_layout.dart';
import '../data/seasonal_repository.dart';

/// Seasonal tokens for the salon: today's queue at the desk, and the events editor.
class SeasonalAdminScreen extends ConsumerStatefulWidget {
  const SeasonalAdminScreen({super.key});
  @override
  ConsumerState<SeasonalAdminScreen> createState() => _SeasonalAdminScreenState();
}

class _SeasonalAdminScreenState extends ConsumerState<SeasonalAdminScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final admin = ref.watch(membershipProvider)?.isAdmin ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(l.navSeasonal)),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(gutterOf(context), Space.sm, gutterOf(context), Space.sm),
            child: ContentWidth(
              maxWidth: 900,
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 0, icon: const Icon(Icons.confirmation_number_outlined), label: Text(l.seasonQueue)),
                  ButtonSegment(value: 1, icon: const Icon(Icons.celebration_outlined), label: Text(l.seasonEvents)),
                ],
                selected: {_tab},
                onSelectionChanged: (s) => setState(() => _tab = s.first),
              ),
            ),
          ),
          Expanded(child: _tab == 0 ? const _QueueTab() : _EventsTab(admin: admin)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Queue
// ---------------------------------------------------------------------------

class _QueueTab extends ConsumerStatefulWidget {
  const _QueueTab();
  @override
  ConsumerState<_QueueTab> createState() => _QueueTabState();
}

class _QueueTabState extends ConsumerState<_QueueTab> {
  String? _date;
  String? _eventId;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    // Customers keep taking tokens online — keep the desk view fresh.
    _poll = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted && _date != null) ref.invalidate(tokenQueueProvider((date: _date!, eventId: _eventId)));
    });
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _set(QueueToken t, String status) async {
    final l = context.l10n;
    if (status == 'CANCELLED') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          content: Text(l.seasonCancelConfirm(t.number)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.actionKeep)),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: ctx.colors.error, foregroundColor: ctx.colors.onError),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(l.seasonCancelToken),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    HapticFeedback.selectionClick();
    await guard(context, () => ref.read(seasonalRepositoryProvider).setStatus(t.id, status));
    ref.invalidate(tokenQueueProvider((date: _date!, eventId: _eventId)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final tz = ref.watch(membershipProvider)?.timezone ?? 'Asia/Muscat';
    final today = Ymd.today(tz);
    final date = _date ??= today;
    final events = ref.watch(adminSeasonalEventsProvider).valueOrNull ?? const <SeasonalEvent>[];
    final q = (date: date, eventId: _eventId);
    final queue = ref.watch(tokenQueueProvider(q));
    final g = gutterOf(context);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(tokenQueueProvider(q).future),
      child: ListView(
        padding: EdgeInsets.fromLTRB(g, 0, g, Space.xxxl),
        children: [
          ContentWidth(
            maxWidth: 900,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(tooltip: l.actionBack, onPressed: () => setState(() => _date = Ymd.add(date, -1)), icon: const Icon(Icons.chevron_left_rounded)),
                    Expanded(
                      child: InkWell(
                        borderRadius: Radii.mdAll,
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: Ymd.parse(date),
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) setState(() => _date = Ymd.of(picked));
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: Space.sm),
                          child: Text(
                            date == today ? '${l.labelToday} · ${fmt.ymdLabel(date)}' : fmt.ymdLabel(date, pattern: 'yMMMEd'),
                            style: context.text.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    IconButton(tooltip: l.actionNext, onPressed: () => setState(() => _date = Ymd.add(date, 1)), icon: const Icon(Icons.chevron_right_rounded)),
                  ],
                ),
                if (events.length > 1)
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        Padding(
                          padding: const EdgeInsetsDirectional.only(end: Space.sm),
                          child: ChoiceChip(label: Text(l.seasonAllEvents), selected: _eventId == null, onSelected: (_) => setState(() => _eventId = null)),
                        ),
                        for (final e in events)
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: Space.sm),
                            child: ChoiceChip(
                              label: Text(e.title(context.lang)),
                              selected: _eventId == e.id,
                              onSelected: (_) => setState(() => _eventId = e.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: Space.sm),
                queue.when(
                  loading: () => const LoadingPad(),
                  error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(tokenQueueProvider(q))),
                  data: (data) => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Stats(queue: data),
                      const SizedBox(height: Space.lg),
                      if (data.tokens.isEmpty)
                        AnimatedEmptyState(art: GlowArt.calendar, title: l.seasonNoTokens, compact: true)
                      else
                        for (var i = 0; i < data.tokens.length; i++)
                          StaggeredEntrance(
                            key: ValueKey(data.tokens[i].id),
                            index: i.clamp(0, 10),
                            child: _QueueRow(token: data.tokens[i], timezone: tz, onStatus: (s) => _set(data.tokens[i], s)),
                          ),
                    ],
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

class _Stats extends StatelessWidget {
  const _Stats({required this.queue});
  final TokenQueue queue;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget tile(String label, String value, StatusColors c) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Space.md, horizontal: Space.sm),
        decoration: BoxDecoration(color: c.bg, borderRadius: Radii.mdAll),
        child: Column(
          children: [
            Text(
              value,
              style: context.text.titleLarge?.copyWith(color: c.fg, fontWeight: FontWeight.w700),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(label, style: context.text.labelSmall?.copyWith(color: c.fg), maxLines: 1),
            ),
          ],
        ),
      ),
    );
    final glow = context.glow;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            tile(l.seasonWaiting, '${queue.waiting}', glow.confirmed),
            const SizedBox(width: Space.sm),
            tile(l.statusArrived, '${queue.arrived}', glow.arrived),
            const SizedBox(width: Space.sm),
            tile(l.statusCompleted, '${queue.completed}', glow.completed),
            const SizedBox(width: Space.sm),
            tile(l.statusNoShow, '${queue.noShow}', glow.noShow),
          ],
        ),
        const SizedBox(height: Space.sm),
        Text('${l.seasonCollected}: ${context.fmt.money(queue.collectedBaisa)}', style: context.text.bodySmall, textAlign: TextAlign.end),
      ],
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.token, required this.timezone, required this.onStatus});
  final QueueToken token;
  final String timezone;
  final ValueChanged<String> onStatus;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final c = context.glow.forStatus(token.status);
    final done = token.status == 'COMPLETED' || token.status == 'CANCELLED' || token.status == 'NO_SHOW';
    final primary = switch (token.status) {
      'CONFIRMED' => (label: l.seasonCheckIn, status: 'ARRIVED', icon: Icons.waving_hand_outlined),
      'ARRIVED' => (label: l.seasonMarkDone, status: 'COMPLETED', icon: Icons.check_rounded),
      _ => null,
    };
    final menu = <({String label, String status})>[
      if (token.status == 'CONFIRMED') (label: l.statusNoShow, status: 'NO_SHOW'),
      if (token.status == 'ARRIVED' || token.status == 'NO_SHOW') (label: l.actionUndo, status: 'CONFIRMED'),
      if (token.status == 'COMPLETED') (label: l.actionUndo, status: 'ARRIVED'),
      if (token.status == 'CONFIRMED') (label: l.seasonCancelToken, status: 'CANCELLED'),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 250),
        opacity: done ? 0.6 : 1,
        child: GlowCard(
          padding: const EdgeInsets.all(Space.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: c.bg, borderRadius: Radii.mdAll),
                    child: Text(
                      '#${token.number}',
                      style: context.text.titleLarge?.copyWith(color: c.fg, fontWeight: FontWeight.w700),
                    ),
                  ),
                  const SizedBox(width: Space.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(token.customerName, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(
                          '${fmt.time(token.start, timezone)} · ${token.offering(context.lang)}',
                          style: context.text.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (token.customerPhone != null) Text(token.customerPhone!, style: context.text.labelSmall, textDirection: TextDirection.ltr),
                        if (token.notes != null) Text(token.notes!, style: context.text.bodySmall?.copyWith(fontStyle: FontStyle.italic), maxLines: 2),
                      ],
                    ),
                  ),
                  if (menu.isNotEmpty)
                    PopupMenuButton<String>(
                      tooltip: l.navMore,
                      onSelected: onStatus,
                      itemBuilder: (_) => [for (final m in menu) PopupMenuItem(value: m.status, child: Text(m.label))],
                    ),
                ],
              ),
              const SizedBox(height: Space.sm),
              Row(
                children: [
                  StatusChip(token.status, dense: true),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      token.balanceBaisa > 0 ? l.seasonBalanceDue(fmt.money(token.balanceBaisa)) : l.seasonPaidInFull,
                      style: context.text.labelSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (primary != null)
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: Space.md),
                      ),
                      onPressed: () => onStatus(primary.status),
                      icon: Icon(primary.icon, size: 18),
                      label: Text(primary.label),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Events
// ---------------------------------------------------------------------------

class _EventsTab extends ConsumerWidget {
  const _EventsTab({required this.admin});
  final bool admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final events = ref.watch(adminSeasonalEventsProvider);
    final g = gutterOf(context);
    return AsyncView(
      value: events,
      onRetry: () => ref.invalidate(adminSeasonalEventsProvider),
      data: (list) => list.isEmpty
          ? Center(
              child: Padding(
                padding: EdgeInsets.all(g),
                child: AnimatedEmptyState(
                  art: GlowArt.sparkles,
                  title: l.seasonNoEvents,
                  body: l.seasonNoEventsBody,
                  action: admin
                      ? FilledButton.icon(onPressed: () => _editEvent(context, ref, null), icon: const Icon(Icons.add_rounded), label: Text(l.seasonNewEvent))
                      : null,
                ),
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(g, 0, g, 120),
              children: [
                ContentWidth(
                  maxWidth: 900,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // In the list, not a FAB: the phone nav bar floats over the bottom edge.
                      if (admin)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.md),
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: FilledButton.tonalIcon(
                              onPressed: () => _editEvent(context, ref, null),
                              icon: const Icon(Icons.add_rounded),
                              label: Text(l.seasonNewEvent),
                            ),
                          ),
                        ),
                      for (var i = 0; i < list.length; i++)
                        StaggeredEntrance(
                          key: ValueKey(list[i].id),
                          index: i,
                          child: _EventCard(event: list[i], admin: admin),
                        ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.event, required this.admin});
  final SeasonalEvent event;
  final bool admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final fmt = context.fmt;
    final lang = context.lang;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: GlowCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(child: Text(event.title(lang), style: context.text.titleLarge)),
                          if (!event.isActive) ...[const SizedBox(width: Space.sm), Chip(label: Text(l.seasonOff), visualDensity: VisualDensity.compact)],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${fmt.ymdLabel(event.startDate)} – ${fmt.ymdLabel(event.endDate)} · ${fmt.minuteOfDay(event.openMinute)} – ${fmt.minuteOfDay(event.closeMinute)}',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (admin) IconButton(tooltip: l.actionEdit, onPressed: () => _editEvent(context, ref, event), icon: const Icon(Icons.edit_outlined)),
              ],
            ),
            const Divider(height: Space.xl),
            if (event.offerings.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: Text(l.seasonNoOfferings, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
              ),
            for (final o in event.offerings)
              InkWell(
                borderRadius: Radii.mdAll,
                onTap: admin ? () => _editOffering(context, ref, event.id, o) : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.sm, horizontal: Space.xs),
                  child: Row(
                    children: [
                      Icon(Icons.spa_outlined, size: 20, color: o.isActive ? context.colors.primary : context.colors.outline),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(o.title(lang), style: context.text.titleSmall?.copyWith(decoration: o.isActive ? null : TextDecoration.lineThrough)),
                            Text(
                              [
                                l.seasonTokenLength(fmt.duration(o.tokenMinutes)),
                                l.seasonCapacityShort(o.capacity),
                                o.paysInFull ? l.seasonPayInFull : l.seasonPayAdvance(fmt.money(o.prepayBaisa)),
                              ].join(' · '),
                              style: context.text.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(fmt.money(o.priceBaisa), style: context.text.titleSmall),
                          Text(l.seasonTokensSold(o.tokenCount), style: context.text.labelSmall),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (admin)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: () => _editOffering(context, ref, event.id, null),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(l.seasonAddOffering),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Future<void> _editEvent(BuildContext context, WidgetRef ref, SeasonalEvent? event) async {
  await showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _EventSheet(event: event),
  );
  ref.invalidate(adminSeasonalEventsProvider);
}

Future<void> _editOffering(BuildContext context, WidgetRef ref, String eventId, SeasonalOffering? offering) async {
  await showModalBottomSheet<void>(
    useRootNavigator: true,
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _OfferingSheet(eventId: eventId, offering: offering),
  );
  ref.invalidate(adminSeasonalEventsProvider);
}

class _SheetFrame extends StatelessWidget {
  const _SheetFrame({required this.title, required this.children, this.onDelete});
  final String title;
  final List<Widget> children;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, MediaQuery.viewInsetsOf(context).bottom + Space.xl),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: context.text.headlineSmall)),
              if (onDelete != null) IconButton(tooltip: context.l10n.actionDelete, onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded)),
            ],
          ),
          const SizedBox(height: Space.lg),
          ...children,
        ],
      ),
    ),
  );
}

Future<bool> _confirmDelete(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.actionDelete)),
        ],
      ),
    ) ==
    true;

class _EventSheet extends ConsumerStatefulWidget {
  const _EventSheet({this.event});
  final SeasonalEvent? event;
  @override
  ConsumerState<_EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends ConsumerState<_EventSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.event?.name ?? '');
  late final _nameAr = TextEditingController(text: widget.event?.nameAr ?? '');
  late final _desc = TextEditingController(text: widget.event?.description ?? '');
  late final _descAr = TextEditingController(text: widget.event?.descriptionAr ?? '');
  late String _start = widget.event?.startDate ?? Ymd.of(DateTime.now());
  late String _end = widget.event?.endDate ?? Ymd.add(Ymd.of(DateTime.now()), 3);
  late int _open = widget.event?.openMinute ?? 10 * 60;
  late int _close = widget.event?.closeMinute ?? 22 * 60;
  late bool _active = widget.event?.isActive ?? true;

  @override
  void dispose() {
    for (final c in [_name, _nameAr, _desc, _descAr]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) throw StateError('invalid');
    final l = context.l10n;
    final body = {
      'name': _name.text.trim(),
      'nameAr': _opt(_nameAr),
      'description': _opt(_desc),
      'descriptionAr': _opt(_descAr),
      'startDate': _start,
      'endDate': _end,
      'openMinute': _open,
      'closeMinute': _close,
      'isActive': _active,
    };
    await guard(context, () => ref.read(seasonalRepositoryProvider).saveEvent(widget.event?.id, body));
    if (mounted) {
      showGlowSnack(context, l.serviceSaved);
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    if (!await _confirmDelete(context, l.seasonDeleteEventConfirm) || !mounted) return;
    await guard(context, () => ref.read(seasonalRepositoryProvider).deleteEvent(widget.event!.id));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: Ymd.parse(start ? _start : _end),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _start = Ymd.of(picked);
        if (_end.compareTo(_start) < 0) _end = _start;
      } else {
        _end = Ymd.of(picked);
      }
    });
  }

  Future<void> _pickTime(bool open) async {
    final m = open ? _open : _close;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: m ~/ 60 % 24, minute: m % 60),
    );
    if (picked == null) return;
    setState(() => open ? _open = picked.hour * 60 + picked.minute : _close = picked.hour * 60 + picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final v = V(context);
    final badHours = _close <= _open;
    return Form(
      key: _form,
      child: _SheetFrame(
        title: widget.event == null ? l.seasonNewEvent : l.seasonEditEvent,
        onDelete: widget.event == null ? null : _delete,
        children: [
          GlowField(controller: _name, label: l.seasonEventName, hint: l.seasonEventNameHint, validator: v.required),
          GlowField(controller: _nameAr, label: l.serviceNameAr, textDirection: TextDirection.rtl),
          GlowField(controller: _desc, label: '${l.serviceDescription} (${l.labelOptional})', maxLines: 2),
          GlowField(controller: _descAr, label: l.serviceDescriptionAr, maxLines: 2, textDirection: TextDirection.rtl),
          Row(
            children: [
              Expanded(
                child: _PickerTile(label: l.seasonFirstDay, value: fmt.ymdLabel(_start), icon: Icons.event_outlined, onTap: () => _pickDate(true)),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: _PickerTile(label: l.seasonLastDay, value: fmt.ymdLabel(_end), icon: Icons.event_available_outlined, onTap: () => _pickDate(false)),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: _PickerTile(label: l.seasonOpens, value: fmt.minuteOfDay(_open), icon: Icons.schedule_rounded, onTap: () => _pickTime(true)),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: _PickerTile(label: l.seasonCloses, value: fmt.minuteOfDay(_close), icon: Icons.schedule_rounded, onTap: () => _pickTime(false)),
              ),
            ],
          ),
          if (badHours)
            Padding(
              padding: const EdgeInsets.only(top: Space.sm),
              child: Text(l.seasonHoursInvalid, style: context.text.bodySmall?.copyWith(color: context.colors.error)),
            ),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: _active, onChanged: (x) => setState(() => _active = x), title: Text(l.seasonActive)),
          const SizedBox(height: Space.md),
          AnimatedButton(label: l.actionSave, keepSuccess: true, enabled: !badHours, onPressed: badHours ? null : _save),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({required this.label, required this.value, required this.icon, required this.onTap});
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: Radii.mdAll,
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon, size: 20)),
      child: Text(value, style: context.text.bodyLarge),
    ),
  );
}

class _OfferingSheet extends ConsumerStatefulWidget {
  const _OfferingSheet({required this.eventId, this.offering});
  final String eventId;
  final SeasonalOffering? offering;
  @override
  ConsumerState<_OfferingSheet> createState() => _OfferingSheetState();
}

class _OfferingSheetState extends ConsumerState<_OfferingSheet> {
  final _form = GlobalKey<FormState>();
  static String _omr(int baisa) => (baisa / 1000).toString().replaceFirst(RegExp(r'\.0$'), '');
  late final _name = TextEditingController(text: widget.offering?.name ?? '');
  late final _nameAr = TextEditingController(text: widget.offering?.nameAr ?? '');
  late final _minutes = TextEditingController(text: '${widget.offering?.tokenMinutes ?? 20}');
  late final _capacity = TextEditingController(text: '${widget.offering?.capacity ?? 1}');
  late final _price = TextEditingController(text: widget.offering == null ? '' : _omr(widget.offering!.priceBaisa));
  late final _advance = TextEditingController(text: widget.offering == null || widget.offering!.paysInFull ? '' : _omr(widget.offering!.prepayBaisa));
  late PrepayMode _mode = widget.offering?.prepayMode ?? PrepayMode.full;
  late bool _active = widget.offering?.isActive ?? true;

  @override
  void dispose() {
    for (final c in [_name, _nameAr, _minutes, _capacity, _price, _advance]) {
      c.dispose();
    }
    super.dispose();
  }

  int _baisa(TextEditingController c) => ((double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0) * 1000).round();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) throw StateError('invalid');
    final l = context.l10n;
    final body = {
      'name': _name.text.trim(),
      'nameAr': _nameAr.text.trim().isEmpty ? null : _nameAr.text.trim(),
      'tokenMinutes': int.parse(_minutes.text.trim()),
      'capacity': int.parse(_capacity.text.trim()),
      'priceBaisa': _baisa(_price),
      'prepayMode': _mode == PrepayMode.full ? 'FULL' : 'FIXED',
      'prepayBaisa': _mode == PrepayMode.fixed ? _baisa(_advance) : 0,
      'isActive': _active,
    };
    await guard(context, () => ref.read(seasonalRepositoryProvider).saveOffering(eventId: widget.eventId, id: widget.offering?.id, body: body));
    if (mounted) {
      showGlowSnack(context, l.serviceSaved);
      Navigator.pop(context);
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    if (!await _confirmDelete(context, l.serviceDeleteConfirm) || !mounted) return;
    await guard(context, () => ref.read(seasonalRepositoryProvider).deleteOffering(widget.offering!.id));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = V(context);
    String? positiveInt(String? s) => (int.tryParse(s?.trim() ?? '') ?? 0) > 0 ? null : l.seasonPositiveNumber;
    return Form(
      key: _form,
      child: _SheetFrame(
        title: widget.offering == null ? l.seasonAddOffering : l.seasonEditOffering,
        onDelete: widget.offering == null ? null : _delete,
        children: [
          GlowField(controller: _name, label: l.serviceName, hint: l.seasonOfferingHint, validator: v.required),
          GlowField(controller: _nameAr, label: l.serviceNameAr, textDirection: TextDirection.rtl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: GlowField(controller: _minutes, label: l.seasonTokenMinutes, keyboardType: TextInputType.number, validator: positiveInt),
              ),
              const SizedBox(width: Space.md),
              Expanded(
                child: GlowField(
                  controller: _capacity,
                  label: l.seasonCapacity,
                  helper: l.seasonCapacityHelp,
                  keyboardType: TextInputType.number,
                  validator: positiveInt,
                ),
              ),
            ],
          ),
          GlowField(controller: _price, label: l.servicePrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: v.number),
          Text(l.seasonAdvance, style: context.text.labelMedium),
          const SizedBox(height: Space.sm),
          SegmentedButton<PrepayMode>(
            segments: [
              ButtonSegment(value: PrepayMode.full, label: Text(l.seasonAdvanceFull)),
              ButtonSegment(value: PrepayMode.fixed, label: Text(l.seasonAdvanceFixed)),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 250),
            child: _mode == PrepayMode.fixed
                ? Padding(
                    padding: const EdgeInsets.only(top: Space.lg),
                    child: GlowField(
                      controller: _advance,
                      label: l.seasonAdvanceAmount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (s) {
                        final a = _baisa(_advance);
                        if (a <= 0) return l.seasonPositiveNumber;
                        if (a > _baisa(_price)) return l.seasonAdvanceTooHigh;
                        return null;
                      },
                    ),
                  )
                : const SizedBox(width: double.infinity, height: Space.md),
          ),
          Text(l.seasonAdvanceHelp, style: context.text.bodySmall),
          SwitchListTile(contentPadding: EdgeInsets.zero, value: _active, onChanged: (x) => setState(() => _active = x), title: Text(l.seasonActive)),
          const SizedBox(height: Space.md),
          AnimatedButton(label: l.actionSave, keepSuccess: true, onPressed: _save),
        ],
      ),
    );
  }
}
