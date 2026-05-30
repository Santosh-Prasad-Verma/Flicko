import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/features/store/data/store_theme_service.dart';
import 'app_theme.dart';

/// Available theme IDs matching AppTheme definitions
enum AppThemeMode {
  dark,
  light,
  amoled,
  plus,
}

/// Theme provider using SharedPreferences for persistence
final themeProvider = NotifierProvider<ThemeNotifier, String>(ThemeNotifier.new);

class ThemeNotifier extends Notifier<String> {
  @override
  String build() {
    _loadTheme();
    return 'dark';
  }

  static const String _themeKey = 'selected_theme';

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString(_themeKey);
    if (savedTheme != null) {
      state = savedTheme;
    }
  }

  Future<void> setTheme(String theme) async {
    if (state != theme) {
      state = theme;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, theme);
    }
  }

  ThemeData get currentTheme {
    switch (state) {
      case 'light':
        return AppTheme.lightTheme;
      case 'amoled':
        return AppTheme.amoledTheme;
      case 'plus':
        return AppTheme.plusTheme;
      case 'dark':
      default:
        return AppTheme.darkTheme;
    }
  }
}

/// Provider that returns the active theme, prioritizing store themes.
/// Watched by MaterialApp so any theme change rebuilds the whole app.
final themeDataProvider = Provider<ThemeData>((ref) {
  ref.watch(themeProvider);
  final storeTheme = ref.watch(activeStoreThemeProvider);

  if (storeTheme != null) {
    return ref.read(storeThemeDataProvider) ?? ref.read(themeProvider.notifier).currentTheme;
  }

  return ref.read(themeProvider.notifier).currentTheme;
});

/// Locale provider — persists selected language and drives MaterialApp.locale.
final appLocaleProvider = NotifierProvider<AppLocaleNotifier, Locale>(AppLocaleNotifier.new);

class AppLocaleNotifier extends Notifier<Locale> {
  static const _key = 'language';

  @override
  Locale build() {
    _load();
    return const Locale('en');
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key) ?? 'en';
    state = Locale(code);
  }

  Future<void> setLocale(String languageCode) async {
    state = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, languageCode);
  }
}

