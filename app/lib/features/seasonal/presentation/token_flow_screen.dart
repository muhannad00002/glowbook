import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/auth/auth_controller.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/animations/animated_success.dart';
import '../../../shared/animations/shimmer_loading.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/step_flow.dart';
import '../../auth/presentation/auth_layout.dart';
import '../../customer_booking/data/customer_booking_repository.dart';
import '../../customer_booking/presentation/booking_flow_screen.dart' show OtpCodeInput, composePhone;
import '../data/seasonal_repository.dart';
import 'token_widgets.dart';

/// Taking a seasonal token: Choose (service, day, time) → Details → Verify → Pay.
/// The token is held while she pays; paying confirms it.
class TokenFlowScreen extends ConsumerWidget {
  const TokenFlowScreen({super.key, required this.slug, required this.eventId});
  final String slug;
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(salonSeasonalEventsProvider(slug));
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AsyncView(
        value: events,
        onRetry: () => ref.invalidate(salonSeasonalEventsProvider(slug)),
        data: (list) {
          final event = list.where((e) => e.id == eventId).firstOrNull;
          if (event == null) {
            return SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(Space.xl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event_busy_outlined, size: 56, color: context.colors.onSurfaceVariant),
                      const SizedBox(height: Space.md),
                      Text(context.l10n.seasonEventOver, style: context.text.titleMedium, textAlign: TextAlign.center),
                      const SizedBox(height: Space.lg),
                      FilledButton(onPressed: () => context.go('/salon/$slug'), child: Text(context.l10n.flowDone)),
                    ],
                  ),
                ),
              ),
            );
          }
          return _Flow(slug: slug, event: event);
        },
      ),
    );
  }
}

class _Flow extends ConsumerStatefulWidget {
  const _Flow({required this.slug, required this.event});
  final String slug;
  final SeasonalEvent event;
  @override
  ConsumerState<_Flow> createState() => _FlowState();
}

class _FlowState extends ConsumerState<_Flow> {
  static const _countryCode = '+968';
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  final _notes = TextEditingController();
  final _code = TextEditingController();
  Timer? _ticker;

  int _step = 0;
  bool _forward = true;
  SeasonalOffering? _offering;
  String? _date;
  TokenSlot? _slot;
  String? _codeSentTo;
  DateTime? _codeSentAt;
  String? _testCode;
  SeasonalToken? _token;
  String? _access;

  SeasonalEvent get _event => widget.event;
  SeasonalRepository get _repo => ref.read(seasonalRepositoryProvider);

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).valueOrNull?.me.user;
    _name = TextEditingController(text: user?.name ?? '');
    final phone = user?.phone ?? '';
    _phone = TextEditingController(text: phone.startsWith(_countryCode) ? phone.substring(_countryCode.length) : phone);
    _code.addListener(() => setState(() {}));
    if (_event.offerings.length == 1) _offering = _event.offerings.first;
    _date = _event.dates.firstOrNull;
    // Drives the resend countdown and the payment-hold timer.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _step >= 2) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in [_name, _phone, _notes, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  void _goTo(int step) => setState(() {
    _forward = step > _step;
    _step = step;
  });

  bool get _phoneAlreadyVerified {
    final user = ref.read(authControllerProvider).valueOrNull?.me.user;
    return user != null && user.phoneVerified && user.phone == composePhone(_phone.text);
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } on ApiException catch (e) {
      if (!mounted) rethrow;
      final needsVerification = e.data is Map && (e.data as Map)['needsVerification'] == true;
      if (e.isConflict) {
        showGlowSnack(context, e.message, error: true);
        ref.invalidate(tokenSlotsProvider);
        setState(() {
          _slot = null;
          _token = null;
          _access = null;
        });
        _goTo(0);
      } else if (needsVerification) {
        showGlowSnack(context, e.message, error: true);
        _goTo(1);
      } else {
        showGlowSnack(context, context.fmt.error(e), error: true);
      }
      rethrow;
    } catch (e) {
      if (mounted) showGlowSnack(context, context.fmt.error(e), error: true);
      rethrow;
    }
  }

  Future<void> _submitDetails() async {
    if (!_form.currentState!.validate()) throw StateError('invalid');
    FocusScope.of(context).unfocus();
    if (_phoneAlreadyVerified) {
      await _run(() => _take(null));
    } else {
      _code.clear();
      await _run(_sendCode);
    }
  }

  Future<void> _sendCode() async {
    final phone = composePhone(_phone.text);
    final testCode = await ref.read(customerBookingRepositoryProvider).requestCode(phone, context.lang);
    setState(() {
      _codeSentTo = phone;
      _codeSentAt = DateTime.now();
      _testCode = testCode;
    });
    _goTo(2);
  }

  Future<void> _verifyAndTake() async {
    final phoneToken = await ref.read(customerBookingRepositoryProvider).verifyCode(composePhone(_phone.text), _code.text);
    await _take(phoneToken);
  }

  Future<void> _take(String? phoneToken) async {
    final r = await _repo.take(
      offeringId: _offering!.id,
      start: _slot!.start,
      name: _name.text.trim(),
      phone: composePhone(_phone.text),
      phoneToken: phoneToken,
      notes: _notes.text.trim(),
    );
    setState(() {
      _token = r.token;
      _access = r.access;
    });
    _goTo(3);
  }

  Future<void> _pay() async {
    final paid = await _repo.pay(_token!.id, access: _access);
    ref.invalidate(tokenSlotsProvider);
    setState(() => _token = paid);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final token = _token;
    if (token != null && token.status == 'CONFIRMED') return _Confirmed(token: token, access: _access!, slug: widget.slug);

    final holdLeft = token?.holdExpiresAt?.difference(DateTime.now());
    final expired = holdLeft != null && holdLeft.isNegative;
    final Widget action = switch (_step) {
      0 => AnimatedButton(
        key: const ValueKey('continue'),
        label: l.actionContinue,
        enabled: _slot != null,
        onPressed: _slot == null ? null : () async => _goTo(1),
      ),
      1 => AnimatedButton(
        key: const ValueKey('send'),
        label: _phoneAlreadyVerified ? l.actionContinue : l.flowSendCode,
        icon: _phoneAlreadyVerified ? Icons.arrow_forward_rounded : Icons.sms_outlined,
        keepSuccess: true,
        onPressed: _submitDetails,
      ),
      2 => AnimatedButton(
        key: const ValueKey('verify'),
        label: l.actionContinue,
        keepSuccess: true,
        enabled: _code.text.length == 6,
        onPressed: _code.text.length == 6 ? () => _run(_verifyAndTake) : null,
      ),
      _ =>
        expired
            ? AnimatedButton(
                key: const ValueKey('again'),
                label: l.seasonTakeAnother,
                icon: Icons.refresh_rounded,
                onPressed: () async {
                  ref.invalidate(tokenSlotsProvider);
                  setState(() {
                    _token = null;
                    _slot = null;
                  });
                  _goTo(0);
                },
              )
            : AnimatedButton(
                key: const ValueKey('pay'),
                label: l.payNow(context.fmt.money(token?.dueBaisa ?? 0)),
                icon: Icons.credit_card_rounded,
                keepSuccess: true,
                onPressed: () => _run(_pay),
              ),
    };

    return Column(
      children: [
        Expanded(
          child: StepSwitcher(
            step: _step,
            forward: _forward,
            child: switch (_step) {
              0 => _ChooseStep(
                event: _event,
                offering: _offering,
                date: _date,
                slot: _slot,
                onOffering: (o) => setState(() {
                  _offering = o;
                  _slot = null;
                }),
                onDate: (d) => setState(() {
                  _forward = _date == null || d.compareTo(_date!) >= 0;
                  _date = d;
                  _slot = null;
                }),
                onSlot: (s) => setState(() => _slot = s),
              ),
              1 => _DetailsStep(
                form: _form,
                name: _name,
                phone: _phone,
                notes: _notes,
                countryCode: _countryCode,
                verifiedAccount: _phoneAlreadyVerified,
                onBack: () => _goTo(0),
                summary: _Summary(event: _event, offering: _offering!, slot: _slot!),
              ),
              2 => _VerifyStep(
                code: _code,
                sentTo: _codeSentTo ?? '',
                sentAt: _codeSentAt,
                testCode: _testCode,
                onBack: () => _goTo(1),
                onResend: () => _run(_sendCode),
              ),
              _ => _PayStep(token: token!, holdLeft: holdLeft ?? Duration.zero),
            },
          ),
        ),
        _BottomBar(
          summary: _slot == null || _offering == null
              ? Text(
                  _offering == null ? l.seasonChooseOffering : l.seasonChooseTime,
                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                )
              : _BarSummary(event: _event, offering: _offering!, slot: _slot!),
          action: action,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

List<String> _steps(BuildContext context) {
  final l = context.l10n;
  return [l.flowStepChoose, l.flowStepDetails, l.flowStepVerify, l.seasonStepPay];
}

class _StepTop extends StatelessWidget {
  const _StepTop({required this.current, this.onBack});
  final int current;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.sm, bottom: Space.lg),
    child: Row(
      children: [
        if (onBack != null) IconButton(tooltip: context.l10n.actionBack, onPressed: onBack, icon: const BackButtonIcon()) else const SizedBox(width: Space.sm),
        const SizedBox(width: Space.sm),
        Expanded(
          child: StepHeader(steps: _steps(context), current: current),
        ),
        const SizedBox(width: Space.lg),
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: Space.xl, bottom: Space.md),
    child: Row(
      children: [
        Expanded(
          child: Semantics(header: true, child: Text(title, style: context.text.titleLarge)),
        ),
        ?trailing,
      ],
    ),
  );
}

String _advanceText(BuildContext context, SeasonalOffering o) =>
    o.paysInFull ? context.l10n.seasonPayInFull : context.l10n.seasonPayAdvance(context.fmt.money(o.prepayBaisa));

class _BarSummary extends StatelessWidget {
  const _BarSummary({required this.event, required this.offering, required this.slot});
  final SeasonalEvent event;
  final SeasonalOffering offering;
  final TokenSlot slot;
  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final tz = event.timezone;
    return Column(
      key: ValueKey('${offering.id}${slot.start}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.confirmation_number_outlined, size: 20, color: context.colors.primary),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(fmt.weekdayDayMonth(slot.start, tz), style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text(fmt.time(slot.start, tz), style: context.text.titleSmall?.copyWith(color: context.colors.onSurfaceVariant)),
          ],
        ),
        const SizedBox(height: 2),
        Row(
          children: [
            Expanded(
              child: Text(offering.title(context.lang), style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text('${context.l10n.seasonDueNow} ${fmt.money(offering.prepayBaisa)}', style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
          ],
        ),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.summary, required this.action});
  final Widget summary;
  final Widget action;
  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    return Container(
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
        border: Border(top: BorderSide(color: context.colors.outlineVariant.withValues(alpha: 0.6))),
        boxShadow: [BoxShadow(color: context.glow.shadow, blurRadius: 24, offset: const Offset(0, -6))],
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: Space.md),
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutterOf(context), Space.lg, gutterOf(context), Space.sm),
          child: ContentWidth(
            maxWidth: 640,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSize(
                  duration: motion.medium,
                  curve: Motion.standard,
                  alignment: Alignment.topCenter,
                  child: AnimatedSwitcher(duration: motion.medium, child: summary),
                ),
                const SizedBox(height: Space.md),
                AnimatedSwitcher(duration: motion.fast, child: action),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.event, required this.offering, required this.slot});
  final SeasonalEvent event;
  final SeasonalOffering offering;
  final TokenSlot slot;
  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final l = context.l10n;
    final tz = event.timezone;
    return GlowCard(
      gradient: context.glow.heroGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(event.title(context.lang), style: context.text.labelLarge?.copyWith(color: context.colors.primary)),
          const SizedBox(height: 2),
          Text(offering.title(context.lang), style: context.text.titleMedium),
          const SizedBox(height: Space.sm),
          Text('${fmt.fullDate(slot.start, tz)} · ${fmt.time(slot.start, tz)}', style: context.text.bodyMedium),
          const Divider(height: Space.xl),
          _Line(l.bookingPrice, fmt.money(offering.priceBaisa)),
          _Line(l.seasonDueNow, fmt.money(offering.prepayBaisa), strong: true),
          if (!offering.paysInFull) _Line(l.seasonPayAtSalon, fmt.money(offering.priceBaisa - offering.prepayBaisa)),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.strong = false});
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

// ---------------------------------------------------------------------------
// Step 1 — Choose
// ---------------------------------------------------------------------------

class _ChooseStep extends StatelessWidget {
  const _ChooseStep({
    required this.event,
    required this.offering,
    required this.date,
    required this.slot,
    required this.onOffering,
    required this.onDate,
    required this.onSlot,
  });
  final SeasonalEvent event;
  final SeasonalOffering? offering;
  final String? date;
  final TokenSlot? slot;
  final ValueChanged<SeasonalOffering> onOffering;
  final ValueChanged<String> onDate;
  final ValueChanged<TokenSlot> onSlot;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = context.lang;
    final g = gutterOf(context);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(g, 0, g, Space.xl),
        children: [
          ContentWidth(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                        icon: const BackButtonIcon(),
                        onPressed: () => context.canPop() ? context.pop() : context.go('/salon/${GoRouterState.of(context).pathParameters['slug']}'),
                      ),
                    ],
                  ),
                ),
                StaggeredEntrance(
                  index: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: context.colors.primaryContainer, borderRadius: Radii.pillAll),
                        child: Text(
                          l.seasonTokensBadge.toUpperCase(),
                          style: context.text.labelSmall?.copyWith(color: context.colors.onPrimaryContainer, letterSpacing: 0.8),
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                      Text(event.title(lang), style: context.text.headlineLarge),
                      if (event.blurb(lang) != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(event.blurb(lang)!, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: Space.lg),
                StepHeader(steps: _steps(context), current: 0),
                _SectionTitle(l.seasonChooseOffering),
                for (var i = 0; i < event.offerings.length; i++)
                  StaggeredEntrance(
                    index: i + 1,
                    child: _OfferingCard(
                      offering: event.offerings[i],
                      selected: offering?.id == event.offerings[i].id,
                      onTap: () => onOffering(event.offerings[i]),
                    ),
                  ),
                _SectionTitle(
                  l.seasonChooseDay,
                  trailing: date == null
                      ? null
                      : Text(DateFormat.yMMMM(lang).format(Ymd.parse(date!)), style: context.text.titleSmall?.copyWith(color: context.colors.onSurfaceVariant)),
                ),
                SizedBox(
                  height: 80,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    itemCount: event.dates.length,
                    separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                    itemBuilder: (_, i) => _DayPill(date: event.dates[i], selected: event.dates[i] == date, onTap: () => onDate(event.dates[i])),
                  ),
                ),
                _SectionTitle(
                  l.seasonChooseTime,
                  trailing: offering == null
                      ? null
                      : Text(
                          l.seasonTokenLength(context.fmt.duration(offering!.tokenMinutes)),
                          style: context.text.titleSmall?.copyWith(color: context.colors.onSurfaceVariant),
                        ),
                ),
                if (offering == null)
                  _Hint(text: l.seasonChooseOffering, icon: Icons.touch_app_outlined)
                else if (date != null)
                  _TimeGrid(offeringId: offering!.id, date: date!, timezone: event.timezone, selected: slot, onSlot: onSlot),
                const SizedBox(height: Space.lg),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.notifications_active_outlined, size: 18, color: context.colors.onSurfaceVariant),
                    const SizedBox(width: Space.sm),
                    Expanded(child: Text(l.seasonReminderNote, style: context.text.bodySmall)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.text, required this.icon});
  final String text;
  final IconData icon;
  @override
  Widget build(BuildContext context) => GlowCard(
    elevated: false,
    color: context.colors.surfaceContainerLow,
    child: Row(
      children: [
        Icon(icon, color: context.colors.onSurfaceVariant),
        const SizedBox(width: Space.md),
        Expanded(child: Text(text, style: context.text.bodyMedium)),
      ],
    ),
  );
}

class _OfferingCard extends StatelessWidget {
  const _OfferingCard({required this.offering, required this.selected, required this.onTap});
  final SeasonalOffering offering;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final scheme = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.sm),
      child: Semantics(
        button: true,
        selected: selected,
        child: PressableScale(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: AnimatedContainer(
            duration: Motion.of(context).medium,
            curve: Motion.standard,
            padding: const EdgeInsets.all(Space.lg),
            decoration: BoxDecoration(
              color: selected ? scheme.primaryContainer.withValues(alpha: 0.55) : scheme.surface,
              borderRadius: Radii.lgAll,
              border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.8), width: selected ? 2 : 1),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(offering.title(context.lang), style: context.text.titleMedium),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: fmt.money(offering.priceBaisa),
                              style: context.text.labelLarge?.copyWith(color: scheme.primary),
                            ),
                            TextSpan(text: '  ·  ${fmt.duration(offering.tokenMinutes)}', style: context.text.bodySmall),
                          ],
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(_advanceText(context, offering), style: context.text.bodySmall),
                    ],
                  ),
                ),
                const SizedBox(width: Space.md),
                AnimatedSwitcher(
                  duration: Motion.of(context).fast,
                  child: Icon(
                    selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    key: ValueKey(selected),
                    color: selected ? scheme.primary : scheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.date, required this.selected, required this.onTap});
  final String date;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final d = Ymd.parse(date);
    final fg = selected ? scheme.onPrimary : scheme.onSurface;
    return Semantics(
      button: true,
      selected: selected,
      label: DateFormat.MMMMEEEEd(context.lang).format(d),
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.of(context).medium,
          curve: Motion.standard,
          width: 60,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.8)),
            boxShadow: selected ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6))] : null,
          ),
          child: ExcludeSemantics(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat.d(context.lang).format(d),
                  style: context.text.titleLarge?.copyWith(color: fg, fontWeight: FontWeight.w700),
                ),
                Text(DateFormat.E(context.lang).format(d).toUpperCase(), style: context.text.labelSmall?.copyWith(color: fg, letterSpacing: 0.6)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeGrid extends ConsumerWidget {
  const _TimeGrid({required this.offeringId, required this.date, required this.timezone, required this.selected, required this.onSlot});
  final String offeringId;
  final String date;
  final String timezone;
  final TokenSlot? selected;
  final ValueChanged<TokenSlot> onSlot;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final q = (offeringId: offeringId, date: date);
    final slots = ref.watch(tokenSlotsProvider(q));
    return slots.when(
      loading: () => ShimmerLoading(
        child: Wrap(
          spacing: Space.sm,
          runSpacing: Space.sm,
          children: [for (var i = 0; i < 8; i++) const SkeletonBox(width: 96, height: 56, radius: Radii.md)],
        ),
      ),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(tokenSlotsProvider(q))),
      data: (list) {
        final open = list.where((s) => !s.full).toList();
        if (open.isEmpty) return _Hint(text: l.seasonNoTimes, icon: Icons.event_busy_outlined);
        // Columns fill the row: three on a phone, more on wider screens.
        return LayoutBuilder(
          builder: (context, box) {
            final cols = ((box.maxWidth + Space.sm) / (96 + Space.sm)).floor().clamp(3, 8);
            final width = (box.maxWidth - (cols - 1) * Space.sm) / cols;
            return Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (var i = 0; i < list.length; i++)
                  _TimeChip(
                    key: ValueKey(list[i].start.toIso8601String()),
                    slot: list[i],
                    timezone: timezone,
                    width: width,
                    selected: selected?.start == list[i].start,
                    onTap: list[i].full ? null : () => onSlot(list[i]),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({super.key, required this.slot, required this.timezone, required this.width, required this.selected, required this.onTap});
  final TokenSlot slot;
  final double width;
  final String timezone;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final l = context.l10n;
    final full = onTap == null;
    final fg = selected ? scheme.onPrimary : (full ? scheme.onSurfaceVariant.withValues(alpha: 0.5) : scheme.onSurface);
    final time = context.fmt.time(slot.start, timezone);
    final sub = full ? l.seasonFull : l.seasonSeatsLeft(slot.left);
    return Semantics(
      button: true,
      selected: selected,
      enabled: !full,
      label: '$time, $sub',
      child: PressableScale(
        onTap: full
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap!();
              },
        child: AnimatedContainer(
          duration: Motion.of(context).fast,
          width: width,
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : (full ? scheme.surfaceContainerLow : scheme.surface),
            borderRadius: Radii.mdAll,
            border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant.withValues(alpha: full ? 0.4 : 0.8)),
          ),
          child: ExcludeSemantics(
            child: Column(
              children: [
                Text(
                  time,
                  style: context.text.labelLarge?.copyWith(color: fg, decoration: full ? TextDecoration.lineThrough : null),
                ),
                Text(sub, style: context.text.labelSmall?.copyWith(color: selected ? scheme.onPrimary.withValues(alpha: 0.85) : (full ? fg : scheme.tertiary))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 — Details
// ---------------------------------------------------------------------------

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.form,
    required this.name,
    required this.phone,
    required this.notes,
    required this.countryCode,
    required this.verifiedAccount,
    required this.onBack,
    required this.summary,
  });
  final GlobalKey<FormState> form;
  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController notes;
  final String countryCode;
  final bool verifiedAccount;
  final VoidCallback onBack;
  final Widget summary;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = V(context);
    return SafeArea(
      bottom: false,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(gutterOf(context), 0, gutterOf(context), Space.xl),
        children: [
          ContentWidth(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepTop(current: 1, onBack: onBack),
                Text(l.flowDetails, style: context.text.headlineMedium),
                const SizedBox(height: 4),
                Text(l.seasonPhoneHelp, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                const SizedBox(height: Space.xl),
                AutofillGroup(
                  child: Form(
                    key: form,
                    child: Column(
                      children: [
                        GlowField(
                          controller: name,
                          label: l.authFullName,
                          autofill: const [AutofillHints.name],
                          validator: v.required,
                          prefixIcon: Icons.person_outline_rounded,
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.lg),
                          child: TextFormField(
                            controller: phone,
                            keyboardType: TextInputType.phone,
                            autofillHints: const [AutofillHints.telephoneNumber],
                            textDirection: TextDirection.ltr,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]'))],
                            validator: (raw) => v.phone(composePhone(raw ?? '')),
                            decoration: InputDecoration(
                              labelText: l.authPhone,
                              prefixIcon: Padding(
                                padding: const EdgeInsetsDirectional.only(start: Space.md, end: Space.sm),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.phone_iphone_rounded, size: 20),
                                    const SizedBox(width: Space.sm),
                                    Text(
                                      countryCode,
                                      textDirection: TextDirection.ltr,
                                      style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
                                    ),
                                  ],
                                ),
                              ),
                              helperText: verifiedAccount ? l.flowVerifiedAccount : null,
                              helperMaxLines: 2,
                            ),
                          ),
                        ),
                        GlowField(controller: notes, label: '${l.flowNotes} (${l.labelOptional})', maxLines: 2),
                      ],
                    ),
                  ),
                ),
                summary,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 3 — Verify
// ---------------------------------------------------------------------------

class _VerifyStep extends StatelessWidget {
  const _VerifyStep({required this.code, required this.sentTo, required this.sentAt, required this.testCode, required this.onBack, required this.onResend});
  final TextEditingController code;
  final String sentTo;
  final DateTime? sentAt;
  final String? testCode;
  final VoidCallback onBack;
  final Future<void> Function() onResend;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final wait = 30 - DateTime.now().difference(sentAt ?? DateTime.now()).inSeconds;
    return SafeArea(
      bottom: false,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.fromLTRB(gutterOf(context), 0, gutterOf(context), Space.xl),
        children: [
          ContentWidth(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepTop(current: 2, onBack: onBack),
                Text(l.flowVerifyTitle, style: context.text.headlineMedium),
                const SizedBox(height: 4),
                Text(l.flowVerifyBody(sentTo), style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                const SizedBox(height: Space.xl),
                OtpCodeInput(controller: code),
                if (testCode != null) ...[
                  const SizedBox(height: Space.lg),
                  PressableScale(
                    onTap: () => code.text = testCode!,
                    child: GlowCard(
                      elevated: false,
                      color: context.colors.tertiaryContainer,
                      child: Row(
                        children: [
                          Icon(Icons.science_outlined, color: context.colors.onTertiaryContainer),
                          const SizedBox(width: Space.md),
                          Expanded(
                            child: Text(l.flowTestCode(testCode!), style: context.text.bodyMedium?.copyWith(color: context.colors.onTertiaryContainer)),
                          ),
                          Icon(Icons.input_rounded, color: context.colors.onTertiaryContainer),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: Space.lg),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    wait > 0
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Text(l.flowResendIn(wait), style: context.text.bodySmall),
                          )
                        : TextButton(onPressed: () => onResend().catchError((_) {}), child: Text(l.flowResend)),
                    TextButton(onPressed: onBack, child: Text(l.flowChangeNumber)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 4 — Pay
// ---------------------------------------------------------------------------

class _PayStep extends StatelessWidget {
  const _PayStep({required this.token, required this.holdLeft});
  final SeasonalToken token;
  final Duration holdLeft;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final expired = holdLeft.isNegative;
    final mm = holdLeft.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = holdLeft.inSeconds.remainder(60).toString().padLeft(2, '0');
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(gutterOf(context), 0, gutterOf(context), Space.xl),
        children: [
          ContentWidth(
            maxWidth: 640,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _StepTop(current: 3),
                Text(expired ? l.seasonHoldExpired : l.seasonPayTitle, style: context.text.headlineMedium),
                const SizedBox(height: 4),
                Text(expired ? l.seasonHoldExpiredBody : l.seasonPayBody, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                const SizedBox(height: Space.lg),
                if (!expired)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: 6),
                      decoration: BoxDecoration(color: context.glow.pending.bg, borderRadius: Radii.pillAll),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.timer_outlined, size: 18, color: context.glow.pending.fg),
                          const SizedBox(width: 6),
                          Text(
                            l.seasonHeldFor('$mm:$ss'),
                            style: context.text.labelLarge?.copyWith(color: context.glow.pending.fg, fontFeatures: const [FontFeature.tabularFigures()]),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: Space.lg),
                TokenTicket(token: token),
                const SizedBox(height: Space.lg),
                GlowCard(
                  child: Column(
                    children: [
                      _Line(l.bookingPrice, fmt.money(token.priceBaisa)),
                      _Line(l.seasonDueNow, fmt.money(token.prepayBaisa), strong: true),
                      if (token.prepayBaisa < token.priceBaisa) _Line(l.seasonPayAtSalon, fmt.money(token.priceBaisa - token.prepayBaisa)),
                    ],
                  ),
                ),
                const SizedBox(height: Space.md),
                Text(l.payTestMode, style: context.text.bodySmall, textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Done
// ---------------------------------------------------------------------------

class _Confirmed extends ConsumerWidget {
  const _Confirmed({required this.token, required this.access, required this.slug});
  final SeasonalToken token;
  final String access;
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final signedIn = ref.watch(authControllerProvider).valueOrNull != null;
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(gutterOf(context)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AnimatedSuccess(),
                StaggeredEntrance(
                  index: 3,
                  child: Text(l.seasonTokenConfirmed, style: context.text.headlineMedium, textAlign: TextAlign.center),
                ),
                const SizedBox(height: Space.sm),
                StaggeredEntrance(
                  index: 4,
                  child: Text(l.seasonTokenConfirmedBody, style: context.text.bodyLarge, textAlign: TextAlign.center),
                ),
                const SizedBox(height: Space.xl),
                StaggeredEntrance(index: 6, child: TokenTicket(token: token)),
                const SizedBox(height: Space.xl),
                FilledButton(onPressed: () => context.go(signedIn ? '/appointments' : '/salon/$slug'), child: Text(l.flowDone)),
                const SizedBox(height: Space.sm),
                OutlinedButton(onPressed: () => context.go('/token/${token.id}?token=$access'), child: Text(l.seasonViewToken)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
