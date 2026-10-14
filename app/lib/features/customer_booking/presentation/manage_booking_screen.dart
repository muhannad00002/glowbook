import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/fit_layout.dart';
import '../../../shared/widgets/step_flow.dart';
import '../data/customer_booking_repository.dart';
import 'booking_draft.dart';
import 'booking_flow_screen.dart';
import 'customer_widgets.dart';

/// The page the WhatsApp link opens (/booking/:id?token=…): her booking, and what she
/// can still do with it. No account — the link is the key, until a day after the visit.
class ManageBookingScreen extends ConsumerWidget {
  const ManageBookingScreen({super.key, required this.id, required this.token});
  final String id;
  final String? token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (id: id, token: token);
    final b = ref.watch(myBookingProvider(key));
    return Scaffold(
      body: b.when(
        loading: () => const Center(child: LoadingPad()),
        error: (e, _) => linkErrorView(context, e, onRetry: () => ref.invalidate(myBookingProvider(key))),
        data: (booking) => _Manage(b: booking, token: token),
      ),
    );
  }
}

class _Manage extends ConsumerWidget {
  const _Manage({required this.b, required this.token});
  final MyBooking b;
  final String? token;

  void _refresh(WidgetRef ref) => ref.invalidate(myBookingProvider((id: b.id, token: token)));

  Future<void> _cancel(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final fmt = context.fmt;
    final q = b.quote;
    final lines = <String>[
      if (q != null && q.isFree) l.myCancelFree(fmt.dateTime(q.freeUntil, b.salonTimezone)),
      if (q != null && !q.isFree && q.retainedBaisa > 0) l.myCancelLate(b.cancellationWindowHours, fmt.money(q.retainedBaisa)),
      if (q != null && q.refundBaisa > 0) l.myCancelRefund(fmt.money(q.refundBaisa)),
    ];
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.bookingCancelTitle),
        content: lines.isEmpty ? null : Text(lines.join('\n\n')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.actionKeep)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.colors.error, foregroundColor: ctx.colors.onError),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.myCancel),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await guard(context, () => ref.read(customerBookingRepositoryProvider).cancel(b.id, token: token));
    _refresh(ref);
    if (context.mounted) showGlowSnack(context, l.bookingCancelled);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final fmt = context.fmt;
    final tz = b.salonTimezone;
    final repo = ref.read(customerBookingRepositoryProvider);
    final canMove = b.canReschedule && (b.quote?.isFree ?? false);

    return FitStepPage(
      title: l.manageTitle,
      subtitle: b.salon.title(context.lang),
      trailing: b.salonPhone == null
          ? null
          : IconButton(tooltip: l.salonCall, onPressed: () => launchUrl(Uri.parse('tel:${b.salonPhone}')), icon: const Icon(Icons.call_outlined)),
      body: FitBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlowCard(
              gradient: context.glow.heroGradient,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(b.servicesTitle(context.lang), style: context.text.titleLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: Space.sm),
                      StatusChip(b.status),
                    ],
                  ),
                  const SizedBox(height: Space.sm),
                  Text(fmt.fullDate(b.start, tz), style: context.text.titleMedium),
                  Text('${fmt.time(b.start, tz)} – ${fmt.time(b.end, tz)} · ${l.flowWith(b.staff.display(context.lang))}', style: context.text.bodyMedium),
                  const SizedBox(height: Space.sm),
                  Text('${l.bookingReference} ${b.reference}', style: context.text.bodySmall),
                  if (b.salonAddress != null) Text(b.salonAddress!, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(height: Space.md),
            GlowCard(
              child: Column(
                children: [
                  _Amt(l.bookingPrice, fmt.money(b.priceBaisa)),
                  if (b.paidBaisa > 0) _Amt(l.bookingPaid, fmt.money(b.paidBaisa)),
                  _Amt(l.bookingBalance, fmt.money(b.balanceBaisa), strong: true),
                ],
              ),
            ),
            if (b.canCancel && b.quote != null) ...[
              const SizedBox(height: Space.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: context.colors.onSurfaceVariant),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(b.quote!.isFree ? l.myCancelFree(fmt.dateTime(b.quote!.freeUntil, tz)) : l.manageTooLate, style: context.text.bodySmall),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      action: Column(
        key: ValueKey(b.status),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (b.depositOutstanding) ...[
            AnimatedButton(
              label: l.payNow(fmt.money(b.payDueBaisa)),
              icon: Icons.credit_card_rounded,
              onPressed: () => guard(context, () async {
                final pay = await repo.startPayment(b.id, token: token);
                await repo.confirmTestPayment(pay.paymentId, token: token);
                _refresh(ref);
                if (context.mounted) showGlowSnack(context, l.paySuccess);
              }),
            ),
            const SizedBox(height: Space.sm),
          ],
          if (canMove)
            FilledButton.tonalIcon(
              onPressed: () => context.push('/booking/${b.id}/reschedule?token=${Uri.encodeComponent(token ?? '')}'),
              icon: const Icon(Icons.edit_calendar_outlined),
              label: Text(l.myReschedule),
            ),
          if (b.canCancel)
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: context.colors.error),
              onPressed: () => _cancel(context, ref),
              icon: const Icon(Icons.close_rounded),
              label: Text(l.myCancel),
            ),
          if (!canMove && !b.canCancel && !b.depositOutstanding) FilledButton(onPressed: () => context.go('/'), child: Text(l.manageBookAgain)),
        ],
      ),
    );
  }
}

class _Amt extends StatelessWidget {
  const _Amt(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      children: [
        Expanded(child: Text(label, style: strong ? context.text.titleSmall : context.text.bodyMedium)),
        Text(value, style: strong ? context.text.titleMedium?.copyWith(color: context.colors.primary) : context.text.bodyMedium),
      ],
    ),
  );
}

/// Moving a booking from the link: Day → Time. The whole visit moves, same artist.
class RescheduleScreen extends ConsumerStatefulWidget {
  const RescheduleScreen({super.key, required this.id, required this.token});
  final String id;
  final String? token;
  @override
  ConsumerState<RescheduleScreen> createState() => _RescheduleScreenState();
}

class _RescheduleScreenState extends ConsumerState<RescheduleScreen> {
  int _step = 0;
  bool _forward = true;
  String? _date;
  Slot? _slot;

  void _back() {
    if (_step == 0) {
      context.canPop() ? context.pop() : context.go('/booking/${widget.id}?token=${Uri.encodeComponent(widget.token ?? '')}');
    } else {
      setState(() {
        _forward = false;
        _step = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final key = (id: widget.id, token: widget.token);
    final booking = ref.watch(myBookingProvider(key));
    return Scaffold(
      body: booking.when(
        loading: () => const Center(child: LoadingPad()),
        error: (e, _) => linkErrorView(context, e, onRetry: () => ref.invalidate(myBookingProvider(key))),
        data: (b) {
          final services = b.serviceIds.join(',');
          final fmt = context.fmt;
          final current = Text(
            '${l.manageNowAt} ${fmt.weekdayDayMonth(b.start, b.salonTimezone)} · ${fmt.time(b.start, b.salonTimezone)}',
            style: context.text.bodySmall,
          );
          final page = _step == 0
              ? FitStepPage(
                  step: 0,
                  total: 2,
                  onBack: _back,
                  title: l.flowDateTitle,
                  subtitle: b.servicesTitle(context.lang),
                  summary: current,
                  body: Consumer(
                    builder: (context, ref, _) {
                      final q = (salon: b.salon.slug, services: services, staffId: b.staff.id, from: Ymd.today(b.salonTimezone));
                      final days = ref.watch(visitDaysProvider(q));
                      return days.when(
                        loading: () => const GridSkeleton(columns: 7, height: 60),
                        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(visitDaysProvider(q))),
                        data: (list) => DateGrid(
                          dates: [for (final d in list) d.date],
                          isEnabled: (date) => list.any((d) => d.date == date && !d.closed && d.slotCount > 0),
                          selected: _date,
                          onPick: (date) => setState(() {
                            _date = date;
                            _slot = null;
                            _forward = true;
                            _step = 1;
                          }),
                        ),
                      );
                    },
                  ),
                )
              : FitStepPage(
                  step: 1,
                  total: 2,
                  onBack: _back,
                  title: l.flowTimeTitle,
                  subtitle: fmt.ymdLabel(_date!, pattern: 'yMMMMEEEEd'),
                  summary: current,
                  body: Consumer(
                    builder: (context, ref, _) {
                      final q = (salon: b.salon.slug, services: services, staffId: b.staff.id, date: _date!);
                      final slots = ref.watch(visitSlotsProvider(q));
                      return slots.when(
                        loading: () => const GridSkeleton(columns: 3, height: 50),
                        error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(visitSlotsProvider(q))),
                        data: (list) => list.isEmpty
                            ? StepHint(
                                icon: Icons.event_busy_outlined,
                                text: l.flowDayFull,
                                action: OutlinedButton(onPressed: _back, child: Text(l.flowPickAnotherDay)),
                              )
                            : TimeGrid(
                                count: list.length,
                                cell: (i) => TimeCell(
                                  label: slotLabel(context, list[i]),
                                  selected: _slot?.start == list[i].start,
                                  onTap: () => setState(() => _slot = list[i]),
                                ),
                              ),
                      );
                    },
                  ),
                  action: AnimatedButton(
                    label: l.myReschedule,
                    icon: Icons.edit_calendar_outlined,
                    keepSuccess: true,
                    enabled: _slot != null,
                    onPressed: _slot == null
                        ? null
                        : () async {
                            try {
                              await ref.read(customerBookingRepositoryProvider).reschedule(b.id, _slot!.start, token: widget.token);
                            } catch (e) {
                              if (context.mounted) showGlowSnack(context, context.fmt.error(e), error: true);
                              ref.invalidate(visitSlotsProvider);
                              setState(() => _slot = null);
                              rethrow;
                            }
                            ref.invalidate(myBookingProvider(key));
                            if (context.mounted) {
                              showGlowSnack(context, l.bookingRescheduled);
                              context.go('/booking/${b.id}?token=${Uri.encodeComponent(widget.token ?? '')}');
                            }
                          },
                  ),
                );
          return StepSwitcher(
            step: _step,
            forward: _forward,
            child: KeyedSubtree(key: ValueKey(_step), child: page),
          );
        },
      ),
    );
  }
}
