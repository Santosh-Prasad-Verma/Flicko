import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final translationServiceProvider = NotifierProvider<TranslationService, Map<String, dynamic>>(TranslationService.new);

class TranslationService extends Notifier<Map<String, dynamic>> {
  String _currentLocale = 'en';
  String get currentLocale => _currentLocale;

  @override
  Map<String, dynamic> build() {
    return {};
  }

  Future<void> loadLocale(String locale) async {
    try {
      final String jsonContent = await rootBundle.loadString('assets/translations/$locale.json');
      final Map<String, dynamic> decoded = json.decode(jsonContent);
      state = decoded;
      _currentLocale = locale;
    } catch (e) {
      // Fallback to English if not found
      if (locale != 'en') {
        await loadLocale('en');
      }
    }
  }

  String translate(String key) {
    List<String> keys = key.split('.');
    dynamic value = state;

    for (var k in keys) {
      if (value is Map && value.containsKey(k)) {
        value = value[k];
      } else {
        return key; // Return the key itself if not found
      }
    }

    return value?.toString() ?? key;
  }
}

// Extension for easier access in Widgets
extension TranslateExtension on WidgetRef {
  String tr(String key) {
    return read(translationServiceProvider.notifier).translate(key);
  }
}
