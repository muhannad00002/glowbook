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
import '../../../shared/animations/animated_calendar_transition.dart';
import '../../../shared/animations/animated_success.dart';
import '../../../shared/animations/shimmer_loading.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/salon_cover.dart';
import '../../../shared/widgets/step_flow.dart';
import '../../auth/presentation/auth_layout.dart';
import '../../salon/data/salon_repository.dart';
import 'booking_draft.dart';

/// Customer booking in three steps:
///   1. Choose — services, artist, date & time (one screen)
///   2. Details — name & phone
///   3. Verify — one-time code, then the booking is made
class BookingFlowScreen extends ConsumerWidget {
  const BookingFlowScreen({super.key, required this.slug, this.serviceId});
  final String slug;
  final String? serviceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(salonProfileProvider(slug));
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AsyncView(
        value: profile,
        onRetry: () => ref.invalidate(salonProfileProvider(slug)),
        data: (p) => _Flow(profile: p, initialServiceId: serviceId),
      ),
    );
  }
}

/// Default country for numbers typed without a "+" prefix.
const _countryCode = '+968';

String composePhone(String raw) {
  final v = raw.replaceAll(RegExp(r'[\s\-()]'), '');
  if (v.startsWith('+')) return v;
  if (v.startsWith('00')) return '+${v.substring(2)}';
  return '$_countryCode$v';
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
  final _notes = TextEditingController();
  final _code = TextEditingController();
  Timer? _ticker;

  String get _slug => widget.profile.card.slug;
  BookingDraftController get _c => ref.read(bookingDraftProvider(_slug).notifier);

  @override
  void initState() {
    super.initState();
    final user = ref.read(authControllerProvider).valueOrNull?.me.user;
    _name = TextEditingController(text: user?.name ?? '');
    final phone = user?.phone ?? '';
    _phone = TextEditingController(text: phone.startsWith(_countryCode) ? phone.substring(_countryCode.length) : phone);
    _code.addListener(() => setState(() {}));
    // Keeps the "Resend in Ns" countdown moving.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && ref.read(bookingDraftProvider(_slug)).step == 2) setState(() {});
    });
    final preset = widget.profile.services.where((s) => s.id == widget.initialServiceId).firstOrNull;
    if (preset != null) WidgetsBinding.instance.addPostFrameCallback((_) => _c.toggleService(preset, widget.profile));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final c in [_name, _phone, _notes, _code]) {
      c.dispose();
    }
    super.dispose();
  }

  /// The signed-in account already proved this phone → skip the code.
  bool get _phoneAlreadyVerified {
    final user = ref.read(authControllerProvider).valueOrNull?.me.user;
    return user != null && user.phoneVerified && user.phone == composePhone(_phone.text);
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
        _c.goTo(1);
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
    _c.details(name: _name.text, phone: composePhone(_phone.text), notes: _notes.text);
    final locale = context.lang;
    if (_phoneAlreadyVerified) {
      await _run(_c.bookVerified);
    } else {
      _code.clear();
      await _run(() => _c.sendCode(locale));
    }
  }

  Future<void> _resend() async {
    final locale = context.lang;
    final l = context.l10n;
    await _run(() => _c.sendCode(locale));
    _code.clear();
    if (mounted) showGlowSnack(context, l.flowCodeResent);
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(bookingDraftProvider(_slug));
    final p = widget.profile;
    if (d.result != null) return _Result(profile: p, draft: d, onPay: () => _run(_c.payDeposits));

    final l = context.l10n;
    final Widget action = switch (d.step) {
      0 => AnimatedButton(
          key: const ValueKey('continue'),
          label: l.actionContinue,
          enabled: d.slot != null,
          onPressed: d.slot == null ? null : () async => _c.goTo(1),
        ),
      1 => AnimatedButton(
          key: const ValueKey('send'),
          label: _phoneAlreadyVerified ? l.flowBook : l.flowSendCode,
          icon: _phoneAlreadyVerified ? Icons.auto_awesome_rounded : Icons.sms_outlined,
          keepSuccess: true,
          onPressed: _submitDetails,
        ),
      _ => AnimatedButton(
          key: const ValueKey('confirm'),
          label: l.flowBook,
          icon: Icons.auto_awesome_rounded,
          keepSuccess: true,
          enabled: _code.text.length == 6,
          onPressed: _code.text.length == 6 ? () => _run(() => _c.verifyAndBook(_code.text)) : null,
        ),
    };

    return Column(
      children: [
        Expanded(
          child: StepSwitcher(
            step: d.step,
            forward: d.forward,
            child: switch (d.step) {
              0 => _ChooseStep(profile: p, draft: d, controller: _c),
              1 => _DetailsStep(
                  profile: p,
                  draft: d,
                  form: _form,
                  name: _name,
                  phone: _phone,
                  notes: _notes,
                  onBack: () => _c.goTo(0),
                  verifiedAccount: _phoneAlreadyVerified,
                ),
              _ => _VerifyStep(
                  draft: d,
                  code: _code,
                  onBack: () => _c.goTo(1),
                  onResend: _resend,
                ),
            },
          ),
        ),
        _BottomPanel(profile: p, draft: d, action: action),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared bits
// ---------------------------------------------------------------------------

List<Service> _chosen(SalonProfile p, BookingDraft d) =>
    [for (final id in d.serviceIds) ...p.services.where((s) => s.id == id)];

int _totalMinutes(SalonProfile p, BookingDraft d) => _chosen(p, d).fold(0, (sum, s) => sum + s.durationMinutes);
int _totalPrice(SalonProfile p, BookingDraft d) => _chosen(p, d).fold(0, (sum, s) => sum + s.priceBaisa);

String _artistName(BuildContext context, SalonProfile p, BookingDraft d) {
  final id = d.staffId ?? (d.slot != null && d.slot!.staffIds.length == 1 ? d.slot!.staffIds.first : null);
  return p.staff.where((m) => m.id == id).firstOrNull?.displayName(context.lang) ?? context.l10n.anyArtist;
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: Space.xl, bottom: Space.md),
        child: Row(children: [
          Expanded(child: Semantics(header: true, child: Text(title, style: context.text.titleLarge))),
          ?trailing,
        ]),
      );
}

/// Sticky summary + primary action. Lives in the body column, so it rides above the
/// keyboard and keeps clear of the iPhone home indicator.
class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.profile, required this.draft, required this.action});
  final SalonProfile profile;
  final BookingDraft draft;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final tz = profile.timezone;
    final motion = Motion.of(context);
    final slot = draft.slot;
    final count = draft.serviceIds.length;

    final Widget summary = slot == null
        ? Text(
            count == 0 ? l.flowPickServiceFirst : l.flowChooseTime,
            key: ValueKey('hint-$count'),
            style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
          )
        : Column(
            key: ValueKey(slot.start.toIso8601String() + draft.servicesKey),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Icon(Icons.event_rounded, size: 20, color: context.colors.primary),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(fmt.weekdayDayMonth(slot.start, tz), style: context.text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
                Text(
                  '${fmt.time(slot.start, tz)} – ${fmt.time(slot.start.add(Duration(minutes: _totalMinutes(profile, draft))), tz)}',
                  style: context.text.titleSmall?.copyWith(color: context.colors.onSurfaceVariant),
                ),
              ]),
              const SizedBox(height: 2),
              Row(children: [
                Expanded(
                  child: Text(
                    '${l.flowServicesCount(count)} · ${_artistName(context, profile, draft)}',
                    style: context.text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(fmt.money(_totalPrice(profile, draft)), style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
              ]),
            ],
          );

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

// ---------------------------------------------------------------------------
// Step 1 — Choose: services, artist, date & time
// ---------------------------------------------------------------------------

class _ChooseStep extends ConsumerWidget {
  const _ChooseStep({required this.profile, required this.draft, required this.controller});
  final SalonProfile profile;
  final BookingDraft draft;
  final BookingDraftController controller;

  String _categoryLabel(BuildContext context) => switch (profile.card.category) {
        'HAIR' => context.l10n.catHair,
        'BEAUTY' => context.l10n.catBeauty,
        'ARTIST' => context.l10n.catArtist,
        'STUDIO' => context.l10n.catStudio,
        _ => context.l10n.catMakeup,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final g = gutterOf(context);
    final eligible = eligibleStaff(profile, draft.serviceIds);
    final hasServices = draft.serviceIds.isNotEmpty;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          stretch: true,
          automaticallyImplyLeading: false,
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          leading: Padding(
            padding: const EdgeInsets.all(6),
            child: CircleAvatar(
              backgroundColor: context.colors.surface.withValues(alpha: 0.88),
              child: IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                icon: const BackButtonIcon(),
                onPressed: () => context.canPop() ? context.pop() : context.go('/salon/${profile.card.slug}'),
              ),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            stretchModes: const [StretchMode.zoomBackground],
            background: Hero(
              tag: 'salon-cover-${profile.card.slug}',
              child: SalonCover(name: profile.card.name, imageUrl: profile.card.coverUrl, height: 260, monogramSize: 88),
            ),
          ),
          // Rounded sheet edge overlapping the cover.
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(Radii.xl),
            child: Container(
              height: Radii.xl,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(Radii.xl)),
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(g, 0, g, Space.xl),
          sliver: SliverToBoxAdapter(
            child: ContentWidth(
              maxWidth: 640,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StaggeredEntrance(
                    index: 0,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: context.colors.primaryContainer, borderRadius: Radii.pillAll),
                        child: Text(
                          _categoryLabel(context).toUpperCase(),
                          style: context.text.labelSmall?.copyWith(color: context.colors.onPrimaryContainer, letterSpacing: 0.8),
                        ),
                      ),
                      const SizedBox(height: Space.sm),
                      Text(profile.card.title(context.lang), style: context.text.headlineLarge),
                      if (profile.card.ratingCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(children: [
                            Icon(Icons.star_rounded, size: 18, color: context.colors.secondary),
                            const SizedBox(width: 4),
                            Text('${profile.card.ratingAvg.toStringAsFixed(1)} · ${l.reviewsCount(profile.card.ratingCount)}', style: context.text.labelMedium),
                          ]),
                        ),
                    ]),
                  ),
                  const SizedBox(height: Space.lg),
                  StepHeader(steps: [l.flowStepChoose, l.flowStepDetails, l.flowStepVerify], current: 0),

                  // Services ------------------------------------------------
                  _SectionTitle(l.flowServicesTitle),
                  StaggeredEntrance(index: 1, child: _ServicesCard(profile: profile, draft: draft, controller: controller)),

                  // Artist --------------------------------------------------
                  _SectionTitle(l.flowArtistTitle),
                  AnimatedSwitcher(
                    duration: Motion.of(context).medium,
                    child: !hasServices
                        ? _Hint(key: const ValueKey('pick'), text: l.flowPickServiceFirst, icon: Icons.touch_app_outlined)
                        : eligible.isEmpty
                            ? _Hint(key: const ValueKey('none'), text: l.flowNoCommonArtist, icon: Icons.info_outline_rounded, warn: true)
                            : _ArtistRow(key: const ValueKey('artists'), staff: eligible, selected: draft.staffId, onPick: controller.pickStaff),
                  ),

                  // Date & time ---------------------------------------------
                  if (hasServices && eligible.isNotEmpty) _DateAndTime(profile: profile, draft: draft, controller: controller),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({super.key, required this.text, required this.icon, this.warn = false});
  final String text;
  final IconData icon;
  final bool warn;
  @override
  Widget build(BuildContext context) => GlowCard(
        elevated: false,
        color: warn ? context.glow.pending.bg : context.colors.surfaceContainerLow,
        child: Row(children: [
          Icon(icon, color: warn ? context.glow.pending.fg : context.colors.onSurfaceVariant),
          const SizedBox(width: Space.md),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ]),
      );
}

class _ServicesCard extends StatelessWidget {
  const _ServicesCard({required this.profile, required this.draft, required this.controller});
  final SalonProfile profile;
  final BookingDraft draft;
  final BookingDraftController controller;

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final l = context.l10n;
    final services = profile.services;
    return GlowCard(
      padding: const EdgeInsets.symmetric(vertical: Space.xs),
      child: Column(
        children: [
          for (var i = 0; i < services.length; i++) ...[
            if (i > 0) Divider(indent: Space.lg, endIndent: Space.lg, color: context.colors.outlineVariant.withValues(alpha: 0.6)),
            Builder(builder: (context) {
              final s = services[i];
              final on = draft.serviceIds.contains(s.id);
              return MergeSemantics(
                child: InkWell(
                  borderRadius: Radii.lgAll,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    controller.toggleService(s, profile);
                  },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 68),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s.title(context.lang), style: context.text.titleMedium),
                              const SizedBox(height: 2),
                              Text.rich(
                                TextSpan(children: [
                                  TextSpan(text: fmt.money(s.priceBaisa), style: context.text.labelLarge?.copyWith(color: context.colors.primary)),
                                  TextSpan(text: '  ·  ${fmt.duration(s.durationMinutes)}', style: context.text.bodySmall),
                                  if (s.needsDeposit) TextSpan(text: '  ·  ${l.bookingDeposit} ${fmt.money(s.depositBaisa)}', style: context.text.bodySmall),
                                ]),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: Space.md),
                        // Native iOS switch on iPhone, Material elsewhere.
                        Switch.adaptive(
                          value: on,
                          activeTrackColor: context.colors.primary,
                          onChanged: (_) {
                            HapticFeedback.selectionClick();
                            controller.toggleService(s, profile);
                          },
                        ),
                      ]),
                    ),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _ArtistRow extends StatelessWidget {
  const _ArtistRow({super.key, required this.staff, required this.selected, required this.onPick});
  final List<StaffMember> staff;
  final String? selected;
  final ValueChanged<String?> onPick;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return SizedBox(
      height: 108,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          _ArtistChip(
            label: l.anyArtistShort,
            selected: selected == null,
            onTap: () => onPick(null),
            avatar: CircleAvatar(radius: 28, backgroundColor: context.colors.primaryContainer, child: Icon(Icons.auto_awesome_rounded, color: context.colors.primary)),
          ),
          for (var i = 0; i < staff.length; i++)
            StaggeredEntrance(
              key: ValueKey(staff[i].id),
              index: i + 1,
              axis: Axis.horizontal,
              offset: 12,
              child: _ArtistChip(
                label: staff[i].displayName(context.lang),
                selected: selected == staff[i].id,
                onTap: () => onPick(staff[i].id),
                avatar: InitialsAvatar(name: staff[i].name, color: hexColor(staff[i].color), size: 56, photoUrl: staff[i].photoUrl),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArtistChip extends StatelessWidget {
  const _ArtistChip({required this.label, required this.selected, required this.onTap, required this.avatar});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget avatar;

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: PressableScale(
        onTap: onTap,
        child: SizedBox(
          width: 80,
          child: Column(
            children: [
              AnimatedContainer(
                duration: motion.medium,
                curve: Motion.standard,
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: selected ? context.colors.primary : Colors.transparent, width: 2.5),
                ),
                child: ExcludeSemantics(child: avatar),
              ),
              const SizedBox(height: 6),
              ExcludeSemantics(
                child: AnimatedDefaultTextStyle(
                  duration: motion.fast,
                  style: context.text.labelMedium!.copyWith(
                    color: selected ? context.colors.primary : context.colors.onSurface,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  ),
                  child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DateAndTime extends ConsumerWidget {
  const _DateAndTime({required this.profile, required this.draft, required this.controller});
  final SalonProfile profile;
  final BookingDraft draft;
  final BookingDraftController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final fmt = context.fmt;
    final tz = profile.timezone;
    final today = Ymd.today(tz);
    final daysQ = (salon: profile.card.slug, services: draft.servicesKey, staffId: draft.staffId, from: today);
    final days = ref.watch(visitDaysProvider(daysQ));

    // First visit (or services changed): land on the first day that has room.
    final list = days.valueOrNull;
    if (list != null && draft.date == null) {
      final first = list.where((d) => d.slotCount > 0).firstOrNull;
      if (first != null) WidgetsBinding.instance.addPostFrameCallback((_) => controller.pickDate(first.date));
    }
    final selectedDate = draft.date ?? list?.where((d) => d.slotCount > 0).firstOrNull?.date ?? today;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          l.flowDateTitle,
          trailing: Text(DateFormat.yMMMM(context.lang).format(Ymd.parse(selectedDate)), style: context.text.titleSmall?.copyWith(color: context.colors.onSurfaceVariant)),
        ),
        SizedBox(
          height: 80,
          child: days.when(
            loading: () => ShimmerLoading(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
                itemBuilder: (_, _) => const SkeletonBox(width: 60, height: 78, radius: 18),
              ),
            ),
            error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(visitDaysProvider(daysQ))),
            data: (list) => ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
              itemBuilder: (_, i) => _DayPill(
                day: list[i],
                selected: list[i].date == selectedDate,
                onTap: () => controller.pickDate(list[i].date),
              ),
            ),
          ),
        ),
        _SectionTitle(l.flowTimeTitle),
        AnimatedCalendarTransition(
          dateKey: '$selectedDate|${draft.servicesKey}|${draft.staffId}',
          forward: draft.forward,
          child: _TimeRow(profile: profile, draft: draft, date: selectedDate, days: list ?? const [], controller: controller),
        ),
        if (draft.slot != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.md),
            child: Text(
              '${fmt.fullDate(draft.slot!.start, tz)} · ${l.flowWith(_artistName(context, profile, draft))}',
              style: context.text.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _DayPill extends StatelessWidget {
  const _DayPill({required this.day, required this.selected, required this.onTap});
  final DayAvailability day;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final motion = Motion.of(context);
    final date = Ymd.parse(day.date);
    final available = !day.closed && day.slotCount > 0;
    final fg = selected ? scheme.onPrimary : (available ? scheme.onSurface : scheme.onSurfaceVariant.withValues(alpha: 0.45));
    return Semantics(
      button: true,
      selected: selected,
      enabled: available,
      label: DateFormat.MMMMEEEEd(context.lang).format(date),
      child: PressableScale(
        onTap: onTap,
        child: AnimatedContainer(
          duration: motion.medium,
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
                Text(DateFormat.d(context.lang).format(date), style: context.text.titleLarge?.copyWith(color: fg, fontWeight: FontWeight.w700)),
                Text(DateFormat.E(context.lang).format(date).toUpperCase(), style: context.text.labelSmall?.copyWith(color: fg, letterSpacing: 0.6)),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: motion.medium,
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: available ? (selected ? scheme.onPrimary : scheme.tertiary) : Colors.transparent,
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

class _TimeRow extends ConsumerWidget {
  const _TimeRow({required this.profile, required this.draft, required this.date, required this.days, required this.controller});
  final SalonProfile profile;
  final BookingDraft draft;
  final String date;
  final List<DayAvailability> days;
  final BookingDraftController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final q = (salon: profile.card.slug, services: draft.servicesKey, staffId: draft.staffId, date: date);
    final slots = ref.watch(visitSlotsProvider(q));
    return slots.when(
      loading: () => SizedBox(
        height: 50,
        child: ShimmerLoading(
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 5,
            separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
            itemBuilder: (_, _) => const SkeletonBox(width: 88, height: 48, radius: Radii.pill),
          ),
        ),
      ),
      error: (e, _) => ErrorView(error: e, onRetry: () => ref.invalidate(visitSlotsProvider(q))),
      data: (list) {
        if (list.isEmpty) {
          final next = days.where((d) => d.slotCount > 0 && d.date.compareTo(date) > 0).firstOrNull;
          return _Hint(
            text: next == null ? l.flowNoAvailability : '${l.flowDayFull} ${l.flowNextAvailable(context.fmt.ymdLabel(next.date))}',
            icon: Icons.event_busy_outlined,
          ).withAction(next == null ? null : () => controller.pickDate(next.date));
        }
        return SizedBox(
          height: 50,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.sm),
            itemBuilder: (_, i) => StaggeredEntrance(
              key: ValueKey(list[i].start.toIso8601String()),
              index: i.clamp(0, 8),
              axis: Axis.horizontal,
              offset: 10,
              child: _TimeChip(slot: list[i], selected: draft.slot?.start == list[i].start, onTap: () => controller.pickSlot(list[i])),
            ),
          ),
        );
      },
    );
  }
}

extension on _Hint {
  Widget withAction(VoidCallback? onTap) => onTap == null ? this : PressableScale(onTap: onTap, child: this);
}

class _TimeChip extends StatelessWidget {
  const _TimeChip({required this.slot, required this.selected, required this.onTap});
  final Slot slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final p = slot.time.split(':').map(int.parse).toList();
    final label = DateFormat.jm(context.lang).format(DateTime(2000, 1, 1, p[0], p[1]));
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: PressableScale(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: AnimatedContainer(
          duration: Motion.of(context).fast,
          constraints: const BoxConstraints(minWidth: 88),
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surface,
            borderRadius: Radii.pillAll,
            border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.8)),
          ),
          child: ExcludeSemantics(
            child: Text(label, style: context.text.labelLarge?.copyWith(color: selected ? scheme.onPrimary : scheme.onSurface)),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Step 2 — Details
// ---------------------------------------------------------------------------

class _StepTop extends StatelessWidget {
  const _StepTop({required this.current, required this.onBack});
  final int current;
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: Space.sm, bottom: Space.lg),
      child: Row(children: [
        IconButton(tooltip: l.actionBack, onPressed: onBack, icon: const BackButtonIcon()),
        const SizedBox(width: Space.sm),
        Expanded(child: StepHeader(steps: [l.flowStepChoose, l.flowStepDetails, l.flowStepVerify], current: current)),
        const SizedBox(width: Space.lg),
      ]),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({required this.profile, required this.draft});
  final SalonProfile profile;
  final BookingDraft draft;
  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final tz = profile.timezone;
    final slot = draft.slot!;
    return GlowCard(
      gradient: context.glow.heroGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(profile.card.title(context.lang), style: context.text.titleMedium),
          const SizedBox(height: Space.sm),
          for (final s in _chosen(profile, draft))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(children: [
                Icon(Icons.spa_outlined, size: 18, color: context.colors.primary),
                const SizedBox(width: Space.sm),
                Expanded(child: Text(s.title(context.lang), style: context.text.bodyMedium)),
                Text(fmt.money(s.priceBaisa), style: context.text.bodyMedium),
              ]),
            ),
          const SizedBox(height: Space.sm),
          Text(
            '${fmt.weekdayDayMonth(slot.start, tz)} · ${fmt.time(slot.start, tz)} · ${context.l10n.flowWith(_artistName(context, profile, draft))}',
            style: context.text.labelMedium,
          ),
        ],
      ),
    );
  }
}

class _DetailsStep extends StatelessWidget {
  const _DetailsStep({
    required this.profile,
    required this.draft,
    required this.form,
    required this.name,
    required this.phone,
    required this.notes,
    required this.onBack,
    required this.verifiedAccount,
  });
  final SalonProfile profile;
  final BookingDraft draft;
  final GlobalKey<FormState> form;
  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController notes;
  final VoidCallback onBack;
  final bool verifiedAccount;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = V(context);
    final fmt = context.fmt;
    final due = _chosen(profile, draft).fold(0, (sum, s) => sum + s.dueAtBookingBaisa);
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
                Text(l.flowPhoneHelp, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
                const SizedBox(height: Space.xl),
                AutofillGroup(
                  child: Form(
                    key: form,
                    child: Column(children: [
                      GlowField(controller: name, label: l.authFullName, autofill: const [AutofillHints.name], validator: v.required, prefixIcon: Icons.person_outline_rounded),
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.lg),
                        child: TextFormField(
                          controller: phone,
                          keyboardType: TextInputType.phone,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          textInputAction: TextInputAction.next,
                          textDirection: TextDirection.ltr,
                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]'))],
                          validator: (raw) => v.phone(composePhone(raw ?? '')),
                          decoration: InputDecoration(
                            labelText: l.authPhone,
                            prefixIcon: Padding(
                              padding: const EdgeInsetsDirectional.only(start: Space.md, end: Space.sm),
                              child: Row(mainAxisSize: MainAxisSize.min, children: [
                                const Icon(Icons.phone_iphone_rounded, size: 20),
                                const SizedBox(width: Space.sm),
                                Text(_countryCode, textDirection: TextDirection.ltr, style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant)),
                              ]),
                            ),
                            helperText: verifiedAccount ? l.flowVerifiedAccount : null,
                            helperMaxLines: 2,
                          ),
                        ),
                      ),
                      GlowField(controller: notes, label: '${l.flowNotes} (${l.labelOptional})', hint: l.flowNotesHint, maxLines: 2),
                    ]),
                  ),
                ),
                _VisitCard(profile: profile, draft: draft),
                const SizedBox(height: Space.lg),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(Icons.info_outline_rounded, size: 18, color: context.colors.onSurfaceVariant),
                  const SizedBox(width: Space.sm),
                  Expanded(
                    child: Text(
                      [
                        l.flowPolicyFree(profile.cancellationWindowHours),
                        if (due > 0) '${l.flowDepositDue}: ${fmt.money(due)}. ${l.flowPolicyDeposit}',
                        if (profile.lateCancellationFeeBaisa > 0) l.flowPolicyFee(fmt.money(profile.lateCancellationFeeBaisa)),
                      ].join(' '),
                      style: context.text.bodySmall,
                    ),
                  ),
                ]),
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
  const _VerifyStep({required this.draft, required this.code, required this.onBack, required this.onResend});
  final BookingDraft draft;
  final TextEditingController code;
  final VoidCallback onBack;
  final Future<void> Function() onResend;

  static const _resendAfter = 30;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final sentAt = draft.codeSentAt ?? DateTime.now();
    final wait = _resendAfter - DateTime.now().difference(sentAt).inSeconds;
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
                Text(
                  l.flowVerifyBody(draft.codeSentTo ?? ''),
                  style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant),
                ),
                const SizedBox(height: Space.xl),
                _CodeInput(controller: code),
                if (draft.testCode != null) ...[
                  const SizedBox(height: Space.lg),
                  PressableScale(
                    onTap: () => code.text = draft.testCode!,
                    child: GlowCard(
                      elevated: false,
                      color: context.colors.tertiaryContainer,
                      child: Row(children: [
                        Icon(Icons.science_outlined, color: context.colors.onTertiaryContainer),
                        const SizedBox(width: Space.md),
                        Expanded(
                          child: Text(l.flowTestCode(draft.testCode!), style: context.text.bodyMedium?.copyWith(color: context.colors.onTertiaryContainer)),
                        ),
                        Icon(Icons.input_rounded, color: context.colors.onTertiaryContainer),
                      ]),
                    ),
                  ),
                ],
                const SizedBox(height: Space.lg),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    wait > 0
                        ? Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Text(l.flowResendIn(wait), style: context.text.bodySmall))
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

/// Six boxes over one real text field — so iOS can autofill the SMS code
/// ("From Messages") and paste works.
class _CodeInput extends StatefulWidget {
  const _CodeInput({required this.controller});
  final TextEditingController controller;
  @override
  State<_CodeInput> createState() => _CodeInputState();
}

class _CodeInputState extends State<_CodeInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _changed() {
    if (widget.controller.text.length == 6) _focus.unfocus();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final motion = Motion.of(context);
    final text = widget.controller.text;
    return Semantics(
      label: context.l10n.flowEnterCode,
      textField: true,
      child: GestureDetector(
        onTap: () => _focus.requestFocus(),
        child: Stack(
          children: [
            // The real field: invisible, but focusable, autofillable and pasteable.
            Positioned.fill(
              child: Opacity(
                opacity: 0,
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.oneTimeCode],
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                  showCursor: false,
                  enableInteractiveSelection: true,
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            IgnorePointer(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Row(
                  children: [
                    for (var i = 0; i < 6; i++) ...[
                      if (i > 0) SizedBox(width: i == 3 ? Space.md : Space.sm),
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 0.82,
                          child: AnimatedContainer(
                            duration: motion.fast,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: Radii.mdAll,
                              border: Border.all(
                                color: i == text.length && _focus.hasFocus ? scheme.primary : (i < text.length ? scheme.primary.withValues(alpha: 0.5) : scheme.outlineVariant),
                                width: i == text.length && _focus.hasFocus ? 2 : 1.2,
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: motion.fast,
                              transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Motion.pop), child: c),
                              child: Text(
                                i < text.length ? text[i] : '',
                                key: ValueKey('$i-${i < text.length ? text[i] : ''}'),
                                style: context.text.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
    final signedIn = ref.watch(authControllerProvider).valueOrNull != null;
    final first = r.bookings.first;
    final last = r.bookings.last;
    final deposit = r.bookings.fold(0, (sum, b) => sum + (b.depositOutstanding ? b.depositBaisa - b.paidBaisa : 0));

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(gutterOf(context)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AnimatedSwitcher(
                  duration: Motion.of(context).slow,
                  child: held
                      ? Padding(key: const ValueKey('held'), padding: const EdgeInsets.all(Space.xl), child: Icon(Icons.lock_clock_outlined, size: 72, color: context.colors.primary))
                      : AnimatedSuccess(key: ValueKey('ok-${draft.paid}')),
                ),
                StaggeredEntrance(index: 4, child: Text(held ? l.flowHeld : l.flowConfirmed, style: context.text.headlineMedium, textAlign: TextAlign.center)),
                const SizedBox(height: Space.sm),
                StaggeredEntrance(index: 5, child: Text(held ? l.flowHeldBody : l.flowConfirmedBody, style: context.text.bodyLarge, textAlign: TextAlign.center)),
                const SizedBox(height: Space.xl),
                StaggeredEntrance(
                  index: 7,
                  child: GlowCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(profile.card.title(context.lang), style: context.text.titleMedium),
                        const SizedBox(height: 4),
                        Text(fmt.fullDate(first.start, tz), style: context.text.bodyMedium),
                        Text('${fmt.time(first.start, tz)} – ${fmt.time(last.end, tz)} · ${l.flowWith(first.staff.display(context.lang))}', style: context.text.bodyMedium),
                        const Divider(height: Space.xl),
                        for (final b in r.bookings)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(children: [
                              Expanded(child: Text(b.service.display(context.lang), style: context.text.titleSmall)),
                              Text(b.reference, style: context.text.bodySmall),
                            ]),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: Space.xl),
                if (held) ...[
                  if (r.onlinePaymentAvailable) ...[
                    Text(l.payTestMode, style: context.text.bodySmall, textAlign: TextAlign.center),
                    const SizedBox(height: Space.sm),
                    AnimatedButton(label: l.payNow(fmt.money(deposit)), icon: Icons.credit_card_rounded, keepSuccess: true, onPressed: onPay),
                  ] else
                    Text(l.payUnavailable, style: context.text.bodyMedium, textAlign: TextAlign.center),
                ] else ...[
                  if (!signedIn) Text(l.flowManageLinkHint, style: context.text.bodySmall, textAlign: TextAlign.center),
                  const SizedBox(height: Space.md),
                  FilledButton(onPressed: () => context.go(signedIn ? '/appointments' : '/salon/${profile.card.slug}'), child: Text(l.flowDone)),
                  const SizedBox(height: Space.sm),
                  OutlinedButton(
                    onPressed: () => context.go(signedIn ? '/appointments/${first.id}' : '/booking/${first.id}?token=${r.manageToken}'),
                    child: Text(l.flowViewAppointment),
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
