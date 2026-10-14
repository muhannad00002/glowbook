import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../../../shared/widgets/salon_cover.dart';
import '../../seasonal/data/seasonal_repository.dart';
import '../../seasonal/presentation/token_widgets.dart';
import '../data/salon_repository.dart';

/// Public salon page — the shareable booking link (/salon/maison-beauty).
/// Works without an account.
class SalonPageScreen extends ConsumerWidget {
  const SalonPageScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(salonProfileProvider(slug));
    return Scaffold(
      body: AsyncView(
        value: profile,
        onRetry: () => ref.invalidate(salonProfileProvider(slug)),
        data: (p) => _SalonBody(profile: p),
      ),
    );
  }
}

class _SalonBody extends ConsumerStatefulWidget {
  const _SalonBody({required this.profile});
  final SalonProfile profile;
  @override
  ConsumerState<_SalonBody> createState() => _SalonBodyState();
}

class _SalonBodyState extends ConsumerState<_SalonBody> {
  late bool _fav = widget.profile.card.isFavorite;

  Future<void> _open(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && mounted) {
      showGlowSnack(context, context.l10n.errorGeneric, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final l = context.l10n;
    final fmt = context.fmt;
    final lang = context.lang;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= Breakpoints.desktop;
    final g = gutterOf(context);
    final signedIn = ref.watch(authControllerProvider).valueOrNull != null;
    final today = Ymd.dayOfWeek(Ymd.today(p.timezone));
    final todayHours = p.hours.where((h) => h.dayOfWeek == today).firstOrNull;

    void book([String? serviceId]) => context.push('/salon/${p.card.slug}/book${serviceId == null ? '' : '?service=$serviceId'}');

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        StaggeredEntrance(index: 0, child: Text(p.card.title(lang), style: context.text.displaySmall)),
        if (p.card.subtitle(lang) != null) StaggeredEntrance(index: 1, child: Text(p.card.subtitle(lang)!, style: context.text.titleMedium?.copyWith(color: context.colors.onSurfaceVariant))),
        const SizedBox(height: Space.md),
        StaggeredEntrance(
          index: 2,
          child: Wrap(spacing: Space.lg, runSpacing: Space.sm, crossAxisAlignment: WrapCrossAlignment.center, children: [
            if (p.card.ratingCount > 0)
              Row(mainAxisSize: MainAxisSize.min, children: [
                RatingStars(rating: p.card.ratingAvg),
                const SizedBox(width: 6),
                Text('${p.card.ratingAvg.toStringAsFixed(1)} · ${l.reviewsCount(p.card.ratingCount)}', style: context.text.labelMedium),
              ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.schedule_rounded, size: 16, color: todayHours != null ? context.colors.tertiary : context.colors.error),
              const SizedBox(width: 4),
              Text(
                todayHours != null ? l.salonOpenNow('${fmt.minuteOfDay(todayHours.startMinute)} – ${fmt.minuteOfDay(todayHours.endMinute)}') : l.salonClosedToday,
                style: context.text.labelMedium,
              ),
            ]),
          ]),
        ),
        const SizedBox(height: Space.lg),
        StaggeredEntrance(
          index: 3,
          child: Wrap(spacing: Space.sm, runSpacing: Space.sm, children: [
            if (p.phone != null) OutlinedButton.icon(onPressed: () => _open(Uri.parse('tel:${p.phone}')), icon: const Icon(Icons.call_outlined), label: Text(l.salonCall)),
            if (p.whatsapp != null)
              OutlinedButton.icon(onPressed: () => _open(Uri.parse('https://wa.me/${p.whatsapp!.replaceAll(RegExp(r'\D'), '')}')), icon: const Icon(Icons.chat_outlined), label: Text(l.salonWhatsapp)),
            if (p.latitude != null && p.longitude != null)
              OutlinedButton.icon(
                onPressed: () => _open(Uri.parse('https://www.google.com/maps/search/?api=1&query=${p.latitude},${p.longitude}')),
                icon: const Icon(Icons.directions_outlined),
                label: Text(l.salonDirections),
              ),
            if (signedIn)
              OutlinedButton.icon(
                onPressed: () async {
                  setState(() => _fav = !_fav);
                  try {
                    await ref.read(salonRepositoryProvider).setFavorite(p.card.id, _fav);
                    ref.invalidate(favoritesProvider);
                  } catch (_) {
                    if (mounted) setState(() => _fav = !_fav);
                  }
                },
                icon: Icon(_fav ? Icons.favorite_rounded : Icons.favorite_border_rounded, color: _fav ? context.colors.primary : null),
                label: Text(_fav ? l.salonSaved : l.salonSave),
              ),
          ]),
        ),
      ],
    );

    final seasonal = ref.watch(salonSeasonalEventsProvider(p.card.slug)).valueOrNull ?? const <SeasonalEvent>[];
    final banners = Column(children: [for (final e in seasonal) SeasonalBanner(slug: p.card.slug, event: e)]);
    final services = _ServicesBlock(profile: p, onBook: book);
    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (p.about(lang) != null) _Card(title: l.salonAbout, child: Text(p.about(lang)!, style: context.text.bodyMedium)),
        if (p.staff.isNotEmpty)
          _Card(
            title: l.salonTeam,
            child: Wrap(spacing: Space.lg, runSpacing: Space.lg, children: [
              for (final s in p.staff)
                SizedBox(
                  width: 92,
                  child: Column(children: [
                    InitialsAvatar(name: s.name, color: hexColor(s.color), size: 60, photoUrl: s.photoUrl),
                    const SizedBox(height: 6),
                    Text(s.displayName(lang), style: context.text.titleSmall, textAlign: TextAlign.center),
                    if (s.displayTitle(lang) != null) Text(s.displayTitle(lang)!, style: context.text.bodySmall, textAlign: TextAlign.center, maxLines: 2),
                  ]),
                ),
            ]),
          ),
        _Card(
          title: l.salonHours,
          child: Column(children: [
            for (final dow in [6, 0, 1, 2, 3, 4, 5])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(children: [
                  Expanded(child: Text(fmt.weekdayName(dow), style: dow == today ? context.text.titleSmall : context.text.bodyMedium)),
                  Text(
                    p.hours.where((h) => h.dayOfWeek == dow).map((h) => '${fmt.minuteOfDay(h.startMinute)} – ${fmt.minuteOfDay(h.endMinute)}').firstOrNull ?? l.settingsClosed,
                    style: dow == today ? context.text.titleSmall : context.text.bodyMedium,
                  ),
                ]),
              ),
            if (p.closures.isNotEmpty) ...[
              const Divider(height: Space.xl),
              Align(alignment: AlignmentDirectional.centerStart, child: Text(l.salonUpcomingClosures, style: context.text.labelMedium)),
              for (final c in p.closures.take(3))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(children: [
                    Expanded(child: Text(c.name, style: context.text.bodySmall)),
                    Text(fmt.ymdLabel(c.date), style: context.text.bodySmall),
                  ]),
                ),
            ],
          ]),
        ),
        if (p.place(lang) != null)
          _Card(
            title: l.salonLocation,
            child: Row(children: [
              Icon(Icons.location_on_outlined, color: context.colors.primary),
              const SizedBox(width: Space.sm),
              Expanded(child: Text(p.place(lang)!, style: context.text.bodyMedium)),
            ]),
          ),
        _Card(
          title: l.flowPolicy,
          child: Text(
            [
              l.flowPolicyFree(p.cancellationWindowHours),
              if (p.depositPolicy == 'NON_REFUNDABLE' || p.lateCancellationFeeBaisa > 0) l.flowPolicyDeposit,
              if (p.lateCancellationFeeBaisa > 0) l.flowPolicyFee(fmt.money(p.lateCancellationFeeBaisa)),
            ].join(' '),
            style: context.text.bodyMedium,
          ),
        ),
      ],
    );

    final reviews = _Card(
      title: '${l.salonReviews} · ${l.reviewsCount(p.card.ratingCount)}',
      child: p.reviews.isEmpty
          ? AnimatedEmptyState(art: GlowArt.sparkles, title: l.reviewsEmpty, compact: true)
          : Column(children: [
              for (final r in p.reviews)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.lg),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      InitialsAvatar(name: r.customerName, size: 34),
                      const SizedBox(width: Space.sm),
                      Expanded(child: Text(r.customerName, style: context.text.titleSmall)),
                      RatingStars(rating: r.rating.toDouble(), size: 14),
                    ]),
                    if (r.comment != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text(r.comment!, style: context.text.bodyMedium)),
                    if (r.serviceName != null) Padding(padding: const EdgeInsets.only(top: 2), child: Text(r.serviceName!, style: context.text.bodySmall)),
                    if (r.reply != null)
                      Container(
                        margin: const EdgeInsets.only(top: Space.sm),
                        padding: const EdgeInsets.all(Space.md),
                        decoration: BoxDecoration(color: context.colors.surfaceContainerLow, borderRadius: Radii.mdAll),
                        child: Text('${l.reviewsSalonReply}: ${r.reply}', style: context.text.bodySmall),
                      ),
                  ]),
                ),
            ]),
    );

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: wide ? 320 : 240,
              pinned: true,
              stretch: true,
              leading: Padding(
                padding: const EdgeInsets.all(6),
                child: CircleAvatar(
                  backgroundColor: context.colors.surface.withValues(alpha: 0.85),
                  child: IconButton(
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    icon: const BackButtonIcon(),
                    onPressed: () => context.canPop() ? context.pop() : context.go(signedIn ? '/' : '/discover'),
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: Hero(
                  tag: 'salon-cover-${p.card.slug}',
                  child: SalonCover(name: p.card.name, imageUrl: p.card.coverUrl, height: wide ? 360 : 280, monogramSize: 96),
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(g, Space.xl, g, 140),
              sliver: SliverToBoxAdapter(
                child: ContentWidth(
                  child: wide
                      ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, const SizedBox(height: Space.xl), banners, services, reviews])),
                          const SizedBox(width: Space.xxl),
                          Expanded(flex: 2, child: side),
                        ])
                      : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [header, const SizedBox(height: Space.xl), banners, services, side, reviews]),
                ),
              ),
            ),
          ],
        ),
        // Sticky "Book appointment".
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(g, 0, g, Space.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: AnimatedButton(label: l.salonBook, icon: Icons.auto_awesome_rounded, onPressed: () async => book()),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ServicesBlock extends StatelessWidget {
  const _ServicesBlock({required this.profile, required this.onBook});
  final SalonProfile profile;
  final void Function(String serviceId) onBook;

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final fmt = context.fmt;
    final l = context.l10n;
    final byCat = <String?, List<Service>>{};
    for (final s in profile.services) {
      byCat.putIfAbsent(s.categoryId, () => []).add(s);
    }
    final groups = [
      ...profile.categories.where((c) => byCat.containsKey(c.id)).map((c) => (c.title(lang), byCat[c.id]!)),
      if (byCat.containsKey(null)) (l.serviceUncategorized, byCat[null]!),
    ];
    var i = 0;
    return _Card(
      title: l.salonServices,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (title, items) in groups) ...[
            Padding(padding: const EdgeInsets.only(top: Space.sm, bottom: Space.sm), child: Text(title, style: context.text.labelLarge?.copyWith(color: context.colors.primary))),
            for (final s in items)
              StaggeredEntrance(
                key: ValueKey(s.id),
                index: i++,
                child: InkWell(
                  borderRadius: Radii.mdAll,
                  onTap: () => onBook(s.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.md, horizontal: Space.xs),
                    child: Row(children: [
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s.title(lang), style: context.text.titleMedium),
                          if (s.blurb(lang) != null) Text(s.blurb(lang)!, style: context.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(
                            [fmt.duration(s.durationMinutes), if (s.needsDeposit) '${l.bookingDeposit} ${fmt.money(s.depositBaisa)}'].join(' · '),
                            style: context.text.labelSmall,
                          ),
                        ]),
                      ),
                      const SizedBox(width: Space.md),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text(fmt.money(s.priceBaisa), style: context.text.titleMedium),
                        const SizedBox(height: 4),
                        FilledButton.tonal(
                          style: FilledButton.styleFrom(minimumSize: const Size(0, 40), padding: const EdgeInsets.symmetric(horizontal: Space.lg)),
                          onPressed: () => onBook(s.id),
                          child: Text(l.salonBook.split(' ').first),
                        ),
                      ]),
                    ]),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: Space.lg),
        child: GlowCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: context.text.titleLarge),
            const SizedBox(height: Space.md),
            child,
          ]),
        ),
      );
}
