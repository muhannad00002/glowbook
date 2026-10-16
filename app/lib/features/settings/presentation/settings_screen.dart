import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/constants/env.dart';
import '../../../core/localization/preferences_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/presentation/auth_layout.dart';
import '../data/settings_repository.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final settings = ref.watch(salonSettingsProvider);
    final isAdmin = ref.watch(membershipProvider)?.isAdmin ?? false;
    final g = gutterOf(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView(
          value: settings,
          onRetry: () => ref.invalidate(salonSettingsProvider),
          data: (s) {
            final sections = <Widget>[
              _BookingLinkCard(slug: s.slug),
              if (isAdmin) ...[
                _ProfileSection(settings: s),
                _RulesSection(settings: s),
                _PolicySection(settings: s),
                _ChannelsSection(settings: s),
                _HoursSection(settings: s),
                const _HolidaysSection(),
                const _DeliveryLogSection(),
                const _TeamSection(),
              ],
              const PreferencesSection(),
            ];
            return ListView(
              padding: EdgeInsets.fromLTRB(g, Space.lg, g, 120),
              children: [
                ContentWidth(
                  maxWidth: 820,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l.settingsTitle, style: context.text.headlineMedium),
                      const SizedBox(height: Space.lg),
                      for (var i = 0; i < sections.length; i++)
                        Padding(padding: const EdgeInsets.only(bottom: Space.lg), child: StaggeredEntrance(index: i, child: sections[i])),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Immediately PATCHes one or more salon fields and refreshes the settings.
Future<void> patchSalon(BuildContext context, WidgetRef ref, Json fields, {bool toast = true}) async {
  await guard(context, () => ref.read(settingsRepositoryProvider).patch(fields));
  ref.invalidate(salonSettingsProvider);
  if (toast && context.mounted) showGlowSnack(context, context.l10n.settingsSaved);
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children, this.subtitle, this.icon});
  final String title;
  final String? subtitle;
  final IconData? icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            if (icon != null) ...[Icon(icon, color: context.colors.primary, size: 22), const SizedBox(width: Space.md)],
            Expanded(child: Text(title, style: context.text.titleLarge)),
          ]),
          if (subtitle != null) Padding(padding: const EdgeInsets.only(top: 4), child: Text(subtitle!, style: context.text.bodySmall)),
          const SizedBox(height: Space.md),
          ...children,
        ],
      ),
    );
  }
}

class _BookingLinkCard extends StatelessWidget {
  const _BookingLinkCard({required this.slug});
  final String slug;
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final url = '${Env.appBaseUrl}/salon/$slug';
    return GlowCard(
      gradient: context.glow.heroGradient,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.link_rounded, color: context.colors.primary),
            const SizedBox(width: Space.sm),
            Text(l.settingsBookingLink, style: context.text.titleLarge),
          ]),
          const SizedBox(height: Space.sm),
          Text(l.settingsBookingLinkBody, style: context.text.bodyMedium),
          const SizedBox(height: Space.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
            decoration: BoxDecoration(color: context.colors.surface.withValues(alpha: 0.8), borderRadius: Radii.mdAll),
            child: SelectableText(url, style: context.text.bodyMedium, textDirection: TextDirection.ltr),
          ),
          const SizedBox(height: Space.md),
          Wrap(spacing: Space.sm, children: [
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: url));
                if (context.mounted) showGlowSnack(context, l.settingsLinkCopied);
              },
              icon: const Icon(Icons.copy_rounded),
              label: Text(l.settingsCopyLink),
            ),
            OutlinedButton.icon(onPressed: () => context.push('/salon/$slug'), icon: const Icon(Icons.open_in_new_rounded), label: Text(l.settingsOpenPage)),
          ]),
        ],
      ),
    );
  }
}

class _ProfileSection extends ConsumerStatefulWidget {
  const _ProfileSection({required this.settings});
  final SalonSettings settings;
  @override
  ConsumerState<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends ConsumerState<_ProfileSection> {
  late final _fields = {
    for (final k in ['name', 'nameAr', 'tagline', 'taglineAr', 'description', 'descriptionAr', 'phone', 'whatsapp', 'address', 'addressAr', 'city'])
      k: TextEditingController(text: widget.settings.text(k) ?? ''),
  };
  late final _photos = TextEditingController(text: ((widget.settings.json['photos'] as List?) ?? const []).join('\n'));

  @override
  void dispose() {
    for (final c in [..._fields.values, _photos]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget f(String k, String label, {bool ar = false, int lines = 1, bool ltr = false}) =>
        GlowField(controller: _fields[k]!, label: label, maxLines: lines, textDirection: ar ? TextDirection.rtl : (ltr ? TextDirection.ltr : null));
    return _Section(
      title: l.settingsSalonProfile,
      icon: Icons.storefront_outlined,
      children: [
        f('name', l.authSalonName),
        f('nameAr', '${l.authSalonName} (AR)', ar: true),
        f('tagline', l.settingsTagline),
        f('taglineAr', '${l.settingsTagline} (AR)', ar: true),
        f('description', l.settingsDescription, lines: 3),
        f('descriptionAr', '${l.settingsDescription} (AR)', ar: true, lines: 3),
        Row(children: [
          Expanded(child: f('phone', l.settingsPhone, ltr: true)),
          const SizedBox(width: Space.md),
          Expanded(child: f('whatsapp', l.settingsWhatsapp, ltr: true)),
        ]),
        f('address', l.settingsAddress),
        f('addressAr', '${l.settingsAddress} (AR)', ar: true),
        f('city', l.authCity),
        GlowField(controller: _photos, label: l.settingsGallery, helper: l.settingsGalleryHelp, maxLines: 4, textDirection: TextDirection.ltr),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: widget.settings.flag('isPublished'),
          onChanged: (v) => patchSalon(context, ref, {'isPublished': v}),
          title: Text(l.settingsPublished),
        ),
        AnimatedButton(
          label: l.actionSaveChanges,
          tone: ButtonTone.soft,
          onPressed: () => patchSalon(context, ref, {
            for (final e in _fields.entries) e.key: e.value.text.trim().isEmpty ? (e.key == 'name' ? widget.settings.name : null) : e.value.text.trim(),
            'photos': _photos.text.split(RegExp(r'\s+')).where((u) => u.startsWith('http')).take(12).toList(),
          }),
        ),
      ],
    );
  }
}

class _RulesSection extends ConsumerWidget {
  const _RulesSection({required this.settings});
  final SalonSettings settings;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final fmt = context.fmt;
    return _Section(
      title: l.settingsBookingRules,
      icon: Icons.rule_rounded,
      children: [
        _DropdownRow<int>(
          label: l.settingsSlotInterval,
          value: settings.integer('slotIntervalMinutes'),
          items: {for (final m in [10, 15, 20, 30, 60]) m: fmt.duration(m)},
          onChanged: (v) => patchSalon(context, ref, {'slotIntervalMinutes': v}),
        ),
        _DropdownRow<int>(
          label: l.settingsMinNotice,
          value: settings.integer('minNoticeMinutes'),
          items: {for (final m in [0, 30, 60, 120, 180, 360, 720, 1440]) m: m == 0 ? '—' : fmt.duration(m)},
          onChanged: (v) => patchSalon(context, ref, {'minNoticeMinutes': v}),
        ),
        _DropdownRow<int>(
          label: l.settingsHorizon,
          value: settings.integer('bookingHorizonDays'),
          items: {for (final d in [14, 30, 60, 90, 180]) d: l.settingsHorizonDays(d)},
          onChanged: (v) => patchSalon(context, ref, {'bookingHorizonDays': v}),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: settings.flag('autoConfirm'),
          onChanged: (v) => patchSalon(context, ref, {'autoConfirm': v}),
          title: Text(l.settingsAutoConfirm),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: settings.flag('allowCustomerReschedule'),
          onChanged: (v) => patchSalon(context, ref, {'allowCustomerReschedule': v}),
          title: Text(l.settingsAllowReschedule),
        ),
      ],
    );
  }
}

class _PolicySection extends ConsumerWidget {
  const _PolicySection({required this.settings});
  final SalonSettings settings;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final fmt = context.fmt;
    return _Section(
      title: l.settingsCancellation,
      icon: Icons.policy_outlined,
      children: [
        _DropdownRow<int>(
          label: l.settingsCancellationWindow,
          value: settings.integer('cancellationWindowHours'),
          items: {for (final h in [0, 2, 6, 12, 24, 48, 72]) h: l.settingsHoursBefore(h)},
          onChanged: (v) => patchSalon(context, ref, {'cancellationWindowHours': v}),
        ),
        _DropdownRow<int>(
          label: l.settingsLateFee,
          value: settings.integer('lateCancellationFeeBaisa'),
          items: {for (final b in [0, 2000, 5000, 10000, 15000, 20000]) b: b == 0 ? '—' : fmt.money(b)},
          onChanged: (v) => patchSalon(context, ref, {'lateCancellationFeeBaisa': v}),
        ),
        const SizedBox(height: Space.sm),
        Text(l.settingsDepositPolicy, style: context.text.labelMedium),
        const SizedBox(height: Space.sm),
        SegmentedButton<String>(
          segments: [
            ButtonSegment(value: 'REFUNDABLE_IN_WINDOW', label: Text(l.settingsDepositRefundable)),
            ButtonSegment(value: 'NON_REFUNDABLE', label: Text(l.settingsDepositNonRefundable)),
          ],
          selected: {settings.text('depositPolicy') ?? 'REFUNDABLE_IN_WINDOW'},
          onSelectionChanged: (v) => patchSalon(context, ref, {'depositPolicy': v.first}),
        ),
      ],
    );
  }
}

class _DropdownRow<T> extends StatelessWidget {
  const _DropdownRow({required this.label, required this.value, required this.items, required this.onChanged});
  final String label;
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;
  @override
  Widget build(BuildContext context) {
    final options = {...items, if (!items.containsKey(value)) value: '$value'};
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.md),
      child: DropdownButtonFormField<T>(
        initialValue: value,
        decoration: InputDecoration(labelText: label),
        items: [for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
        onChanged: (v) => v == null ? null : onChanged(v),
      ),
    );
  }
}

class _ChannelsSection extends ConsumerWidget {
  const _ChannelsSection({required this.settings});
  final SalonSettings settings;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final providers = asJson(ref.watch(deliveryLogProvider).valueOrNull?['providers']);
    bool configured(String key) => asJson(providers[key])['configured'] == true;
    final channels = [
      ('notifyInApp', l.channelInApp, Icons.notifications_none_rounded, null),
      ('notifyPush', l.channelPush, Icons.phone_iphone_rounded, 'PUSH'),
      ('notifyWhatsapp', l.channelWhatsapp, Icons.chat_outlined, 'WHATSAPP'),
      ('notifyEmail', l.channelEmail, Icons.mail_outline_rounded, 'EMAIL'),
      ('notifySms', l.channelSms, Icons.sms_outlined, 'SMS'),
    ];
    return _Section(
      title: l.settingsChannels,
      subtitle: l.settingsChannelsBody,
      icon: Icons.campaign_outlined,
      children: [
        for (final c in channels)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: Icon(c.$3),
            value: settings.flag(c.$1),
            onChanged: (v) => patchSalon(context, ref, {c.$1: v}),
            title: Text(c.$2),
            subtitle: c.$4 != null && providers.isNotEmpty && !configured(c.$4!) ? Text(l.channelNotConfigured) : null,
          ),
        const Divider(height: Space.xl),
        Text(l.settingsReminders, style: context.text.titleSmall),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: settings.flag('remind24h'), onChanged: (v) => patchSalon(context, ref, {'remind24h': v}), title: Text(l.settingsRemind24h)),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: settings.flag('remind3h'), onChanged: (v) => patchSalon(context, ref, {'remind3h': v}), title: Text(l.settingsRemind3h)),
        SwitchListTile(contentPadding: EdgeInsets.zero, value: settings.flag('reviewRequests'), onChanged: (v) => patchSalon(context, ref, {'reviewRequests': v}), title: Text(l.settingsReviewRequests)),
      ],
    );
  }
}

class _HoursSection extends ConsumerStatefulWidget {
  const _HoursSection({required this.settings});
  final SalonSettings settings;
  @override
  ConsumerState<_HoursSection> createState() => _HoursSectionState();
}

class _HoursSectionState extends ConsumerState<_HoursSection> {
  late final Map<int, (int, int)> _days = {for (final h in widget.settings.hours) h.dayOfWeek: (h.startMinute, h.endMinute)};
  bool _dirty = false;

  Future<void> _pick(int dow, bool open) async {
    final (s, e) = _days[dow]!;
    final cur = open ? s : e;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
    if (t == null) return;
    final v = t.hour * 60 + t.minute;
    setState(() {
      _days[dow] = open ? (v, e > v ? e : v + 60) : (s, v > s ? v : s + 60);
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    return _Section(
      title: l.settingsOpeningHours,
      icon: Icons.schedule_rounded,
      children: [
        for (final dow in [6, 0, 1, 2, 3, 4, 5])
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Row(children: [
              SizedBox(width: 96, child: Text(fmt.weekdayName(dow))),
              Switch(
                value: _days.containsKey(dow),
                onChanged: (on) => setState(() {
                  on ? _days[dow] = (9 * 60, 21 * 60) : _days.remove(dow);
                  _dirty = true;
                }),
              ),
              const SizedBox(width: Space.sm),
              Expanded(
                child: _days.containsKey(dow)
                    ? Row(children: [
                        Expanded(child: OutlinedButton(onPressed: () => _pick(dow, true), child: Text(fmt.minuteOfDay(_days[dow]!.$1)))),
                        const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('–')),
                        Expanded(child: OutlinedButton(onPressed: () => _pick(dow, false), child: Text(fmt.minuteOfDay(_days[dow]!.$2)))),
                      ])
                    : Text(l.settingsClosed, style: context.text.bodySmall),
              ),
            ]),
          ),
        AnimatedSize(
          duration: Motion.of(context).medium,
          child: _dirty
              ? AnimatedButton(
                  label: l.actionSaveChanges,
                  tone: ButtonTone.soft,
                  onPressed: () async {
                    await guard(
                      context,
                      () => ref.read(settingsRepositoryProvider).saveHours([
                        for (final e in _days.entries) Shift(dayOfWeek: e.key, startMinute: e.value.$1, endMinute: e.value.$2),
                      ]),
                    );
                    ref.invalidate(salonSettingsProvider);
                    if (context.mounted) {
                      setState(() => _dirty = false);
                      showGlowSnack(context, l.settingsSaved);
                    }
                  },
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

class _HolidaysSection extends ConsumerWidget {
  const _HolidaysSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final fmt = context.fmt;
    final list = ref.watch(holidaysProvider);
    return _Section(
      title: l.settingsHolidays,
      icon: Icons.celebration_outlined,
      children: [
        ...(list.valueOrNull ?? const []).map((h) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(h['isClosed'] == true ? Icons.do_not_disturb_on_outlined : Icons.schedule_rounded),
              title: Text('${fmt.ymdLabel(h['date'] as String, pattern: 'yMMMEd')} · ${h['name']}'),
              subtitle: Text(h['isClosed'] == true
                  ? l.settingsClosedAllDay
                  : '${l.settingsSpecialHours}: ${fmt.minuteOfDay(asInt(h['openMinute']))} – ${fmt.minuteOfDay(asInt(h['closeMinute']))}'),
              trailing: IconButton(
                tooltip: l.actionDelete,
                icon: const Icon(Icons.delete_outline_rounded),
                onPressed: () async {
                  await guard(context, () => ref.read(settingsRepositoryProvider).deleteHoliday(h['id'] as String));
                  ref.invalidate(holidaysProvider);
                },
              ),
            )),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(onPressed: () => _add(context, ref), icon: const Icon(Icons.add_rounded), label: Text(l.settingsAddHoliday)),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final l = context.l10n;
    final date = await showDatePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date == null || !context.mounted) return;
    final name = TextEditingController();
    var closed = true;
    var open = 16 * 60;
    var close = 21 * 60;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(l.settingsAddHoliday),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: InputDecoration(labelText: l.settingsHolidayName)),
            SwitchListTile(contentPadding: EdgeInsets.zero, value: closed, onChanged: (v) => set(() => closed = v), title: Text(l.settingsClosedAllDay)),
            if (!closed)
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await showTimePicker(context: ctx, initialTime: TimeOfDay(hour: open ~/ 60, minute: open % 60));
                      if (t != null) set(() => open = t.hour * 60 + t.minute);
                    },
                    child: Text(ctx.fmt.minuteOfDay(open)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await showTimePicker(context: ctx, initialTime: TimeOfDay(hour: close ~/ 60, minute: close % 60));
                      if (t != null) set(() => close = t.hour * 60 + t.minute);
                    },
                    child: Text(ctx.fmt.minuteOfDay(close)),
                  ),
                ),
              ]),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.actionCancel)),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.actionAdd)),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    await guard(
      context,
      () => ref.read(settingsRepositoryProvider).addHoliday({
        'date': Ymd.of(date),
        'name': name.text.trim().isEmpty ? l.settingsClosed : name.text.trim(),
        'isClosed': closed,
        if (!closed) 'openMinute': open,
        if (!closed) 'closeMinute': close,
      }),
    );
    ref.invalidate(holidaysProvider);
  }
}

class _DeliveryLogSection extends ConsumerWidget {
  const _DeliveryLogSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final log = ref.watch(deliveryLogProvider);
    final tz = ref.watch(salonTimezoneProvider);
    final items = asJsonList(log.valueOrNull?['items']).take(12).toList();
    return _Section(
      title: l.settingsDeliveryLog,
      icon: Icons.outbox_outlined,
      children: [
        if (items.isEmpty) Text('—', style: context.text.bodySmall),
        for (final n in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            leading: Icon(switch (n['channel']) {
              'WHATSAPP' => Icons.chat_outlined,
              'EMAIL' => Icons.mail_outline_rounded,
              'SMS' => Icons.sms_outlined,
              _ => Icons.phone_iphone_rounded,
            }),
            title: Text('${n['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              [n['status'], if (n['lastError'] != null) n['lastError'], context.fmt.relativeDay(asDateReq(n['createdAt']), tz)].join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }
}

class _TeamSection extends ConsumerWidget {
  const _TeamSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final members = ref.watch(membersProvider).valueOrNull ?? const [];
    return _Section(
      title: l.settingsTeamAccess,
      icon: Icons.admin_panel_settings_outlined,
      children: [
        for (final m in members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: InitialsAvatar(name: asStr(asJson(m['user'])['name']) ?? '?', size: 38),
            title: Text(asStr(asJson(m['user'])['name']) ?? ''),
            subtitle: Text(asStr(asJson(m['user'])['email']) ?? ''),
            trailing: Chip(label: Text(context.fmt.roleLabel(m['role'] as String))),
          ),
      ],
    );
  }
}

/// Language, appearance, salon switcher and sign-out — shared by every role.
class PreferencesSection extends ConsumerWidget {
  const PreferencesSection({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final prefs = ref.watch(preferencesProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final memberships = session?.me.memberships ?? const [];
    return _Section(
      title: l.settingsAccount,
      icon: Icons.person_outline_rounded,
      children: [
        if (session != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: InitialsAvatar(name: session.me.user.name),
            title: Text(session.me.user.name),
            subtitle: Text(session.me.user.email ?? session.me.user.phone ?? ''),
          ),
        if (memberships.length > 1)
          _DropdownRow<String>(
            label: l.authSalonName,
            value: session!.activeSalonId ?? memberships.first.salonId,
            items: {for (final m in memberships) m.salonId: m.salonName},
            onChanged: (id) => ref.read(authControllerProvider.notifier).switchSalon(id),
          ),
        Text(l.settingsLanguage, style: context.text.labelMedium),
        const SizedBox(height: Space.sm),
        SegmentedButton<String>(
          segments: const [ButtonSegment(value: 'en', label: Text('English')), ButtonSegment(value: 'ar', label: Text('العربية'))],
          selected: {prefs.locale.languageCode},
          onSelectionChanged: (v) {
            ref.read(preferencesProvider.notifier).setLocale(v.first);
            if (session != null) ref.read(authControllerProvider.notifier).updateProfile(locale: v.first).ignore();
          },
        ),
        if (session != null) ...[
          const SizedBox(height: Space.xl),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: context.colors.error),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(l.authSignOutConfirm),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.actionCancel)),
                    FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.authSignOut)),
                  ],
                ),
              );
              if (ok == true) await ref.read(authControllerProvider.notifier).logout();
            },
            icon: const Icon(Icons.logout_rounded),
            label: Text(l.authSignOut),
          ),
        ],
      ],
    );
  }
}
