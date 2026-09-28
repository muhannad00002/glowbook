import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_counter.dart';
import '../../../shared/animations/animated_empty_state.dart';
import '../../../shared/animations/glow_illustration.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';
import '../../bookings/presentation/booking_detail_sheet.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/payments_repository.dart';

class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});
  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final tz = ref.watch(salonTimezoneProvider);
    final to = Ymd.today(tz);
    final range = (from: Ymd.add(to, -(_days - 1)), to: to);
    final page = ref.watch(paymentsProvider(range));
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
                      Text(l.paymentsTitle, style: context.text.headlineMedium),
                      SegmentedButton<int>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(value: 1, label: Text(l.labelToday)),
                          ButtonSegment(value: 7, label: Text(l.reportsLast7)),
                          ButtonSegment(value: 30, label: Text(l.reportsLast30)),
                        ],
                        selected: {_days},
                        onSelectionChanged: (v) => setState(() => _days = v.first),
                      ),
                    ],
                  ),
                  const SizedBox(height: Space.xl),
                  AsyncView(
                    value: page,
                    onRetry: () => ref.invalidate(paymentsProvider(range)),
                    data: (p) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LayoutBuilder(builder: (context, c) {
                          final cols = c.maxWidth >= 700 ? 4 : 2;
                          final w = (c.maxWidth - Space.md * (cols - 1)) / cols;
                          final tiles = [
                            (l.paymentsCollected, p.collected, Icons.south_west_rounded),
                            (l.paymentsRefunded, p.refunded, Icons.north_east_rounded),
                            (l.paymentsNet, p.net, Icons.account_balance_wallet_outlined),
                            (l.paymentsOwed, p.owed, Icons.hourglass_top_rounded),
                          ];
                          return Wrap(spacing: Space.md, runSpacing: Space.md, children: [
                            for (var i = 0; i < tiles.length; i++)
                              SizedBox(
                                width: w,
                                child: StaggeredEntrance(
                                  index: i,
                                  child: StatTile(label: tiles[i].$1, icon: tiles[i].$3, value: AnimatedCounter(value: tiles[i].$2, format: (v) => fmt.money(v.round()))),
                                ),
                              ),
                          ]);
                        }),
                        if (p.byMethod.isNotEmpty) ...[
                          const SizedBox(height: Space.md),
                          Wrap(spacing: Space.sm, children: [
                            for (final e in p.byMethod.entries) Chip(label: Text('${fmt.methodLabel(e.key)} · ${fmt.money(e.value)}')),
                          ]),
                        ],
                        const SizedBox(height: Space.xl),
                        if (p.items.isEmpty) AnimatedEmptyState(art: GlowArt.sparkles, title: l.paymentsEmpty, compact: true),
                        for (var i = 0; i < p.items.length; i++)
                          StaggeredEntrance(key: ValueKey(p.items[i].id), index: i, child: _PaymentRow(payment: p.items[i], range: range)),
                      ],
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

class _PaymentRow extends ConsumerWidget {
  const _PaymentRow({required this.payment, required this.range});
  final Payment payment;
  final ({String from, String to}) range;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fmt = context.fmt;
    final l = context.l10n;
    final tz = ref.watch(salonTimezoneProvider);
    final p = payment;
    final owed = p.isRefund && p.status == 'PENDING';
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: GlowCard(
        onTap: p.bookingId == null ? null : () => showBookingDetail(context, p.bookingId!),
        padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: (p.isRefund ? context.glow.pending.bg : context.glow.completed.bg), shape: BoxShape.circle),
            child: Icon(p.isRefund ? Icons.undo_rounded : Icons.payments_outlined, size: 18, color: p.isRefund ? context.glow.pending.fg : context.glow.completed.fg),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${p.customerName ?? ''} · ${fmt.kindLabel(p.kind)}', style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                [fmt.methodLabel(p.method), if (p.bookingRef != null) p.bookingRef!, fmt.dateTime(p.paidAt ?? p.createdAt, tz)].join(' · '),
                style: context.text.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ]),
          ),
          if (owed)
            TextButton(
              onPressed: () async {
                final method = await showModalBottomSheet<String>(
                  context: context,
                  builder: (ctx) => SafeArea(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      for (final m in ['CASH', 'CARD', 'BANK_TRANSFER'])
                        ListTile(title: Text(fmt.methodLabel(m)), onTap: () => Navigator.pop(ctx, m)),
                    ]),
                  ),
                );
                if (method == null || !context.mounted) return;
                await guard(context, () => settleRefund(ref, p.id, method));
                ref.invalidate(paymentsProvider(range));
                ref.invalidate(dashboardProvider);
                if (context.mounted) showGlowSnack(context, l.paymentsSettled);
              },
              child: Text(l.paymentsSettle),
            )
          else
            Text(
              '${p.isRefund ? '−' : ''}${fmt.money(p.amountBaisa)}',
              style: context.text.titleSmall?.copyWith(color: p.status == 'PAID' ? null : context.colors.onSurfaceVariant),
            ),
        ]),
      ),
    );
  }
}
