import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/animations/animated_success.dart';
import '../../../shared/animations/shimmer_loading.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/fit_layout.dart';
import '../../../shared/widgets/step_flow.dart';
import '../../salon/data/salon_repository.dart';
import 'booking_draft.dart';
import 'customer_widgets.dart';

/// Customer booking, one decision per screen so nothing ever scrolls:
///   Services → Artist → Day → Time → Name & phone → Code → booked.
class BookingFlowScreen extends ConsumerWidget {
  const BookingFlowScreen({super.key, required this.slug, this.serviceId});
  final String slug;
  final String? serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(salonProfileProvider(slug));
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: profile.when(
        loading: () => const Center(child: LoadingPad()),
        error: (e, _) => linkErrorView(context, e, onRetry: () => ref.invalidate(salonProfileProvider(slug))),
        data: (p) => _Flow(profile: p, initialServiceId: serviceId),
      ),
    );
  }
}

class _Flow extends ConsumerStatefulWidget {
  const _Flow({required this.profile, this.initialServiceId});
  final SalonProfile profile;
  final String? initialServiceId;
  @override
  ConsumerState<_Flow> createState() => _FlowState();
}

class _FlowState extends ConsumerState<_Flow> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _code = TextEditingController();
  Timer? _ticker;

  String get _slug => widget.profile.card.slug;
  BookingDraftController get _c => ref.read(bookingDraftProvider(_slug).notifier);

  @override
  void initState() {
    super.initState();
    _code.addListener(() => setState(() {}));
    // Keeps the "Resend in Ns" countdown moving.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(bookingDraftProvider(_slug)).step == BookStep.verify) setState(() {});
    });
    final preset = widget.profile.services.where((s) => s.id == widget.initialServiceId).firstOrNull;
    if (preset != null) WidgetsBinding.instance.addPostFrameCallback((_) => _c.toggleService(preset, widget.profile));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in [_name, _phone, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Runs a booking action; maps the server's answers to the right step.
  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      if (!mounted) rethrow;
      final needsVerification = e.data is Map && (e.data as Map)['needsVerification'] == true;
      if (e.isConflict) {
        showGlowSnack(context, context.l10n.flowSlotTaken, error: true);
        _c.slotTaken();
      } else if (needsVerification) {
        showGlowSnack(context, e.message, error: true);
        _c.goTo(BookStep.details);
      } else {
        showGlowSnack(context, context.fmt.error(e), error: true);
      }
      rethrow;
    } catch (e) {
      if (mounted) showGlowSnack(context, context.fmt.error(e), error: true);
      rethrow;
    }
  }

  Future<void> _sendCode() async {
    if (!_form.currentState!.validate()) throw StateError('invalid');
    FocusScope.of(context).unfocus();
    _c.details(name: _name.text.trim(), phone: composePhone(_phone.text));
    _code.clear();
    final locale = context.lang;
    await _run(() => _c.sendCode(locale));
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(bookingDraftProvider(_slug));
    final p = widget.profile;
    final l = context.l10n;
    if (d.result != null) return _Result(profile: p, draft: d, onPay: () => _run(_c.payDeposits));

    final summary = d.serviceIds.isEmpty ? null : _Summary(profile: p, draft: d);
    void back() => d.step == BookStep.services ? context.go('/') : _c.goTo(d.step - 1);
    final hasArtists = eligibleStaff(p, d.serviceIds).isNotEmpty;

    final page = switch (d.step) {
      BookStep.services => FitStepPage(
        step: d.step,
        total: BookStep.count,
        onBack: back,
        title: l.flowServicesTitle,
        body: _ServicesStep(profile: p, draft: d, controller: _c),
        summary: summary,
        action: AnimatedButton(
          key: const ValueKey('services'),
          label: l.actionContinue,
          enabled: d.serviceIds.isNotEmpty,
          onPressed: d.serviceIds.isEmpty ? null : () async => _c.goTo(BookStep.artist),
        ),
      ),
      BookStep.artist => FitStepPage(
        step: d.step,
        total: BookStep.count,
        onBack: back,
        title: l.flowArtistTitle,
        body: _ArtistStep(profile: p, draft: d, controller: _c),
        summary: summary,
        action: AnimatedButton(
          key: const ValueKey('artist'),
          label: l.actionContinue,
          enabled: hasArtists,
          onPressed: hasArtists ? () async => _c.goTo(BookStep.date) : null,
        ),
      ),
      BookStep.date => FitStepPage(
        step: d.step,
        total: BookStep.count,
        onBack: back,
        title: l.flowDateTitle,
        body: _DateStep(
          profile: p,
          draft: d,
          onPick: (date) {
            _c.pickDate(date);
            _c.goTo(BookStep.time);
          },
        ),
        summary: summary,
      ),
      BookStep.time => FitStepPage(
        step: d.step,
        total: BookStep.count,
        onBack: back,
        title: l.flowTimeTitle,
        subtitle: d.date == null ? null : context.fmt.ymdLabel(d.date!, pattern: 'yMMMMEEEEd'),
        body: _TimeStep(profile: p, draft: d, controller: _c),
        summary: summary,
        action: AnimatedButton(
          key: const ValueKey('time'),
          label: l.actionContinue,
          enabled: d.slot != null,
          onPressed: d.slot == null ? null : () async => _c.goTo(BookStep.details),
        ),
      ),
      BookStep.details => FitStepPage(
        step: d.step,
        total: BookStep.count,
        onBack: back,
        title: l.flowDetails,
        subtitle: l.flowPhoneHelp,
        body: FitBox(
          child: DetailsForm(form: _form, name: _name, phone: _phone),
        ),
        summary: summary,
        action: AnimatedButton(key: const ValueKey('send'), label: l.flowSendCode, icon: Icons.sms_outlined, keepSuccess: true, onPressed: _sendCode),
      ),
      _ => FitStepPage(
        step: d.step,
        total: BookStep.count,
        onBack: back,
        title: l.flowVerifyTitle,
        subtitle: l.flowVerifyBody(d.codeSentTo ?? ''),
        body: VerifyBody(
          code: _code,
          sentAt: d.codeSentAt,
          testCode: d.testCode,
          onResend: () async {
            final locale = context.lang;
            await _run(() => _c.sendCode(locale));
            _code.clear();
          },
          onChangeNumber: () => _c.goTo(BookStep.details),
        ),
        summary: summary,
        action: AnimatedButton(
          key: const ValueKey('confirm'),
          label: l.flowBook,
          icon: Icons.auto_awesome_rounded,
          keepSuccess: true,
          enabled: _code.text.length == 6,
          onPressed: _code.text.length == 6 ? () => _run(() => _c.verifyAndBook(_code.text)) : null,
        ),
      ),
    };
    return StepSwitcher(
      step: d.step,
      forward: d.forward,
      child: KeyedSubtree(key: ValueKey(d.step), child: page),
    );
  }
}

// ---------------------------------------------------------------------------
// Bits
// ---------------------------------------------------------------------------

List<Service> _chosen(SalonProfile p, BookingDraft d) => [for (final id in d.serviceIds) ...p.services.where((s) => s.id == id)];
int _totalMinutes(SalonProfile p, BookingDraft d) => _chosen(p, d).fold(0, (sum, s) => sum + s.durationMinutes);
int _totalPrice(SalonProfile p, BookingDraft d) => _chosen(p, d).fold(0, (sum, s) => sum + s.priceBaisa);

String _artistName(BuildContext context, SalonProfile p, BookingDraft d) {
  final id = d.staffId ?? (d.slot != null && d.slot!.staffIds.length == 1 ? d.slot!.staffIds.first : null);
  return p.staff.where((m) => m.id == id).firstOrNull?.displayName(context.lang) ?? context.l10n.anyArtist;
}

/// What she has picked so far, above the action button.
class _Summary extends StatelessWidget {
  const _Summary({required this.profile, required this.draft});
  final SalonProfile profile;
  final BookingDraft draft;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final tz = profile.timezone;
    final slot = draft.slot;
    final when = slot != null
        ? '${fmt.weekdayDayMonth(slot.start, tz)} · ${fmt.time(slot.start, tz)} – ${fmt.time(slot.start.add(Duration(minutes: _totalMinutes(profile, draft))), tz)}'
        : draft.date != null && draft.step >= BookStep.time
        ? fmt.ymdLabel(draft.date!)
        : fmt.duration(_totalMinutes(profile, draft));
    return Column(
      key: ValueKey('${draft.servicesKey}|${slot?.start}|${draft.staffId}|${draft.date}|${draft.step > BookStep.artist}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(slot != null ? Icons.event_rounded : Icons.spa_outlined, size: 18, color: context.colors.primary),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(when, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text(fmt.money(_totalPrice(profile, draft)), style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
          ],
        ),
        Text(
          [l.flowServicesCount(draft.serviceIds.length), if (draft.step > BookStep.artist) _artistName(context, profile, draft)].join(' · '),
          style: context.text.bodySmall,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _ServicesStep extends StatelessWidget {
  const _ServicesStep({required this.profile, required this.draft, required this.controller});
  final SalonProfile profile;
  final BookingDraft draft;
  final BookingDraftController controller;
  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final l = context.l10n;
    return PagedGrid<Service>(
      items: profile.services,
      itemHeight: 70,
      minItemWidth: 260,
      itemBuilder: (context, s) => ChoiceTile(
        multi: true,
        selected: draft.serviceIds.contains(s.id),
        onTap: () => controller.toggleService(s, profile),
        child: TileText(
          s.title(context.lang),
          subtitle: [
            fmt.money(s.priceBaisa),
            fmt.duration(s.durationMinutes),
            if (s.needsDeposit) '${l.bookingDeposit} ${fmt.money(s.depositBaisa)}',
          ].join(' · '),
        ),
      ),
    );
  }
}

class _ArtistStep extends StatelessWidget {
  const _ArtistStep({required this.profile, required this.draft, required this.controller});
  final SalonProfile profile;
  final BookingDraft draft;
  final BookingDraftController controller;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final eligible = eligibleStaff(profile, draft.serviceIds);
    if (eligible.isEmpty) return StepHint(icon: Icons.info_outline_rounded, text: l.flowNoCommonArtist);
    return PagedGrid<StaffMember?>(
      items: [null, ...eligible],
      itemHeight: 70,
      minItemWidth: 260,
      itemBuilder: (context, m) => ChoiceTile(
        selected: draft.staffId == m?.id,
        onTap: () => controller.pickStaff(m?.id),
        child: Row(
          children: [
            m == null
                ? CircleAvatar(
                    radius: 20,
                    backgroundColor: context.colors.primaryContainer,
                    child: Icon(Icons.auto_awesome_rounded, size: 20, color: context.colors.primary),
                  )
                : InitialsAvatar(name: m.name, color: hexColor(m.color), size: 40, photoUrl: m.photoUrl),
            const SizedBox(width: Space.md),
            Expanded(
              child: TileText(m == null ? l.anyArtist : m.displayName(context.lang), subtitle: m == null ? l.flowAnyArtistHint : m.displayTitle(context.lang)),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateStep extends ConsumerWidget {
  const _DateStep({required this.profile, required this.draft, required this.onPick});
  final SalonProfile profile;
  final BookingDraft draft;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final q = (salon: profile.card.slug, services: draft.servicesKey, staffId: draft.staffId, from: Ymd.today(profile.timezone));
    final days = ref.watch(visitDaysProvider(q));
    return days.when(
      loading: () => const GridSkeleton(columns: 7, height: 60),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(visitDaysProvider(q))),
      data: (list) {
        if (!list.any((d) => !d.closed && d.slotCount > 0)) return StepHint(icon: Icons.event_busy_outlined, text: l.flowNoAvailability);
        final selected = list.indexWhere((d) => d.date == draft.date);
        return DateGrid(
          dates: [for (final d in list) d.date],
          isEnabled: (date) => list.any((d) => d.date == date && !d.closed && d.slotCount > 0),
          selected: draft.date,
          initialIndex: selected < 0 ? 0 : selected,
          onPick: onPick,
        );
      },
    );
  }
}

/// Days in a 7-wide grid with the month above — pages on very short screens.
class DateGrid extends StatelessWidget {
  const DateGrid({super.key, required this.dates, required this.isEnabled, required this.selected, required this.onPick, this.initialIndex = 0});
  final List<String> dates;
  final bool Function(String date) isEnabled;
  final String? selected;
  final ValueChanged<String> onPick;
  final int initialIndex;
  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final months = {for (final d in dates) DateFormat.yMMMM(lang).format(Ymd.parse(d))}.join(' – ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: Text(months, style: context.text.titleSmall?.copyWith(color: context.colors.onSurfaceVariant)),
        ),
        Expanded(
          child: PagedGrid<String>(
            items: dates,
            itemHeight: 60,
            minItemWidth: 36,
            maxColumns: 7,
            spacing: 6,
            initialIndex: initialIndex,
            itemBuilder: (context, d) => DayCell(date: d, selected: d == selected, enabled: isEnabled(d), onTap: () => onPick(d)),
          ),
        ),
      ],
    );
  }
}

class _TimeStep extends ConsumerWidget {
  const _TimeStep({required this.profile, required this.draft, required this.controller});
  final SalonProfile profile;
  final BookingDraft draft;
  final BookingDraftController controller;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final date = draft.date;
    if (date == null) return const SizedBox.shrink();
    final q = (salon: profile.card.slug, services: draft.servicesKey, staffId: draft.staffId, date: date);
    final slots = ref.watch(visitSlotsProvider(q));
    return slots.when(
      loading: () => const GridSkeleton(columns: 3, height: 50),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(visitSlotsProvider(q))),
      data: (list) {
        if (list.isEmpty) {
          return StepHint(
            icon: Icons.event_busy_outlined,
            text: l.flowDayFull,
            action: OutlinedButton(onPressed: () => controller.goTo(BookStep.date), child: Text(l.flowPickAnotherDay)),
          );
        }
        final selected = list.indexWhere((s) => s.start == draft.slot?.start);
        return TimeGrid(
          count: list.length,
          initialIndex: selected < 0 ? 0 : selected,
          cell: (i) => TimeCell(label: slotLabel(context, list[i]), selected: draft.slot?.start == list[i].start, onTap: () => controller.pickSlot(list[i])),
        );
      },
    );
  }
}

/// "2:30 PM" for a slot's salon-local time.
String slotLabel(BuildContext context, Slot s) {
  final p = s.time.split(':').map(int.parse).toList();
  return DateFormat.jm(context.lang).format(DateTime(2000, 1, 1, p[0], p[1]));
}

/// Times in a grid that fills the step and pages when there are many.
class TimeGrid extends StatelessWidget {
  const TimeGrid({super.key, required this.count, required this.cell, this.initialIndex = 0, this.itemHeight = 50});
  final int count;
  final Widget Function(int index) cell;
  final int initialIndex;
  final double itemHeight;
  @override
  Widget build(BuildContext context) => PagedGrid<int>(
    items: List.generate(count, (i) => i),
    itemHeight: itemHeight,
    minItemWidth: 96,
    maxColumns: 5,
    initialIndex: initialIndex,
    itemBuilder: (context, i) => cell(i),
  );
}

/// Placeholder rows while a grid loads.
class GridSkeleton extends StatelessWidget {
  const GridSkeleton({super.key, required this.columns, required this.height});
  final int columns;
  final double height;
  @override
  Widget build(BuildContext context) => ShimmerLoading(
    child: Column(
      children: [
        for (var r = 0; r < 3; r++)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Row(
              children: [
                for (var c = 0; c < columns; c++) ...[
                  if (c > 0) const SizedBox(width: Space.sm),
                  Expanded(
                    child: SkeletonBox(height: height, radius: Radii.md),
                  ),
                ],
              ],
            ),
          ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Done
// ---------------------------------------------------------------------------

class _Result extends ConsumerWidget {
  const _Result({required this.profile, required this.draft, required this.onPay});
  final SalonProfile profile;
  final BookingDraft draft;
  final Future<void> Function() onPay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final fmt = context.fmt;
    final r = draft.result!;
    final tz = profile.timezone;
    final held = r.requiresPayment && !draft.paid;
    final first = r.bookings.first;
    final last = r.bookings.last;
    final deposit = r.bookings.fold(0, (sum, b) => sum + (b.depositOutstanding ? b.depositBaisa - b.paidBaisa : 0));
    final g = gutterOf(context);

    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: EdgeInsets.fromLTRB(g, Space.md, g, Space.md),
            child: Column(
              children: [
                Expanded(
                  child: FitBox(
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AnimatedSwitcher(
                          duration: Motion.of(context).slow,
                          child: held
                              ? Padding(
                                  key: const ValueKey('held'),
                                  padding: const EdgeInsets.all(Space.lg),
                                  child: Icon(Icons.lock_clock_outlined, size: 64, color: context.colors.primary),
                                )
                              : AnimatedSuccess(key: ValueKey('ok-${draft.paid}'), size: 104),
                        ),
                        Text(held ? l.flowHeld : l.flowConfirmed, style: context.text.headlineMedium, textAlign: TextAlign.center),
                        const SizedBox(height: Space.xs),
                        Text(held ? l.flowHeldBody : l.flowLinkSentBody, style: context.text.bodyMedium, textAlign: TextAlign.center),
                        const SizedBox(height: Space.lg),
                        GlowCard(
                          gradient: context.glow.heroGradient,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(fmt.fullDate(first.start, tz), style: context.text.titleMedium),
                              Text(
                                '${fmt.time(first.start, tz)} – ${fmt.time(last.end, tz)} · ${l.flowWith(first.staff.display(context.lang))}',
                                style: context.text.bodyMedium,
                              ),
                              const SizedBox(height: Space.sm),
                              Text(
                                r.bookings.map((b) => b.service.display(context.lang)).join(' · '),
                                style: context.text.titleSmall,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text('${l.bookingReference} ${first.reference}', style: context.text.bodySmall),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Space.md),
                if (held) ...[
                  if (r.onlinePaymentAvailable) ...[
                    AnimatedButton(label: l.payNow(fmt.money(deposit)), icon: Icons.credit_card_rounded, keepSuccess: true, onPressed: onPay),
                    const SizedBox(height: Space.xs),
                    Text(l.payTestMode, style: context.text.bodySmall, textAlign: TextAlign.center),
                  ] else
                    Text(l.payUnavailable, style: context.text.bodyMedium, textAlign: TextAlign.center),
                ] else ...[
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: () => context.go('/booking/${first.id}?token=${r.manageToken}'), child: Text(l.flowViewAppointment)),
                  ),
                  const SizedBox(height: Space.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(onPressed: () => context.go('/'), child: Text(l.flowDone)),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
