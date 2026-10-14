import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/providers.dart';

/// UI preferences (language) — per device, persisted locally. The app always uses the
/// light theme.
@immutable
class AppPreferences {
  const AppPreferences({required this.locale});
  final Locale locale;

  AppPreferences copyWith({Locale? locale}) => AppPreferences(locale: locale ?? this.locale);
}

class PreferencesController extends Notifier<AppPreferences> {
  static const _localeKey = 'prefs.locale';

  @override
  AppPreferences build() {
    final prefs = ref.watch(sharedPrefsProvider);
    final saved = prefs.getString(_localeKey);
    final device = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    final code = saved ?? (device == 'ar' ? 'ar' : 'en');
    ref.read(apiClientProvider).locale = code;
    return AppPreferences(locale: Locale(code));
  }

  Future<void> setLocale(String code) async {
    await ref.read(sharedPrefsProvider).setString(_localeKey, code);
    ref.read(apiClientProvider).locale = code;
    state = state.copyWith(locale: Locale(code));
  }
}

final preferencesProvider = NotifierProvider<PreferencesController, AppPreferences>(PreferencesController.new);
