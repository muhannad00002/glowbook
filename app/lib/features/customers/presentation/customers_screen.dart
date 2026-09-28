import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/animations/animated_counter.dart';
import '../../../shared/animations/animated_empty_state.dart';
import '../../../shared/animations/glow_illustration.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/booking_tile.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/presentation/auth_layout.dart';
import '../../bookings/presentation/booking_detail_sheet.dart';
import '../../staff/data/staff_repository.dart';
import '../data/customers_repository.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key, this.openNew = false});
  final bool openNew;
  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  String _q = '';
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (widget.openNew) WidgetsBinding.instance.addPostFrameCallback((_) => showCustomerForm(context, ref));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final list = ref.watch(customerSearchProvider(_q));
    final canEdit = ref.watch(membershipProvider)?.isFrontDesk ?? false;
    final base = ref.watch(membershipProvider)?.role == 'STAFF' ? '/staff' : '/admin';
    final g = gutterOf(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ContentWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(g, Space.lg, g, Space.md),
                child: Row(children: [
                  Expanded(child: Text(l.customersTitle, style: context.text.headlineMedium)),
                  if (canEdit) FilledButton.tonalIcon(onPressed: () => showCustomerForm(context, ref), icon: const Icon(Icons.person_add_alt_1_outlined), label: Text(l.customerAdd)),
                ]),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: g),
                child: TextField(
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), labelText: l.customersSearch),
                  onChanged: (v) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 300), () => setState(() => _q = v.trim()));
                  },
                ),
              ),
              const SizedBox(height: Space.md),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => ref.refresh(customerSearchProvider(_q).future),
                  child: AsyncView(
                    value: list,
                    onRetry: () => ref.invalidate(customerSearchProvider(_q)),
                    data: (items) => items.isEmpty
                        ? ListView(children: [
                            AnimatedEmptyState(
                              art: GlowArt.lipstick,
                              title: l.customersEmptyTitle,
                              body: l.customersEmptyBody,
                              action: canEdit ? FilledButton.icon(onPressed: () => showCustomerForm(context, ref), icon: const Icon(Icons.add_rounded), label: Text(l.customerAdd)) : null,
                            ),
                          ])
                        : ListView.separated(
                            padding: EdgeInsets.fromLTRB(g, Space.sm, g, 120),
                            itemCount: items.length,
                            separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
                            itemBuilder: (_, i) {
                              final c = items[i];
                              return StaggeredEntrance(
                                key: ValueKey(c.id),
                                index: i,
                                child: GlowCard(
                                  onTap: () => context.push('$base/clients/${c.id}'),
                                  padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
                                  child: Row(children: [
                                    InitialsAvatar(name: c.name),
                                    const SizedBox(width: Space.lg),
                                    Expanded(
                                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                        Text(c.name, style: context.text.titleMedium),
                                        Text(
                                          [c.phone, l.calendarBookingsCount(c.bookingCount)].whereType<String>().join(' · '),
                                          style: context.text.bodySmall,
                                        ),
                                      ]),
                                    ),
                                    if (c.totalSpentBaisa > 0) Text(fmt.money(c.totalSpentBaisa), style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
                                    const SizedBox(width: Space.xs),
                                    Icon(Icons.chevron_right_rounded, color: context.colors.onSurfaceVariant),
                                  ]),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Add / edit client sheet. Returns the new client's id when creating.
Future<String?> showCustomerForm(BuildContext context, WidgetRef ref, {CustomerProfile? existing}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CustomerForm(existing: existing),
  );
}

class _CustomerForm extends ConsumerStatefulWidget {
  const _CustomerForm({this.existing});
  final CustomerProfile? existing;
  @override
  ConsumerState<_CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends ConsumerState<_CustomerForm> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name);
  late final _phone = TextEditingController(text: widget.existing?.phone);
  late final _email = TextEditingController(text: widget.existing?.email);
  late final _notes = TextEditingController(text: widget.existing?.notes);
  late String? _birthday = widget.existing?.birthday;
  late String? _preferred = widget.existing?.preferredStaffId;

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) throw StateError('invalid');
    final body = {
      'name': _name.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      'birthday': _birthday,
      'preferredStaffId': _preferred,
    };
    final repo = ref.read(customersRepositoryProvider);
    try {
      String? id;
      if (widget.existing == null) {
        id = await repo.create(body);
      } else {
        await repo.update(widget.existing!.id, body);
        ref.invalidate(customerProfileProvider(widget.existing!.id));
      }
      ref.invalidate(customerSearchProvider);
      if (mounted) {
        showGlowSnack(context, context.l10n.customerSaved);
        Navigator.pop(context, id);
      }
    } on ApiException catch (e) {
      if (mounted) showGlowSnack(context, e.message, error: true);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = V(context);
    final staff = ref.watch(staffListProvider).valueOrNull ?? const [];
    return Padding(
      padding: EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, MediaQuery.viewInsetsOf(context).bottom + Space.xl),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.existing == null ? l.customerAdd : l.customerEdit, style: context.text.headlineSmall),
              const SizedBox(height: Space.lg),
              GlowField(controller: _name, label: l.authFullName, validator: v.required),
              GlowField(controller: _phone, label: l.authPhone, keyboardType: TextInputType.phone, validator: v.optionalPhone, textDirection: TextDirection.ltr),
              GlowField(controller: _email, label: '${l.authEmail} (${l.labelOptional})', keyboardType: TextInputType.emailAddress),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.cake_outlined),
                title: Text(l.customerBirthday),
                subtitle: Text(_birthday == null ? '—' : context.fmt.ymdLabel(_birthday!, pattern: 'yMMMMd')),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _birthday == null ? DateTime(1995) : Ymd.parse(_birthday!),
                    firstDate: DateTime(1930),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setState(() => _birthday = Ymd.of(d));
                },
              ),
              if (staff.isNotEmpty) ...[
                const SizedBox(height: Space.sm),
                Text(l.customerPreferredArtist, style: context.text.labelMedium),
                const SizedBox(height: Space.sm),
                Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
                  for (final s in staff.where((s) => s.isActive))
                    ChoiceChip(
                      avatar: CircleAvatar(radius: 6, backgroundColor: hexColor(s.color)),
                      label: Text(s.displayName(context.lang)),
                      selected: _preferred == s.id,
                      onSelected: (sel) => setState(() => _preferred = sel ? s.id : null),
                    ),
                ]),
                const SizedBox(height: Space.lg),
              ],
              GlowField(controller: _notes, label: l.customerPrivateNotes, helper: l.customerPrivateNotesHint, maxLines: 3, prefixIcon: Icons.lock_outline_rounded),
              AnimatedButton(label: l.actionSave, onPressed: _save, keepSuccess: true),
            ],
          ),
        ),
      ),
    );
  }
}

class CustomerProfileScreen extends ConsumerWidget {
  const CustomerProfileScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(customerProfileProvider(id));
    final canEdit = ref.watch(membershipProvider)?.isFrontDesk ?? false;
    return Scaffold(
      appBar: AppBar(actions: [
        if (canEdit && profile.hasValue)
          IconButton(tooltip: context.l10n.customerEdit, icon: const Icon(Icons.edit_outlined), onPressed: () => showCustomerForm(context, ref, existing: profile.value)),
      ]),
      body: AsyncView(
        value: profile,
        onRetry: () => ref.invalidate(customerProfileProvider(id)),
        data: (p) => _ProfileBody(profile: p, canEdit: canEdit),
      ),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.profile, required this.canEdit});
  final CustomerProfile profile;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final fmt = context.fmt;
    final tz = ref.watch(salonTimezoneProvider);
    final g = gutterOf(context);
    final p = profile;
    return ListView(
      padding: EdgeInsets.fromLTRB(g, 0, g, 120),
      children: [
        ContentWidth(
          maxWidth: 820,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StaggeredEntrance(
                index: 0,
                child: GlowCard(
                  gradient: context.glow.heroGradient,
                  child: Row(children: [
                    Hero(tag: 'client-${p.id}', child: InitialsAvatar(name: p.name, size: 64)),
                    const SizedBox(width: Space.lg),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, style: context.text.headlineSmall),
                        if (p.phone != null) Text(p.phone!, style: context.text.bodyMedium, textDirection: TextDirection.ltr),
                        if (p.email != null) Text(p.email!, style: context.text.bodySmall),
                        if (p.birthday != null)
                          Row(children: [
                            Icon(Icons.cake_outlined, size: 14, color: context.colors.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text(fmt.ymdLabel(p.birthday!, pattern: 'MMMMd'), style: context.text.bodySmall),
                          ]),
                      ]),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: Space.lg),
              LayoutBuilder(builder: (context, c) {
                final w = (c.maxWidth - Space.md) / 2;
                final tiles = [
                  StatTile(label: l.customerTotalSpent, icon: Icons.payments_outlined, value: AnimatedCounter(value: p.totalSpentBaisa, format: (v) => fmt.money(v.round()))),
                  StatTile(label: l.customerVisits, icon: Icons.favorite_border_rounded, value: AnimatedCounter(value: p.visits)),
                  StatTile(label: l.customerLastVisit, icon: Icons.history_rounded, value: Text(p.lastVisitAt == null ? l.customerNever : fmt.relativeDay(p.lastVisitAt!, tz))),
                  StatTile(label: l.customerFavoriteService, icon: Icons.spa_outlined, value: Text(p.favoriteService ?? '—', maxLines: 1, overflow: TextOverflow.ellipsis)),
                ];
                return Wrap(spacing: Space.md, runSpacing: Space.md, children: [
                  for (var i = 0; i < tiles.length; i++) SizedBox(width: c.maxWidth >= 700 ? (c.maxWidth - Space.md * 3) / 4 : w, child: StaggeredEntrance(index: i + 1, child: tiles[i])),
                ]);
              }),
              if (p.noShows > 0 || p.cancellations > 0) ...[
                const SizedBox(height: Space.md),
                Text('${l.customerCancellations}: ${p.cancellations} · ${l.customerNoShows}: ${p.noShows}', style: context.text.bodySmall),
              ],
              if (p.notes != null) ...[
                const SizedBox(height: Space.lg),
                GlowCard(
                  color: context.colors.tertiaryContainer,
                  elevated: false,
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Icon(Icons.lock_outline_rounded, size: 18, color: context.colors.onTertiaryContainer),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(l.customerPrivateNotes, style: context.text.labelMedium),
                        const SizedBox(height: 4),
                        Text(p.notes!, style: context.text.bodyMedium),
                      ]),
                    ),
                  ]),
                ),
              ],
              if (canEdit) ...[
                const SizedBox(height: Space.lg),
                AnimatedButton(
                  label: l.customerBookNow,
                  icon: Icons.add_rounded,
                  onPressed: () async => context.push('/admin/bookings/new?customer=${p.id}'),
                ),
              ],
              if (p.upcoming != null) ...[
                const SizedBox(height: Space.xl),
                SectionHeader(l.customerUpcoming),
                BookingTile(booking: p.upcoming!, timezone: tz, showDate: true, onTap: () => showBookingDetail(context, p.upcoming!.id)),
              ],
              const SizedBox(height: Space.xl),
              SectionHeader(l.customerHistory),
              if (p.history.isEmpty)
                Text('—', style: context.text.bodySmall)
              else
                for (var i = 0; i < p.history.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: AnimatedBookingCard(
                      key: ValueKey(p.history[i].id),
                      index: i,
                      booking: p.history[i],
                      timezone: tz,
                      showDate: true,
                      onTap: () => showBookingDetail(context, p.history[i].id),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}
