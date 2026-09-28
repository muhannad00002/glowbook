import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../customers/data/customers_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../data/bookings_repository.dart';
import 'slot_picker.dart';

/// Opens the appointment as a sheet on phones and a dialog-like panel on wide screens.
Future<void> showBookingDetail(BuildContext context, String bookingId) {
  final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
  if (wide) {
    return showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        insetPadding: const EdgeInsets.all(Space.xl),
        child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560, maxHeight: 820), child: BookingDetailView(bookingId: bookingId)),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, controller) => BookingDetailView(bookingId: bookingId, scrollController: controller),
    ),
  );
}

/// Refreshes every screen that shows bookings after a change.
void invalidateBookingViews(WidgetRef ref, String id) {
  ref.invalidate(bookingDetailProvider(id));
  ref.invalidate(dashboardProvider);
  ref.invalidate(calendarRangeProvider);
  ref.invalidate(calendarMonthProvider);
  ref.invalidate(customerProfileProvider);
}

class BookingDetailView extends ConsumerWidget {
  const BookingDetailView({super.key, required this.bookingId, this.scrollController});
  final String bookingId;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(bookingDetailProvider(bookingId));
    return AsyncView(
      value: detail,
      onRetry: () => ref.invalidate(bookingDetailProvider(bookingId)),
      data: (d) => _DetailBody(detail: d, scrollController: scrollController),
    );
  }
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail, this.scrollController});
  final BookingDetail detail;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = detail.booking;
    final l = context.l10n;
    final fmt = context.fmt;
    final tz = ref.watch(salonTimezoneProvider);
    final m = ref.watch(membershipProvider);
    final frontDesk = m?.isFrontDesk ?? false;
    final artist = hexColor(b.staff.color);
    final repo = ref.read(bookingsRepositoryProvider);

    Future<void> setStatus(String status) => guard(context, () async {
          await repo.setStatus(b.id, status);
          invalidateBookingViews(ref, b.id);
          if (context.mounted) showGlowSnack(context, l.bookingStatusUpdated);
        });

    final actions = <Widget>[
      if (b.status == 'PENDING' && frontDesk) AnimatedButton(label: l.bookingConfirm, icon: Icons.check_rounded, onPressed: () => setStatus('CONFIRMED')),
      if (b.status == 'CONFIRMED' || b.status == 'PENDING') AnimatedButton(label: l.bookingMarkArrived, icon: Icons.waving_hand_outlined, onPressed: () => setStatus('ARRIVED'), tone: b.status == 'PENDING' && frontDesk ? ButtonTone.soft : ButtonTone.primary),
      if (b.status == 'ARRIVED') AnimatedButton(label: l.bookingStartService, icon: Icons.brush_outlined, onPressed: () => setStatus('IN_SERVICE')),
      if (b.status == 'IN_SERVICE' || b.status == 'ARRIVED')
        AnimatedButton(label: l.bookingMarkCompleted, icon: Icons.favorite_rounded, onPressed: () => setStatus('COMPLETED'), tone: b.status == 'ARRIVED' ? ButtonTone.soft : ButtonTone.primary),
    ];

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.sm, Space.xl, Space.xxl),
      children: [
        Row(
          children: [
            Expanded(child: Text(l.bookingDetails, style: context.text.headlineSmall)),
            StatusChip(b.status),
          ],
        ),
        const SizedBox(height: Space.xs),
        Text('${l.bookingReference} ${b.reference}', style: context.text.bodySmall),
        const SizedBox(height: Space.xl),
        GlowCard(
          child: Column(
            children: [
              _Row(icon: Icons.person_outline_rounded, label: l.bookingClient, value: b.customer.name, trailing: frontDesk || m?.role == 'STAFF'
                  ? IconButton(
                      tooltip: l.customerHistory,
                      icon: const Icon(Icons.open_in_new_rounded, size: 20),
                      onPressed: () {
                        Navigator.of(context).maybePop();
                        context.push('${m?.role == 'STAFF' ? '/staff' : '/admin'}/clients/${b.customer.id}');
                      },
                    )
                  : null),
              if (b.customer.phone != null) _Row(icon: Icons.phone_outlined, label: l.authPhone, value: b.customer.phone!, ltr: true),
              _Row(icon: Icons.spa_outlined, label: l.bookingService, value: b.service.display(context.lang)),
              _Row(icon: Icons.brush_outlined, label: l.bookingArtist, value: b.staff.display(context.lang), dot: artist),
              _Row(icon: Icons.event_outlined, label: l.bookingWhen, value: '${fmt.relativeDay(b.start, tz)} · ${fmt.time(b.start, tz)} – ${fmt.time(b.end, tz)}'),
              _Row(icon: Icons.timelapse_rounded, label: l.bookingDuration, value: fmt.duration(b.durationMinutes), last: true),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        GlowCard(
          child: Column(
            children: [
              _Money(label: l.bookingPrice, value: fmt.money(b.priceBaisa)),
              if (b.depositBaisa > 0) _Money(label: l.bookingDeposit, value: fmt.money(b.depositBaisa)),
              _Money(label: l.bookingPaid, value: fmt.money(b.paidBaisa)),
              const Divider(height: Space.xl),
              _Money(label: l.bookingBalance, value: fmt.money(detail.balanceBaisa), strong: true),
              if (frontDesk && detail.balanceBaisa > 0 && b.isLive) ...[
                const SizedBox(height: Space.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _recordPayment(context, ref, b, detail.balanceBaisa),
                    icon: const Icon(Icons.point_of_sale_rounded),
                    label: Text(l.bookingRecordPayment),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (b.customerNotes != null) ...[
          const SizedBox(height: Space.lg),
          GlowCard(
            color: context.colors.secondaryContainer,
            elevated: false,
            child: _Note(title: l.bookingClientNotes, body: b.customerNotes!),
          ),
        ],
        if (detail.customerPrivateNotes != null) ...[
          const SizedBox(height: Space.md),
          GlowCard(color: context.colors.tertiaryContainer, elevated: false, child: _Note(title: l.customerPrivateNotes, body: detail.customerPrivateNotes!)),
        ],
        const SizedBox(height: Space.lg),
        _InternalNotes(booking: b),
        if (actions.isNotEmpty) ...[
          const SizedBox(height: Space.xl),
          ...actions.map((a) => Padding(padding: const EdgeInsets.only(bottom: Space.md), child: a)),
        ],
        if (b.isLive && b.status != 'COMPLETED') ...[
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              if (frontDesk && (b.status == 'PENDING' || b.status == 'CONFIRMED'))
                OutlinedButton.icon(onPressed: () => _reschedule(context, ref, b), icon: const Icon(Icons.edit_calendar_outlined), label: Text(l.bookingReschedule)),
              if (b.status == 'CONFIRMED' || b.status == 'PENDING')
                OutlinedButton.icon(onPressed: () => setStatus('NO_SHOW'), icon: const Icon(Icons.event_busy_outlined), label: Text(l.bookingMarkNoShow)),
              if (frontDesk)
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: context.colors.error),
                  onPressed: () => _cancel(context, ref, b),
                  icon: const Icon(Icons.close_rounded),
                  label: Text(l.bookingCancel),
                ),
            ],
          ),
        ],
        const SizedBox(height: Space.xl),
        Text(l.bookingHistory, style: context.text.titleMedium),
        const SizedBox(height: Space.md),
        ...detail.history.reversed.map((h) => _HistoryItem(entry: h, timezone: tz)),
        if (detail.payments.isNotEmpty) ...[
          const SizedBox(height: Space.lg),
          Text(context.l10n.navPayments, style: context.text.titleMedium),
          const SizedBox(height: Space.sm),
          for (final p in detail.payments)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(p.isRefund ? Icons.undo_rounded : Icons.payments_outlined),
              title: Text('${fmt.kindLabel(p.kind)} · ${fmt.methodLabel(p.method)}'),
              subtitle: Text(p.status == 'PAID' ? l.paymentStatusPaid : l.paymentStatusPending),
              trailing: Text((p.isRefund ? '−' : '') + fmt.money(p.amountBaisa), style: context.text.titleSmall),
            ),
        ],
      ],
    );
  }

  Future<void> _cancel(BuildContext context, WidgetRef ref, Booking b) async {
    final l = context.l10n;
    final reason = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.bookingCancelTitle),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text(l.bookingCancelBody),
          const SizedBox(height: Space.lg),
          TextField(controller: reason, decoration: InputDecoration(labelText: l.bookingCancelReason)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.actionKeep)),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ctx.colors.error, foregroundColor: ctx.colors.onError),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l.bookingCancel),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final repo = ref.read(bookingsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.cancel(b.id, reason: reason.text.trim().isEmpty ? null : reason.text.trim());
      invalidateBookingViews(ref, b.id);
      messenger.showSnackBar(SnackBar(
        content: Text(l.bookingCancelled),
        duration: const Duration(seconds: 8),
        action: SnackBarAction(
          label: l.actionUndo,
          onPressed: () async {
            try {
              await repo.restore(b.id);
              invalidateBookingViews(ref, b.id);
              messenger.showSnackBar(SnackBar(content: Text(l.bookingRestored)));
            } catch (e) {
              messenger.showSnackBar(SnackBar(content: Text('$e')));
            }
          },
        ),
      ));
    } catch (e) {
      if (context.mounted) showGlowSnack(context, context.fmt.error(e), error: true);
    }
  }

  Future<void> _reschedule(BuildContext context, WidgetRef ref, Booking b) async {
    final m = ref.read(membershipProvider)!;
    final tz = ref.read(salonTimezoneProvider);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _RescheduleSheet(booking: b, salonId: m.salonId, timezone: tz),
    );
  }

  Future<void> _recordPayment(BuildContext context, WidgetRef ref, Booking b, int balance) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => _PaymentSheet(booking: b, balanceBaisa: balance),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value, this.last = false, this.dot, this.trailing, this.ltr = false});
  final IconData icon;
  final String label;
  final String value;
  final bool last;
  final Color? dot;
  final Widget? trailing;
  final bool ltr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : Space.md),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colors.onSurfaceVariant),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: context.text.labelSmall),
                Row(children: [
                  if (dot != null) ...[Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)), const SizedBox(width: 6)],
                  Flexible(child: Text(value, style: context.text.titleSmall, textDirection: ltr ? TextDirection.ltr : null)),
                ]),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

class _Money extends StatelessWidget {
  const _Money({required this.label, required this.value, this.strong = false});
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

class _Note extends StatelessWidget {
  const _Note({required this.title, required this.body});
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: context.text.labelMedium),
        const SizedBox(height: 4),
        Text(body, style: context.text.bodyMedium),
      ]);
}

class _InternalNotes extends ConsumerStatefulWidget {
  const _InternalNotes({required this.booking});
  final Booking booking;
  @override
  ConsumerState<_InternalNotes> createState() => _InternalNotesState();
}

class _InternalNotesState extends ConsumerState<_InternalNotes> {
  late final _c = TextEditingController(text: widget.booking.internalNotes ?? '');
  bool _dirty = false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _c,
          minLines: 2,
          maxLines: 5,
          onChanged: (_) => setState(() => _dirty = true),
          decoration: InputDecoration(labelText: l.bookingInternalNotes, helperText: l.bookingInternalNotesHint, prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20)),
        ),
        AnimatedSize(
          duration: Motion.of(context).medium,
          child: _dirty
              ? Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: AnimatedButton(
                      expand: false,
                      tone: ButtonTone.soft,
                      label: l.actionSave,
                      onPressed: () => guard(context, () async {
                        await ref.read(bookingsRepositoryProvider).saveNotes(widget.booking.id, _c.text.trim().isEmpty ? null : _c.text.trim());
                        ref.invalidate(bookingDetailProvider(widget.booking.id));
                        if (context.mounted) setState(() => _dirty = false);
                      }),
                    ),
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _HistoryItem extends StatelessWidget {
  const _HistoryItem({required this.entry, required this.timezone});
  final HistoryEntry entry;
  final String timezone;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final text = switch (entry.kind) {
      'CREATED' => l.historyCreated,
      'RESCHEDULE' => l.historyRescheduled(
          entry.oldStart == null ? '' : fmt.dateTime(entry.oldStart!, timezone),
          entry.newStart == null ? '' : fmt.dateTime(entry.newStart!, timezone),
        ),
      'NOTE' => l.historyNote,
      _ => l.historyStatus(fmt.statusLabel(entry.toStatus ?? '')),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 5),
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: context.glow.forStatus(entry.toStatus ?? 'CONFIRMED').fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: context.text.bodyMedium),
                Text(
                  [fmt.dateTime(entry.at, timezone), if (entry.byName != null) l.historyBy(entry.byName!), if (entry.note != null && entry.kind != 'NOTE') '“${entry.note}”'].join(' · '),
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RescheduleSheet extends ConsumerStatefulWidget {
  const _RescheduleSheet({required this.booking, required this.salonId, required this.timezone});
  final Booking booking;
  final String salonId;
  final String timezone;
  @override
  ConsumerState<_RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends ConsumerState<_RescheduleSheet> {
  Slot? _slot;
  int _refresh = 0;

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(bookingsRepositoryProvider);
    final l = context.l10n;
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, MediaQuery.viewInsetsOf(context).bottom + Space.xl),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.bookingReschedule, style: context.text.headlineSmall),
            Text('${widget.booking.customer.name} · ${widget.booking.service.display(context.lang)} · ${widget.booking.staff.display(context.lang)}', style: context.text.bodySmall),
            const SizedBox(height: Space.lg),
            SlotPicker(
              timezone: widget.timezone,
              refreshToken: _refresh,
              initialDate: Ymd.of(Fmt.inZone(widget.booking.start, widget.timezone)),
              selected: _slot,
              onSelected: (s) => setState(() => _slot = s),
              loadSlots: (date) async => (await repo.availability(
                salonId: widget.salonId,
                serviceId: widget.booking.service.id,
                date: date,
                staffId: widget.booking.staff.id,
              ))
                  .slots,
            ),
            const SizedBox(height: Space.lg),
            AnimatedButton(
              label: l.bookingReschedule,
              icon: Icons.edit_calendar_outlined,
              enabled: _slot != null,
              onPressed: _slot == null
                  ? null
                  : () async {
                      try {
                        await repo.reschedule(widget.booking.id, _slot!.start);
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
                      invalidateBookingViews(ref, widget.booking.id);
                      if (context.mounted) {
                        showGlowSnack(context, l.bookingRescheduled);
                        Navigator.pop(context);
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentSheet extends ConsumerStatefulWidget {
  const _PaymentSheet({required this.booking, required this.balanceBaisa});
  final Booking booking;
  final int balanceBaisa;
  @override
  ConsumerState<_PaymentSheet> createState() => _PaymentSheetState();
}

class _PaymentSheetState extends ConsumerState<_PaymentSheet> {
  late final _amount = TextEditingController(text: (widget.balanceBaisa / 1000).toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), ''));
  String _method = 'CARD';

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final b = widget.booking;
    final kind = b.paidBaisa == 0 && b.depositBaisa == 0 ? 'FULL' : (b.paidBaisa < b.depositBaisa ? 'DEPOSIT' : 'BALANCE');
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, MediaQuery.viewInsetsOf(context).bottom + Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.bookingRecordPayment, style: context.text.headlineSmall),
          const SizedBox(height: Space.lg),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: l.paymentAmount, prefixIcon: const Icon(Icons.payments_outlined)),
          ),
          const SizedBox(height: Space.lg),
          Text(l.paymentMethod, style: context.text.labelMedium),
          const SizedBox(height: Space.sm),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'CARD', label: Text(l.methodCard), icon: const Icon(Icons.credit_card_rounded)),
              ButtonSegment(value: 'CASH', label: Text(l.methodCash), icon: const Icon(Icons.money_rounded)),
              ButtonSegment(value: 'BANK_TRANSFER', label: Text(l.methodBank), icon: const Icon(Icons.account_balance_outlined)),
            ],
            selected: {_method},
            onSelectionChanged: (s) => setState(() => _method = s.first),
          ),
          const SizedBox(height: Space.xl),
          AnimatedButton(
            label: l.bookingRecordPayment,
            keepSuccess: true,
            onPressed: () => guard(context, () async {
              final value = double.tryParse(_amount.text.trim().replaceAll(',', '.'));
              if (value == null || value <= 0) throw StateError(l.errorNumber);
              await ref.read(bookingsRepositoryProvider).recordPayment(b.id, amountBaisa: (value * 1000).round(), method: _method, kind: kind);
              invalidateBookingViews(ref, b.id);
              if (context.mounted) {
                showGlowSnack(context, l.paymentRecorded);
                Navigator.pop(context);
              }
            }),
          ),
        ],
      ),
    );
  }
}
