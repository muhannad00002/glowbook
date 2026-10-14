import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/animations/animated_success.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/fit_layout.dart';
import '../../../shared/widgets/step_flow.dart';
import '../../customer_booking/data/customer_booking_repository.dart';
import '../../customer_booking/presentation/booking_flow_screen.dart' show DateGrid, GridSkeleton, TimeGrid;
import '../../customer_booking/presentation/customer_widgets.dart';
import '../data/seasonal_repository.dart';
import 'token_widgets.dart';

abstract final class _Step {
  static const service = 0;
  static const day = 1;
  static const time = 2;
  static const details = 3;
  static const verify = 4;
  static const pay = 5;
  static const count = 6;
}

/// Taking a seasonal token, one decision per screen:
///   Service → Day → Time → Name & phone → Code → Pay → token.
/// The token is held while she pays; paying confirms it.
class TokenFlowScreen extends ConsumerWidget {
  const TokenFlowScreen({super.key, required this.slug, required this.eventId});
  final String slug;
  final String eventId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final events = ref.watch(salonSeasonalEventsProvider(slug));
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: events.when(
        loading: () => const Center(child: LoadingPad()),
        error: (e, _) => linkErrorView(context, e, onRetry: () => ref.invalidate(salonSeasonalEventsProvider(slug))),
        data: (list) {
          final event = list.where((e) => e.id == eventId).firstOrNull;
          if (event == null || event.dates.isEmpty) {
            return FitMessage(
              icon: Icons.event_busy_outlined,
              title: l.seasonEventOver,
              action: FilledButton(onPressed: () => context.go('/'), child: Text(l.flowDone)),
            );
          }
          return _Flow(event: event);
        },
      ),
    );
  }
}

class _Flow extends ConsumerStatefulWidget {
  const _Flow({required this.event});
  final SeasonalEvent event;
  @override
  ConsumerState<_Flow> createState() => _FlowState();
}

class _FlowState extends ConsumerState<_Flow> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
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
    _code.addListener(() => setState(() {}));
    if (_event.offerings.length == 1) _offering = _event.offerings.first;
    // Drives the resend countdown and the payment-hold timer.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _step >= _Step.verify) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in [_name, _phone, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  void _goTo(int step) => setState(() {
    _forward = step > _step;
    _step = step;
  });

  void _back() {
    if (_step == _Step.service) {
      context.go('/');
    } else if (_step == _Step.pay) {
      // The hold stays until it lapses; going back just lets her look again.
      _goTo(_Step.time);
    } else {
      _goTo(_step - 1);
    }
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
        _goTo(_Step.time);
      } else if (needsVerification) {
        showGlowSnack(context, e.message, error: true);
        _goTo(_Step.details);
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
    final phone = composePhone(_phone.text);
    final testCode = await ref.read(customerBookingRepositoryProvider).requestCode(phone, context.lang);
    setState(() {
      _codeSentTo = phone;
      _codeSentAt = DateTime.now();
      _testCode = testCode;
    });
    _goTo(_Step.verify);
  }

  Future<void> _verifyAndTake() async {
    final phoneToken = await ref.read(customerBookingRepositoryProvider).verifyCode(composePhone(_phone.text), _code.text);
    final r = await _repo.take(
      offeringId: _offering!.id,
      start: _slot!.start,
      name: _name.text.trim(),
      phone: composePhone(_phone.text),
      phoneToken: phoneToken,
    );
    setState(() {
      _token = r.token;
      _access = r.access;
    });
    _goTo(_Step.pay);
  }

  Future<void> _pay() async {
    final paid = await _repo.pay(_token!.id, access: _access);
    ref.invalidate(tokenSlotsProvider);
    setState(() => _token = paid);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final token = _token;
    if (token != null && token.status == 'CONFIRMED') return _Confirmed(token: token, access: _access!);

    final summary = _offering == null ? null : _Summary(event: _event, offering: _offering!, date: _date, slot: _slot);
    final holdLeft = token?.holdExpiresAt?.difference(DateTime.now());
    final expired = holdLeft != null && holdLeft.isNegative;

    final page = switch (_step) {
      _Step.service => FitStepPage(
        step: _step,
        total: _Step.count,
        onBack: _back,
        title: _event.title(context.lang),
        subtitle: l.seasonChooseOffering,
        body: PagedGrid<SeasonalOffering>(
          items: _event.offerings,
          itemHeight: 76,
          minItemWidth: 260,
          itemBuilder: (context, o) => ChoiceTile(
            selected: _offering?.id == o.id,
            onTap: () => setState(() {
              _offering = o;
              _slot = null;
            }),
            child: TileText(o.title(context.lang), subtitle: '${fmt.money(o.priceBaisa)} · ${fmt.duration(o.tokenMinutes)}\n${_advanceText(context, o)}'),
          ),
        ),
        summary: summary,
        action: AnimatedButton(
          key: const ValueKey('service'),
          label: l.actionContinue,
          enabled: _offering != null,
          onPressed: _offering == null ? null : () async => _goTo(_Step.day),
        ),
      ),
      _Step.day => FitStepPage(
        step: _step,
        total: _Step.count,
        onBack: _back,
        title: l.seasonChooseDay,
        subtitle: l.seasonReminderNote,
        body: DateGrid(
          dates: _event.dates,
          isEnabled: (_) => true,
          selected: _date,
          onPick: (d) {
            setState(() {
              _date = d;
              _slot = null;
            });
            _goTo(_Step.time);
          },
        ),
        summary: summary,
      ),
      _Step.time => FitStepPage(
        step: _step,
        total: _Step.count,
        onBack: _back,
        title: l.seasonChooseTime,
        subtitle: '${fmt.ymdLabel(_date!, pattern: 'yMMMMEEEEd')} · ${l.seasonTokenLength(fmt.duration(_offering!.tokenMinutes))}',
        body: _TimeStep(
          offeringId: _offering!.id,
          date: _date!,
          timezone: _event.timezone,
          selected: _slot,
          onSlot: (s) => setState(() => _slot = s),
          onOtherDay: () => _goTo(_Step.day),
        ),
        summary: summary,
        action: AnimatedButton(
          key: const ValueKey('time'),
          label: l.actionContinue,
          enabled: _slot != null,
          onPressed: _slot == null ? null : () async => _goTo(_Step.details),
        ),
      ),
      _Step.details => FitStepPage(
        step: _step,
        total: _Step.count,
        onBack: _back,
        title: l.flowDetails,
        subtitle: l.seasonPhoneHelp,
        body: FitBox(
          child: DetailsForm(form: _form, name: _name, phone: _phone),
        ),
        summary: summary,
        action: AnimatedButton(
          key: const ValueKey('send'),
          label: l.flowSendCode,
          icon: Icons.sms_outlined,
          keepSuccess: true,
          onPressed: () async {
            if (!_form.currentState!.validate()) throw StateError('invalid');
            FocusScope.of(context).unfocus();
            _code.clear();
            await _run(_sendCode);
          },
        ),
      ),
      _Step.verify => FitStepPage(
        step: _step,
        total: _Step.count,
        onBack: _back,
        title: l.flowVerifyTitle,
        subtitle: l.flowVerifyBody(_codeSentTo ?? ''),
        body: VerifyBody(code: _code, sentAt: _codeSentAt, testCode: _testCode, onResend: () => _run(_sendCode), onChangeNumber: () => _goTo(_Step.details)),
        summary: summary,
        action: AnimatedButton(
          key: const ValueKey('verify'),
          label: l.actionContinue,
          keepSuccess: true,
          enabled: _code.text.length == 6,
          onPressed: _code.text.length == 6 ? () => _run(_verifyAndTake) : null,
        ),
      ),
      _ => FitStepPage(
        step: _step,
        total: _Step.count,
        onBack: _back,
        title: expired ? l.seasonHoldExpired : l.seasonPayTitle,
        subtitle: expired ? l.seasonHoldExpiredBody : l.seasonPayBody,
        body: _PayBody(token: token!, holdLeft: holdLeft ?? Duration.zero),
        action: expired
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
                  _goTo(_Step.time);
                },
              )
            : AnimatedButton(
                key: const ValueKey('pay'),
                label: l.payNow(fmt.money(token.dueBaisa)),
                icon: Icons.credit_card_rounded,
                keepSuccess: true,
                onPressed: () => _run(_pay),
              ),
      ),
    };
    return StepSwitcher(
      step: _step,
      forward: _forward,
      child: KeyedSubtree(key: ValueKey(_step), child: page),
    );
  }
}

String _advanceText(BuildContext context, SeasonalOffering o) =>
    o.paysInFull ? context.l10n.seasonPayInFull : context.l10n.seasonPayAdvance(context.fmt.money(o.prepayBaisa));

class _Summary extends StatelessWidget {
  const _Summary({required this.event, required this.offering, required this.date, required this.slot});
  final SeasonalEvent event;
  final SeasonalOffering offering;
  final String? date;
  final TokenSlot? slot;
  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final tz = event.timezone;
    final when = slot != null
        ? '${fmt.weekdayDayMonth(slot!.start, tz)} · ${fmt.time(slot!.start, tz)}'
        : (date != null ? fmt.ymdLabel(date!) : offering.title(context.lang));
    return Column(
      key: ValueKey('${offering.id}|$date|${slot?.start}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.confirmation_number_outlined, size: 18, color: context.colors.primary),
            const SizedBox(width: Space.sm),
            Expanded(
              child: Text(when, style: context.text.titleSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            Text('${context.l10n.seasonDueNow} ${fmt.money(offering.prepayBaisa)}', style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
          ],
        ),
        if (slot != null || date != null) Text(offering.title(context.lang), style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _TimeStep extends ConsumerWidget {
  const _TimeStep({
    required this.offeringId,
    required this.date,
    required this.timezone,
    required this.selected,
    required this.onSlot,
    required this.onOtherDay,
  });
  final String offeringId;
  final String date;
  final String timezone;
  final TokenSlot? selected;
  final ValueChanged<TokenSlot> onSlot;
  final VoidCallback onOtherDay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final q = (offeringId: offeringId, date: date);
    final slots = ref.watch(tokenSlotsProvider(q));
    return slots.when(
      loading: () => const GridSkeleton(columns: 3, height: 56),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(tokenSlotsProvider(q))),
      data: (list) {
        if (!list.any((s) => !s.full)) {
          return StepHint(
            icon: Icons.event_busy_outlined,
            text: l.seasonNoTimes,
            action: OutlinedButton(onPressed: onOtherDay, child: Text(l.flowPickAnotherDay)),
          );
        }
        final first = list.indexWhere((s) => selected?.start == s.start);
        return TimeGrid(
          count: list.length,
          itemHeight: 56,
          initialIndex: first < 0 ? list.indexWhere((s) => !s.full) : first,
          cell: (i) => TimeCell(
            label: context.fmt.time(list[i].start, timezone),
            sub: list[i].full ? l.seasonFull : l.seasonSeatsLeft(list[i].left),
            selected: selected?.start == list[i].start,
            enabled: !list[i].full,
            onTap: () => onSlot(list[i]),
          ),
        );
      },
    );
  }
}

class _PayBody extends StatelessWidget {
  const _PayBody({required this.token, required this.holdLeft});
  final SeasonalToken token;
  final Duration holdLeft;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final expired = holdLeft.isNegative;
    final mm = holdLeft.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = holdLeft.inSeconds.remainder(60).toString().padLeft(2, '0');
    return FitBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
          const SizedBox(height: Space.md),
          TokenTicket(token: token),
          const SizedBox(height: Space.md),
          Row(
            children: [
              Expanded(
                child: Text('${l.seasonDueNow} ${fmt.money(token.prepayBaisa)}', style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
              ),
              if (token.prepayBaisa < token.priceBaisa)
                Text(l.seasonBalanceDue(fmt.money(token.priceBaisa - token.prepayBaisa)), style: context.text.bodySmall),
            ],
          ),
          const SizedBox(height: Space.xs),
          Text(l.payTestMode, style: context.text.bodySmall),
        ],
      ),
    );
  }
}

class _Confirmed extends StatelessWidget {
  const _Confirmed({required this.token, required this.access});
  final SeasonalToken token;
  final String access;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
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
                        const AnimatedSuccess(size: 96),
                        Text(l.seasonTokenConfirmed, style: context.text.headlineMedium, textAlign: TextAlign.center),
                        const SizedBox(height: Space.xs),
                        Text(l.seasonTokenConfirmedBody, style: context.text.bodyMedium, textAlign: TextAlign.center),
                        const SizedBox(height: Space.lg),
                        TokenTicket(token: token),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Space.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(onPressed: () => context.go('/token/${token.id}?token=$access'), child: Text(l.seasonViewToken)),
                ),
                const SizedBox(height: Space.sm),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(onPressed: () => context.go('/'), child: Text(l.flowDone)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
