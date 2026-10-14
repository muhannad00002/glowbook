import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/preferences_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/models/models.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/fit_layout.dart';
import '../../../shared/widgets/salon_cover.dart';
import '../../customer_booking/presentation/customer_widgets.dart';
import '../../seasonal/data/seasonal_repository.dart';
import '../../seasonal/presentation/token_widgets.dart';
import '../data/salon_repository.dart';

/// The salon's front door — the whole app for customers starts here. One screen, no
/// scrolling: who we are, today's hours, any seasonal event, and "Book".
class SalonHomeScreen extends ConsumerWidget {
  const SalonHomeScreen({super.key, required this.slug});
  final String slug;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(salonProfileProvider(slug));
    return Scaffold(
      body: profile.when(
        loading: () => const Center(child: LoadingPad()),
        error: (e, _) => linkErrorView(context, e, onRetry: () => ref.invalidate(salonProfileProvider(slug))),
        data: (p) => _Home(profile: p),
      ),
    );
  }
}

class _Home extends ConsumerWidget {
  const _Home({required this.profile});
  final SalonProfile profile;

  Future<void> _open(BuildContext context, Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) {
      showGlowSnack(context, context.l10n.errorGeneric, error: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = profile;
    final l = context.l10n;
    final fmt = context.fmt;
    final lang = context.lang;
    final g = gutterOf(context);
    final today = Ymd.dayOfWeek(Ymd.today(p.timezone));
    final todayHours = p.hours.where((h) => h.dayOfWeek == today).firstOrNull;
    final events = ref.watch(salonSeasonalEventsProvider(p.card.slug)).valueOrNull ?? const <SeasonalEvent>[];

    final actions = <(IconData, String, VoidCallback)>[
      if (p.phone != null) (Icons.call_outlined, l.salonCall, () => _open(context, Uri.parse('tel:${p.phone}'))),
      if (p.whatsapp != null)
        (Icons.chat_outlined, l.salonWhatsapp, () => _open(context, Uri.parse('https://wa.me/${p.whatsapp!.replaceAll(RegExp(r'\D'), '')}'))),
      if (p.latitude != null && p.longitude != null)
        (
          Icons.directions_outlined,
          l.salonDirections,
          () => _open(context, Uri.parse('https://www.google.com/maps/search/?api=1&query=${p.latitude},${p.longitude}')),
        ),
      (Icons.schedule_rounded, l.homeHours, () => _showHours(context, p)),
    ];

    return LayoutBuilder(
      builder: (context, box) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The cover takes whatever height is left — it is the part that gives way.
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  LayoutBuilder(
                    builder: (context, c) => SalonCover(name: p.card.name, imageUrl: p.card.coverUrl, height: c.maxHeight, monogramSize: 88),
                  ),
                  SafeArea(
                    child: Align(
                      alignment: AlignmentDirectional.topEnd,
                      child: Padding(
                        padding: const EdgeInsets.all(Space.sm),
                        child: _LanguageToggle(lang: lang, onPick: (code) => ref.read(preferencesProvider.notifier).setLocale(code)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: box.maxHeight * 0.78),
              child: SafeArea(
                top: false,
                minimum: const EdgeInsets.only(bottom: Space.md),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(g, Space.lg, g, 0),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    heightFactor: 1,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: FitBox(
                        alignment: Alignment.bottomCenter,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            StaggeredEntrance(index: 0, child: Text(p.card.title(lang), style: context.text.displaySmall)),
                            if (p.card.subtitle(lang) != null)
                              Text(
                                p.card.subtitle(lang)!,
                                style: context.text.titleMedium?.copyWith(color: context.colors.onSurfaceVariant),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            const SizedBox(height: Space.sm),
                            Wrap(
                              spacing: Space.lg,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                if (p.card.ratingCount > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.star_rounded, size: 18, color: context.colors.secondary),
                                      const SizedBox(width: 4),
                                      Text('${p.card.ratingAvg.toStringAsFixed(1)} · ${l.reviewsCount(p.card.ratingCount)}', style: context.text.labelMedium),
                                    ],
                                  ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.schedule_rounded, size: 16, color: todayHours != null ? context.colors.tertiary : context.colors.error),
                                    const SizedBox(width: 4),
                                    Text(
                                      todayHours != null
                                          ? l.salonOpenNow('${fmt.minuteOfDay(todayHours.startMinute)} – ${fmt.minuteOfDay(todayHours.endMinute)}')
                                          : l.salonClosedToday,
                                      style: context.text.labelMedium,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: Space.md),
                            Row(
                              children: [
                                for (var i = 0; i < actions.length; i++) ...[
                                  if (i > 0) const SizedBox(width: Space.sm),
                                  Expanded(
                                    child: _QuickAction(icon: actions[i].$1, label: actions[i].$2, onTap: actions[i].$3),
                                  ),
                                ],
                              ],
                            ),
                            for (final e in events.take(2)) ...[const SizedBox(height: Space.sm), SeasonalBanner(event: e)],
                            const SizedBox(height: Space.lg),
                            AnimatedButton(label: l.salonBook, icon: Icons.auto_awesome_rounded, onPressed: () async => context.push('/book')),
                            const SizedBox(height: Space.xs),
                            TextButton(onPressed: () => context.push('/login'), child: Text(l.homeTeamSignIn)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: PressableScale(
      onTap: onTap,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: Radii.mdAll,
          border: Border.all(color: context.colors.outlineVariant),
        ),
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22, color: context.colors.primary),
              const SizedBox(height: 2),
              Text(label, style: context.text.labelSmall, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    ),
  );
}

class _LanguageToggle extends StatelessWidget {
  const _LanguageToggle({required this.lang, required this.onPick});
  final String lang;
  final ValueChanged<String> onPick;
  @override
  Widget build(BuildContext context) => Material(
    color: context.colors.surface.withValues(alpha: 0.9),
    shape: const StadiumBorder(),
    child: InkWell(
      customBorder: const StadiumBorder(),
      onTap: () => onPick(lang == 'ar' ? 'en' : 'ar'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.translate_rounded, size: 18, color: context.colors.primary),
            const SizedBox(width: 6),
            // Shows the language she can switch to.
            Text(lang == 'ar' ? 'English' : 'العربية', style: context.text.labelLarge),
          ],
        ),
      ),
    ),
  );
}

/// Opening hours and address in a dialog — short enough never to scroll.
void _showHours(BuildContext context, SalonProfile p) {
  final l = context.l10n;
  final fmt = context.fmt;
  final today = Ymd.dayOfWeek(Ymd.today(p.timezone));
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.salonHours),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final dow in [6, 0, 1, 2, 3, 4, 5])
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: [
                  Expanded(child: Text(fmt.weekdayName(dow), style: dow == today ? ctx.text.titleSmall : ctx.text.bodyMedium)),
                  Text(
                    p.hours.where((h) => h.dayOfWeek == dow).map((h) => '${fmt.minuteOfDay(h.startMinute)} – ${fmt.minuteOfDay(h.endMinute)}').firstOrNull ??
                        l.settingsClosed,
                    style: dow == today ? ctx.text.titleSmall : ctx.text.bodyMedium,
                  ),
                ],
              ),
            ),
          if (p.place(ctx.lang) != null) ...[
            const Divider(height: Space.xl),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 18, color: ctx.colors.primary),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(p.place(ctx.lang)!, style: ctx.text.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
          ],
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l.actionClose))],
    ),
  );
}
