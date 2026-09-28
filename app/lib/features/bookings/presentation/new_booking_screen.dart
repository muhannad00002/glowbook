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
import '../../../shared/animations/animated_success.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/step_flow.dart';
import '../../auth/presentation/auth_layout.dart';
import '../../customers/data/customers_repository.dart';
import '../../services/data/services_repository.dart';
import '../../staff/data/staff_repository.dart';
import '../data/bookings_repository.dart';
import 'booking_detail_sheet.dart';
import 'slot_picker.dart';

/// Front-desk booking wizard: Client → Service → Artist → Date & time → Confirm.
class NewBookingScreen extends ConsumerStatefulWidget {
  const NewBookingScreen({super.key, this.date, this.staffId, this.minute, this.customerId});
  final String? date;
  final String? staffId;
  final int? minute;
  final String? customerId;
  @override
  ConsumerState<NewBookingScreen> createState() => _NewBookingScreenState();
}

class _NewBookingScreenState extends ConsumerState<NewBookingScreen> {
  int _step = 0;
  bool _forward = true;
  int _slotRefresh = 0;

  CustomerSummary? _customer;
  bool _newClient = false;
  final _newName = TextEditingController();
  final _newPhone = TextEditingController();
  final _newEmail = TextEditingController();
  final _search = TextEditingController();
  String _query = '';
  Timer? _debounce;

  Service? _service;
  String? _staffId; // null = any
  Slot? _slot;
  bool _walkIn = false;
  bool _arrived = false;
  bool _notify = true;
  final _notes = TextEditingController();
  Booking? _created;

  @override
  void initState() {
    super.initState();
    _staffId = widget.staffId;
    // Rebuild so "Next" enables as she types a new client's name.
    _newName.addListener(() => setState(() {}));
    if (widget.customerId != null) {
      ref.read(customersRepositoryProvider).profile(widget.customerId!).then((p) {
        if (mounted) {
          setState(() {
            _customer = CustomerSummary(id: p.id, name: p.name, phone: p.phone, email: p.email);
            _step = 1;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_newName, _newPhone, _newEmail, _search, _notes]) {
      c.dispose();
    }
    _debounce?.cancel();
    super.dispose();
  }

  void _go(int step) => setState(() {
        _forward = step > _step;
        _step = step;
      });

  bool get _canNext => switch (_step) {
        0 => _customer != null || (_newClient && _newName.text.trim().length >= 2),
        1 => _service != null,
        2 => true,
        3 => _slot != null,
        _ => true,
      };

  Future<void> _create() async {
    try {
      final b = await ref.read(bookingsRepositoryProvider).create(
            serviceId: _service!.id,
            staffId: _staffId ?? (_slot!.staffIds.length == 1 ? _slot!.staffIds.first : null),
            start: _slot!.start,
            customerId: _newClient ? null : _customer?.id,
            newCustomer: _newClient
                ? {
                    'name': _newName.text.trim(),
                    if (_newPhone.text.trim().isNotEmpty) 'phone': _newPhone.text.trim(),
                    if (_newEmail.text.trim().isNotEmpty) 'email': _newEmail.text.trim(),
                  }
                : null,
            internalNotes: _notes.text.trim(),
            source: _walkIn ? 'WALK_IN' : 'ADMIN',
            status: _arrived ? 'ARRIVED' : 'CONFIRMED',
            notifyCustomer: _notify,
          );
      invalidateBookingViews(ref, b.id);
      ref.invalidate(customerSearchProvider);
      if (mounted) setState(() => _created = b);
    } on ApiException catch (e) {
      if (!mounted) rethrow;
      showGlowSnack(context, e.message, error: true);
      if (e.isConflict) {
        // The slot was just taken: go back to the time step with fresh availability.
        setState(() {
          _slot = null;
          _slotRefresh++;
        });
        _go(3);
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final steps = [l.wizardClient, l.wizardService, l.wizardArtist, l.wizardDateTime, l.wizardConfirm];

    if (_created != null) return _Success(booking: _created!);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.close_rounded), tooltip: l.actionClose, onPressed: () => context.pop()),
        title: Text(l.newBooking),
      ),
      body: ContentWidth(
        maxWidth: 760,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: gutterOf(context)),
              child: StepHeader(steps: steps, current: _step, onTapStep: _go),
            ),
            const SizedBox(height: Space.lg),
            Expanded(
              child: StepSwitcher(
                step: _step,
                forward: _forward,
                child: switch (_step) {
                  0 => _clientStep(),
                  1 => _serviceStep(),
                  2 => _artistStep(),
                  3 => _timeStep(),
                  _ => _confirmStep(),
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(gutterOf(context), Space.sm, gutterOf(context), Space.lg),
          child: ContentWidth(
            maxWidth: 760,
            child: Row(
              children: [
                if (_step > 0) ...[
                  OutlinedButton(onPressed: () => _go(_step - 1), child: Text(l.actionBack)),
                  const SizedBox(width: Space.md),
                ],
                Expanded(
                  child: _step < 4
                      ? AnimatedButton(label: l.actionNext, enabled: _canNext, onPressed: _canNext ? () async => _go(_step + 1) : null)
                      : AnimatedButton(label: l.wizardCreate, icon: Icons.auto_awesome_rounded, keepSuccess: true, onPressed: _create),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _clientStep() {
    final l = context.l10n;
    final results = ref.watch(customerSearchProvider(_query));
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: gutterOf(context)),
      children: [
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: false, label: Text(l.wizardSearchClients.split(' ').first), icon: const Icon(Icons.search_rounded)),
            ButtonSegment(value: true, label: Text(l.wizardNewClient), icon: const Icon(Icons.person_add_alt_1_outlined)),
          ],
          selected: {_newClient},
          onSelectionChanged: (v) => setState(() => _newClient = v.first),
        ),
        const SizedBox(height: Space.lg),
        if (_newClient) ...[
          GlowField(controller: _newName, label: l.authFullName, validator: V(context).required),
          GlowField(controller: _newPhone, label: '${l.authPhone} (${l.labelOptional})', keyboardType: TextInputType.phone, textDirection: TextDirection.ltr),
          GlowField(controller: _newEmail, label: '${l.authEmail} (${l.labelOptional})', keyboardType: TextInputType.emailAddress),
        ] else ...[
          TextField(
            controller: _search,
            decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), labelText: l.wizardSearchClients),
            onChanged: (v) {
              _debounce?.cancel();
              _debounce = Timer(const Duration(milliseconds: 300), () => setState(() => _query = v.trim()));
            },
          ),
          const SizedBox(height: Space.md),
          AsyncView(
            value: results,
            loading: const SkeletonListLite(),
            data: (list) => Column(
              children: [
                for (var i = 0; i < list.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Space.sm),
                    child: StaggeredEntrance(
                      key: ValueKey(list[i].id),
                      index: i,
                      child: OptionCard(
                        selected: _customer?.id == list[i].id,
                        onTap: () => setState(() => _customer = list[i]),
                        leading: InitialsAvatar(name: list[i].name, size: 40),
                        title: list[i].name,
                        subtitle: [list[i].phone, if (list[i].bookingCount > 0) l.calendarBookingsCount(list[i].bookingCount)].whereType<String>().join(' · '),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: Space.xl),
      ],
    );
  }

  Widget _serviceStep() {
    final services = ref.watch(servicesProvider);
    final fmt = context.fmt;
    return AsyncView(
      value: services,
      data: (list) {
        final active = list.where((s) => s.isActive).toList();
        return ListView.separated(
          padding: EdgeInsets.symmetric(horizontal: gutterOf(context), vertical: Space.sm),
          itemCount: active.length,
          separatorBuilder: (_, _) => const SizedBox(height: Space.sm),
          itemBuilder: (_, i) {
            final s = active[i];
            return StaggeredEntrance(
              index: i,
              child: OptionCard(
                selected: _service?.id == s.id,
                onTap: () => setState(() {
                  _service = s;
                  _slot = null;
                  if (_staffId != null && !s.staffIds.contains(_staffId)) _staffId = null;
                }),
                title: s.title(context.lang),
                subtitle: '${fmt.duration(s.durationMinutes)}${s.needsDeposit ? ' · ${context.l10n.bookingDeposit} ${fmt.money(s.depositBaisa)}' : ''}',
                trailing: Text(fmt.money(s.priceBaisa), style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
              ),
            );
          },
        );
      },
    );
  }

  Widget _artistStep() {
    final staff = ref.watch(staffListProvider);
    final l = context.l10n;
    return AsyncView(
      value: staff,
      data: (list) {
        final able = list.where((s) => s.isActive && (_service?.staffIds.contains(s.id) ?? true)).toList();
        return ListView(
          padding: EdgeInsets.symmetric(horizontal: gutterOf(context), vertical: Space.sm),
          children: [
            OptionCard(
              selected: _staffId == null,
              onTap: () => setState(() {
                _staffId = null;
                _slot = null;
              }),
              leading: CircleAvatar(backgroundColor: context.colors.primaryContainer, child: Icon(Icons.auto_awesome_rounded, color: context.colors.primary)),
              title: l.anyArtist,
              subtitle: l.anyArtistBody,
            ),
            const SizedBox(height: Space.sm),
            for (var i = 0; i < able.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.sm),
                child: StaggeredEntrance(
                  index: i + 1,
                  child: OptionCard(
                    selected: _staffId == able[i].id,
                    onTap: () => setState(() {
                      _staffId = able[i].id;
                      _slot = null;
                    }),
                    leading: InitialsAvatar(name: able[i].name, color: hexColor(able[i].color), photoUrl: able[i].photoUrl),
                    title: able[i].displayName(context.lang),
                    subtitle: able[i].displayTitle(context.lang),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _timeStep() {
    final m = ref.watch(membershipProvider)!;
    final tz = m.timezone;
    final repo = ref.read(bookingsRepositoryProvider);
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: gutterOf(context), vertical: Space.sm),
      children: [
        SlotPicker(
          timezone: tz,
          initialDate: widget.date,
          refreshToken: _slotRefresh,
          selected: _slot,
          onSelected: (s) => setState(() => _slot = s),
          loadSlots: (date) async {
            final res = await repo.availability(salonId: m.salonId, serviceId: _service!.id, date: date, staffId: _staffId);
            // Pre-select the tapped calendar time when arriving from the grid.
            if (widget.minute != null && date == widget.date && _slot == null) {
              final hh = (widget.minute! ~/ 60).toString().padLeft(2, '0');
              final mm = (widget.minute! % 60).toString().padLeft(2, '0');
              final match = res.slots.where((s) => s.time == '$hh:$mm').firstOrNull;
              if (match != null) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? setState(() => _slot = match) : null);
            }
            return res.slots;
          },
        ),
        const SizedBox(height: Space.xl),
      ],
    );
  }

  Widget _confirmStep() {
    final l = context.l10n;
    final fmt = context.fmt;
    final tz = ref.watch(salonTimezoneProvider);
    final staff = ref.watch(staffListProvider).valueOrNull ?? const [];
    final artist = _staffId == null
        ? (_slot != null && _slot!.staffIds.length == 1 ? staff.where((s) => s.id == _slot!.staffIds.first).firstOrNull?.displayName(context.lang) : null) ?? l.anyArtist
        : staff.where((s) => s.id == _staffId).firstOrNull?.displayName(context.lang) ?? '';
    final name = _newClient ? _newName.text.trim() : _customer?.name ?? '';
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: gutterOf(context), vertical: Space.sm),
      children: [
        GlowCard(
          gradient: context.glow.heroGradient,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: context.text.headlineSmall),
              const SizedBox(height: Space.sm),
              Text('${_service?.title(context.lang)} · ${fmt.duration(_service?.durationMinutes ?? 0)}', style: context.text.titleMedium),
              Text('$artist · ${_slot == null ? '' : fmt.dateTime(_slot!.start, tz)}', style: context.text.bodyMedium),
              const SizedBox(height: Space.md),
              Text(fmt.money(_service?.priceBaisa ?? 0), style: context.text.headlineSmall?.copyWith(color: context.colors.primary)),
            ],
          ),
        ),
        const SizedBox(height: Space.lg),
        SwitchListTile(value: _walkIn, onChanged: (v) => setState(() => _walkIn = v), title: Text(l.wizardWalkIn), secondary: const Icon(Icons.directions_walk_rounded)),
        SwitchListTile(value: _arrived, onChanged: (v) => setState(() => _arrived = v), title: Text(l.wizardMarkArrived), secondary: const Icon(Icons.waving_hand_outlined)),
        SwitchListTile(value: _notify, onChanged: (v) => setState(() => _notify = v), title: Text(l.wizardNotifyClient), secondary: const Icon(Icons.notifications_active_outlined)),
        const SizedBox(height: Space.md),
        TextField(controller: _notes, maxLines: 3, decoration: InputDecoration(labelText: l.bookingInternalNotes, helperText: l.bookingInternalNotesHint)),
        const SizedBox(height: Space.xl),
      ],
    );
  }
}

class SkeletonListLite extends StatelessWidget {
  const SkeletonListLite({super.key});
  @override
  Widget build(BuildContext context) => const LoadingPad();
}

class _Success extends ConsumerWidget {
  const _Success({required this.booking});
  final Booking booking;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final tz = ref.watch(salonTimezoneProvider);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(Space.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                children: [
                  const AnimatedSuccess(),
                  StaggeredEntrance(index: 6, child: Text(l.wizardCreated, style: context.text.headlineMedium, textAlign: TextAlign.center)),
                  const SizedBox(height: Space.xl),
                  StaggeredEntrance(
                    index: 8,
                    child: GlowCard(
                      child: Column(children: [
                        Text(booking.customer.name, style: context.text.titleLarge),
                        const SizedBox(height: 4),
                        Text('${booking.service.display(context.lang)} · ${booking.staff.display(context.lang)}', style: context.text.bodyMedium),
                        Text(context.fmt.dateTime(booking.start, tz), style: context.text.bodyMedium),
                        const SizedBox(height: Space.sm),
                        Text('${l.bookingReference} ${booking.reference}', style: context.text.bodySmall),
                      ]),
                    ),
                  ),
                  const SizedBox(height: Space.xl),
                  StaggeredEntrance(
                    index: 10,
                    child: Row(children: [
                      Expanded(child: OutlinedButton(onPressed: () => context.pushReplacement('/admin/bookings/new'), child: Text(l.flowBookAnother))),
                      const SizedBox(width: Space.md),
                      Expanded(child: FilledButton(onPressed: () => context.pop(), child: Text(l.actionDone))),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
