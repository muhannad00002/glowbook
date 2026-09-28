import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_counter.dart';
import '../../../shared/animations/shimmer_loading.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/widgets/common.dart';
import '../data/reports_repository.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});
  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  int _days = 30;
  String _granularity = 'daily';

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final tz = ref.watch(salonTimezoneProvider);
    final to = Ymd.today(tz);
    final range = (from: Ymd.add(to, -(_days - 1)), to: to);
    final report = ref.watch(reportsProvider(range));
    final g = gutterOf(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(g, Space.lg, g, 120),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    runSpacing: Space.md,
                    children: [
                      Text(l.reportsTitle, style: context.text.headlineMedium),
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(value: 7, label: Text(l.reportsLast7)),
                          ButtonSegment(value: 30, label: Text(l.reportsLast30)),
                          ButtonSegment(value: 90, label: Text(l.reportsLast90)),
                        ],
                        selected: {_days},
                        onSelectionChanged: (v) => setState(() => _days = v.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xl),
                  AsyncView(
                    value: report,
                    onRetry: () => ref.invalidate(reportsProvider(range)),
                    loading: ShimmerLoading(
                      child: Column(children: List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: Space.md), child: SkeletonBox(height: 180, radius: Radii.lg)))),
                    ),
                    data: (r) => _ReportBody(
                      key: ValueKey('$_days'),
                      report: r,
                      granularity: _granularity,
                      onGranularity: (v) => setState(() => _granularity = v),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  const _ReportBody({super.key, required this.report, required this.granularity, required this.onGranularity});
  final ReportData report;
  final String granularity;
  final ValueChanged<String> onGranularity;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final r = report;
    final kpis = [
      (l.reportsRevenue, AnimatedCounter(value: r.totalRevenue, format: (v) => fmt.money(v.round())), Icons.payments_outlined, context.colors.primary),
      (l.reportsBookings, AnimatedCounter(value: r.bookingsTotal), Icons.event_available_rounded, context.colors.secondary),
      (l.reportsCancellationRate, AnimatedCounter(value: r.cancellationRate, format: (v) => fmt.percent(v.toDouble())), Icons.event_busy_outlined, context.glow.cancelled.fg),
      (l.reportsNoShowRate, AnimatedCounter(value: r.noShowRate, format: (v) => fmt.percent(v.toDouble())), Icons.person_off_outlined, context.glow.noShow.fg),
      (l.reportsNewClients, AnimatedCounter(value: r.newClients), Icons.person_add_alt_1_outlined, context.colors.tertiary),
      (l.reportsReturningClients, AnimatedCounter(value: r.returningClients), Icons.favorite_border_rounded, context.colors.primary),
    ];
    final series = switch (granularity) {
      'weekly' => r.weekly,
      'monthly' => r.monthly,
      _ => r.daily,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, c) {
          final cols = c.maxWidth >= 900 ? 6 : c.maxWidth >= 560 ? 3 : 2;
          final w = (c.maxWidth - Space.md * (cols - 1)) / cols;
          return Wrap(spacing: Space.md, runSpacing: Space.md, children: [
            for (var i = 0; i < kpis.length; i++)
              SizedBox(width: w, child: StaggeredEntrance(index: i, child: StatTile(label: kpis[i].$1, value: kpis[i].$2, icon: kpis[i].$3, tint: kpis[i].$4))),
          ]);
        }),
        const SizedBox(height: Space.xl),
        StaggeredEntrance(
          index: 6,
          child: GlowCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: Space.sm,
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(l.reportsRevenue, style: context.text.titleMedium),
                      Text(l.reportsAvgPerDay(fmt.money(r.avgPerDay)), style: context.text.bodySmall),
                    ]),
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: [
                        ButtonSegment(value: 'daily', label: Text(l.reportsDaily)),
                        ButtonSegment(value: 'weekly', label: Text(l.reportsWeekly)),
                        ButtonSegment(value: 'monthly', label: Text(l.reportsMonthly)),
                      ],
                      selected: {granularity},
                      onSelectionChanged: (v) => onGranularity(v.first),
                    ),
                  ],
                ),
                const SizedBox(height: Space.xl),
                SizedBox(height: 220, child: _RevenueChart(series: series, granularity: granularity)),
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.lg),
        LayoutBuilder(builder: (context, c) {
          final two = c.maxWidth >= 820;
          final popular = _PopularServices(report: r);
          final staff = _StaffPerformance(report: r);
          return two
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: StaggeredEntrance(index: 7, child: popular)),
                  const SizedBox(width: Space.lg),
                  Expanded(child: StaggeredEntrance(index: 8, child: staff)),
                ])
              : Column(children: [
                  StaggeredEntrance(index: 7, child: popular),
                  const SizedBox(height: Space.lg),
                  StaggeredEntrance(index: 8, child: staff),
                ]);
        }),
        const SizedBox(height: Space.lg),
        StaggeredEntrance(index: 9, child: _ClientMix(report: r)),
      ],
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart({required this.series, required this.granularity});
  final List<({String label, int value})> series;
  final String granularity;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final fmt = context.fmt;
    if (series.isEmpty) return const SizedBox();
    final maxY = series.map((s) => s.value).reduce(math.max).toDouble();
    String label(int i) {
      final s = series[i].label;
      return granularity == 'monthly' ? fmt.ymdLabel('$s-01', pattern: 'MMM') : fmt.ymdLabel(s, pattern: 'd MMM');
    }

    final step = math.max(1, (series.length / 6).ceil());
    // Animate from zero on first load: TweenAnimationBuilder scales the values up.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.of(context).reduced ? Duration.zero : const Duration(milliseconds: 900),
      curve: Motion.standard,
      builder: (context, t, _) => LineChart(
        LineChartData(
          minY: 0,
          maxY: maxY == 0 ? 1 : maxY * 1.15,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxY == 0 ? 1 : maxY / 3,
            getDrawingHorizontalLine: (_) => FlLine(color: scheme.outlineVariant.withValues(alpha: 0.5), strokeWidth: 1),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                interval: maxY == 0 ? 1 : maxY / 3,
                getTitlesWidget: (v, _) => Text(fmt.amount(v.round()), style: context.text.labelSmall),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 26,
                interval: step.toDouble(),
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= series.length) return const SizedBox();
                  return Padding(padding: const EdgeInsets.only(top: 6), child: Text(label(i), style: context.text.labelSmall));
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem('${label(s.x.toInt())}\n${fmt.money((s.y / (t == 0 ? 1 : t)).round())}', TextStyle(color: scheme.onInverseSurface, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < series.length; i++) FlSpot(i.toDouble(), series[i].value * t)],
              isCurved: true,
              curveSmoothness: 0.3,
              preventCurveOverShooting: true,
              color: scheme.primary,
              barWidth: 3,
              dotData: FlDotData(show: series.length <= 14),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [scheme.primary.withValues(alpha: 0.25), scheme.primary.withValues(alpha: 0)]),
              ),
            ),
          ],
        ),
        duration: Duration.zero,
      ),
    );
  }
}

class _PopularServices extends StatelessWidget {
  const _PopularServices({required this.report});
  final ReportData report;
  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final items = report.popular.take(6).toList();
    final max = items.isEmpty ? 1 : items.first.count;
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.reportsPopularServices, style: context.text.titleMedium),
          const SizedBox(height: Space.lg),
          for (var i = 0; i < items.length; i++) ...[
            Row(children: [
              Expanded(child: Text(context.lang == 'ar' && items[i].nameAr != null ? items[i].nameAr! : items[i].name, style: context.text.bodyMedium)),
              Text('${items[i].count}', style: context.text.titleSmall),
            ]),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: Radii.pillAll,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: items[i].count / max),
                duration: Motion.of(context).reduced ? Duration.zero : Duration(milliseconds: 700 + i * 90),
                curve: Motion.standard,
                builder: (_, v, _) => LinearProgressIndicator(value: v, minHeight: 8, backgroundColor: context.colors.primaryContainer.withValues(alpha: 0.5)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: Space.md),
              child: Text(fmt.money(items[i].revenue), style: context.text.bodySmall),
            ),
          ],
        ],
      ),
    );
  }
}

class _StaffPerformance extends StatelessWidget {
  const _StaffPerformance({required this.report});
  final ReportData report;
  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.reportsStaffPerformance, style: context.text.titleMedium),
          const SizedBox(height: Space.md),
          for (final s in report.staff)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Space.sm),
              child: Row(children: [
                InitialsAvatar(name: s.name, color: hexColor(s.color), size: 40),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(context.lang == 'ar' && s.nameAr != null ? s.nameAr! : s.name, style: context.text.titleSmall),
                    Row(children: [
                      Text(context.l10n.reportsCompleted(s.completed), style: context.text.bodySmall),
                      if (s.rating != null) ...[
                        const SizedBox(width: Space.sm),
                        Icon(Icons.star_rounded, size: 14, color: context.colors.secondary),
                        Text(s.rating!.toStringAsFixed(1), style: context.text.bodySmall),
                      ],
                    ]),
                  ]),
                ),
                AnimatedCounter(value: s.revenue, format: (v) => fmt.money(v.round()), style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
              ]),
            ),
        ],
      ),
    );
  }
}

class _ClientMix extends StatelessWidget {
  const _ClientMix({required this.report});
  final ReportData report;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final total = report.newClients + report.returningClients;
    return GlowCard(
      child: Row(
        children: [
          SizedBox(
            width: 120,
            height: 120,
            child: total == 0
                ? const SizedBox()
                : TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: Motion.of(context).reduced ? Duration.zero : const Duration(milliseconds: 900),
                    curve: Motion.standard,
                    builder: (_, t, _) => PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        sectionsSpace: 3,
                        centerSpaceRadius: 34,
                        sections: [
                          PieChartSectionData(value: report.returningClients * t + 0.0001, color: context.colors.primary, radius: 18, showTitle: false),
                          PieChartSectionData(value: report.newClients * t + 0.0001, color: context.colors.tertiary, radius: 18, showTitle: false),
                          PieChartSectionData(value: total * (1 - t) + 0.0001, color: context.colors.surfaceContainer, radius: 18, showTitle: false),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: Space.xl),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.reportsRetention, style: context.text.titleMedium),
                Text(fmt.percent(report.retention), style: context.text.headlineMedium?.copyWith(color: context.colors.primary)),
                const SizedBox(height: Space.sm),
                _Legend(color: context.colors.primary, label: '${l.reportsReturningClients}: ${report.returningClients}'),
                _Legend(color: context.colors.tertiary, label: '${l.reportsNewClients}: ${report.newClients}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 6),
          Text(label, style: context.text.bodySmall),
        ]),
      );
}
