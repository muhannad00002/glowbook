import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_web_plugins/url_strategy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_10y.dart' as tzdata;

import 'core/api/providers.dart';
import 'core/localization/preferences_controller.dart';
import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'l10n/app_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Clean URLs on the web: /salon/maison-beauty instead of /#/salon/maison-beauty.
  usePathUrlStrategy();
  tzdata.initializeTimeZones();
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [sharedPrefsProvider.overrideWithValue(prefs)], child: const GlowbookApp()));
}

class GlowbookApp extends ConsumerWidget {
  const GlowbookApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(preferencesProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Glowbook',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: prefs.locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Glowbook is a light-theme product.
      themeMode: ThemeMode.light,
      theme: AppTheme.light(prefs.locale),
    );
  }
}
