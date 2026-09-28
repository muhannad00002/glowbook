import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/animations/animated_empty_state.dart';
import '../../../shared/animations/glow_illustration.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';
import '../../auth/presentation/auth_layout.dart';
import '../../staff/data/staff_repository.dart';
import '../data/services_repository.dart';

class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final services = ref.watch(servicesProvider);
    final categories = ref.watch(serviceCategoriesProvider).valueOrNull ?? const [];
    final canEdit = ref.watch(membershipProvider)?.isAdmin ?? false;
    final g = gutterOf(context);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => ref.refresh(servicesProvider.future),
          child: AsyncView(
            value: services,
            onRetry: () => ref.invalidate(servicesProvider),
            data: (list) {
              final groups = <String?, List<Service>>{};
              for (final s in list) {
                groups.putIfAbsent(s.categoryId, () => []).add(s);
              }
              final ordered = [
                ...categories.where((c) => groups.containsKey(c.id)).map((c) => (c.title(context.lang), groups[c.id]!)),
                if (groups.containsKey(null)) (l.serviceUncategorized, groups[null]!),
              ];
              var index = 0;
              return ListView(
                padding: EdgeInsets.fromLTRB(g, Space.lg, g, 120),
                children: [
                  ContentWidth(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Expanded(child: Text(l.servicesTitle, style: context.text.headlineMedium)),
                          if (canEdit) FilledButton.tonalIcon(onPressed: () => context.push('/admin/services/new'), icon: const Icon(Icons.add_rounded), label: Text(l.serviceAdd)),
                        ]),
                        const SizedBox(height: Space.lg),
                        if (list.isEmpty)
                          AnimatedEmptyState(
                            art: GlowArt.brush,
                            title: l.serviceEmptyTitle,
                            body: l.serviceEmptyBody,
                            action: canEdit ? FilledButton.icon(onPressed: () => context.push('/admin/services/new'), icon: const Icon(Icons.add_rounded), label: Text(l.serviceAdd)) : null,
                          ),
                        for (final (title, items) in ordered) ...[
                          SectionHeader(title),
                          LayoutBuilder(builder: (context, c) {
                            final cols = c.maxWidth >= 900 ? 3 : c.maxWidth >= 560 ? 2 : 1;
                            final w = (c.maxWidth - Space.md * (cols - 1)) / cols;
                            return Wrap(spacing: Space.md, runSpacing: Space.md, children: [
                              for (final s in items)
                                SizedBox(
                                  width: w,
                                  child: StaggeredEntrance(
                                    key: ValueKey(s.id),
                                    index: index++,
                                    child: _ServiceCard(service: s, onTap: canEdit ? () => context.push('/admin/services/${s.id}') : null),
                                  ),
                                ),
                            ]);
                          }),
                          const SizedBox(height: Space.lg),
                        ],
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service, this.onTap});
  final Service service;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final l = context.l10n;
    return GlowCard(
      onTap: onTap,
      child: Opacity(
        opacity: service.isActive ? 1 : 0.55,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(child: Text(service.title(context.lang), style: context.text.titleMedium)),
              Text(fmt.money(service.priceBaisa), style: context.text.titleMedium?.copyWith(color: context.colors.primary)),
            ]),
            if (service.blurb(context.lang) != null) ...[
              const SizedBox(height: 4),
              Text(service.blurb(context.lang)!, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
            ],
            const SizedBox(height: Space.md),
            Wrap(spacing: Space.sm, runSpacing: Space.xs, children: [
              _Tag(icon: Icons.schedule_rounded, text: fmt.duration(service.durationMinutes)),
              if (service.bufferMinutes > 0) _Tag(icon: Icons.cleaning_services_outlined, text: '+${fmt.duration(service.bufferMinutes)}'),
              if (service.needsDeposit) _Tag(icon: Icons.lock_clock_outlined, text: '${l.bookingDeposit} ${fmt.money(service.depositBaisa)}', tint: context.colors.secondary),
              if (service.needsFull) _Tag(icon: Icons.credit_card_rounded, text: l.servicePayFull, tint: context.colors.secondary),
              if (!service.isActive) _Tag(icon: Icons.visibility_off_outlined, text: l.serviceInactive),
            ]),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text, this.tint});
  final IconData icon;
  final String text;
  final Color? tint;
  @override
  Widget build(BuildContext context) {
    final c = tint ?? context.colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: Radii.pillAll),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: c),
        const SizedBox(width: 4),
        Text(text, style: context.text.labelSmall?.copyWith(color: c)),
      ]),
    );
  }
}

class ServiceFormScreen extends ConsumerStatefulWidget {
  const ServiceFormScreen({super.key, this.id});
  final String? id;
  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nameAr = TextEditingController();
  final _desc = TextEditingController();
  final _descAr = TextEditingController();
  final _price = TextEditingController();
  final _duration = TextEditingController(text: '60');
  final _buffer = TextEditingController(text: '15');
  final _deposit = TextEditingController();
  String? _categoryId;
  String _payment = 'NONE';
  bool _active = true;
  Set<String> _staff = {};
  bool _loaded = false;

  @override
  void dispose() {
    for (final c in [_name, _nameAr, _desc, _descAr, _price, _duration, _buffer, _deposit]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Service s) {
    if (_loaded) return;
    _loaded = true;
    _name.text = s.name;
    _nameAr.text = s.nameAr ?? '';
    _desc.text = s.description ?? '';
    _descAr.text = s.descriptionAr ?? '';
    _price.text = (s.priceBaisa / 1000).toString().replaceFirst(RegExp(r'\.0$'), '');
    _duration.text = '${s.durationMinutes}';
    _buffer.text = '${s.bufferMinutes}';
    _deposit.text = s.depositBaisa > 0 ? (s.depositBaisa / 1000).toString().replaceFirst(RegExp(r'\.0$'), '') : '';
    _categoryId = s.categoryId;
    _payment = s.paymentRequirement;
    _active = s.isActive;
    _staff = s.staffIds.toSet();
  }

  int _baisa(TextEditingController c) => ((double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0) * 1000).round();

  Future<void> _save() async {
    if (!_form.currentState!.validate()) throw StateError('invalid');
    final body = {
      'name': _name.text.trim(),
      'nameAr': _nameAr.text.trim().isEmpty ? null : _nameAr.text.trim(),
      'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      'descriptionAr': _descAr.text.trim().isEmpty ? null : _descAr.text.trim(),
      'categoryId': _categoryId,
      'priceBaisa': _baisa(_price),
      'durationMinutes': int.parse(_duration.text.trim()),
      'bufferMinutes': int.tryParse(_buffer.text.trim()) ?? 0,
      'isActive': _active,
      'paymentRequirement': _payment,
      'depositBaisa': _payment == 'DEPOSIT' ? _baisa(_deposit) : 0,
      'staffIds': _staff.toList(),
    };
    final repo = ref.read(servicesRepositoryProvider);
    await guard(context, () => widget.id == null ? repo.create(body) : repo.update(widget.id!, body));
    ref.invalidate(servicesProvider);
    ref.invalidate(staffListProvider);
    if (mounted) {
      showGlowSnack(context, context.l10n.serviceSaved);
      context.pop();
    }
  }

  Future<void> _delete() async {
    final l = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(l.serviceDeleteConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(l.actionCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(l.actionDelete)),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await guard(context, () => ref.read(servicesRepositoryProvider).delete(widget.id!));
    ref.invalidate(servicesProvider);
    if (mounted) context.pop();
  }

  Future<void> _addCategory() async {
    final c = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.serviceCategory),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(ctx.l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(ctx.l10n.actionAdd)),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    await ref.read(servicesRepositoryProvider).createCategory(name, null);
    ref.invalidate(serviceCategoriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = V(context);
    if (widget.id != null) {
      final s = ref.watch(servicesProvider).valueOrNull?.where((s) => s.id == widget.id).firstOrNull;
      if (s == null) return const Scaffold(body: LoadingPad());
      _fill(s);
    }
    final categories = ref.watch(serviceCategoriesProvider).valueOrNull ?? const [];
    final staff = ref.watch(staffListProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.id == null ? l.serviceAdd : l.serviceEdit),
        actions: [if (widget.id != null) IconButton(tooltip: l.actionDelete, icon: const Icon(Icons.delete_outline_rounded), onPressed: _delete)],
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
                  GlowField(controller: _name, label: l.serviceName, validator: v.required),
                  GlowField(controller: _nameAr, label: l.serviceNameAr, textDirection: TextDirection.rtl),
                  Row(children: [
                    Expanded(child: GlowField(controller: _price, label: l.servicePrice, keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: v.number)),
                    const SizedBox(width: Space.md),
                    Expanded(child: GlowField(controller: _duration, label: l.serviceDuration, keyboardType: TextInputType.number, validator: v.number)),
                  ]),
                  GlowField(controller: _buffer, label: l.serviceBuffer, helper: l.serviceBufferHelp, keyboardType: TextInputType.number),
                  Text(l.serviceCategory, style: context.text.labelMedium),
                  const SizedBox(height: Space.sm),
                  Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
                    for (final c in categories)
                      ChoiceChip(label: Text(c.title(context.lang)), selected: _categoryId == c.id, onSelected: (s) => setState(() => _categoryId = s ? c.id : null)),
                    ActionChip(avatar: const Icon(Icons.add_rounded, size: 16), label: Text(l.actionAdd), onPressed: _addCategory),
                  ]),
                  const SizedBox(height: Space.lg),
                  GlowField(controller: _desc, label: l.serviceDescription, maxLines: 3),
                  GlowField(controller: _descAr, label: l.serviceDescriptionAr, maxLines: 3, textDirection: TextDirection.rtl),
                  Text(l.servicePayment, style: context.text.labelMedium),
                  const SizedBox(height: Space.sm),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(value: 'NONE', label: Text(l.servicePayNone)),
                      ButtonSegment(value: 'DEPOSIT', label: Text(l.servicePayDeposit)),
                      ButtonSegment(value: 'FULL', label: Text(l.servicePayFull)),
                    ],
                    selected: {_payment},
                    onSelectionChanged: (s) => setState(() => _payment = s.first),
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 250),
                    child: _payment == 'DEPOSIT'
                        ? Padding(
                            padding: const EdgeInsets.only(top: Space.lg),
                            child: GlowField(controller: _deposit, label: l.serviceDepositAmount, keyboardType: const TextInputType.numberWithOptions(decimal: true), validator: v.number),
                          )
                        : const SizedBox(width: double.infinity, height: Space.lg),
                  ),
                  Text(l.serviceWhoPerforms, style: context.text.labelMedium),
                  const SizedBox(height: Space.sm),
                  Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
                    for (final s in staff.where((s) => s.isActive))
                      FilterChip(
                        avatar: CircleAvatar(radius: 6, backgroundColor: hexColor(s.color)),
                        label: Text(s.displayName(context.lang)),
                        selected: _staff.contains(s.id),
                        onSelected: (sel) => setState(() => sel ? _staff.add(s.id) : _staff.remove(s.id)),
                      ),
                  ]),
                  const SizedBox(height: Space.lg),
                  SwitchListTile(contentPadding: EdgeInsets.zero, value: _active, onChanged: (v) => setState(() => _active = v), title: Text(l.serviceActive)),
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
