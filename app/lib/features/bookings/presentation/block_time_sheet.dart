import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/widgets/common.dart';
import '../../calendar/data/calendar_repository.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../staff/data/staff_repository.dart';
import '../data/bookings_repository.dart';

Future<void> showBlockTimeSheet(BuildContext context, WidgetRef ref, {String? staffId, String? date}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _BlockTimeSheet(staffId: staffId, date: date),
  );
}

class _BlockTimeSheet extends ConsumerStatefulWidget {
  const _BlockTimeSheet({this.staffId, this.date});
  final String? staffId;
  final String? date;
  @override
  ConsumerState<_BlockTimeSheet> createState() => _BlockTimeSheetState();
}

class _BlockTimeSheetState extends ConsumerState<_BlockTimeSheet> {
  String? _staffId;
  late String _date;
  int _start = 13 * 60;
  int _end = 14 * 60;
  String _type = 'LUNCH';

  @override
  void initState() {
    super.initState();
    final m = ref.read(membershipProvider);
    _staffId = m?.role == 'STAFF' ? m!.staffId : widget.staffId;
    _date = widget.date ?? Ymd.today(ref.read(salonTimezoneProvider));
  }

  Future<void> _pickTime(bool start) async {
    final current = start ? _start : _end;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60));
    if (t == null) return;
    setState(() {
      final v = t.hour * 60 + t.minute;
      if (start) {
        _start = v;
        if (_end <= _start) _end = _start + 30;
      } else {
        _end = v;
      }
    });
  }

  Future<void> _save({bool force = false}) async {
    final tz = ref.read(salonTimezoneProvider);
    DateTime at(int minute) => Fmt.zonedInstant(_date, minute, tz);

    try {
      await ref.read(bookingsRepositoryProvider).blockTime(staffId: _staffId, start: at(_start), end: at(_end), type: _type, force: force);
    } on ApiException catch (e) {
      if (e.isConflict && !force && mounted) {
        final go = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            content: Text(e.message),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(ctx.l10n.actionCancel)),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ctx.l10n.saveAnyway)),
            ],
          ),
        );
        if (go == true) return _save(force: true);
      }
      if (mounted) showGlowSnack(context, e.message, error: true);
      rethrow;
    }
    ref.invalidate(calendarRangeProvider);
    ref.invalidate(dashboardProvider);
    if (mounted) {
      showGlowSnack(context, context.l10n.blockSaved);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final m = ref.watch(membershipProvider);
    final staff = m?.role == 'STAFF' ? null : ref.watch(staffListProvider).valueOrNull;
    final types = {
      'LUNCH': (l.blockLunch, Icons.restaurant_rounded),
      'BREAK': (l.blockBreak, Icons.coffee_rounded),
      'PERSONAL': (l.blockPersonal, Icons.self_improvement_rounded),
      'MEETING': (l.blockMeeting, Icons.groups_outlined),
      'PRIVATE_BOOKING': (l.blockPrivate, Icons.lock_outline_rounded),
      'OTHER': (l.blockOther, Icons.more_horiz_rounded),
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, MediaQuery.viewInsetsOf(context).bottom + Space.xl),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l.blockTitle, style: context.text.headlineSmall),
            const SizedBox(height: Space.lg),
            if (staff != null) ...[
              Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
                if (m?.isAdmin ?? false)
                  ChoiceChip(label: Text(l.blockWholeSalon), selected: _staffId == null, onSelected: (_) => setState(() => _staffId = null)),
                for (final s in staff.where((s) => s.isActive))
                  ChoiceChip(
                    avatar: CircleAvatar(backgroundColor: hexColor(s.color), radius: 6),
                    label: Text(s.displayName(context.lang)),
                    selected: _staffId == s.id,
                    onSelected: (_) => setState(() => _staffId = s.id),
                  ),
              ]),
              const SizedBox(height: Space.lg),
            ],
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: Text(fmt.ymdLabel(_date, pattern: 'yMMMMEEEEd')),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: Ymd.parse(_date),
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (d != null) setState(() => _date = Ymd.of(d));
              },
            ),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => _pickTime(true), child: Text('${l.blockStart} · ${fmt.minuteOfDay(_start)}'))),
              const SizedBox(width: Space.md),
              Expanded(child: OutlinedButton(onPressed: () => _pickTime(false), child: Text('${l.blockEnd} · ${fmt.minuteOfDay(_end)}'))),
            ]),
            const SizedBox(height: Space.lg),
            Text(l.blockType, style: context.text.labelMedium),
            const SizedBox(height: Space.sm),
            Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
              for (final t in types.entries)
                ChoiceChip(avatar: Icon(t.value.$2, size: 16), label: Text(t.value.$1), selected: _type == t.key, onSelected: (_) => setState(() => _type = t.key)),
            ]),
            const SizedBox(height: Space.xl),
            AnimatedButton(label: l.blockTitle, icon: Icons.block_rounded, onPressed: _end > _start ? () => _save() : null, keepSuccess: true),
          ],
        ),
      ),
    );
  }
}
