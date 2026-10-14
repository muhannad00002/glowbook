import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_counter.dart';
import '../../../shared/animations/animated_empty_state.dart';
import '../../../shared/animations/glow_illustration.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';

class SalonReviewsRepository {
  SalonReviewsRepository(this._ref);
  final Ref _ref;
  Future<Json> list() async => asJson(await _ref.read(apiClientProvider).get<Object?>('/api/reviews'));
  Future<void> reply(String id, String text) => _ref.read(apiClientProvider).post<Object?>('/api/reviews/$id/reply', body: {'reply': text});
}

final salonReviewsRepositoryProvider = Provider((ref) => SalonReviewsRepository(ref));

final salonReviewsProvider = FutureProvider.autoDispose<({List<Json> items, double avg, int count, List<Json> dist})>((ref) async {
  ref.watch(membershipProvider.select((m) => m?.salonId));
  final j = await ref.watch(salonReviewsRepositoryProvider).list();
  return (items: asJsonList(j['items']), avg: asDouble(j['ratingAvg']), count: asInt(j['ratingCount']), dist: asJsonList(j['distribution']));
});

/// The salon team's view of its reviews, with replies.
class SalonReviewsScreen extends ConsumerWidget {
  const SalonReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final data = ref.watch(salonReviewsProvider);
    final canReply = ref.watch(membershipProvider)?.isAdmin ?? false;
    final tz = ref.watch(salonTimezoneProvider);
    final g = gutterOf(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: AsyncView(
          value: data,
          onRetry: () => ref.invalidate(salonReviewsProvider),
          data: (d) => ListView(
            padding: EdgeInsets.fromLTRB(g, Space.lg, g, 120),
            children: [
              ContentWidth(
                maxWidth: 820,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(l.reviewsTitle, style: context.text.headlineMedium),
                    const SizedBox(height: Space.lg),
                    GlowCard(
                      gradient: context.glow.heroGradient,
                      child: Row(
                        children: [
                          Column(
                            children: [
                              AnimatedCounter(value: d.avg, format: (v) => v.toStringAsFixed(1), style: context.text.displayMedium),
                              RatingStars(rating: d.avg, size: 18),
                              Text(l.reviewsCount(d.count), style: context.text.bodySmall),
                            ],
                          ),
                          const SizedBox(width: Space.xl),
                          Expanded(
                            child: Column(
                              children: [
                                for (final row in d.dist)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        SizedBox(width: 16, child: Text('${row['star']}', style: context.text.labelSmall)),
                                        const SizedBox(width: 6),
                                        Expanded(
                                          child: ClipRRect(
                                            borderRadius: Radii.pillAll,
                                            child: LinearProgressIndicator(
                                              value: d.items.isEmpty ? 0 : asInt(row['count']) / d.items.length,
                                              minHeight: 6,
                                              color: context.colors.secondary,
                                              backgroundColor: context.colors.surface.withValues(alpha: 0.6),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: Space.xl),
                    if (d.items.isEmpty) AnimatedEmptyState(art: GlowArt.sparkles, title: l.reviewsEmpty, compact: true),
                    for (var i = 0; i < d.items.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.md),
                        child: StaggeredEntrance(
                          key: ValueKey(d.items[i]['id']),
                          index: i,
                          child: _ReviewCard(review: d.items[i], canReply: canReply, timezone: tz),
                        ),
                      ),
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

class _ReviewCard extends ConsumerWidget {
  const _ReviewCard({required this.review, required this.canReply, required this.timezone});
  final Json review;
  final bool canReply;
  final String timezone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final booking = asJson(review['booking']);
    final reply = asStr(review['reply']);
    return GlowCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InitialsAvatar(name: asStr(asJson(review['customer'])['name']) ?? '?', size: 36),
              const SizedBox(width: Space.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(asStr(asJson(review['customer'])['name']) ?? '', style: context.text.titleSmall),
                    Text(
                      [
                        asStr(asJson(booking['service'])['name']),
                        asStr(asJson(review['staff'])['name']),
                        context.fmt.relativeDay(asDateReq(review['createdAt']), timezone),
                      ].whereType<String>().join(' · '),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              RatingStars(rating: asInt(review['rating']).toDouble()),
            ],
          ),
          if (asStr(review['comment']) != null) ...[const SizedBox(height: Space.md), Text(review['comment'] as String, style: context.text.bodyMedium)],
          if (reply != null)
            Container(
              margin: const EdgeInsets.only(top: Space.md),
              padding: const EdgeInsets.all(Space.md),
              decoration: BoxDecoration(color: context.colors.surfaceContainerLow, borderRadius: Radii.mdAll),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.reviewsSalonReply, style: context.text.labelSmall),
                  Text(reply, style: context.text.bodyMedium),
                ],
              ),
            )
          else if (canReply)
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: TextButton.icon(
                icon: const Icon(Icons.reply_rounded),
                label: Text(l.reviewsReply),
                onPressed: () async {
                  final c = TextEditingController();
                  final text = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(l.reviewsReply),
                      content: TextField(
                        controller: c,
                        maxLines: 3,
                        autofocus: true,
                        decoration: InputDecoration(hintText: l.reviewsReplyHint),
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.actionCancel)),
                        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: Text(l.reviewsReply)),
                      ],
                    ),
                  );
                  if (text == null || text.isEmpty || !context.mounted) return;
                  await guard(context, () => ref.read(salonReviewsRepositoryProvider).reply(review['id'] as String, text));
                  ref.invalidate(salonReviewsProvider);
                  if (context.mounted) showGlowSnack(context, l.reviewsReplied);
                },
              ),
            ),
        ],
      ),
    );
  }
}
