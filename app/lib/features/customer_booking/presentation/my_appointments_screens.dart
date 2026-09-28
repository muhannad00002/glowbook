import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/animations/animated_empty_state.dart';
import '../../../shared/animations/animated_success.dart';
import '../../../shared/animations/glow_illustration.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/salon_cover.dart';
import '../../bookings/presentation/slot_picker.dart';
import '../../salon/data/salon_repository.dart';
import '../data/customer_booking_repository.dart';

class MyAppointmentsScreen extends ConsumerWidget {
  const MyAppointmentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: ContentWidth(
            maxWidth: 820,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(gutterOf(context), Space.lg, gutterOf(context), Space.sm),
                  child: Text(l.navAppointments, style: context.text.headlineMedium),
                ),
                TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.label,
                  tabs: [Tab(text: l.myUpcoming), Tab(text: l.myPast)],
                ),
                const Expanded(child: TabBarView(children: [_List(scope: 'upcoming'), _List(scope: 'past')])),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _List extends ConsumerWidget {
  const _List({required this.scope});
  final String scope;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final list = ref.watch(myBookingsProvider(scope));
    return RefreshIndicator(
      onRefresh: () => ref.refresh(myBookingsProvider(scope).future),
      child: AsyncView(
        value: list,
        onRetry: () => ref.invalidate(myBookingsProvider(scope)),
        data: (items) => items.isEmpty
            ? ListView(children: [
                AnimatedEmptyState(
                  art: scope == 'upcoming' ? GlowArt.calendar : GlowArt.mirror,
                  title: l.myEmptyTitle,
                  body: l.myEmptyBody,
                  action: FilledButton.icon(onPressed: () => context.go('/discover'), icon: const Icon(Icons.search_rounded), label: Text(l.myDiscover)),
                ),
              ])
            : ListView.separated(
                padding: EdgeInsets.fromLTRB(gutterOf(context), Space.lg, gutterOf(context), 120),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: Space.md),
                itemBuilder: (_, i) => StaggeredEntrance(key: ValueKey(items[i].id), index: i, child: _MyCard(b: items[i])),
              ),
      ),
    );
  }
}

class _MyCard extends StatelessWidget {
  const _MyCard({required this.b});
  final MyBooking b;
  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final l = context.l10n;
    return GlowCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/appointments/${b.id}'),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: const BorderRadiusDirectional.horizontal(start: Radius.circular(Radii.lg)).resolve(Directionality.of(context)),
            child: SizedBox(width: 88, height: 112, child: SalonCover(name: b.salon.name, height: 112, monogramSize: 34)),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(Space.lg),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(fmt.relativeDay(b.start, b.salonTimezone), style: context.text.labelMedium?.copyWith(color: context.colors.primary))),
                  StatusChip(b.status, dense: true),
                ]),
                const SizedBox(height: 2),
                Text(b.service.display(context.lang), style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${fmt.time(b.start, b.salonTimezone)} · ${b.salon.title(context.lang)}', style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (b.depositOutstanding) Text(l.myPayDeposit, style: context.text.labelSmall?.copyWith(color: context.glow.pending.fg)),
                if (b.canReview) Text(l.myLeaveReview, style: context.text.labelSmall?.copyWith(color: context.colors.secondary)),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

/// Appointment detail for the signed-in customer, or a guest holding the manage link.
class AppointmentDetailScreen extends ConsumerWidget {
  const AppointmentDetailScreen({super.key, required this.id, this.token});
  final String id;
  final String? token;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = (id: id, token: token);
    final b = ref.watch(myBookingProvider(key));
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.bookingDetails)),
      body: AsyncView(
        value: b,
        onRetry: () => ref.invalidate(myBookingProvider(key)),
        data: (booking) => _Detail(b: booking, token: token),
      ),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.b, this.token});
  final MyBooking b;
  final String? token;

  void _refresh(WidgetRef ref) {
    ref.invalidate(myBookingProvider((id: b.id, token: token)));
    ref.invalidate(myBookingsProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final fmt = context.fmt;
    final tz = b.salonTimezone;
    final repo = ref.read(customerBookingRepositoryProvider);
    final g = gutterOf(context);

    return ListView(
      padding: EdgeInsets.fromLTRB(g, 0, g, Space.xxxl),
      children: [
        ContentWidth(
          maxWidth: 640,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StaggeredEntrance(
                index: 0,
                child: GlowCard(
                  padding: EdgeInsets.zero,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    SalonCover(name: b.salon.name, height: 120, radius: Radii.lg),
                    Padding(
                      padding: const EdgeInsets.all(Space.lg),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(b.service.display(context.lang), style: context.text.headlineSmall)),
                          StatusChip(b.status),
                        ]),
                        const SizedBox(height: Space.sm),
                        Text(fmt.fullDate(b.start, tz), style: context.text.titleMedium),
                        Text('${fmt.time(b.start, tz)} – ${fmt.time(b.end, tz)} · ${b.staff.display(context.lang)}', style: context.text.bodyMedium),
                        const SizedBox(height: Space.sm),
                        InkWell(
                          onTap: () => context.push('/salon/${b.salon.slug}'),
                          child: Text(b.salon.title(context.lang), style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
                        ),
                        if (b.salonAddress != null) Text(b.salonAddress!, style: context.text.bodySmall),
                        const SizedBox(height: Space.sm),
                        Text('${l.bookingReference} ${b.reference}', style: context.text.bodySmall),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: Space.lg),
              StaggeredEntrance(
                index: 1,
                child: GlowCard(
                  child: Column(children: [
                    _Amt(l.bookingPrice, fmt.money(b.priceBaisa)),
                    if (b.depositBaisa > 0) _Amt(l.bookingDeposit, fmt.money(b.depositBaisa)),
                    _Amt(l.bookingPaid, fmt.money(b.paidBaisa)),
                    _Amt(l.bookingBalance, fmt.money(b.balanceBaisa), strong: true),
                  ]),
                ),
              ),
              const SizedBox(height: Space.lg),
              if (b.depositOutstanding)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: AnimatedButton(
                    label: l.payNow(fmt.money(b.depositBaisa - b.paidBaisa)),
                    icon: Icons.credit_card_rounded,
                    onPressed: () => guard(context, () async {
                      final pay = await repo.startPayment(b.id, token: token);
                      await repo.confirmTestPayment(pay.paymentId, token: token);
                      _refresh(ref);
                      if (context.mounted) showGlowSnack(context, l.paySuccess);
                    }),
                  ),
                ),
              if (b.status == 'COMPLETED' && b.reviewRating != null)
                GlowCard(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.myYourReview, style: context.text.titleSmall),
                    const SizedBox(height: 4),
                    RatingStars(rating: b.reviewRating!.toDouble()),
                    if (b.reviewComment != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(b.reviewComment!)),
                  ]),
                ),
              if (b.canReview && token == null)
                AnimatedButton(label: l.myLeaveReview, icon: Icons.star_rounded, tone: ButtonTone.soft, onPressed: () async => _review(context, ref)),
              if (b.canReschedule)
                Padding(
                  padding: const EdgeInsets.only(top: Space.md),
                  child: OutlinedButton.icon(onPressed: () => _reschedule(context, ref), icon: const Icon(Icons.edit_calendar_outlined), label: Text(l.myReschedule)),
                ),
              if (b.canCancel)
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: context.colors.error),
                    onPressed: () => _cancel(context, ref),
                    icon: const Icon(Icons.close_rounded),
                    label: Text(l.myCancel),
                  ),
                ),
              if (b.salonPhone != null)
                Padding(
                  padding: const EdgeInsets.only(top: Space.md),
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('tel:${b.salonPhone}')),
                    icon: const Icon(Icons.call_outlined),
                    label: Text(l.salonCall),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

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
        content: Text(lines.join('\n\n')),
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

  Future<void> _reschedule(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _RescheduleSheet(b: b, token: token),
    );
    _refresh(ref);
  }

  Future<void> _review(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(context: context, isScrollControlled: true, useSafeArea: true, builder: (_) => _ReviewSheet(b: b));
    _refresh(ref);
  }
}

class _Amt extends StatelessWidget {
  const _Amt(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(children: [
          Expanded(child: Text(label, style: strong ? context.text.titleSmall : context.text.bodyMedium)),
          Text(value, style: strong ? context.text.titleMedium?.copyWith(color: context.colors.primary) : context.text.bodyMedium),
        ]),
      );
}

class _RescheduleSheet extends ConsumerStatefulWidget {
  const _RescheduleSheet({required this.b, this.token});
  final MyBooking b;
  final String? token;
  @override
  ConsumerState<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends ConsumerState<_RescheduleSheet> {
  Slot? _slot;
  int _refresh = 0;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = ref.read(salonRepositoryProvider);
    final b = widget.b;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.xl),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.myRescheduleTitle, style: context.text.headlineSmall),
          const SizedBox(height: Space.lg),
          SlotPicker(
            timezone: b.salonTimezone,
            selected: _slot,
            refreshToken: _refresh,
            onSelected: (s) => setState(() => _slot = s),
            loadSlots: (date) => repo.slots(salon: b.salon.slug, serviceId: b.service.id, date: date, staffId: b.staff.id),
            loadDays: (from, days) => repo.days(salon: b.salon.slug, serviceId: b.service.id, from: from, days: days, staffId: b.staff.id),
          ),
          const SizedBox(height: Space.lg),
          AnimatedButton(
            label: l.myReschedule,
            enabled: _slot != null,
            onPressed: _slot == null
                ? null
                : () async {
                    try {
                      await ref.read(customerBookingRepositoryProvider).reschedule(b.id, _slot!.start, token: widget.token);
                    } catch (e) {
                      if (context.mounted) {
                        showGlowSnack(context, context.fmt.error(e), error: true);
                        setState(() {
                          _slot = null;
                          _refresh++;
                        });
                      }
                      rethrow;
                    }
                    if (context.mounted) {
                      showGlowSnack(context, l.bookingRescheduled);
                      Navigator.pop(context);
                    }
                  },
          ),
        ]),
      ),
    );
  }
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.b});
  final MyBooking b;
  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  int _rating = 5;
  final _comment = TextEditingController();
  bool _done = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final motion = Motion.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, MediaQuery.viewInsetsOf(context).bottom + Space.xl),
      child: AnimatedSwitcher(
        duration: motion.medium,
        child: _done
            ? Column(key: const ValueKey('done'), mainAxisSize: MainAxisSize.min, children: [
                const AnimatedSuccess(size: 96),
                Text(l.myReviewThanks, style: context.text.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: Space.lg),
                FilledButton(onPressed: () => Navigator.pop(context), child: Text(l.actionDone)),
              ])
            : Column(key: const ValueKey('form'), mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text(l.myReviewTitle, style: context.text.headlineSmall, textAlign: TextAlign.center),
                const SizedBox(height: Space.lg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 1; i <= 5; i++)
                      Semantics(
                        button: true,
                        selected: i <= _rating,
                        label: '$i / 5',
                        child: PressableScale(
                          scale: 0.8,
                          onTap: () => setState(() => _rating = i),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: AnimatedScale(
                              scale: i <= _rating ? 1.1 : 1,
                              duration: motion.medium,
                              curve: Motion.pop,
                              child: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 44, color: context.colors.secondary),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: Space.lg),
                TextField(controller: _comment, maxLines: 4, decoration: InputDecoration(hintText: l.myReviewHint)),
                const SizedBox(height: Space.lg),
                AnimatedButton(
                  label: l.myReviewSubmit,
                  onPressed: () => guard(context, () async {
                    await ref.read(customerBookingRepositoryProvider).review(widget.b.id, _rating, _comment.text.trim());
                    if (context.mounted) setState(() => _done = true);
                  }),
                ),
              ]),
      ),
    );
  }
}
