import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/fit_layout.dart';
import '../../customer_booking/presentation/customer_widgets.dart';
import '../data/seasonal_repository.dart';
import 'token_widgets.dart';

/// The token page the WhatsApp message links to (/token/:id?token=…). No account — the
/// link is the key, until a day after the token.
class TokenScreen extends ConsumerStatefulWidget {
  const TokenScreen({super.key, required this.id, this.access});
  final String id;
  final String? access;
  @override
  ConsumerState<TokenScreen> createState() => _TokenScreenState();
}

class _TokenScreenState extends ConsumerState<TokenScreen> {
  Timer? _ticker;

  ({String id, String? access}) get _key => (id: widget.id, access: widget.access);

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

  @override
  Widget build(BuildContext context) {
    final token = ref.watch(seasonalTokenProvider(_key));
    return Scaffold(
      body: token.when(
        loading: () => const Center(child: LoadingPad()),
        error: (e, _) => linkErrorView(context, e, onRetry: () => ref.invalidate(seasonalTokenProvider(_key))),
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
    final left = token.holdExpiresAt?.difference(DateTime.now());
    final holding = token.awaitingPayment && left != null && !left.isNegative;
    final expired = token.status == 'EXPIRED' || (token.awaitingPayment && !holding);

    final note = expired
        ? l.seasonHoldExpiredBody
        : token.status == 'CANCELLED'
        ? l.seasonCancelledBody
        : holding
        ? l.seasonHeldFor('${left.inMinutes.remainder(60).toString().padLeft(2, '0')}:${left.inSeconds.remainder(60).toString().padLeft(2, '0')}')
        : l.seasonReminderNote;

    return FitStepPage(
      title: l.seasonMyToken,
      subtitle: token.salon.title(context.lang),
      trailing: token.salonPhone == null
          ? null
          : IconButton(tooltip: l.salonCall, onPressed: () => launchUrl(Uri.parse('tel:${token.salonPhone}')), icon: const Icon(Icons.call_outlined)),
      body: FitBox(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TokenTicket(token: token),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(child: Text('${l.bookingPaid} ${fmt.money(token.paidBaisa)}', style: context.text.bodyMedium)),
                if (token.status != 'CANCELLED' && !expired && token.balanceBaisa > 0)
                  Text(l.seasonBalanceDue(fmt.money(token.balanceBaisa)), style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
              ],
            ),
            const SizedBox(height: Space.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  holding ? Icons.timer_outlined : Icons.info_outline_rounded,
                  size: 18,
                  color: holding ? context.glow.pending.fg : context.colors.onSurfaceVariant,
                ),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(note, style: context.text.bodySmall?.copyWith(color: holding ? context.glow.pending.fg : null)),
                ),
              ],
            ),
          ],
        ),
      ),
      action: holding
          ? AnimatedButton(
              label: l.payNow(fmt.money(token.dueBaisa)),
              icon: Icons.credit_card_rounded,
              keepSuccess: true,
              onPressed: () => guard(context, () async {
                await ref.read(seasonalRepositoryProvider).pay(token.id, access: access);
                onChanged();
                if (context.mounted) showGlowSnack(context, l.seasonTokenConfirmed);
              }),
            )
          : expired
          ? FilledButton.icon(onPressed: () => context.go('/'), icon: const Icon(Icons.refresh_rounded), label: Text(l.seasonTakeAnother))
          : null,
    );
  }
}
