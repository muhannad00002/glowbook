import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/providers.dart';

/// UI preferences (language + theme) — per device, persisted locally.
@immutable
class AppPreferences {
  const AppPreferences({required this.locale, required this.themeMode});
  final Locale locale;
  final ThemeMode themeMode;

  AppPreferences copyWith({Locale? locale, ThemeMode? themeMode}) =>
      AppPreferences(locale: locale ?? this.locale, themeMode: themeMode ?? this.themeMode);
}

class PreferencesController extends Notifier<AppPreferences> {
  static const _localeKey = 'prefs.locale';
  static const _themeKey = 'prefs.theme';

  @override
  AppPreferences build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final saved = prefs.getString(_localeKey);
    final device = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final code = saved ?? (device == 'ar' ? 'ar' : 'en');
    final theme = ThemeMode.values.firstWhere(
      (m) => m.name == prefs.getString(_themeKey),
      orElse: () => ThemeMode.system,
    );
    ref.read(apiClientProvider).locale = code;
    return AppPreferences(locale: Locale(code), themeMode: theme);
  }

  Future<void> setLocale(String code) async {
    await ref.read(sharedPrefsProvider).setString(_localeKey, code);
    ref.read(apiClientProvider).locale = code;
    state = state.copyWith(locale: Locale(code));
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await ref.read(sharedPrefsProvider).setString(_themeKey, mode.name);
    state = state.copyWith(themeMode: mode);
  }
}

final preferencesProvider = NotifierProvider<PreferencesController, AppPreferences>(PreferencesController.new);
