import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/widgets/common.dart';
import '../../settings/presentation/settings_screen.dart';

/// A team member's profile: language and sign out.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final user = ref.watch(authControllerProvider).valueOrNull?.me.user;
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
                        child: Row(
                          children: [
                            InitialsAvatar(name: user.name, size: 64),
                            const SizedBox(width: Space.lg),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(user.name, style: context.text.headlineSmall),
                                  if (user.email != null) Text(user.email!, style: context.text.bodyMedium),
                                  if (user.phone != null) Text(user.phone!, style: context.text.bodySmall, textDirection: TextDirection.ltr),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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
