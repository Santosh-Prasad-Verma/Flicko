import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Aura AI settings state, persisted via SharedPreferences.
class AuraSettings {
  final String themeName;
  final Color accentColor;
  final String language;
  final double temperature;
  final bool autoVoiceAutoplay;

  const AuraSettings({
    this.themeName = 'Sync with App',
    this.accentColor = Colors.transparent,
    this.language = 'English',
    this.temperature = 0.7,
    this.autoVoiceAutoplay = false,
  });

  AuraSettings copyWith({
    String? themeName,
    Color? accentColor,
    String? language,
    double? temperature,
    bool? autoVoiceAutoplay,
  }) {
    return AuraSettings(
      themeName: themeName ?? this.themeName,
      accentColor: accentColor ?? this.accentColor,
      language: language ?? this.language,
      temperature: temperature ?? this.temperature,
      autoVoiceAutoplay: autoVoiceAutoplay ?? this.autoVoiceAutoplay,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'themeName': themeName,
      'accentColor': accentColor.value,
      'language': language,
      'temperature': temperature,
      'autoVoiceAutoplay': autoVoiceAutoplay,
    };
  }

  factory AuraSettings.fromMap(Map<String, dynamic> map) {
    return AuraSettings(
      themeName: map['themeName'] as String? ?? 'Sync with App',
      accentColor: Color(map['accentColor'] as int? ?? Colors.transparent.value),
      language: map['language'] as String? ?? 'English',
      temperature: (map['temperature'] as num?)?.toDouble() ?? 0.7,
      autoVoiceAutoplay: map['autoVoiceAutoplay'] as bool? ?? false,
    );
  }
}

/// Available themes with name-to-color mapping.
class AuraTheme {
  final String name;
  final Color color;
  const AuraTheme({required this.name, required this.color});
}

const List<AuraTheme> auraThemes = [
  AuraTheme(name: 'Sync with App', color: Colors.transparent),
  AuraTheme(name: 'Neon Glow', color: Color(0xFF7B4FFF)),
  AuraTheme(name: 'Cyberpunk Violet', color: Color(0xFFFF00F5)),
  AuraTheme(name: 'Emerald Aurora', color: Color(0xFF00FFCC)),
  AuraTheme(name: 'Sunset Gold', color: Color(0xFFFFB300)),
  AuraTheme(name: 'Ocean Blue', color: Color(0xFF0091FF)),
  AuraTheme(name: 'Cherry Red', color: Color(0xFFFF3B5C)),
];

/// Supported languages.
const List<String> auraLanguages = [
  'English',
  'Deutsch',
  'Español',
  'Français',
  'हिन्दी',
  '日本語',
  '中文',
  'Português',
];

class AuraSettingsNotifier extends Notifier<AuraSettings> {
  static const String _storageKey = 'flicko_aura_settings';

  @override
  AuraSettings build() {
    _loadSettings();
    return const AuraSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_storageKey);
      if (data != null) {
        final map = jsonDecode(data) as Map<String, dynamic>;
        state = AuraSettings.fromMap(map);
      }
    } catch (_) {
      // Fallback to defaults
    }
  }

  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(state.toMap()));
    } catch (_) {}
  }

  void setTheme(String themeName, Color accentColor) {
    state = state.copyWith(themeName: themeName, accentColor: accentColor);
    _saveSettings();
  }

  void setLanguage(String language) {
    state = state.copyWith(language: language);
    _saveSettings();
  }

  void setTemperature(double temperature) {
    state = state.copyWith(temperature: temperature);
    _saveSettings();
  }

  void setAutoVoiceAutoplay(bool value) {
    state = state.copyWith(autoVoiceAutoplay: value);
    _saveSettings();
  }
}

final auraSettingsProvider =
    NotifierProvider<AuraSettingsNotifier, AuraSettings>(
  AuraSettingsNotifier.new,
);
