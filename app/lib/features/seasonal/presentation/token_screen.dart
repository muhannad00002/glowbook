import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/animations/staggered_entrance.dart';
import '../../../shared/widgets/common.dart';
import '../data/seasonal_repository.dart';
import 'token_widgets.dart';

/// The token page the WhatsApp message links to (/token/:id?token=…). No account needed.
class TokenScreen extends ConsumerStatefulWidget {
  const TokenScreen({super.key, required this.id, this.access});
  final String id;
  final String? access;
  @override
  ConsumerState<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends ConsumerState<TokenScreen> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Keeps the hold countdown honest while she decides to pay.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final t = ref.read(seasonalTokenProvider(_key)).valueOrNull;
      if (mounted && t != null && t.awaitingPayment) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  ({String id, String? access}) get _key => (id: widget.id, access: widget.access);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final token = ref.watch(seasonalTokenProvider(_key));
    return Scaffold(
      appBar: AppBar(title: Text(l.seasonMyToken)),
      body: AsyncView(
        value: token,
        onRetry: () => ref.invalidate(seasonalTokenProvider(_key)),
        data: (t) => _Body(token: t, access: widget.access, onChanged: () => ref.invalidate(seasonalTokenProvider(_key))),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.token, required this.access, required this.onChanged});
  final SeasonalToken token;
  final String? access;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final fmt = context.fmt;
    final g = gutterOf(context);
    final left = token.holdExpiresAt?.difference(DateTime.now());
    final holding = token.awaitingPayment && left != null && !left.isNegative;
    final expired = token.status == 'EXPIRED' || (token.awaitingPayment && !holding);

    return ListView(
      padding: EdgeInsets.fromLTRB(g, Space.sm, g, Space.xxxl),
      children: [
        ContentWidth(
          maxWidth: 520,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StaggeredEntrance(index: 0, child: TokenTicket(token: token)),
              const SizedBox(height: Space.lg),
              if (expired)
                _Notice(icon: Icons.timer_off_outlined, title: l.seasonHoldExpired, body: l.seasonHoldExpiredBody)
              else if (token.status == 'CONFIRMED')
                _Notice(icon: Icons.notifications_active_outlined, title: l.seasonTokenConfirmed, body: l.seasonReminderNote)
              else if (token.status == 'CANCELLED')
                _Notice(icon: Icons.info_outline_rounded, title: l.statusCancelled, body: l.seasonCancelledBody),
              StaggeredEntrance(
                index: 1,
                child: GlowCard(
                  child: Column(
                    children: [
                      _Amt(l.bookingPrice, fmt.money(token.priceBaisa)),
                      _Amt(l.bookingPaid, fmt.money(token.paidBaisa)),
                      if (token.status != 'CANCELLED' && !expired) _Amt(l.seasonPayAtSalon, fmt.money(token.balanceBaisa), strong: true),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: Space.lg),
              if (holding) ...[
                Text(
                  l.seasonHeldFor('${left.inMinutes.remainder(60).toString().padLeft(2, '0')}:${left.inSeconds.remainder(60).toString().padLeft(2, '0')}'),
                  style: context.text.labelLarge?.copyWith(color: context.glow.pending.fg),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: Space.sm),
                AnimatedButton(
                  label: l.payNow(fmt.money(token.dueBaisa)),
                  icon: Icons.credit_card_rounded,
                  keepSuccess: true,
                  onPressed: () => guard(context, () async {
                    await ref.read(seasonalRepositoryProvider).pay(token.id, access: access);
                    onChanged();
                    if (context.mounted) showGlowSnack(context, l.seasonTokenConfirmed);
                  }),
                ),
                const SizedBox(height: Space.sm),
                Text(l.payTestMode, style: context.text.bodySmall, textAlign: TextAlign.center),
              ],
              if (expired)
                FilledButton.icon(
                  onPressed: () => context.go('/salon/${token.salon.slug}'),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(l.seasonTakeAnother),
                ),
              if (token.salonPhone != null)
                Padding(
                  padding: const EdgeInsets.only(top: Space.md),
                  child: OutlinedButton.icon(
                    onPressed: () => launchUrl(Uri.parse('tel:${token.salonPhone}')),
                    icon: const Icon(Icons.call_outlined),
                    label: Text(l.salonCall),
                  ),
                ),
              if (token.salonAddress != null)
                Padding(
                  padding: const EdgeInsets.only(top: Space.md),
                  child: Row(
                    children: [
                      Icon(Icons.location_on_outlined, size: 18, color: context.colors.onSurfaceVariant),
                      const SizedBox(width: Space.sm),
                      Expanded(child: Text(token.salonAddress!, style: context.text.bodySmall)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: Space.lg),
    child: GlowCard(
      elevated: false,
      color: context.colors.surfaceContainerLow,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: context.colors.primary),
          const SizedBox(width: Space.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleSmall),
                const SizedBox(height: 2),
                Text(body, style: context.text.bodySmall),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _Amt extends StatelessWidget {
  const _Amt(this.label, this.value, {this.strong = false});
  final String label;
  final String value;
  final bool strong;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: strong ? context.text.titleSmall : context.text.bodyMedium)),
        Text(value, style: strong ? context.text.titleMedium?.copyWith(color: context.colors.primary) : context.text.bodyMedium),
      ],
    ),
  );
}
