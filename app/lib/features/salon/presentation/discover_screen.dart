import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/animations/animated_empty_state.dart';
import '../../../shared/animations/glow_illustration.dart';
import '../../../shared/animations/shimmer_loading.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/salon_cover.dart';
import '../data/salon_repository.dart';

class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});
  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  String _q = '';
  String? _category;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final me = ref.watch(authControllerProvider).valueOrNull?.me.user;
    final salons = ref.watch(discoverProvider((q: _q, category: _category)));
    final g = gutterOf(context);
    final cats = [
      (null, l.catAll, Icons.auto_awesome_rounded),
      ('MAKEUP', l.catMakeup, Icons.brush_outlined),
      ('HAIR', l.catHair, Icons.content_cut_rounded),
      ('BEAUTY', l.catBeauty, Icons.spa_outlined),
      ('ARTIST', l.catArtist, Icons.palette_outlined),
      ('STUDIO', l.catStudio, Icons.storefront_outlined),
    ];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(discoverProvider((q: _q, category: _category)).future),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: BoxDecoration(gradient: context.glow.heroGradient),
                padding: EdgeInsets.fromLTRB(g, MediaQuery.paddingOf(context).top + Space.xl, g, Space.xl),
                child: ContentWidth(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      StaggeredEntrance(
                        index: 0,
                        child: Row(children: [
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              if (me != null)
                                Text(
                                  '${DateTime.now().hour < 12 ? l.greetingMorning : DateTime.now().hour < 17 ? l.greetingAfternoon : l.greetingEvening}, ${me.firstName} 💕',
                                  style: context.text.titleMedium,
                                ),
                              Text(l.discoverTitle, style: context.text.displaySmall),
                            ]),
                          ),
                          const GlowIllustration(GlowArt.sparkles, size: 72),
                        ]),
                      ),
                      StaggeredEntrance(index: 1, child: Text(l.discoverSubtitle, style: context.text.bodyMedium)),
                      const SizedBox(height: Space.lg),
                      StaggeredEntrance(
                        index: 2,
                        child: TextField(
                          decoration: InputDecoration(prefixIcon: const Icon(Icons.search_rounded), hintText: l.discoverSearch),
                          onChanged: (v) {
                            _debounce?.cancel();
                            _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _q = v.trim()));
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 60,
                child: ListView(
                  padding: EdgeInsets.symmetric(horizontal: g, vertical: Space.md),
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final c in cats)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: Space.sm),
                        child: ChoiceChip(avatar: Icon(c.$3, size: 16), label: Text(c.$2), selected: _category == c.$1, onSelected: (_) => setState(() => _category = c.$1)),
                      ),
                  ],
                ),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(g, 0, g, 120),
              sliver: SliverToBoxAdapter(
                child: ContentWidth(
                  child: AsyncView(
                    value: salons,
                    onRetry: () => ref.invalidate(discoverProvider),
                    loading: ShimmerLoading(
                      child: Column(children: List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: Space.lg), child: SkeletonBox(height: 230, radius: Radii.lg)))),
                    ),
                    data: (list) => list.isEmpty
                        ? AnimatedEmptyState(art: GlowArt.mirror, title: l.discoverEmpty, compact: true)
                        : LayoutBuilder(builder: (context, c) {
                            final cols = c.maxWidth >= 1000 ? 3 : c.maxWidth >= 620 ? 2 : 1;
                            final w = (c.maxWidth - Space.lg * (cols - 1)) / cols;
                            return Wrap(spacing: Space.lg, runSpacing: Space.lg, children: [
                              for (var i = 0; i < list.length; i++)
                                SizedBox(width: w, child: StaggeredEntrance(key: ValueKey(list[i].id), index: i, child: SalonCardView(salon: list[i]))),
                            ]);
                          }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SalonCardView extends ConsumerStatefulWidget {
  const SalonCardView({super.key, required this.salon});
  final SalonCard salon;
  @override
  ConsumerState<SalonCardView> createState() => _SalonCardViewState();
}

class _SalonCardViewState extends ConsumerState<SalonCardView> {
  late bool _fav = widget.salon.isFavorite;

  @override
  Widget build(BuildContext context) {
    final s = widget.salon;
    final l = context.l10n;
    final signedIn = ref.watch(authControllerProvider).valueOrNull != null;
    return GlowCard(
      padding: EdgeInsets.zero,
      onTap: () => context.push('/salon/${s.slug}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(children: [
            Hero(
              tag: 'salon-cover-${s.slug}',
              child: SalonCover(name: s.name, imageUrl: s.coverUrl, height: 150, radius: Radii.lg),
            ),
            if (signedIn)
              PositionedDirectional(
                top: Space.sm,
                end: Space.sm,
                child: _HeartButton(
                  active: _fav,
                  onTap: () async {
                    setState(() => _fav = !_fav);
                    try {
                      await ref.read(salonRepositoryProvider).setFavorite(s.id, _fav);
                      ref.invalidate(favoritesProvider);
                    } catch (_) {
                      if (mounted) setState(() => _fav = !_fav);
                    }
                  },
                ),
              ),
          ]),
          Padding(
            padding: const EdgeInsets.all(Space.lg),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title(context.lang), style: context.text.titleLarge),
              if (s.subtitle(context.lang) != null) Text(s.subtitle(context.lang)!, style: context.text.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: Space.sm),
              Row(children: [
                if (s.ratingCount > 0) ...[
                  Icon(Icons.star_rounded, size: 16, color: context.colors.secondary),
                  const SizedBox(width: 2),
                  Text('${s.ratingAvg.toStringAsFixed(1)} (${s.ratingCount})', style: context.text.labelMedium),
                  const SizedBox(width: Space.md),
                ],
                if (s.city != null) ...[
                  Icon(Icons.location_on_outlined, size: 16, color: context.colors.onSurfaceVariant),
                  Text(s.city!, style: context.text.bodySmall),
                ],
                const Spacer(),
                if (s.fromPriceBaisa != null) Text(l.fromPrice(context.fmt.money(s.fromPriceBaisa!)), style: context.text.labelLarge?.copyWith(color: context.colors.primary)),
              ]),
            ]),
          ),
        ],
      ),
    );
  }
}

class _HeartButton extends StatelessWidget {
  const _HeartButton({required this.active, required this.onTap});
  final bool active;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    return Semantics(
      button: true,
      toggled: active,
      label: active ? context.l10n.salonSaved : context.l10n.salonSave,
      child: PressableScale(
        onTap: onTap,
        scale: 0.85,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: context.colors.surface.withValues(alpha: 0.9), shape: BoxShape.circle),
          child: AnimatedSwitcher(
            duration: motion.medium,
            transitionBuilder: (c, a) => ScaleTransition(scale: CurvedAnimation(parent: a, curve: Motion.pop), child: c),
            child: Icon(
              active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              key: ValueKey(active),
              color: active ? context.colors.primary : context.colors.onSurfaceVariant,
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}
