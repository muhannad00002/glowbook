import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/animations/animated_success.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/salon_cover.dart';
import '../../../shared/widgets/step_flow.dart';
import '../../auth/presentation/auth_layout.dart';
import '../../bookings/presentation/slot_picker.dart';
import '../../salon/data/salon_repository.dart';
import 'booking_draft.dart';

/// Service → Artist → Date & time → Details → Confirm, then pay & celebrate.
class BookingFlowScreen extends ConsumerWidget {
  const BookingFlowScreen({super.key, required this.slug, this.serviceId});
  final String slug;
  final String? serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(salonProfileProvider(slug));
    return Scaffold(
      body: AsyncView(
        value: profile,
        onRetry: () => ref.invalidate(salonProfileProvider(slug)),
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
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  final _notes = TextEditingController();

  String get _slug => widget.profile.card.slug;
  BookingDraftController get _c => ref.read(bookingDraftProvider(_slug).notifier);

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).valueOrNull?.me.user;
    _name = TextEditingController(text: user?.name ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    final preset = widget.profile.services.where((s) => s.id == widget.initialServiceId).firstOrNull;
    if (preset != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _c.pickService(preset);
        _c.goTo(1);
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _canNext(BookingDraft d) => switch (d.step) {
        0 => d.service != null,
        1 => true,
        2 => d.slot != null,
        _ => true,
      };

  Future<void> _next(BookingDraft d) async {
    if (d.step == 3) {
      if (!_form.currentState!.validate()) throw StateError('invalid');
      _c.details(name: _name.text, phone: _phone.text, email: _email.text, notes: _notes.text);
    }
    _c.goTo(d.step + 1);
  }

  Future<void> _confirm() async {
    try {
      await _c.confirm();
    } on ApiException catch (e) {
      if (!mounted) rethrow;
      if (e.isConflict) {
        showGlowSnack(context, context.l10n.flowSlotTaken, error: true);
        _c.slotTaken();
      } else {
        showGlowSnack(context, context.fmt.error(e), error: true);
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final d = ref.watch(bookingDraftProvider(_slug));
    final p = widget.profile;
    if (d.result != null) return _Result(profile: p, draft: d, onPay: _c.payDeposit);

    final steps = [l.flowService, l.flowArtist, l.flowTime, l.flowDetails, l.flowConfirm];
    final titles = [l.flowChooseService, l.flowChooseArtist, l.flowChooseTime, l.flowYourDetails, l.flowReview];
    final g = gutterOf(context);

    return Column(
      children: [
        SafeArea(
          bottom: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(Space.sm, Space.sm, g, 0),
            child: Row(children: [
              IconButton(
                tooltip: d.step == 0 ? l.actionClose : l.actionBack,
                icon: Icon(d.step == 0 ? Icons.close_rounded : Icons.arrow_back_rounded),
                onPressed: () => d.step == 0 ? (context.canPop() ? context.pop() : context.go('/salon/$_slug')) : _c.goTo(d.step - 1),
              ),
              Expanded(
                child: Row(children: [
                  ClipOval(child: SizedBox(width: 32, height: 32, child: SalonCover(name: p.card.name, height: 32, monogramSize: 16))),
                  const SizedBox(width: Space.sm),
                  Expanded(child: Text(p.card.title(context.lang), style: context.text.titleMedium, overflow: TextOverflow.ellipsis)),
                ]),
              ),
            ]),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(g, Space.sm, g, Space.md),
          child: ContentWidth(maxWidth: 720, child: StepHeader(steps: steps, current: d.step, onTapStep: _c.goTo)),
        ),
        Expanded(
          child: ContentWidth(
            maxWidth: 720,
            child: StepSwitcher(
              step: d.step,
              forward: d.forward,
              child: ListView(
                padding: EdgeInsets.fromLTRB(g, Space.sm, g, Space.xl),
                children: [
                  Text(titles[d.step], style: context.text.headlineMedium),
                  const SizedBox(height: Space.lg),
                  switch (d.step) {
                    0 => _serviceStep(d),
                    1 => _artistStep(d),
                    2 => _timeStep(d),
                    3 => _detailsStep(),
                    _ => _reviewStep(d),
                  },
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(g, Space.sm, g, Space.lg),
            child: ContentWidth(
              maxWidth: 720,
              child: d.step < 4
                  ? AnimatedButton(label: l.actionContinue, enabled: _canNext(d), onPressed: _canNext(d) ? () => _next(d) : null)
                  : AnimatedButton(
                      label: d.service!.dueAtBookingBaisa > 0 ? l.flowBookAndPay : l.flowBook,
                      icon: Icons.auto_awesome_rounded,
                      keepSuccess: true,
                      onPressed: _confirm,
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _serviceStep(BookingDraft d) {
    final p = widget.profile;
    final fmt = context.fmt;
    return Column(
      children: [
        for (var i = 0; i < p.services.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: StaggeredEntrance(
              index: i,
              child: OptionCard(
                selected: d.service?.id == p.services[i].id,
                onTap: () => _c.pickService(p.services[i]),
                title: p.services[i].title(context.lang),
                subtitle: [
                  fmt.duration(p.services[i].durationMinutes),
                  if (p.services[i].needsDeposit) '${context.l10n.bookingDeposit} ${fmt.money(p.services[i].depositBaisa)}',
                ].join(' · '),
                trailing: Text(fmt.money(p.services[i].priceBaisa), style: context.text.titleMedium?.copyWith(color: context.colors.primary)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _artistStep(BookingDraft d) {
    final l = context.l10n;
    final able = widget.profile.staff.where((s) => d.service?.staffIds.contains(s.id) ?? true).toList();
    return Column(children: [
      StaggeredEntrance(
        index: 0,
        child: OptionCard(
          selected: d.staffId == null,
          onTap: () => _c.pickStaff(null),
          leading: CircleAvatar(radius: 22, backgroundColor: context.colors.primaryContainer, child: Icon(Icons.auto_awesome_rounded, color: context.colors.primary)),
          title: l.anyArtist,
          subtitle: l.anyArtistBody,
        ),
      ),
      const SizedBox(height: Space.sm),
      for (var i = 0; i < able.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: Space.sm),
          child: StaggeredEntrance(
            index: i + 1,
            child: OptionCard(
              selected: d.staffId == able[i].id,
              onTap: () => _c.pickStaff(able[i].id),
              leading: InitialsAvatar(name: able[i].name, color: hexColor(able[i].color), photoUrl: able[i].photoUrl),
              title: able[i].displayName(context.lang),
              subtitle: able[i].displayTitle(context.lang),
            ),
          ),
        ),
    ]);
  }

  Widget _timeStep(BookingDraft d) {
    final repo = ref.read(salonRepositoryProvider);
    return SlotPicker(
      timezone: widget.profile.timezone,
      selected: d.slot,
      refreshToken: d.slotRefresh,
      onSelected: _c.pickSlot,
      loadSlots: (date) => repo.slots(salon: _slug, serviceId: d.service!.id, date: date, staffId: d.staffId),
      loadDays: (from, days) => repo.days(salon: _slug, serviceId: d.service!.id, from: from, days: days, staffId: d.staffId),
    );
  }

  Widget _detailsStep() {
    final l = context.l10n;
    final v = V(context);
    final signedIn = ref.read(authControllerProvider).valueOrNull != null;
    return AutofillGroup(
      child: Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GlowField(controller: _name, label: l.authFullName, autofill: const [AutofillHints.name], validator: v.required),
            GlowField(controller: _phone, label: l.authPhone, hint: '+968 9…', keyboardType: TextInputType.phone, autofill: const [AutofillHints.telephoneNumber], validator: v.phone, textDirection: TextDirection.ltr),
            GlowField(controller: _email, label: '${l.authEmail} (${l.labelOptional})', keyboardType: TextInputType.emailAddress, autofill: const [AutofillHints.email]),
            GlowField(controller: _notes, label: l.flowNotes, hint: l.flowNotesHint, maxLines: 3),
            if (!signedIn)
              TextButton.icon(
                onPressed: () => context.push('/login?from=${Uri.encodeComponent('/salon/$_slug/book')}'),
                icon: const Icon(Icons.login_rounded),
                label: Text(l.flowSignInHint),
              ),
          ],
        ),
      ),
    );
  }

  Widget _reviewStep(BookingDraft d) {
    final l = context.l10n;
    final fmt = context.fmt;
    final p = widget.profile;
    final s = d.service!;
    final tz = p.timezone;
    final artist = d.staffId == null
        ? (d.slot!.staffIds.length == 1 ? p.staff.where((x) => x.id == d.slot!.staffIds.first).firstOrNull?.displayName(context.lang) : null) ?? l.anyArtist
        : p.staff.where((x) => x.id == d.staffId).firstOrNull?.displayName(context.lang) ?? '';
    final due = s.dueAtBookingBaisa;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        StaggeredEntrance(
          index: 0,
          child: GlowCard(
            gradient: context.glow.heroGradient,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title(context.lang), style: context.text.headlineSmall),
              const SizedBox(height: Space.sm),
              _Line(Icons.event_outlined, fmt.fullDate(d.slot!.start, tz)),
              _Line(Icons.schedule_rounded, '${fmt.time(d.slot!.start, tz)} · ${fmt.duration(s.durationMinutes)}'),
              _Line(Icons.brush_outlined, artist),
              _Line(Icons.person_outline_rounded, '${d.name} · ${d.phone}'),
            ]),
          ),
        ),
        const SizedBox(height: Space.lg),
        StaggeredEntrance(
          index: 1,
          child: GlowCard(
            child: Column(children: [
              _Amount(l.flowTotal, fmt.money(s.priceBaisa)),
              if (due > 0) ...[
                _Amount(l.flowDepositDue, fmt.money(due), strong: true),
                _Amount(l.flowRemaining, fmt.money(s.priceBaisa - due)),
              ] else
                _Amount(l.flowPayAtSalon, fmt.money(s.priceBaisa), strong: true),
            ]),
          ),
        ),
        const SizedBox(height: Space.lg),
        StaggeredEntrance(
          index: 2,
          child: GlowCard(
            color: context.colors.secondaryContainer,
            elevated: false,
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.info_outline_rounded, color: context.colors.onSecondaryContainer),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(l.flowPolicy, style: context.text.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    [
                      l.flowPolicyFree(p.cancellationWindowHours),
                      if (due > 0) l.flowPolicyDeposit,
                      if (p.lateCancellationFeeBaisa > 0) l.flowPolicyFee(fmt.money(p.lateCancellationFeeBaisa)),
                    ].join(' '),
                    style: context.text.bodyMedium,
                  ),
                ]),
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.text);
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(children: [
          Icon(icon, size: 18, color: context.colors.primary),
          const SizedBox(width: Space.sm),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ]),
      );
}

class _Amount extends StatelessWidget {
  const _Amount(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Text(label, style: strong ? context.text.titleSmall : context.text.bodyMedium)),
          Text(value, style: strong ? context.text.titleMedium?.copyWith(color: context.colors.primary) : context.text.bodyMedium),
        ]),
      );
}

/// Success (or "held — pay the deposit") after booking.
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
    final b = r.booking;
    final tz = profile.timezone;
    final held = r.requiresPayment && !draft.paid;
    final signedIn = ref.watch(authControllerProvider).valueOrNull != null;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(Space.xl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  child: held
                      ? const Padding(key: ValueKey('held'), padding: EdgeInsets.all(Space.xl), child: Icon(Icons.lock_clock_outlined, size: 72))
                      : AnimatedSuccess(key: ValueKey('ok-${draft.paid}')),
                ),
                StaggeredEntrance(
                  index: 5,
                  child: Text(held ? l.flowHeld : l.flowConfirmed, style: context.text.headlineMedium, textAlign: TextAlign.center),
                ),
                const SizedBox(height: Space.sm),
                StaggeredEntrance(
                  index: 6,
                  child: Text(held ? l.flowHeldBody : l.flowConfirmedBody, style: context.text.bodyLarge, textAlign: TextAlign.center),
                ),
                const SizedBox(height: Space.xl),
                StaggeredEntrance(
                  index: 8,
                  child: GlowCard(
                    child: Column(children: [
                      Text(b.service.display(context.lang), style: context.text.titleLarge),
                      const SizedBox(height: 4),
                      Text(fmt.fullDate(b.start, tz), style: context.text.bodyMedium),
                      Text('${fmt.time(b.start, tz)} · ${b.staff.display(context.lang)}', style: context.text.bodyMedium),
                      const SizedBox(height: Space.sm),
                      Text('${l.bookingReference} ${b.reference}', style: context.text.bodySmall),
                      if (b.paidBaisa > 0) ...[
                        const Divider(height: Space.xl),
                        _Amount(l.bookingPaid, fmt.money(b.paidBaisa)),
                        _Amount(l.flowRemaining, fmt.money(b.balanceBaisa), strong: true),
                      ],
                    ]),
                  ),
                ),
                const SizedBox(height: Space.xl),
                if (held) ...[
                  if (r.onlinePaymentAvailable) ...[
                    Text(l.payTestMode, style: context.text.bodySmall, textAlign: TextAlign.center),
                    const SizedBox(height: Space.sm),
                    AnimatedButton(
                      label: l.payNow(fmt.money(b.depositBaisa - b.paidBaisa)),
                      icon: Icons.credit_card_rounded,
                      keepSuccess: true,
                      onPressed: () => guard(context, onPay),
                    ),
                  ] else
                    Text(l.payUnavailable, style: context.text.bodyMedium, textAlign: TextAlign.center),
                ] else ...[
                  if (!signedIn) Text(l.flowManageLinkHint, style: context.text.bodySmall, textAlign: TextAlign.center),
                  const SizedBox(height: Space.md),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => context.go(signedIn ? '/appointments/${b.id}' : '/booking/${b.id}?token=${r.manageToken}'),
                        child: Text(l.flowViewAppointment),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(child: FilledButton(onPressed: () => context.go(signedIn ? '/appointments' : '/salon/${profile.card.slug}'), child: Text(l.flowDone))),
                  ]),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

