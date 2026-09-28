import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/animations/animated_empty_state.dart';
import '../../../shared/animations/glow_illustration.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/presentation/auth_layout.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../services/data/services_repository.dart';
import '../data/staff_repository.dart';

const staffSwatches = ['#8E4B61', '#B7835A', '#5E7F73', '#6B5B95', '#A0707A', '#3F6E8C', '#9C5B6E', '#7A8B4F'];

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final staff = ref.watch(staffListProvider);
    final services = ref.watch(servicesProvider).valueOrNull ?? const [];
    final canEdit = ref.watch(membershipProvider)?.isAdmin ?? false;
    final g = gutterOf(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView(
          value: staff,
          onRetry: () => ref.invalidate(staffListProvider),
          data: (list) => ListView(
            padding: EdgeInsets.fromLTRB(g, Space.lg, g, 120),
            children: [
              ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(children: [
                      Expanded(child: Text(l.staffTitle, style: context.text.headlineMedium)),
                      if (canEdit) FilledButton.tonalIcon(onPressed: () => context.push('/admin/team/new'), icon: const Icon(Icons.person_add_alt_1_outlined), label: Text(l.staffAdd)),
                    ]),
                    const SizedBox(height: Space.lg),
                    if (list.isEmpty)
                      AnimatedEmptyState(art: GlowArt.brush, title: l.staffEmptyTitle, body: l.staffEmptyBody),
                    LayoutBuilder(builder: (context, c) {
                      final cols = c.maxWidth >= 900 ? 3 : c.maxWidth >= 560 ? 2 : 1;
                      final w = (c.maxWidth - Space.md * (cols - 1)) / cols;
                      return Wrap(spacing: Space.md, runSpacing: Space.md, children: [
                        for (var i = 0; i < list.length; i++)
                          SizedBox(
                            width: w,
                            child: StaggeredEntrance(
                              key: ValueKey(list[i].id),
                              index: i,
                              child: _StaffCard(
                                staff: list[i],
                                serviceNames: services.where((s) => list[i].serviceIds.contains(s.id)).map((s) => s.title(context.lang)).toList(),
                                onTap: canEdit ? () => context.push('/admin/team/${list[i].id}') : null,
                              ),
                            ),
                          ),
                      ]);
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.staff, required this.serviceNames, this.onTap});
  final StaffMember staff;
  final List<String> serviceNames;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final color = hexColor(staff.color);
    final days = staff.hours.map((h) => h.dayOfWeek).toSet().toList()..sort((a, b) => ((a + 1) % 7).compareTo((b + 1) % 7));
    return GlowCard(
      onTap: onTap,
      child: Opacity(
        opacity: staff.isActive ? 1 : 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Hero(tag: 'staff-${staff.id}', child: InitialsAvatar(name: staff.name, color: color, size: 52, photoUrl: staff.photoUrl)),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(staff.displayName(context.lang), style: context.text.titleMedium),
                  if (staff.displayTitle(context.lang) != null) Text(staff.displayTitle(context.lang)!, style: context.text.bodySmall),
                  if (!staff.isActive) Text(context.l10n.staffInactive, style: context.text.labelSmall?.copyWith(color: context.colors.error)),
                ]),
              ),
              if (staff.hasLogin) Tooltip(message: context.l10n.staffHasLogin, child: Icon(Icons.verified_user_outlined, size: 18, color: context.colors.tertiary)),
            ]),
            const SizedBox(height: Space.md),
            Wrap(spacing: 4, children: [
              for (var d = 0; d < 7; d++)
                Builder(builder: (context) {
                  final dow = (d + 6) % 7; // start Saturday
                  final on = days.contains(dow);
                  return Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: on ? color.withValues(alpha: 0.16) : Colors.transparent, shape: BoxShape.circle, border: Border.all(color: on ? color : context.colors.outlineVariant)),
                    child: Text(fmt.weekdayName(dow, short: true).characters.first, style: context.text.labelSmall?.copyWith(color: on ? color : context.colors.onSurfaceVariant)),
                  );
                }),
            ]),
            if (serviceNames.isNotEmpty) ...[
              const SizedBox(height: Space.md),
              Text(serviceNames.join(' · '), style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
          ],
        ),
      ),
    );
  }
}

class StaffFormScreen extends ConsumerStatefulWidget {
  const StaffFormScreen({super.key, this.id});
  final String? id;
  @override
  ConsumerState<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends ConsumerState<StaffFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nameAr = TextEditingController();
  final _title = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  String _color = staffSwatches.first;
  bool _active = true;
  Set<String> _services = {};
  // One shift per day (dayOfWeek → [start, end]); absent = day off.
  final Map<int, (int, int)> _hours = {for (final d in [6, 0, 1, 2, 3, 4]) d: (9 * 60, 18 * 60)};
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in [_name, _nameAr, _title, _phone, _email]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(StaffMember s) {
    if (_loaded) return;
    _loaded = true;
    _name.text = s.name;
    _nameAr.text = s.nameAr ?? '';
    _title.text = s.title ?? '';
    _phone.text = s.phone ?? '';
    _email.text = s.email ?? '';
    _color = s.color;
    _active = s.isActive;
    _services = s.serviceIds.toSet();
    _hours
      ..clear()
      ..addAll({for (final h in s.hours) h.dayOfWeek: (h.startMinute, h.endMinute)});
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) throw StateError('invalid');
    final body = {
      'name': _name.text.trim(),
      'nameAr': _nameAr.text.trim().isEmpty ? null : _nameAr.text.trim(),
      'title': _title.text.trim().isEmpty ? null : _title.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'color': _color,
      'isActive': _active,
      'serviceIds': _services.toList(),
      'hours': [for (final e in _hours.entries) {'dayOfWeek': e.key, 'startMinute': e.value.$1, 'endMinute': e.value.$2}],
    };
    final repo = ref.read(staffRepositoryProvider);
    await guard(context, () => widget.id == null ? repo.create(body) : repo.update(widget.id!, body));
    ref.invalidate(staffListProvider);
    ref.invalidate(servicesProvider);
    ref.invalidate(calendarRangeProvider);
    if (widget.id != null) ref.invalidate(staffDetailProvider(widget.id!));
    if (mounted) {
      showGlowSnack(context, context.l10n.staffSaved);
      context.pop();
    }
  }

  Future<void> _remove() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.actionDelete),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.actionCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.actionDelete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await guard(context, () => ref.read(staffRepositoryProvider).remove(widget.id!));
    ref.invalidate(staffListProvider);
    if (mounted) context.pop();
  }

  Future<void> _pickTime(int day, bool start) async {
    final (s, e) = _hours[day]!;
    final current = start ? s : e;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60));
    if (t == null) return;
    final v = t.hour * 60 + t.minute;
    setState(() => _hours[day] = start ? (v, e > v ? e : v + 60) : (s, v > s ? v : s + 60));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final v = V(context);
    StaffMember? existing;
    if (widget.id != null) {
      final s = ref.watch(staffDetailProvider(widget.id!));
      if (!s.hasValue) return Scaffold(appBar: AppBar(), body: AsyncView(value: s, data: (_) => const SizedBox()));
      existing = s.value;
      _fill(existing!);
    }
    final services = ref.watch(servicesProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == null ? l.staffAdd : l.staffEdit),
        actions: [if (widget.id != null) IconButton(tooltip: l.actionDelete, icon: const Icon(Icons.delete_outline_rounded), onPressed: _remove)],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: EdgeInsets.fromLTRB(gutterOf(context), Space.sm, gutterOf(context), Space.xxxl),
          children: [
            ContentWidth(
              maxWidth: 720,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Hero(
                      tag: 'staff-${widget.id ?? 'new'}',
                      child: AnimatedContainer(
                        duration: Motion.of(context).medium,
                        child: ListenableBuilder(
                          listenable: _name,
                          builder: (_, _) => InitialsAvatar(name: _name.text.isEmpty ? '?' : _name.text, color: hexColor(_color), size: 84),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  GlowField(controller: _name, label: l.staffName, validator: v.required),
                  GlowField(controller: _nameAr, label: l.staffNameAr, textDirection: TextDirection.rtl),
                  GlowField(controller: _title, label: l.staffJobTitle),
                  Row(children: [
                    Expanded(child: GlowField(controller: _phone, label: l.authPhone, keyboardType: TextInputType.phone, validator: v.optionalPhone, textDirection: TextDirection.ltr)),
                    const SizedBox(width: Space.md),
                    Expanded(child: GlowField(controller: _email, label: l.authEmail, keyboardType: TextInputType.emailAddress)),
                  ]),
                  Text(l.staffColor, style: context.text.labelMedium),
                  const SizedBox(height: Space.sm),
                  Wrap(spacing: Space.md, runSpacing: Space.md, children: [
                    for (final c in staffSwatches)
                      Semantics(
                        button: true,
                        selected: _color == c,
                        label: c,
                        child: PressableScale(
                          onTap: () => setState(() => _color = c),
                          child: AnimatedContainer(
                            duration: Motion.of(context).fast,
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: hexColor(c),
                              shape: BoxShape.circle,
                              border: Border.all(color: _color == c ? context.colors.onSurface : Colors.transparent, width: 3),
                            ),
                            child: _color == c ? const Icon(Icons.check_rounded, color: Colors.white, size: 20) : null,
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(height: Space.xl),
                  Text(l.staffServices, style: context.text.labelMedium),
                  const SizedBox(height: Space.sm),
                  Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
                    for (final s in services.where((s) => s.isActive))
                      FilterChip(
                        label: Text(s.title(context.lang)),
                        selected: _services.contains(s.id),
                        onSelected: (sel) => setState(() => sel ? _services.add(s.id) : _services.remove(s.id)),
                      ),
                  ]),
                  const SizedBox(height: Space.xl),
                  Text(l.staffHours, style: context.text.titleMedium),
                  const SizedBox(height: Space.sm),
                  for (final dow in [6, 0, 1, 2, 3, 4, 5])
                    Padding(
                      padding: const EdgeInsets.only(bottom: Space.sm),
                      child: Row(children: [
                        SizedBox(width: 96, child: Text(fmt.weekdayName(dow), style: context.text.bodyMedium)),
                        Switch(
                          value: _hours.containsKey(dow),
                          onChanged: (on) => setState(() => on ? _hours[dow] = (9 * 60, 18 * 60) : _hours.remove(dow)),
                        ),
                        const SizedBox(width: Space.sm),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: Motion.of(context).medium,
                            child: _hours.containsKey(dow)
                                ? Row(key: const ValueKey('on'), children: [
                                    Expanded(child: OutlinedButton(onPressed: () => _pickTime(dow, true), child: Text(fmt.minuteOfDay(_hours[dow]!.$1)))),
                                    const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('–')),
                                    Expanded(child: OutlinedButton(onPressed: () => _pickTime(dow, false), child: Text(fmt.minuteOfDay(_hours[dow]!.$2)))),
                                  ])
                                : Text(l.staffDayOff, key: const ValueKey('off'), style: context.text.bodySmall),
                          ),
                        ),
                      ]),
                    ),
                  SwitchListTile(contentPadding: EdgeInsets.zero, value: _active, onChanged: (v) => setState(() => _active = v), title: Text(l.staffActive)),
                  if (existing != null) ...[
                    const SizedBox(height: Space.lg),
                    _TimeOffSection(staff: existing),
                  ],
                  const SizedBox(height: Space.xl),
                  AnimatedButton(label: l.actionSave, onPressed: _save, keepSuccess: true),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeOffSection extends ConsumerWidget {
  const _TimeOffSection({required this.staff});
  final StaffMember staff;

  Future<void> _add(BuildContext context, WidgetRef ref, {bool force = false, DateTimeRange? range, String type = 'VACATION'}) async {
    final tz = ref.read(salonTimezoneProvider);
    final r = range ??
        await showDateRangePicker(context: context, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (r == null || !context.mounted) return;
    try {
      await ref.read(staffRepositoryProvider).addTimeOff(
            staff.id,
            start: Fmt.zonedInstant(Ymd.of(r.start), 0, tz),
            end: Fmt.zonedInstant(Ymd.add(Ymd.of(r.end), 1), 0, tz),
            type: type,
            force: force,
          );
      ref.invalidate(staffDetailProvider(staff.id));
      ref.invalidate(calendarRangeProvider);
      if (context.mounted) showGlowSnack(context, context.l10n.staffTimeOffSaved);
    } on ApiException catch (e) {
      if (!context.mounted) return;
      final clashes = e.data is Map ? ((e.data as Map)['clashes'] as List?)?.length ?? 0 : 0;
      if (e.isConflict && clashes > 0) {
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(ctx.l10n.staffClashes(clashes)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.actionCancel)),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.saveAnyway)),
            ],
          ),
        );
        if (go == true && context.mounted) await _add(context, ref, force: true, range: r, type: type);
      } else {
        showGlowSnack(context, e.message, error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tz = ref.watch(salonTimezoneProvider);
    final fmt = context.fmt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(l.staffTimeOff, action: l.staffAddTimeOff, onAction: () => _add(context, ref)),
        if (staff.timeOff.isEmpty) Text('—', style: context.text.bodySmall),
        for (final t in staff.timeOff)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.beach_access_outlined),
            title: Text('${fmt.dayMonth(t.start, tz)} – ${fmt.dayMonth(t.end.subtract(const Duration(minutes: 1)), tz)}'),
            subtitle: Text(t.reason ?? (t.type == 'SICK' ? l.staffSick : t.type == 'VACATION' ? l.staffVacation : l.staffOther)),
            trailing: IconButton(
              tooltip: l.actionDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () async {
                await ref.read(staffRepositoryProvider).deleteTimeOff(staff.id, t.id);
                ref.invalidate(staffDetailProvider(staff.id));
                ref.invalidate(calendarRangeProvider);
              },
            ),
          ),
      ],
    );
  }
}
