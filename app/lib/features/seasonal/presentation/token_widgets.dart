import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/widgets/common.dart';
import '../data/seasonal_repository.dart';

/// How early a customer should be at the salon before her token time.
const arriveEarlyMinutes = 10;

/// The token as a ticket: the number is the hero, then when to arrive.
class TokenTicket extends StatelessWidget {
  const TokenTicket({super.key, required this.token});
  final SeasonalToken token;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final tz = token.timezone;
    final lang = context.lang;
    const onCard = Colors.white;
    final soft = onCard.withValues(alpha: 0.82);
    final dimmed = !token.isLive && token.status != 'COMPLETED';
    return Semantics(
      container: true,
      label: '${l.seasonTokenNumber} ${token.number}, ${token.offering(lang)}, ${fmt.fullDate(token.start, tz)} ${fmt.time(token.start, tz)}',
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: dimmed ? 0.55 : 1,
          child: Container(
            decoration: BoxDecoration(
              gradient: context.glow.cardGradient,
              borderRadius: Radii.lgAll,
              boxShadow: [BoxShadow(color: context.glow.shadow, blurRadius: 24, offset: const Offset(0, 10))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.xl, Space.xl, Space.xl, Space.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              token.event(lang).toUpperCase(),
                              style: context.text.labelMedium?.copyWith(color: soft, letterSpacing: 1.1),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          StatusChip(token.status, dense: true),
                        ],
                      ),
                      const SizedBox(height: Space.xs),
                      Text(token.offering(lang), style: context.text.titleLarge?.copyWith(color: onCard)),
                      Text(token.salon.title(lang), style: context.text.bodyMedium?.copyWith(color: soft)),
                      const SizedBox(height: Space.lg),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(l.seasonTokenNumber, style: context.text.titleMedium?.copyWith(color: soft)),
                          const SizedBox(width: Space.sm),
                          Text(
                            '#${token.number}',
                            style: context.text.displayLarge?.copyWith(color: onCard, fontWeight: FontWeight.w700, height: 1),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _Perforation(color: Theme.of(context).scaffoldBackgroundColor),
                Padding(
                  padding: const EdgeInsets.fromLTRB(Space.xl, Space.lg, Space.xl, Space.xl),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _Fact(label: fmt.weekdayDayMonth(token.start, tz), value: fmt.time(token.start, tz), color: onCard),
                          ),
                          _Fact(label: l.bookingReference, value: token.reference, color: onCard, end: true),
                        ],
                      ),
                      if (token.isLive) ...[
                        const SizedBox(height: Space.md),
                        Row(
                          children: [
                            Icon(Icons.directions_walk_rounded, size: 18, color: soft),
                            const SizedBox(width: Space.sm),
                            Expanded(
                              child: Text(
                                l.seasonArriveBy(fmt.time(token.start.subtract(const Duration(minutes: arriveEarlyMinutes)), tz)),
                                style: context.text.bodyMedium?.copyWith(color: onCard),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, required this.color, this.end = false});
  final String label;
  final String value;
  final Color color;
  final bool end;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: end ? CrossAxisAlignment.end : CrossAxisAlignment.start,
    children: [
      Text(label, style: context.text.labelMedium?.copyWith(color: color.withValues(alpha: 0.8))),
      Text(value, style: context.text.titleLarge?.copyWith(color: color)),
    ],
  );
}

/// Ticket tear line with notches on both sides.
class _Perforation extends StatelessWidget {
  const _Perforation({required this.color});
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 20,
    child: Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (_, c) => Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [for (var i = 0; i < (c.maxWidth / 14).floor(); i++) Container(width: 6, height: 2, color: Colors.white.withValues(alpha: 0.45))],
            ),
          ),
        ),
        PositionedDirectional(start: -10, top: 0, child: CircleAvatar(radius: 10, backgroundColor: color)),
        PositionedDirectional(end: -10, top: 0, child: CircleAvatar(radius: 10, backgroundColor: color)),
      ],
    ),
  );
}

/// The seasonal event on the salon home: a ticket-like card that says what it is, when,
/// what's on offer and how to get a token — in one glance.
class SeasonalBanner extends StatelessWidget {
  const SeasonalBanner({super.key, required this.event});
  final SeasonalEvent event;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final fmt = context.fmt;
    final lang = context.lang;
    const onCard = Colors.white;
    final soft = onCard.withValues(alpha: 0.8);
    void open() => context.push('/tokens/${event.id}');
    return Semantics(
      button: true,
      label: '${event.title(lang)}, ${l.seasonTakeToken}',
      child: PressableScale(
        onTap: open,
        child: Container(
          decoration: BoxDecoration(
            gradient: context.glow.cardGradient,
            borderRadius: Radii.lgAll,
            boxShadow: [BoxShadow(color: context.glow.shadow, blurRadius: 18, offset: const Offset(0, 8))],
          ),
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.md, Space.md),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.confirmation_number_outlined, color: onCard, size: 20),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: Text(
                        event.title(lang),
                        style: context.text.titleMedium?.copyWith(color: onCard),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '${fmt.ymdLabel(event.startDate, pattern: 'MMMd')} – ${fmt.ymdLabel(event.endDate, pattern: 'MMMd')}',
                      style: context.text.labelMedium?.copyWith(color: soft),
                    ),
                  ],
                ),
                const SizedBox(height: Space.sm),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        event.offerings.map((o) => o.title(lang)).join(' · '),
                        style: context.text.bodySmall?.copyWith(color: soft),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: Space.md, vertical: Space.sm),
                      decoration: BoxDecoration(color: onCard, borderRadius: Radii.pillAll),
                      child: Text(l.seasonTakeToken, style: context.text.labelLarge?.copyWith(color: context.colors.primary)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "Add to Apple Wallet". Opens the signed pass from the API; Safari on iPhone hands it
/// straight to Wallet. Shown only when the salon has Wallet set up and the token is paid.
class AddToWalletButton extends StatelessWidget {
  const AddToWalletButton({super.key, required this.token, required this.access});
  final SeasonalToken token;
  final String? access;

  @override
  Widget build(BuildContext context) {
    if (!token.walletAvailable) return const SizedBox.shrink();
    final l = context.l10n;
    final uri = Uri.parse('${Env.apiBaseUrl}/api/public/tokens/${token.id}/wallet').replace(queryParameters: {'token': ?access, 'lang': context.lang});
    return Semantics(
      button: true,
      label: l.walletAdd,
      child: Material(
        color: Colors.black,
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => launchUrl(uri, webOnlyWindowName: '_self'),
          child: SizedBox(
            height: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.wallet_rounded, color: Colors.white, size: 22),
                const SizedBox(width: Space.sm),
                Text(l.walletAdd, style: context.text.labelLarge?.copyWith(color: Colors.white)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
