import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/constants/env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/animations/glow_illustration.dart';
import '../../../shared/widgets/common.dart';
import 'auth_layout.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.redirect});
  final String? redirect;
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _id = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _id.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) throw StateError('invalid');
    await guard(context, () => ref.read(authControllerProvider.notifier).login(_id.text.trim(), _password.text));
    // The router's redirect takes it from here (role-based home, or `redirect`).
  }

  void _fill(String id, String pw) {
    _id.text = id;
    _password.text = pw;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = V(context);
    return AuthLayout(
      title: l.authTeamSignIn,
      subtitle: l.authTeamSignInSubtitle,
      art: GlowArt.mirror,
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlowField(
                controller: _id,
                label: l.authEmailOrPhone,
                keyboardType: TextInputType.emailAddress,
                autofill: const [AutofillHints.email, AutofillHints.username],
                validator: v.required,
                prefixIcon: Icons.alternate_email_rounded,
              ),
              GlowField(
                controller: _password,
                label: l.authPassword,
                obscure: _obscure,
                autofill: const [AutofillHints.password],
                validator: v.required,
                textInputAction: TextInputAction.done,
                prefixIcon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  tooltip: _obscure ? l.authShowPassword : l.authHidePassword,
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton(onPressed: () => context.push('/forgot-password'), child: Text(l.authForgotPassword)),
        ),
        const SizedBox(height: Space.sm),
        AnimatedButton(label: l.authSignIn, onPressed: _submit, keepSuccess: true),
        const SizedBox(height: Space.lg),
        TextButton.icon(onPressed: () => context.go('/'), icon: const Icon(Icons.storefront_outlined), label: Text(l.authBackToSalon)),
        if (Env.showDemoAccounts) ...[
          const SizedBox(height: Space.lg),
          _DemoAccounts(onPick: _fill),
        ],
      ],
    );
  }
}

class _DemoAccounts extends StatelessWidget {
  const _DemoAccounts({required this.onPick});
  final void Function(String id, String pw) onPick;

  @override
  Widget build(BuildContext context) {
    const accounts = [
      ('Owner', 'owner@maisonbeauty.om', 'Maison#2026', Icons.storefront_outlined),
      ('Reception', 'reception@maisonbeauty.om', 'Maison#2026', Icons.support_agent_outlined),
      ('Sarah · Artist', 'sarah@maisonbeauty.om', 'Staff#2026', Icons.brush_outlined),
      ('Super admin', 'admin@glowbook.app', 'Glowbook#2026', Icons.admin_panel_settings_outlined),
    ];
    return GlowCard(
      elevated: false,
      color: context.colors.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.authDemoAccounts, style: context.text.labelMedium),
          const SizedBox(height: Space.sm),
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final a in accounts)
                ActionChip(avatar: Icon(a.$4, size: 16), label: Text(a.$1), onPressed: () => onPick(a.$2, a.$3)),
            ],
          ),
        ],
      ),
    );
  }
}
