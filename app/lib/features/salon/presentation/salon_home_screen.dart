import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/localization/preferences_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
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
      if (p.phone != null) (Icons.call_rounded, l.salonCall, () => _open(context, Uri.parse('tel:${p.phone}'))),
      if (p.whatsapp != null)
        (Icons.chat_rounded, l.salonWhatsapp, () => _open(context, Uri.parse('https://wa.me/${p.whatsapp!.replaceAll(RegExp(r'\D'), '')}'))),
      if (p.latitude != null && p.longitude != null)
        (
          Icons.near_me_rounded,
          l.salonDirections,
          () => _open(context, Uri.parse('https://www.google.com/maps/search/?api=1&query=${p.latitude},${p.longitude}')),
        ),
      (Icons.schedule_rounded, l.homeHours, () => _showHours(context, p)),
    ];

    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The gallery takes whatever height is left — it is the part that gives way.
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _Gallery(profile: p),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(Space.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _GlassIcon(icon: Icons.person_outline_rounded, label: l.homeTeamSignIn, onTap: () => context.push('/login')),
                        const Spacer(),
                        _LanguageToggle(lang: lang, onPick: (code) => ref.read(preferencesProvider.notifier).setLocale(code)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: box.maxHeight * 0.7),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.only(bottom: Space.md),
              child: Padding(
                padding: EdgeInsets.fromLTRB(g, Space.sm, g, 0),
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(p.card.title(lang), style: context.text.displaySmall, maxLines: 1),
                                ),
                              ),
                              const SizedBox(width: Space.sm),
                              _OpenPill(
                                open: todayHours != null,
                                label: todayHours != null
                                    ? '${fmt.minuteOfDay(todayHours.startMinute)} – ${fmt.minuteOfDay(todayHours.endMinute)}'
                                    : l.salonClosedToday,
                              ),
                            ],
                          ),
                          const SizedBox(height: Space.lg),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [for (final a in actions) _CircleAction(icon: a.$1, label: a.$2, onTap: a.$3)],
                          ),
                          for (final e in events.take(1)) ...[const SizedBox(height: Space.lg), SeasonalBanner(event: e)],
                          const SizedBox(height: Space.md),
                          AnimatedButton(label: l.salonBook, icon: Icons.auto_awesome_rounded, onPressed: () async => context.push('/book')),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Swipeable photos of the salon, fading softly into the page, with page dots.
class _Gallery extends StatefulWidget {
  const _Gallery({required this.profile});
  final SalonProfile profile;
  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _fallback() => LayoutBuilder(
    builder: (context, c) => SalonCover(name: widget.profile.card.name, height: c.maxHeight, monogramSize: 88),
  );

  @override
  Widget build(BuildContext context) {
    final photos = widget.profile.photos;
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (photos.isEmpty)
          _fallback()
        else
          ScrollConfiguration(
            // Swipe with a mouse or trackpad too, not only touch.
            behavior: ScrollConfiguration.of(context).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
            child: PageView.builder(
              controller: _controller,
              itemCount: photos.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => Image.network(
                photos[i],
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => progress == null ? child : ColoredBox(color: context.colors.primaryContainer),
                errorBuilder: (context, _, _) => _fallback(),
              ),
            ),
          ),
        // Darken the top for the buttons; fade the bottom into the page so the name sits on calm ground.
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0, 0.2, 0.75, 1],
                colors: [Colors.black.withValues(alpha: 0.25), Colors.transparent, Colors.transparent, bg],
              ),
            ),
          ),
        ),
        if (photos.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: Space.lg,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < photos.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? context.colors.primary : context.colors.primary.withValues(alpha: 0.3),
                      borderRadius: Radii.pillAll,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Small translucent round button over the photo.
class _GlassIcon extends StatelessWidget {
  const _GlassIcon({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    child: Material(
      color: context.colors.surface.withValues(alpha: 0.85),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 20, color: context.colors.onSurface, semanticLabel: label),
        ),
      ),
    ),
  );
}

/// "● 2:00 PM – 10:00 PM" — today's hours, green when open.
class _OpenPill extends StatelessWidget {
  const _OpenPill({required this.open, required this.label});
  final bool open;
  final String label;
  @override
  Widget build(BuildContext context) {
    final c = open ? context.glow.completed : context.glow.cancelled;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.bg, borderRadius: Radii.pillAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: c.fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(label, style: context.text.labelMedium?.copyWith(color: c.fg)),
        ],
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  const _CircleAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: label,
    child: PressableScale(
      onTap: onTap,
      child: SizedBox(
        width: 72,
        child: ExcludeSemantics(
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(color: context.colors.primaryContainer.withValues(alpha: 0.7), shape: BoxShape.circle),
                child: Icon(icon, size: 22, color: context.colors.primary),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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
