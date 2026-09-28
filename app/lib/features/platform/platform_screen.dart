import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/providers.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/format.dart';
import '../../shared/animations/animated_counter.dart';
import '../../shared/animations/staggered_entrance.dart';
import '../../shared/models/models.dart';
import '../../shared/widgets/common.dart';
import '../settings/presentation/settings_screen.dart';

class PlatformRepository {
  PlatformRepository(this._ref);
  final Ref _ref;
  Future<Json> stats() async => asJson(await _ref.read(apiClientProvider).get<Object?>('/api/admin/stats'));
  Future<List<Json>> salons() async => asJsonList(await _ref.read(apiClientProvider).get<List<dynamic>>('/api/admin/salons'));
  Future<void> update(String id, Json body) => _ref.read(apiClientProvider).patch<Object?>('/api/admin/salons/$id', body: body);
}

final platformRepositoryProvider = Provider((ref) => PlatformRepository(ref));
final platformStatsProvider = FutureProvider.autoDispose((ref) => ref.watch(platformRepositoryProvider).stats());
final platformSalonsProvider = FutureProvider.autoDispose((ref) => ref.watch(platformRepositoryProvider).salons());

/// Super-admin overview of every tenant on the platform.
class PlatformScreen extends ConsumerWidget {
  const PlatformScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final fmt = context.fmt;
    final stats = ref.watch(platformStatsProvider);
    final salons = ref.watch(platformSalonsProvider);
    final g = gutterOf(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(g, Space.lg, g, Space.xxxl),
          children: [
            ContentWidth(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.platformTitle, style: context.text.headlineMedium),
                  const SizedBox(height: Space.lg),
                  AsyncView(
                    value: stats,
                    data: (s) => LayoutBuilder(builder: (context, c) {
                      final cols = c.maxWidth >= 900 ? 5 : 2;
                      final w = (c.maxWidth - Space.md * (cols - 1)) / cols;
                      final tiles = [
                        (l.platformSalons, asInt(s['salons']), false),
                        (l.platformActive, asInt(s['activeSalons30d']), false),
                        (l.platformUsers, asInt(s['users']), false),
                        (l.platformBookings, asInt(s['bookings30d']), false),
                        (l.platformGmv, asInt(s['gmv30dBaisa']), true),
                      ];
                      return Wrap(spacing: Space.md, runSpacing: Space.md, children: [
                        for (var i = 0; i < tiles.length; i++)
                          SizedBox(
                            width: w,
                            child: StaggeredEntrance(
                              index: i,
                              child: StatTile(label: tiles[i].$1, value: AnimatedCounter(value: tiles[i].$2, format: tiles[i].$3 ? (v) => fmt.money(v.round()) : null)),
                            ),
                          ),
                      ]);
                    }),
                  ),
                  const SizedBox(height: Space.xl),
                  SectionHeader(l.platformTenants),
                  AsyncView(
                    value: salons,
                    data: (list) => Column(children: [
                      for (var i = 0; i < list.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.sm),
                          child: StaggeredEntrance(
                            index: i,
                            child: GlowCard(
                              onTap: () => context.push('/salon/${list[i]['slug']}'),
                              child: Row(children: [
                                InitialsAvatar(name: list[i]['name'] as String),
                                const SizedBox(width: Space.lg),
                                Expanded(
                                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                    Text(list[i]['name'] as String, style: context.text.titleMedium),
                                    Text(
                                      '${list[i]['city'] ?? ''} · ${l.calendarBookingsCount(asInt(list[i]['bookingCount']))} · ${l.platformPlan} ${list[i]['plan']}',
                                      style: context.text.bodySmall,
                                    ),
                                  ]),
                                ),
                                Switch(
                                  value: list[i]['isPublished'] == true,
                                  onChanged: (v) async {
                                    await guard(context, () => ref.read(platformRepositoryProvider).update(list[i]['id'] as String, {'isPublished': v}));
                                    ref.invalidate(platformSalonsProvider);
                                  },
                                ),
                              ]),
                            ),
                          ),
                        ),
                    ]),
                  ),
                  const SizedBox(height: Space.xl),
                  const PreferencesSection(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
