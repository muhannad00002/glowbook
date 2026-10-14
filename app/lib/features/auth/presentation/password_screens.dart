import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/animations/glow_illustration.dart';
import '../../../shared/widgets/common.dart';
import 'auth_layout.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _sent = false;
  String? _devToken;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) throw StateError('invalid');
    final token = await guard(context, () => ref.read(authControllerProvider.notifier).forgotPassword(_email.text.trim()));
    setState(() {
      _sent = true;
      _devToken = token;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AuthLayout(
      title: l.authForgotTitle,
      subtitle: l.authForgotBody,
      art: GlowArt.bell,
      showBack: true,
      children: [
        Form(
          key: _form,
          child: GlowField(controller: _email, label: l.authEmail, keyboardType: TextInputType.emailAddress, autofill: const [AutofillHints.email], validator: V(context).email),
        ),
        AnimatedButton(label: l.authSendResetLink, onPressed: _submit),
        AnimatedSize(
          duration: const Duration(milliseconds: 260),
          child: !_sent
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(top: Space.xl),
                  child: GlowCard(
                    color: context.colors.tertiaryContainer,
                    elevated: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.authResetSent, style: context.text.bodyMedium?.copyWith(color: context.colors.onTertiaryContainer)),
                        if (_devToken != null) ...[
                          const SizedBox(height: Space.sm),
                          Text(l.authDevResetHint, style: context.text.bodySmall),
                          TextButton(onPressed: () => context.push('/reset-password?token=$_devToken'), child: Text(l.authOpenResetLink)),
                        ],
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});
  final String token;
  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) throw StateError('invalid');
    await guard(context, () => ref.read(authControllerProvider.notifier).resetPassword(widget.token, _password.text));
    if (!mounted) return;
    showGlowSnack(context, context.l10n.authPasswordUpdated);
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AuthLayout(
      title: l.authResetTitle,
      subtitle: l.errorPasswordShort,
      art: GlowArt.sparkles,
      children: [
        Form(
          key: _form,
          child: GlowField(controller: _password, label: l.authNewPassword, obscure: true, autofill: const [AutofillHints.newPassword], validator: V(context).password),
        ),
        AnimatedButton(label: l.actionSave, onPressed: _submit),
      ],
    );
  }
}
