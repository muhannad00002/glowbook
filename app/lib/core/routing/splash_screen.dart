import 'package:flutter/material.dart';

import '../../shared/animations/animated_button.dart';
import '../../shared/animations/glow_illustration.dart';
import '../theme/app_colors.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';

/// Shown while the stored session is restored.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: context.glow.heroGradient),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.85, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(scale: v, child: child),
              child: const GlowIllustration(GlowArt.mirror, size: 120),
            ),
            const SizedBox(height: Space.lg),
            Text(context.l10n.appName, style: context.text.displaySmall),
            const SizedBox(height: Space.lg),
            const InlineLoader(),
          ]),
        ),
      ),
    );
  }
}
