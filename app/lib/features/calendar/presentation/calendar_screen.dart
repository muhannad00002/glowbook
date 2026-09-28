import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/auth/auth_controller.dart';
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
import '../../../shared/widgets/booking_tile.dart';
import '../../../shared/widgets/common.dart';
import '../../bookings/presentation/block_time_sheet.dart';
import '../../bookings/presentation/booking_detail_sheet.dart';
import '../data/calendar_repository.dart';
import 'calendar_controller.dart';

const double _pxPerMinute = 1.6; // 96px per hour
const double _gutter = 56;

class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(calendarControllerProvider);
    final c = ref.read(calendarControllerProvider.notifier);
    final m = ref.watch(membershipProvider);
    final l = context.l10n;
    final fmt = context.fmt;
    final staffMode = m?.role == 'STAFF';

    final title = switch (s.view) {
      CalendarView.day => fmt.ymdLabel(s.date, pattern: 'MMMMEEEEd'),
      CalendarView.week => '${fmt.ymdLabel(s.weekStart, pattern: 'MMMd')} – ${fmt.ymdLabel(s.weekEnd, pattern: 'MMMd')}',
      CalendarView.month => fmt.ymdLabel('${s.month}-01', pattern: 'yMMMM'),
    };
    final rtl = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(gutterOf(context), Space.lg, gutterOf(context), Space.sm),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: Motion.of(context).medium,
                          layoutBuilder: (current, previous) => Stack(alignment: AlignmentDirectional.centerStart, children: [...previous, ?current]),
                          child: Text(title, key: ValueKey(title), style: context.text.headlineMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                      IconButton(tooltip: l.calendarPrevious, onPressed: () => c.step(-1), icon: Icon(rtl ? Icons.chevron_right_rounded : Icons.chevron_left_rounded)),
                      TextButton(onPressed: c.today, child: Text(l.calendarJumpToday)),
                      IconButton(tooltip: l.calendarNext, onPressed: () => c.step(1), icon: Icon(rtl ? Icons.chevron_left_rounded : Icons.chevron_right_rounded)),
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  Row(
                    children: [
                      SegmentedButton<CalendarView>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(value: CalendarView.day, label: Text(l.calendarDay)),
                          ButtonSegment(value: CalendarView.week, label: Text(l.calendarWeek)),
                          ButtonSegment(value: CalendarView.month, label: Text(l.calendarMonth)),
                        ],
                        selected: {s.view},
                        onSelectionChanged: (v) => c.setView(v.first),
                      ),
                      const Spacer(),
                      if (!staffMode && MediaQuery.sizeOf(context).width >= 520)
                        FilledButton.icon(onPressed: () => context.push('/admin/bookings/new?date=${s.date}'), icon: const Icon(Icons.add_rounded), label: Text(l.newBooking)),
                    ],
                  ),
                  if (!staffMode) ...[const SizedBox(height: Space.sm), _StaffFilter(selected: s.staffId, onSelect: c.setStaff)],
                ],
              ),
            ),
            Expanded(
              child: GestureDetector(
                // Swipe between days/weeks/months.
                onHorizontalDragEnd: (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v.abs() < 400) return;
                  final next = v < 0 ? 1 : -1;
                  c.step(rtl ? -next : next);
                },
                child: AnimatedCalendarTransition(
                  dateKey: '${s.view.name}:${s.view == CalendarView.day ? s.date : s.view == CalendarView.week ? s.weekStart : s.month}:${s.staffId}',
                  forward: s.forward,
                  child: switch (s.view) {
                    CalendarView.day => _DayView(state: s),
                    CalendarView.week => _WeekView(state: s),
                    CalendarView.month => _MonthView(state: s),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: staffMode || MediaQuery.sizeOf(context).width >= 520
          ? null
          : Padding(
              padding: const EdgeInsets.only(bottom: 84),
              child: FloatingActionButton(
                tooltip: l.newBooking,
                onPressed: () => context.push('/admin/bookings/new?date=${s.date}'),
                child: const Icon(Icons.add_rounded),
              ),
            ),
    );
  }
}

class _StaffFilter extends ConsumerWidget {
  const _StaffFilter({required this.selected, required this.onSelect});
  final String? selected;
  final ValueChanged<String?> onSelect;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(calendarControllerProvider);
    final data = ref.watch(calendarRangeProvider((from: s.date, to: s.date, staffId: null))).valueOrNull;
    final staff = data?.staff ?? const <StaffMember>[];
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: Space.sm),
            child: ChoiceChip(label: Text(context.l10n.calendarAllStaff), selected: selected == null, onSelected: (_) => onSelect(null)),
          ),
          for (final m in staff)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: Space.sm),
              child: ChoiceChip(
                avatar: CircleAvatar(radius: 6, backgroundColor: hexColor(m.color)),
                label: Text(m.displayName(context.lang)),
                selected: selected == m.id,
                onSelected: (_) => onSelect(selected == m.id ? null : m.id),
              ),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day view: staff columns on a time grid
// ---------------------------------------------------------------------------

class _DayView extends ConsumerWidget {
  const _DayView({required this.state});
  final CalendarState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(calendarRangeProvider((from: state.date, to: state.date, staffId: state.staffId)));
    return AsyncView(
      value: data,
      loading: const _GridSkeleton(),
      onRetry: () => ref.invalidate(calendarRangeProvider),
      data: (d) => _DayGrid(data: d, date: state.date),
    );
  }
}

class _DayGrid extends ConsumerStatefulWidget {
  const _DayGrid({required this.data, required this.date});
  final CalendarData data;
  final String date;
  @override
  ConsumerState<_DayGrid> createState() => _DayGridState();
}

class _DayGridState extends ConsumerState<_DayGrid> {
  final _vertical = ScrollController();
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Keep the "now" line moving.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => mounted ? setState(() {}) : null);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToInterest());
  }

  @override
  void dispose() {
    _tick?.cancel();
    _vertical.dispose();
    super.dispose();
  }

  (int, int) _bounds() {
    final dow = Ymd.dayOfWeek(widget.date);
    final open = widget.data.salonHours.where((h) => h.dayOfWeek == dow).toList();
    var start = open.isEmpty ? 9 * 60 : open.map((h) => h.startMinute).reduce(math.min);
    var end = open.isEmpty ? 21 * 60 : open.map((h) => h.endMinute).reduce(math.max);
    final tz = ref.read(salonTimezoneProvider);
    for (final b in widget.data.bookings) {
      final s = _minute(b.start, tz);
      final e = s + b.durationMinutes;
      start = math.min(start, s);
      end = math.max(end, e);
    }
    return ((start ~/ 60) * 60, ((end + 59) ~/ 60) * 60);
  }

  static int _minute(DateTime instant, String tz) {
    final d = Fmt.inZone(instant, tz);
    return d.hour * 60 + d.minute;
  }

  void _scrollToInterest() {
    if (!_vertical.hasClients) return;
    final tz = ref.read(salonTimezoneProvider);
    final (start, _) = _bounds();
    final isToday = widget.date == Ymd.today(tz);
    final target = isToday
        ? _minute(DateTime.now(), tz) - 60
        : (widget.data.bookings.isEmpty ? start : _minute(widget.data.bookings.first.start, tz) - 30);
    final offset = ((target - start) * _pxPerMinute).clamp(0.0, _vertical.position.maxScrollExtent);
    _vertical.animateTo(offset, duration: Motion.of(context).slow, curve: Motion.standard);
  }

  @override
  Widget build(BuildContext context) {
    final tz = ref.watch(salonTimezoneProvider);
    final l = context.l10n;
    final d = widget.data;
    final closedName = d.closedDates[widget.date];
    final dow = Ymd.dayOfWeek(widget.date);
    final salonOpen = d.salonHours.any((h) => h.dayOfWeek == dow);

    if (d.staff.isEmpty) {
      return AnimatedEmptyState(art: GlowArt.brush, title: l.staffEmptyTitle, body: l.staffEmptyBody, compact: true);
    }
    if (closedName != null || !salonOpen) {
      if (d.bookings.isEmpty) {
        return AnimatedEmptyState(art: GlowArt.calendar, title: l.calendarClosed, body: closedName, compact: true);
      }
    }

    final (start, end) = _bounds();
    final height = (end - start) * _pxPerMinute;
    final width = MediaQuery.sizeOf(context).width;
    final colWidth = math.max(150.0, (width - _gutter - gutterOf(context) * 2 - (width >= Breakpoints.tablet ? 264 : 0)) / d.staff.length);
    final isToday = widget.date == Ymd.today(tz);
    final nowMinute = _minute(DateTime.now(), tz);
    final canBook = ref.watch(membershipProvider)?.isFrontDesk ?? false;

    return Column(
      children: [
        // Staff header row, scrolls horizontally with the grid.
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: gutterOf(context)),
            child: SizedBox(
              width: _gutter + colWidth * d.staff.length,
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: _gutter),
                      for (final s in d.staff)
                        SizedBox(
                          width: colWidth,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: Space.sm),
                            child: Row(children: [
                              InitialsAvatar(name: s.name, color: hexColor(s.color), size: 32, photoUrl: s.photoUrl),
                              const SizedBox(width: Space.sm),
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(s.displayName(context.lang), style: context.text.titleSmall, overflow: TextOverflow.ellipsis),
                                  Text(
                                    l.calendarBookingsCount(d.bookings.where((b) => b.staff.id == s.id && b.isLive).length),
                                    style: context.text.bodySmall,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ]),
                              ),
                            ]),
                          ),
                        ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _vertical,
                      padding: const EdgeInsets.only(bottom: 120),
                      child: SizedBox(
                        height: height + Space.lg,
                        child: Stack(
                          children: [
                            // Hour lines + labels.
                            for (var m = start; m <= end; m += 60)
                              Positioned(
                                top: (m - start) * _pxPerMinute,
                                left: 0,
                                right: 0,
                                child: Row(children: [
                                  SizedBox(
                                    width: _gutter,
                                    child: Transform.translate(
                                      offset: const Offset(0, -8),
                                      child: Text(context.fmt.minuteOfDay(m), style: context.text.labelSmall, textAlign: TextAlign.center),
                                    ),
                                  ),
                                  Expanded(child: Divider(height: 1, color: context.colors.outlineVariant.withValues(alpha: 0.5))),
                                ]),
                              ),
                            // Columns.
                            for (var i = 0; i < d.staff.length; i++)
                              Positioned(
                                top: 0,
                                bottom: 0,
                                left: _gutter + colWidth * i,
                                width: colWidth,
                                child: _StaffColumn(
                                  staff: d.staff[i],
                                  data: d,
                                  date: widget.date,
                                  dayStart: start,
                                  dayEnd: end,
                                  timezone: tz,
                                  canBook: canBook,
                                ),
                              ),
                            if (isToday && nowMinute >= start && nowMinute <= end)
                              Positioned(
                                top: (nowMinute - start) * _pxPerMinute - 5,
                                left: _gutter - 5,
                                right: 0,
                                child: IgnorePointer(
                                  child: Row(children: [
                                    Container(width: 10, height: 10, decoration: BoxDecoration(color: context.colors.error, shape: BoxShape.circle)),
                                    Expanded(child: Container(height: 2, color: context.colors.error)),
                                  ]),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _StaffColumn extends ConsumerWidget {
  const _StaffColumn({required this.staff, required this.data, required this.date, required this.dayStart, required this.dayEnd, required this.timezone, required this.canBook});
  final StaffMember staff;
  final CalendarData data;
  final String date;
  final int dayStart;
  final int dayEnd;
  final String timezone;
  final bool canBook;

  int _m(DateTime t) {
    final d = Fmt.inZone(t, timezone);
    final day = Ymd.of(d);
    if (day.compareTo(date) < 0) return 0;
    if (day.compareTo(date) > 0) return 24 * 60;
    return d.hour * 60 + d.minute;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dow = Ymd.dayOfWeek(date);
    final salon = data.salonHours.where((h) => h.dayOfWeek == dow).toList();
    final shifts = data.closedDates.containsKey(date) || salon.isEmpty
        ? <Shift>[]
        : staff.hours.where((h) => h.dayOfWeek == dow).map((h) {
            final s = math.max(h.startMinute, salon.first.startMinute);
            final e = math.min(h.endMinute, salon.first.endMinute);
            return Shift(dayOfWeek: dow, startMinute: s, endMinute: e);
          }).where((h) => h.endMinute > h.startMinute).toList();

    // Off-shift ranges shaded.
    final off = <(int, int)>[];
    var cursor = dayStart;
    for (final s in shifts..sort((a, b) => a.startMinute - b.startMinute)) {
      if (s.startMinute > cursor) off.add((cursor, s.startMinute));
      cursor = math.max(cursor, s.endMinute);
    }
    if (cursor < dayEnd) off.add((cursor, dayEnd));

    final blocks = data.blocks.where((b) => b.staffId == null || b.staffId == staff.id).toList();
    final bookings = data.bookings.where((b) => b.staff.id == staff.id).toList()..sort((a, b) => a.start.compareTo(b.start));
    final artist = hexColor(staff.color);

    return Container(
      decoration: BoxDecoration(border: BorderDirectional(start: BorderSide(color: context.colors.outlineVariant.withValues(alpha: 0.5)))),
      child: Stack(
        children: [
          // Tap empty time → new booking with this artist at that time.
          if (canBook)
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTapUp: (d) {
                  final minute = dayStart + (d.localPosition.dy / _pxPerMinute) ~/ 15 * 15;
                  final inShift = shifts.any((s) => minute >= s.startMinute && minute < s.endMinute);
                  if (!inShift) return;
                  context.push('/admin/bookings/new?date=$date&staff=${staff.id}&minute=$minute');
                },
              ),
            ),
          for (final (s, e) in off)
            Positioned(
              top: (s - dayStart) * _pxPerMinute,
              height: (e - s) * _pxPerMinute,
              left: 0,
              right: 0,
              child: IgnorePointer(child: _Hatch(color: context.colors.onSurface.withValues(alpha: 0.05))),
            ),
          for (final b in blocks)
            Positioned(
              top: (math.max(_m(b.start), dayStart) - dayStart) * _pxPerMinute,
              height: math.max(18, (math.min(_m(b.end), dayEnd) - math.max(_m(b.start), dayStart)) * _pxPerMinute),
              left: 3,
              right: 3,
              child: _BlockTile(block: b),
            ),
          for (var i = 0; i < bookings.length; i++)
            Positioned(
              top: (_m(bookings[i].start) - dayStart) * _pxPerMinute + 1,
              height: math.max(28, bookings[i].durationMinutes * _pxPerMinute - 2),
              left: 3,
              right: 3,
              child: StaggeredEntrance(
                key: ValueKey(bookings[i].id),
                index: i,
                offset: 10,
                child: _GridBooking(booking: bookings[i], color: artist, timezone: timezone),
              ),
            ),
        ],
      ),
    );
  }
}

class _GridBooking extends StatelessWidget {
  const _GridBooking({required this.booking, required this.color, required this.timezone});
  final Booking booking;
  final Color color;
  final String timezone;

  @override
  Widget build(BuildContext context) {
    final status = context.glow.forStatus(booking.status);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = booking.isLive ? Color.alphaBlend(color.withValues(alpha: dark ? 0.32 : 0.16), context.colors.surface) : context.colors.surfaceContainer;
    final fmt = context.fmt;
    return Semantics(
      button: true,
      label: '${fmt.time(booking.start, timezone)} ${booking.customer.name}, ${booking.service.display(context.lang)}, ${fmt.statusLabel(booking.status)}',
      child: PressableScale(
        onTap: () => showBookingDetail(context, booking.id),
        child: AnimatedContainer(
          duration: Motion.of(context).medium,
          padding: const EdgeInsets.fromLTRB(8, 5, 6, 4),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: Radii.smAll,
            border: BorderDirectional(start: BorderSide(color: booking.isLive ? color : context.colors.outline, width: 4)),
          ),
          child: ExcludeSemantics(
            child: LayoutBuilder(builder: (context, c) {
              final tall = c.maxHeight > 60;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        booking.customer.name,
                        style: context.text.labelMedium?.copyWith(decoration: booking.status == 'CANCELLED' ? TextDecoration.lineThrough : null),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(StatusChip.iconFor(booking.status), size: 13, color: status.fg),
                  ]),
                  if (c.maxHeight > 36)
                    Text(booking.service.display(context.lang), style: context.text.bodySmall?.copyWith(fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (tall)
                    Text('${fmt.time(booking.start, timezone)} · ${fmt.duration(booking.durationMinutes)}',
                        style: context.text.labelSmall?.copyWith(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({required this.block});
  final CalendarBlock block;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final label = block.isTimeOff
        ? l.calendarTimeOff
        : switch (block.type) {
            'LUNCH' => l.blockLunch,
            'BREAK' => l.blockBreak,
            'PERSONAL' => l.blockPersonal,
            'MEETING' => l.blockMeeting,
            'PRIVATE_BOOKING' => l.blockPrivate,
            _ => l.calendarBlocked,
          };
    return IgnorePointer(
      child: ClipRRect(
        borderRadius: Radii.smAll,
        child: Stack(children: [
          Positioned.fill(child: _Hatch(color: context.colors.onSurface.withValues(alpha: 0.09), dense: true)),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Text(block.note ?? label, style: context.text.labelSmall, maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
        ]),
      ),
    );
  }
}

class _Hatch extends StatelessWidget {
  const _Hatch({required this.color, this.dense = false});
  final Color color;
  final bool dense;
  @override
  Widget build(BuildContext context) => CustomPaint(painter: _HatchPainter(color, dense ? 8 : 12));
}

class _HatchPainter extends CustomPainter {
  _HatchPainter(this.color, this.gap);
  final Color color;
  final double gap;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = color.withValues(alpha: color.a * 0.6));
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    for (double x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), p);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.color != color;
}

class _GridSkeleton extends StatelessWidget {
  const _GridSkeleton();
  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: gutterOf(context), vertical: Space.lg),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(width: _gutter),
            for (var c = 0; c < 3; c++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(children: [
                    const SkeletonBox(height: 32, radius: 16),
                    const SizedBox(height: Space.lg),
                    SkeletonBox(height: 90.0 + c * 20, radius: Radii.sm),
                    const SizedBox(height: Space.xl),
                    SkeletonBox(height: 140.0 - c * 20, radius: Radii.sm),
                    const SizedBox(height: Space.md),
                    const SkeletonBox(height: 70, radius: Radii.sm),
                  ]),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Week view
// ---------------------------------------------------------------------------

class _WeekView extends ConsumerWidget {
  const _WeekView({required this.state});
  final CalendarState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(calendarRangeProvider((from: state.weekStart, to: state.weekEnd, staffId: state.staffId)));
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    return AsyncView(
      value: data,
      loading: wide ? const _GridSkeleton() : const SkeletonList(),
      onRetry: () => ref.invalidate(calendarRangeProvider),
      data: (d) => wide ? _WeekGrid(data: d, state: state) : _WeekAgenda(data: d, state: state),
    );
  }
}

class _WeekAgenda extends ConsumerWidget {
  const _WeekAgenda({required this.data, required this.state});
  final CalendarData data;
  final CalendarState state;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tz = ref.watch(salonTimezoneProvider);
    final fmt = context.fmt;
    final today = Ymd.today(tz);
    var index = 0;
    return ListView(
      padding: EdgeInsets.fromLTRB(gutterOf(context), Space.sm, gutterOf(context), 140),
      children: [
        for (var i = 0; i < 7; i++)
          Builder(builder: (context) {
            final date = Ymd.add(state.weekStart, i);
            final items = data.bookings.where((b) => Ymd.of(Fmt.inZone(b.start, tz)) == date).toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InkWell(
                  borderRadius: Radii.mdAll,
                  onTap: () => ref.read(calendarControllerProvider.notifier).openDay(date),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.md),
                    child: Row(children: [
                      Text(fmt.ymdLabel(date, pattern: 'EEEE d MMM'),
                          style: context.text.titleMedium?.copyWith(color: date == today ? context.colors.primary : null)),
                      const SizedBox(width: Space.sm),
                      if (data.closedDates.containsKey(date)) Text('· ${context.l10n.calendarClosed}', style: context.text.bodySmall),
                      const Spacer(),
                      Text(context.l10n.calendarBookingsCount(items.where((b) => b.isLive).length), style: context.text.bodySmall),
                    ]),
                  ),
                ),
                for (final b in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: AnimatedBookingCard(key: ValueKey(b.id), index: index++, booking: b, timezone: tz, onTap: () => showBookingDetail(context, b.id)),
                  ),
                if (items.isEmpty) Padding(padding: const EdgeInsets.only(bottom: Space.sm), child: Text('—', style: context.text.bodySmall)),
              ],
            );
          }),
      ],
    );
  }
}

class _WeekGrid extends ConsumerWidget {
  const _WeekGrid({required this.data, required this.state});
  final CalendarData data;
  final CalendarState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tz = ref.watch(salonTimezoneProvider);
    final fmt = context.fmt;
    final today = Ymd.today(tz);
    final open = data.salonHours.isEmpty ? 9 * 60 : data.salonHours.map((h) => h.startMinute).reduce(math.min);
    final close = data.salonHours.isEmpty ? 21 * 60 : data.salonHours.map((h) => h.endMinute).reduce(math.max);
    final start = (open ~/ 60) * 60;
    final end = ((close + 59) ~/ 60) * 60;
    const px = 1.1;
    final staffColor = {for (final s in data.staff) s.id: hexColor(s.color)};

    int minute(DateTime t) {
      final d = Fmt.inZone(t, tz);
      return d.hour * 60 + d.minute;
    }

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: gutterOf(context)),
      child: Column(
        children: [
          Row(children: [
            const SizedBox(width: _gutter),
            for (var i = 0; i < 7; i++)
              Expanded(
                child: InkWell(
                  borderRadius: Radii.mdAll,
                  onTap: () => ref.read(calendarControllerProvider.notifier).openDay(Ymd.add(state.weekStart, i)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.sm),
                    child: Column(children: [
                      Text(fmt.ymdLabel(Ymd.add(state.weekStart, i), pattern: 'E'), style: context.text.labelSmall),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Ymd.add(state.weekStart, i) == today ? context.colors.primary : null, shape: BoxShape.circle),
                        child: Text(
                          fmt.ymdLabel(Ymd.add(state.weekStart, i), pattern: 'd'),
                          style: context.text.titleMedium?.copyWith(color: Ymd.add(state.weekStart, i) == today ? context.colors.onPrimary : null),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
          ]),
          const Divider(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 120),
              child: SizedBox(
                height: (end - start) * px + Space.lg,
                child: LayoutBuilder(builder: (context, c) {
                  final colW = (c.maxWidth - _gutter) / 7;
                  return Stack(children: [
                    for (var m = start; m <= end; m += 60)
                      Positioned(
                        top: (m - start) * px,
                        left: 0,
                        right: 0,
                        child: Row(children: [
                          SizedBox(width: _gutter, child: Transform.translate(offset: const Offset(0, -8), child: Text(fmt.minuteOfDay(m), style: context.text.labelSmall, textAlign: TextAlign.center))),
                          Expanded(child: Divider(height: 1, color: context.colors.outlineVariant.withValues(alpha: 0.5))),
                        ]),
                      ),
                    for (var i = 0; i < 7; i++)
                      if (data.closedDates.containsKey(Ymd.add(state.weekStart, i)))
                        Positioned(left: _gutter + colW * i, width: colW, top: 0, bottom: 0, child: IgnorePointer(child: _Hatch(color: context.colors.onSurface.withValues(alpha: 0.05)))),
                    ...() {
                      final tiles = <Widget>[];
                      for (var i = 0; i < 7; i++) {
                        final date = Ymd.add(state.weekStart, i);
                        final items = data.bookings.where((b) => Ymd.of(Fmt.inZone(b.start, tz)) == date).toList()..sort((a, b) => a.start.compareTo(b.start));
                        // Simple lane assignment so overlapping artists sit side by side.
                        final laneEnds = <int>[];
                        final lanes = <String, int>{};
                        for (final b in items) {
                          final s = minute(b.start);
                          var lane = laneEnds.indexWhere((e) => e <= s);
                          if (lane == -1) {
                            laneEnds.add(0);
                            lane = laneEnds.length - 1;
                          }
                          laneEnds[lane] = s + b.durationMinutes;
                          lanes[b.id] = lane;
                        }
                        final laneCount = math.max(1, laneEnds.length);
                        for (var k = 0; k < items.length; k++) {
                          final b = items[k];
                          final w = colW / laneCount;
                          tiles.add(Positioned(
                            top: (minute(b.start) - start) * px,
                            height: math.max(20, b.durationMinutes * px - 2),
                            left: _gutter + colW * i + w * lanes[b.id]! + 1,
                            width: w - 2,
                            child: StaggeredEntrance(
                              key: ValueKey(b.id),
                              index: k,
                              offset: 8,
                              child: _GridBooking(booking: b, color: staffColor[b.staff.id] ?? context.colors.primary, timezone: tz),
                            ),
                          ));
                        }
                      }
                      return tiles;
                    }(),
                  ]);
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Month view
// ---------------------------------------------------------------------------

class _MonthView extends ConsumerWidget {
  const _MonthView({required this.state});
  final CalendarState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(calendarMonthProvider((month: state.month, staffId: state.staffId)));
    final tz = ref.watch(salonTimezoneProvider);
    final today = Ymd.today(tz);
    final locale = context.lang;
    return AsyncView(
      value: data,
      loading: const _GridSkeleton(),
      onRetry: () => ref.invalidate(calendarMonthProvider),
      data: (m) {
        final first = '${state.month}-01';
        final lead = (Ymd.dayOfWeek(first) + 1) % 7; // weeks start Saturday
        final maxCount = m.days.fold<int>(1, (a, d) => math.max(a, d.total));
        final cells = <Widget>[];
        for (var i = 0; i < 7; i++) {
          cells.add(Center(child: Text(DateFormat.E(locale).format(Ymd.parse(Ymd.add('2023-01-07', i))), style: context.text.labelSmall)));
        }
        for (var i = 0; i < lead; i++) {
          cells.add(const SizedBox());
        }
        for (var i = 0; i < m.days.length; i++) {
          final d = m.days[i];
          final intensity = d.total / maxCount;
          final closed = m.closed.containsKey(d.date);
          cells.add(StaggeredEntrance(
            index: i ~/ 7,
            offset: 6,
            child: PressableScale(
              onTap: () => ref.read(calendarControllerProvider.notifier).openDay(d.date),
              child: Semantics(
                button: true,
                label: '${context.fmt.ymdLabel(d.date, pattern: 'MMMMEEEEd')}, ${context.l10n.calendarBookingsCount(d.total)}',
                child: Container(
                  margin: const EdgeInsets.all(3),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: closed
                        ? context.colors.surfaceContainer
                        : Color.lerp(context.colors.surface, context.colors.primaryContainer, (intensity * 0.9).clamp(0.0, 1.0)),
                    borderRadius: Radii.mdAll,
                    border: Border.all(color: d.date == today ? context.colors.primary : context.colors.outlineVariant.withValues(alpha: 0.6), width: d.date == today ? 2 : 1),
                  ),
                  child: ExcludeSemantics(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(context.fmt.ymdLabel(d.date, pattern: 'd'), style: context.text.labelLarge),
                        const Spacer(),
                        if (closed)
                          Icon(Icons.do_not_disturb_on_outlined, size: 14, color: context.colors.onSurfaceVariant)
                        else if (d.total > 0)
                          Text('${d.total}', style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ));
        }
        return GridView.count(
          padding: EdgeInsets.fromLTRB(gutterOf(context), Space.sm, gutterOf(context), 140),
          crossAxisCount: 7,
          childAspectRatio: MediaQuery.sizeOf(context).width >= Breakpoints.tablet ? 1.3 : 0.78,
          children: cells,
        );
      },
    );
  }
}

/// Used by the staff "block time" FAB in calendar contexts.
Future<void> blockTimeFromCalendar(BuildContext context, WidgetRef ref) {
  final s = ref.read(calendarControllerProvider);
  return showBlockTimeSheet(context, ref, staffId: s.staffId, date: s.date);
}

