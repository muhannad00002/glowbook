import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/widgets/common.dart';
import '../../salon/data/salon_repository.dart';
import '../../salon/presentation/discover_screen.dart';
import '../../settings/presentation/settings_screen.dart';

/// Customer (and artist) profile: favourites, language, theme, sign out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key, this.showFavorites = true});
  final bool showFavorites;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final user = ref.watch(authControllerProvider).valueOrNull?.me.user;
    final favs = showFavorites ? ref.watch(favoritesProvider) : null;
    final g = gutterOf(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(g, Space.lg, g, 120),
          children: [
            ContentWidth(
              maxWidth: 820,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.profileTitle, style: context.text.headlineMedium),
                  const SizedBox(height: Space.lg),
                  if (user != null)
                    StaggeredEntrance(
                      index: 0,
                      child: GlowCard(
                        gradient: context.glow.heroGradient,
                        child: Row(children: [
                          InitialsAvatar(name: user.name, size: 64),
                          const SizedBox(width: Space.lg),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(user.name, style: context.text.headlineSmall),
                              if (user.email != null) Text(user.email!, style: context.text.bodyMedium),
                              if (user.phone != null) Text(user.phone!, style: context.text.bodySmall, textDirection: TextDirection.ltr),
                            ]),
                          ),
                        ]),
                      ),
                    ),
                  if (favs != null) ...[
                    const SizedBox(height: Space.xl),
                    SectionHeader(l.profileFavorites),
                    AsyncView(
                      value: favs,
                      loading: const LoadingPad(),
                      data: (list) => list.isEmpty
                          ? Text(l.profileNoFavorites, style: context.text.bodyMedium)
                          : LayoutBuilder(builder: (context, c) {
                              final cols = c.maxWidth >= 620 ? 2 : 1;
                              final w = (c.maxWidth - Space.lg * (cols - 1)) / cols;
                              return Wrap(spacing: Space.lg, runSpacing: Space.lg, children: [
                                for (final s in list) SizedBox(width: w, child: SalonCardView(salon: s)),
                              ]);
                            }),
                    ),
                  ],
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
