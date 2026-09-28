import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/animations/animated_counter.dart';
import '../../../shared/animations/animated_empty_state.dart';
import '../../../shared/animations/glow_illustration.dart';
import '../../../shared/animations/shimmer_loading.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/booking_tile.dart';
import '../../../shared/widgets/common.dart';
import '../../bookings/presentation/block_time_sheet.dart';
import '../../bookings/presentation/booking_detail_sheet.dart';
import '../data/dashboard_repository.dart';

/// Salon home (owners, managers, reception) and "My day" for artists.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, this.staffMode = false});
  final bool staffMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dashboardProvider);
    final tz = ref.watch(salonTimezoneProvider);
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardProvider.future),
        child: AsyncView(
          value: data,
          onRetry: () => ref.invalidate(dashboardProvider),
          loading: const _DashboardSkeleton(),
          data: (d) => _DashboardBody(data: d, timezone: tz, staffMode: staffMode),
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody({required this.data, required this.timezone, required this.staffMode});
  final DashboardData data;
  final String timezone;
  final bool staffMode;

  String _greeting(BuildContext context) {
    final h = data.localMinute ~/ 60;
    final l = context.l10n;
    return h < 12 ? l.greetingMorning : h < 17 ? l.greetingAfternoon : l.greetingEvening;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final fmt = context.fmt;
    final me = ref.watch(authControllerProvider).valueOrNull?.me.user;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= Breakpoints.desktop;
    final g = gutterOf(context);
    final base = staffMode ? '/staff' : '/admin';

    final stats = [
      (l.summaryAppointments, data.appointments, Icons.event_available_rounded, context.colors.primary, false),
      (l.summaryConfirmed, data.confirmed, Icons.check_circle_outline_rounded, context.glow.confirmed.fg, false),
      (l.summaryPending, data.pending, Icons.hourglass_top_rounded, context.glow.pending.fg, false),
      (l.summaryCompleted, data.completed, Icons.favorite_border_rounded, context.glow.completed.fg, false),
      if (!staffMode) (l.summaryRevenue, data.revenueBaisa, Icons.payments_outlined, context.colors.secondary, true),
    ];

    final schedule = data.schedule;
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StaggeredEntrance(
          index: 0,
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(child: Text('${_greeting(context)}, ${me?.firstName ?? ''}', style: context.text.titleMedium?.copyWith(color: context.colors.onSurfaceVariant))),
                      const SizedBox(width: 6),
                      Icon(Icons.waving_hand_rounded, size: 18, color: context.colors.secondary),
                    ]),
                    const SizedBox(height: 2),
                    Text(context.lang == 'ar' && data.salonNameAr != null ? data.salonNameAr! : data.salonName, style: context.text.headlineLarge),
                    const SizedBox(height: 2),
                    Text(fmt.fullDate(DateTime.now(), timezone), style: context.text.bodySmall),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: l.navNotifications,
                onPressed: () => context.go('$base/inbox'),
                icon: Badge(isLabelVisible: data.unread > 0, label: Text('${data.unread}'), child: const Icon(Icons.notifications_none_rounded)),
              ),
            ],
          ),
        ),
        const SizedBox(height: Space.xl),
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 900 ? stats.length : c.maxWidth >= 520 ? 3 : 2;
          final w = (c.maxWidth - Space.md * (cols - 1)) / cols;
          return Wrap(
            spacing: Space.md,
            runSpacing: Space.md,
            children: [
              for (var i = 0; i < stats.length; i++)
                SizedBox(
                  width: (!staffMode && i == stats.length - 1 && cols == 2) ? c.maxWidth : w,
                  child: StaggeredEntrance(
                    index: i + 1,
                    child: StatTile(
                      label: stats[i].$1,
                      icon: stats[i].$3,
                      tint: stats[i].$4,
                      value: AnimatedCounter(
                        value: stats[i].$2,
                        format: stats[i].$5 ? (v) => fmt.money(v.round()) : null,
                        style: context.text.headlineSmall,
                      ),
                    ),
                  ),
                ),
            ],
          );
        }),
        if (!staffMode && data.expectedRevenueBaisa > 0) ...[
          const SizedBox(height: Space.sm),
          Text(l.summaryExpected(fmt.money(data.expectedRevenueBaisa)), style: context.text.bodySmall),
        ],
        if (data.nextUp != null) ...[
          const SizedBox(height: Space.xl),
          StaggeredEntrance(index: 6, child: _NextUpCard(booking: data.nextUp!, timezone: timezone)),
        ],
        if (!staffMode) ...[
          const SizedBox(height: Space.xl),
          StaggeredEntrance(index: 7, child: _QuickActions(base: base)),
        ] else ...[
          const SizedBox(height: Space.lg),
          OutlinedButton.icon(
            onPressed: () => showBlockTimeSheet(context, ref),
            icon: const Icon(Icons.block_rounded),
            label: Text(l.quickBlockTime),
          ),
        ],
        if (!staffMode && data.pendingRefunds > 0) ...[
          const SizedBox(height: Space.lg),
          GlowCard(
            color: context.glow.pending.bg,
            elevated: false,
            onTap: () => context.go('/admin/payments'),
            child: Row(children: [
              Icon(Icons.currency_exchange_rounded, color: context.glow.pending.fg),
              const SizedBox(width: Space.md),
              Expanded(child: Text(l.pendingRefunds(data.pendingRefunds), style: context.text.titleSmall?.copyWith(color: context.glow.pending.fg))),
              Icon(Icons.chevron_right_rounded, color: context.glow.pending.fg),
            ]),
          ),
        ],
      ],
    );

    final scheduleList = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(l.todaysSchedule, action: l.navCalendar, onAction: () => context.go('$base/calendar')),
        if (schedule.isEmpty)
          GlowCard(
            child: AnimatedEmptyState(
              art: GlowArt.calendar,
              title: l.emptyTodayTitle,
              body: l.emptyTodayBody,
              compact: true,
              action: staffMode
                  ? null
                  : FilledButton.icon(onPressed: () => context.push('/admin/bookings/new'), icon: const Icon(Icons.add_rounded), label: Text(l.newBooking)),
            ),
          )
        else
          for (var i = 0; i < schedule.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: Space.md),
              child: AnimatedBookingCard(
                key: ValueKey(schedule[i].id),
                index: i,
                booking: schedule[i],
                timezone: timezone,
                onTap: () => showBookingDetail(context, schedule[i].id),
              ),
            ),
      ],
    );

    return ListView(
      padding: EdgeInsets.fromLTRB(g, MediaQuery.paddingOf(context).top + Space.xl, g, 120),
      children: [
        ContentWidth(
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(children: [
                        header,
                        if (!staffMode) ...[const SizedBox(height: Space.xl), _WeekRevenue(week: data.week)],
                      ]),
                    ),
                    const SizedBox(width: Space.xxl),
                    Expanded(flex: 4, child: scheduleList),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    const SizedBox(height: Space.xl),
                    scheduleList,
                    if (!staffMode) ...[const SizedBox(height: Space.lg), _WeekRevenue(week: data.week)],
                  ],
                ),
        ),
      ],
    );
  }
}

class _NextUpCard extends StatelessWidget {
  const _NextUpCard({required this.booking, required this.timezone});
  final Booking booking;
  final String timezone;

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final minutes = (booking.start).difference(DateTime.now()).inMinutes;
    final onGradient = Colors.white;
    return GlowCard(
      gradient: context.glow.cardGradient,
      onTap: () => showBookingDetail(context, booking.id),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(Space.md),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: Radii.mdAll),
            child: Icon(Icons.schedule_rounded, color: onGradient),
          ),
          const SizedBox(width: Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${context.l10n.nextUp} · ${minutes > 0 ? context.l10n.inMinutes(minutes) : fmt.time(booking.start, timezone)}',
                    style: context.text.labelMedium?.copyWith(color: onGradient.withValues(alpha: 0.85))),
                const SizedBox(height: 4),
                Text(booking.customer.name, style: context.text.titleLarge?.copyWith(color: onGradient)),
                Text('${booking.service.display(context.lang)} · ${booking.staff.display(context.lang)}',
                    style: context.text.bodyMedium?.copyWith(color: onGradient.withValues(alpha: 0.9)), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Text(fmt.time(booking.start, timezone), style: context.text.titleMedium?.copyWith(color: onGradient)),
        ],
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  const _QuickActions({required this.base});
  final String base;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final actions = [
      (l.newBooking, Icons.add_rounded, () => context.push('/admin/bookings/new'), true),
      (l.quickCustomer, Icons.person_add_alt_1_outlined, () => context.go('/admin/clients?new=1'), false),
      (l.quickService, Icons.spa_outlined, () => context.push('/admin/services/new'), false),
      (l.quickBlockTime, Icons.block_rounded, () => showBlockTimeSheet(context, ref), false),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(l.quickActions),
        Wrap(
          spacing: Space.md,
          runSpacing: Space.md,
          children: [
            for (final a in actions)
              PressableScale(
                onTap: a.$3,
                child: Semantics(
                  button: true,
                  label: a.$1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                    decoration: BoxDecoration(
                      color: a.$4 ? context.colors.primary : context.colors.surface,
                      borderRadius: Radii.pillAll,
                      border: a.$4 ? null : Border.all(color: context.colors.outlineVariant),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(a.$2, size: 20, color: a.$4 ? context.colors.onPrimary : context.colors.primary),
                      const SizedBox(width: Space.sm),
                      Text(a.$1, style: context.text.labelLarge?.copyWith(color: a.$4 ? context.colors.onPrimary : context.colors.onSurface)),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _WeekRevenue extends StatelessWidget {
  const _WeekRevenue({required this.week});
  final List<({String date, int revenueBaisa})> week;

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final scheme = context.colors;
    final maxY = week.fold<int>(0, (m, w) => w.revenueBaisa > m ? w.revenueBaisa : m).toDouble();
    final total = week.fold<int>(0, (s, w) => s + w.revenueBaisa);
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(context.l10n.weekRevenue, style: context.text.titleMedium)),
            AnimatedCounter(value: total, format: (v) => fmt.money(v.round()), style: context.text.titleMedium?.copyWith(color: scheme.primary)),
          ]),
          const SizedBox(height: Space.lg),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                maxY: maxY == 0 ? 1 : maxY * 1.15,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(),
                  rightTitles: const AxisTitles(),
                  topTitles: const AxisTitles(),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (v, _) => Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(fmt.ymdLabel(week[v.toInt()].date, pattern: 'E'), style: context.text.labelSmall),
                      ),
                    ),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => scheme.inverseSurface,
                    getTooltipItem: (g, _, r, _) => BarTooltipItem(fmt.money(r.toY.round()), TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w600)),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < week.length; i++)
                    BarChartGroupData(x: i, barRods: [
                      BarChartRodData(
                        toY: week[i].revenueBaisa.toDouble(),
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: i == week.length - 1 ? [scheme.primary, scheme.primary.withValues(alpha: 0.7)] : [scheme.primaryContainer, scheme.primary.withValues(alpha: 0.45)],
                        ),
                      ),
                    ]),
                ],
              ),
              duration: Motion.of(context).slow,
              curve: Motion.standard,
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();
  @override
  Widget build(BuildContext context) {
    final g = gutterOf(context);
    return ShimmerLoading(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(g, MediaQuery.paddingOf(context).top + Space.xl, g, Space.xl),
        children: [
          const SkeletonBox(width: 140, height: 14),
          const SizedBox(height: Space.sm),
          const SkeletonBox(width: 220, height: 28),
          const SizedBox(height: Space.xl),
          Wrap(spacing: Space.md, runSpacing: Space.md, children: List.generate(4, (_) => const SkeletonBox(width: 150, height: 96, radius: Radii.lg))),
          const SizedBox(height: Space.xl),
          ...List.generate(4, (_) => const Padding(padding: EdgeInsets.only(bottom: Space.md), child: SkeletonBox(height: 88, radius: Radii.lg))),
        ],
      ),
    );
  }
}
