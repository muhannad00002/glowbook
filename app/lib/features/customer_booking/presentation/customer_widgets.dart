import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/errors/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/motion.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/utils/format.dart';
import '../../../shared/animations/animated_button.dart';
import '../../../shared/widgets/common.dart';
import '../../../shared/widgets/fit_layout.dart';
import '../../auth/presentation/auth_layout.dart';

/// Pieces shared by the customer screens (booking, seasonal tokens, the link pages).

/// Default country for numbers typed without a "+" prefix.
const countryCode = '+968';

String composePhone(String raw) {
  final v = raw.replaceAll(RegExp(r'[\s\-()]'), '');
  if (v.startsWith('+')) return v;
  if (v.startsWith('00')) return '+${v.substring(2)}';
  return '$countryCode$v';
}

/// Name + phone: all a customer gives us (no account, no password).
class DetailsForm extends StatelessWidget {
  const DetailsForm({super.key, required this.form, required this.name, required this.phone, this.helper});
  final GlobalKey<FormState> form;
  final TextEditingController name;
  final TextEditingController phone;
  final String? helper;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final v = V(context);
    return AutofillGroup(
      child: Form(
        key: form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlowField(
              controller: name,
              label: l.authFullName,
              autofill: const [AutofillHints.name],
              validator: v.required,
              prefixIcon: Icons.person_outline_rounded,
            ),
            TextFormField(
              controller: phone,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              textInputAction: TextInputAction.done,
              textDirection: TextDirection.ltr,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s\-()]'))],
              validator: (raw) => v.phone(composePhone(raw ?? '')),
              decoration: InputDecoration(
                labelText: l.authPhone,
                helperText: helper,
                helperMaxLines: 2,
                prefixIcon: Padding(
                  padding: const EdgeInsetsDirectional.only(start: Space.md, end: Space.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_iphone_rounded, size: 20),
                      const SizedBox(width: Space.sm),
                      Text(
                        countryCode,
                        textDirection: TextDirection.ltr,
                        style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one-time-code step body: six boxes, the test-mode helper, resend / change number.
class VerifyBody extends StatelessWidget {
  const VerifyBody({super.key, required this.code, required this.sentAt, this.testCode, required this.onResend, required this.onChangeNumber});
  final TextEditingController code;
  final DateTime? sentAt;
  final String? testCode;
  final Future<void> Function() onResend;
  final VoidCallback onChangeNumber;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final wait = 30 - DateTime.now().difference(sentAt ?? DateTime.now()).inSeconds;
    return FitBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OtpCodeInput(controller: code),
          if (testCode != null) ...[
            const SizedBox(height: Space.lg),
            PressableScale(
              onTap: () => code.text = testCode!,
              child: GlowCard(
                elevated: false,
                color: context.colors.tertiaryContainer,
                child: Row(
                  children: [
                    Icon(Icons.science_outlined, color: context.colors.onTertiaryContainer),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: Text(l.flowTestCode(testCode!), style: context.text.bodyMedium?.copyWith(color: context.colors.onTertiaryContainer)),
                    ),
                    Icon(Icons.input_rounded, color: context.colors.onTertiaryContainer),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: Space.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              wait > 0
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(l.flowResendIn(wait), style: context.text.bodySmall),
                    )
                  : TextButton(onPressed: () => onResend().catchError((_) {}), child: Text(l.flowResend)),
              TextButton(onPressed: onChangeNumber, child: Text(l.flowChangeNumber)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Six boxes over one real text field — so iOS can autofill the SMS code
/// ("From Messages") and paste works.
class OtpCodeInput extends StatefulWidget {
  const OtpCodeInput({super.key, required this.controller});
  final TextEditingController controller;
  @override
  State<OtpCodeInput> createState() => _OtpCodeInputState();
}

class _OtpCodeInputState extends State<OtpCodeInput> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  void _changed() {
    if (widget.controller.text.length == 6) _focus.unfocus();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    final motion = Motion.of(context);
    final text = widget.controller.text;
    return Semantics(
      label: context.l10n.flowEnterCode,
      textField: true,
      child: GestureDetector(
        onTap: () => _focus.requestFocus(),
        child: SizedBox(
          height: 64,
          child: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                    showCursor: false,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              IgnorePointer(
                child: Directionality(
                  textDirection: TextDirection.ltr,
                  child: Row(
                    children: [
                      for (var i = 0; i < 6; i++) ...[
                        if (i > 0) SizedBox(width: i == 3 ? Space.md : Space.sm),
                        Expanded(
                          child: AnimatedContainer(
                            duration: motion.fast,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: Radii.mdAll,
                              border: Border.all(
                                color: i == text.length && _focus.hasFocus
                                    ? scheme.primary
                                    : (i < text.length ? scheme.primary.withValues(alpha: 0.5) : scheme.outlineVariant),
                                width: i == text.length && _focus.hasFocus ? 2 : 1.2,
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: motion.fast,
                              transitionBuilder: (c, a) => ScaleTransition(
                                scale: CurvedAnimation(parent: a, curve: Motion.pop),
                                child: c,
                              ),
                              child: Text(
                                i < text.length ? text[i] : '',
                                key: ValueKey('$i-${i < text.length ? text[i] : ''}'),
                                style: context.text.titleLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A selectable row for a grid: a service, an offering, a time.
class ChoiceTile extends StatelessWidget {
  const ChoiceTile({super.key, required this.selected, required this.onTap, required this.child, this.multi = false, this.enabled = true, this.dense = false});
  final bool selected;
  final bool multi;
  final bool enabled;
  final bool dense;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      child: PressableScale(
        onTap: enabled
            ? () {
                HapticFeedback.selectionClick();
                onTap();
              }
            : null,
        child: AnimatedContainer(
          duration: Motion.of(context).fast,
          curve: Motion.standard,
          padding: EdgeInsets.symmetric(horizontal: dense ? Space.sm : Space.lg, vertical: dense ? 4 : Space.sm),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : (enabled ? scheme.surface : scheme.surfaceContainerLow),
            borderRadius: dense ? Radii.mdAll : Radii.lgAll,
            border: Border.all(color: selected ? scheme.primary : scheme.outlineVariant.withValues(alpha: enabled ? 0.8 : 0.4)),
            boxShadow: selected ? [BoxShadow(color: scheme.primary.withValues(alpha: 0.25), blurRadius: 12, offset: const Offset(0, 4))] : null,
          ),
          child: DefaultTextStyle.merge(
            style: TextStyle(color: selected ? scheme.onPrimary : (enabled ? scheme.onSurface : scheme.onSurfaceVariant.withValues(alpha: 0.5))),
            child: IconTheme.merge(
              data: IconThemeData(color: selected ? scheme.onPrimary : scheme.primary),
              child: dense
                  ? Center(child: child)
                  : Row(
                      children: [
                        Expanded(child: child),
                        const SizedBox(width: Space.sm),
                        Icon(
                          multi
                              ? (selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded)
                              : (selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded),
                          color: selected ? scheme.onPrimary : scheme.outline,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Text inside a [ChoiceTile] that follows its selected colour.
class TileText extends StatelessWidget {
  const TileText(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) {
    final color = DefaultTextStyle.of(context).style.color;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: context.text.titleMedium?.copyWith(color: color),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: context.text.bodySmall?.copyWith(color: color?.withValues(alpha: 0.8)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }
}

/// A day in a 7-column date grid.
class DayCell extends StatelessWidget {
  const DayCell({super.key, required this.date, required this.selected, required this.enabled, required this.onTap});
  final String date;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final d = Ymd.parse(date);
    final lang = context.lang;
    return ChoiceTile(
      dense: true,
      selected: selected,
      enabled: enabled,
      onTap: onTap,
      child: Semantics(
        label: DateFormat.MMMMEEEEd(lang).format(d),
        child: ExcludeSemantics(
          child: Builder(
            builder: (context) {
              final color = DefaultTextStyle.of(context).style.color;
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FittedBox(fit: BoxFit.scaleDown, child: Text(DateFormat.E(lang).format(d), style: context.text.labelSmall?.copyWith(color: color), maxLines: 1)),
                  Text(
                    DateFormat.d(lang).format(d),
                    style: context.text.titleMedium?.copyWith(color: color, fontWeight: FontWeight.w700),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A time in a time grid, with an optional second line (e.g. "2 left").
class TimeCell extends StatelessWidget {
  const TimeCell({super.key, required this.label, this.sub, required this.selected, this.enabled = true, required this.onTap});
  final String label;
  final String? sub;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ChoiceTile(
    dense: true,
    selected: selected,
    enabled: enabled,
    onTap: onTap,
    child: Builder(
      builder: (context) {
        final color = DefaultTextStyle.of(context).style.color;
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: context.text.labelLarge?.copyWith(color: color, decoration: enabled ? null : TextDecoration.lineThrough),
              maxLines: 1,
            ),
            if (sub != null) Text(sub!, style: context.text.labelSmall?.copyWith(color: color?.withValues(alpha: 0.8)), maxLines: 1),
          ],
        );
      },
    ),
  );
}

/// A centred hint in an empty step (nothing free that day, etc.).
class StepHint extends StatelessWidget {
  const StepHint({super.key, required this.icon, required this.text, this.action});
  final IconData icon;
  final String text;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Center(
    child: FitBox(
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: context.colors.onSurfaceVariant),
          const SizedBox(height: Space.md),
          Text(text, style: context.text.bodyLarge, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: Space.md), action!],
        ],
      ),
    ),
  );
}

/// What a customer sees when her link is wrong or past its date.
Widget linkErrorView(BuildContext context, Object error, {VoidCallback? onRetry}) {
  final l = context.l10n;
  final status = error is ApiException ? error.status : null;
  if (status == 410 || status == 403 || status == 404) {
    return FitMessage(
      icon: status == 410 ? Icons.timer_off_outlined : Icons.link_off_rounded,
      title: status == 410 ? l.linkExpiredTitle : l.linkInvalidTitle,
      body: status == 410 ? l.linkExpiredBody : l.linkInvalidBody,
    );
  }
  return FitMessage(
    icon: Icons.cloud_off_rounded,
    title: context.fmt.error(error),
    action: onRetry == null ? null : FilledButton(onPressed: onRetry, child: Text(l.actionRetry)),
  );
}
