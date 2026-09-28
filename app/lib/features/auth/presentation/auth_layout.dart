import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/glow_illustration.dart';
import '../../../shared/animations/staggered_entrance.dart';

/// Shared frame for auth screens: brand panel beside the form on wide screens,
/// a soft gradient header above it on phones.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.title, required this.subtitle, required this.children, this.art = GlowArt.mirror, this.showBack = false});
  final String title;
  final String subtitle;
  final List<Widget> children;
  final GlowArt art;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= Breakpoints.tablet;
    final form = SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: Space.xl, vertical: Space.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!wide) ...[
                    Center(child: GlowIllustration(art, size: 104)),
                    const SizedBox(height: Space.lg),
                  ],
                  StaggeredEntrance(index: 0, child: Text(title, style: context.text.headlineLarge, textAlign: wide ? TextAlign.start : TextAlign.center)),
                  const SizedBox(height: Space.sm),
                  StaggeredEntrance(
                    index: 1,
                    child: Text(subtitle, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant), textAlign: wide ? TextAlign.start : TextAlign.center),
                  ),
                  const SizedBox(height: Space.xl),
                  for (var i = 0; i < children.length; i++) StaggeredEntrance(index: i + 2, child: children[i]),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: showBack ? AppBar(backgroundColor: Colors.transparent) : null,
      extendBodyBehindAppBar: true,
      body: wide
          ? Row(
              children: [
                Expanded(child: _BrandPanel(art: art)),
                Expanded(child: form),
              ],
            )
          : DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.center,
                  colors: [context.colors.primaryContainer.withValues(alpha: 0.55), Theme.of(context).scaffoldBackgroundColor],
                ),
              ),
              child: form,
            ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel({required this.art});
  final GlowArt art;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(Space.lg),
      decoration: BoxDecoration(gradient: context.glow.heroGradient, borderRadius: Radii.xlAll),
      padding: const EdgeInsets.all(Space.xxxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.auto_awesome_rounded, color: context.colors.primary),
            const SizedBox(width: Space.sm),
            Text(context.l10n.appName, style: context.text.headlineSmall),
          ]),
          const Spacer(),
          Center(child: GlowIllustration(art, size: 220)),
          const Spacer(),
          Text(context.l10n.appTagline, style: context.text.displaySmall),
        ],
      ),
    );
  }
}

/// Visible-label text field with the house styling and validation.
class GlowField extends StatelessWidget {
  const GlowField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.validator,
    this.keyboardType,
    this.autofill,
    this.obscure = false,
    this.suffix,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.maxLines = 1,
    this.prefixIcon,
    this.helper,
    this.textDirection,
  });
  final TextEditingController controller;
  final String label;
  final String? hint;
  final String? helper;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final Iterable<String>? autofill;
  final bool obscure;
  final Widget? suffix;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final int maxLines;
  final IconData? prefixIcon;
  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.lg),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        autofillHints: autofill,
        obscureText: obscure,
        textInputAction: maxLines > 1 ? TextInputAction.newline : textInputAction,
        onFieldSubmitted: onSubmitted,
        maxLines: obscure ? 1 : maxLines,
        textDirection: textDirection,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: helper,
          helperMaxLines: 2,
          suffixIcon: suffix,
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
        ),
      ),
    );
  }
}

/// Common validators.
class V {
  V(this.context);
  final BuildContext context;
  String? required(String? v) => (v == null || v.trim().isEmpty) ? context.l10n.errorRequired : null;
  String? email(String? v) => (v == null || !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) ? context.l10n.errorEmail : null;
  String? phone(String? v) => (v == null || !RegExp(r'^\+?\d{8,15}$').hasMatch(v.replaceAll(RegExp(r'[\s\-()]'), ''))) ? context.l10n.errorPhone : null;
  String? optionalPhone(String? v) => (v == null || v.trim().isEmpty) ? null : phone(v);
  String? password(String? v) => (v == null || v.length < 8) ? context.l10n.errorPasswordShort : null;
  String? number(String? v) => (v == null || double.tryParse(v.trim()) == null) ? context.l10n.errorNumber : null;
}
