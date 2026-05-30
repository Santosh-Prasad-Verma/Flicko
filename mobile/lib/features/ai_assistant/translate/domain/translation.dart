/// Domain types for the AI Auto-Translate feature.
library;

import 'package:flutter/foundation.dart';

@immutable
class Translation {
  final String text;
  final String srcLang;
  final String tgtLang;
  final String provider;
  final bool cached;
  final int latencyMs;

  const Translation({
    required this.text,
    required this.srcLang,
    required this.tgtLang,
    required this.provider,
    this.cached = false,
    this.latencyMs = 0,
  });
}

enum TranslationStatus { idle, loading, ready, error }

@immutable
class TranslationState {
  final TranslationStatus status;
  final Translation? value;
  final String? errorCode;

  const TranslationState({
    this.status = TranslationStatus.idle,
    this.value,
    this.errorCode,
  });

  TranslationState copyWith({
    TranslationStatus? status,
    Translation? value,
    String? errorCode,
  }) {
    return TranslationState(
      status: status ?? this.status,
      value: value ?? this.value,
      errorCode: errorCode ?? this.errorCode,
    );
  }
}

/// Per-user translate prefs surfaced through `/ai/translate/settings`.
@immutable
class TranslateUserSettings {
  final String targetLang;
  final List<String> fluentLangs;
  final TranslateBehavior behavior;
  final bool showProviderChip;

  const TranslateUserSettings({
    required this.targetLang,
    required this.fluentLangs,
    required this.behavior,
    required this.showProviderChip,
  });

  static const TranslateUserSettings defaults = TranslateUserSettings(
    targetLang: 'en',
    fluentLangs: ['en'],
    behavior: TranslateBehavior.ask,
    showProviderChip: true,
  );

  factory TranslateUserSettings.fromJson(Map<String, dynamic> json) {
    return TranslateUserSettings(
      targetLang: (json['target_lang'] as String?) ?? 'en',
      fluentLangs:
          ((json['fluent_langs'] as List?)?.cast<String>()) ?? const ['en'],
      behavior: _behaviorFromString(json['behavior'] as String?),
      showProviderChip: (json['show_provider_chip'] as bool?) ?? true,
    );
  }

  TranslateUserSettings copyWith({
    String? targetLang,
    List<String>? fluentLangs,
    TranslateBehavior? behavior,
    bool? showProviderChip,
  }) {
    return TranslateUserSettings(
      targetLang: targetLang ?? this.targetLang,
      fluentLangs: fluentLangs ?? this.fluentLangs,
      behavior: behavior ?? this.behavior,
      showProviderChip: showProviderChip ?? this.showProviderChip,
    );
  }
}

enum TranslateBehavior { always, ask, never }

TranslateBehavior _behaviorFromString(String? raw) {
  switch (raw) {
    case 'always':
      return TranslateBehavior.always;
    case 'never':
      return TranslateBehavior.never;
    default:
      return TranslateBehavior.ask;
  }
}

extension TranslateBehaviorWire on TranslateBehavior {
  String get wire => name; // always|ask|never
}

/// Patch shape sent to PATCH `/ai/translate/settings`. Only non-null fields
/// are written; everything else preserves its current value.
class TranslateUserSettingsPatch {
  final String? targetLang;
  final List<String>? fluentLangs;
  final TranslateBehavior? behavior;
  final bool? showProviderChip;

  const TranslateUserSettingsPatch({
    this.targetLang,
    this.fluentLangs,
    this.behavior,
    this.showProviderChip,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      if (targetLang != null) 'target_lang': targetLang,
      if (fluentLangs != null) 'fluent_langs': fluentLangs,
      if (behavior != null) 'behavior': behavior!.wire,
      if (showProviderChip != null) 'show_provider_chip': showProviderChip,
    };
  }
}
