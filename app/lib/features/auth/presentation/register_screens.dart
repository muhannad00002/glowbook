import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/animations/glow_illustration.dart';
import '../../../shared/widgets/common.dart';
import 'auth_layout.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});
  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) throw StateError('invalid');
    await guard(
      context,
      () => ref.read(authControllerProvider.notifier).register(
            name: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            phone: _phone.text.trim(),
            locale: context.lang,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = V(context);
    return AuthLayout(
      title: l.authRegisterTitle,
      subtitle: l.authRegisterSubtitle,
      art: GlowArt.lipstick,
      showBack: true,
      children: [
        Form(
          key: _form,
          child: Column(children: [
            GlowField(controller: _name, label: l.authFullName, autofill: const [AutofillHints.name], validator: v.required),
            GlowField(controller: _email, label: l.authEmail, keyboardType: TextInputType.emailAddress, autofill: const [AutofillHints.email], validator: v.email),
            GlowField(
              controller: _phone,
              label: '${l.authPhone} (${l.labelOptional})',
              hint: '+968 9…',
              keyboardType: TextInputType.phone,
              autofill: const [AutofillHints.telephoneNumber],
              validator: v.optionalPhone,
              textDirection: TextDirection.ltr,
            ),
            GlowField(
              controller: _password,
              label: l.authPassword,
              obscure: true,
              autofill: const [AutofillHints.newPassword],
              validator: v.password,
              helper: l.errorPasswordShort,
              textInputAction: TextInputAction.done,
            ),
          ]),
        ),
        AnimatedButton(label: l.authCreateAccount, onPressed: _submit, keepSuccess: true),
        const SizedBox(height: Space.lg),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(l.authHaveAccount, style: context.text.bodyMedium),
            TextButton(onPressed: () => context.go('/login'), child: Text(l.authSignIn)),
          ],
        ),
      ],
    );
  }
}

class RegisterSalonScreen extends ConsumerStatefulWidget {
  const RegisterSalonScreen({super.key});
  @override
  ConsumerState<RegisterSalonScreen> createState() => _RegisterSalonScreenState();
}

class _RegisterSalonScreenState extends ConsumerState<RegisterSalonScreen> {
  final _form = GlobalKey<FormState>();
  final _salon = TextEditingController();
  final _city = TextEditingController(text: 'Muscat');
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    for (final c in [_salon, _city, _name, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) throw StateError('invalid');
    await guard(
      context,
      () => ref.read(authControllerProvider.notifier).registerSalon(
            ownerName: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            salonName: _salon.text.trim(),
            phone: _phone.text.trim(),
            city: _city.text.trim(),
            locale: context.lang,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = V(context);
    return AuthLayout(
      title: l.authRegisterSalonTitle,
      subtitle: l.authRegisterSalonSubtitle,
      art: GlowArt.brush,
      showBack: true,
      children: [
        Form(
          key: _form,
          child: Column(children: [
            GlowField(controller: _salon, label: l.authSalonName, validator: v.required, prefixIcon: Icons.storefront_outlined),
            GlowField(controller: _city, label: l.authCity, validator: v.required, prefixIcon: Icons.location_on_outlined),
            GlowField(controller: _name, label: l.authFullName, autofill: const [AutofillHints.name], validator: v.required),
            GlowField(controller: _email, label: l.authEmail, keyboardType: TextInputType.emailAddress, autofill: const [AutofillHints.email], validator: v.email),
            GlowField(controller: _phone, label: '${l.authPhone} (${l.labelOptional})', keyboardType: TextInputType.phone, validator: v.optionalPhone, textDirection: TextDirection.ltr),
            GlowField(controller: _password, label: l.authPassword, obscure: true, autofill: const [AutofillHints.newPassword], validator: v.password, helper: l.errorPasswordShort),
          ]),
        ),
        AnimatedButton(label: l.authStartTrial, icon: Icons.auto_awesome_rounded, onPressed: _submit, keepSuccess: true),
      ],
    );
  }
}

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

class PhoneLoginScreen extends ConsumerStatefulWidget {
  const PhoneLoginScreen({super.key});
  @override
  ConsumerState<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends ConsumerState<PhoneLoginScreen> {
  final _phone = TextEditingController(text: '+968');
  final _code = TextEditingController();
  final _name = TextEditingController();
  bool _codeSent = false;
  bool _needsName = false;
  String? _devCode;

  @override
  void dispose() {
    for (final c in [_phone, _code, _name]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _send() async {
    if (V(context).phone(_phone.text) != null) {
      showGlowSnack(context, context.l10n.errorPhone, error: true);
      throw StateError('invalid');
    }
    final dev = await guard(context, () => ref.read(authControllerProvider.notifier).requestOtp(_phone.text.trim(), context.lang));
    setState(() {
      _codeSent = true;
      _devCode = dev;
    });
  }

  Future<void> _verify() async {
    try {
      await ref.read(authControllerProvider.notifier).verifyOtp(_phone.text.trim(), _code.text.trim(), name: _name.text.trim(), locale: context.lang);
    } catch (e) {
      final needsName = e is ApiException && e.data is Map && (e.data as Map)['needsName'] == true;
      if (needsName && mounted) setState(() => _needsName = true);
      if (mounted) showGlowSnack(context, context.fmt.error(e), error: true);
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AuthLayout(
      title: l.authPhoneSignIn,
      subtitle: _codeSent ? l.authCodeSentTo(_phone.text) : l.authSignInSubtitle,
      art: GlowArt.bell,
      showBack: true,
      children: [
        GlowField(controller: _phone, label: l.authPhone, keyboardType: TextInputType.phone, autofill: const [AutofillHints.telephoneNumber], textDirection: TextDirection.ltr),
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: !_codeSent
              ? AnimatedButton(label: l.authSendCode, onPressed: _send)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GlowField(
                      controller: _code,
                      label: l.authEnterCode,
                      keyboardType: TextInputType.number,
                      autofill: const [AutofillHints.oneTimeCode],
                      textDirection: TextDirection.ltr,
                    ),
                    if (_devCode != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: Space.md),
                        child: Text(l.authDevCodeHint(_devCode!), style: context.text.bodySmall),
                      ),
                    if (_needsName) GlowField(controller: _name, label: l.authFullName, autofill: const [AutofillHints.name]),
                    AnimatedButton(label: l.authVerify, onPressed: _verify, keepSuccess: true),
                  ],
                ),
        ),
      ],
    );
  }
}
