import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/ai_assistant/translate/application/translate_settings_provider.dart';
import 'package:mobile/features/ai_assistant/translate/domain/translation.dart';
import 'package:mobile/features/sonic_music/localization/app_localizations.dart';

/// Settings screen for the AI Auto-Translate feature.
///
/// Lives under Settings → AI → Auto-translate. Lets the user pick:
///   • target_lang — the language to translate INTO
///   • fluent_langs — languages they understand (skipped on auto-translate)
///   • behavior — always | ask | never
///   • show_provider_chip — show the LibreTranslate/DeepL chip in the panel
class TranslateSettingsScreen extends ConsumerWidget {
  const TranslateSettingsScreen({super.key});

  static const String routeName = '/settings/translate';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final async = ref.watch(translateUserSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.translateSettingsTitle ?? 'Auto-translate'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (settings) => _Body(settings: settings),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.settings});
  final TranslateUserSettings settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final controller = ref.read(translateUserSettingsProvider.notifier);

    return ListView(
      children: [
        _SectionHeader(text: l10n?.translateSettingsTargetLabel ?? 'Translate into'),
        _LangPicker(
          value: settings.targetLang,
          onChanged: (lang) => controller.save(
            TranslateUserSettingsPatch(targetLang: lang),
          ),
        ),
        const Divider(height: 24),
        _SectionHeader(
          text: l10n?.translateSettingsBehaviorLabel ??
              'When you receive a message in another language',
        ),
        for (final b in TranslateBehavior.values)
          RadioListTile<TranslateBehavior>(
            title: Text(_labelForBehavior(b, l10n)),
            value: b,
            groupValue: settings.behavior,
            onChanged: (v) {
              if (v == null) return;
              controller.save(
                TranslateUserSettingsPatch(behavior: v),
              );
            },
          ),
        const Divider(height: 24),
        _SectionHeader(
          text: l10n?.translateSettingsFluentLabel ?? 'Languages you understand',
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(
            l10n?.translateSettingsFluentHint ??
                "We won't offer to translate messages already in these languages.",
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final lang in _supportedLangs)
                FilterChip(
                  label: Text(lang.label),
                  selected: settings.fluentLangs.contains(lang.code),
                  onSelected: (selected) {
                    final next = List<String>.from(settings.fluentLangs);
                    if (selected) {
                      if (!next.contains(lang.code)) next.add(lang.code);
                    } else {
                      next.remove(lang.code);
                    }
                    if (next.isEmpty) next.add('en');
                    controller.save(
                      TranslateUserSettingsPatch(fluentLangs: next),
                    );
                  },
                ),
            ],
          ),
        ),
        const Divider(height: 24),
        SwitchListTile(
          title: Text(l10n?.translateSettingsShowProvider ??
              'Show translation provider'),
          value: settings.showProviderChip,
          onChanged: (v) => controller.save(
            TranslateUserSettingsPatch(showProviderChip: v),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  static String _labelForBehavior(TranslateBehavior b, AppLocalizations? l10n) {
    switch (b) {
      case TranslateBehavior.always:
        return l10n?.translateBehaviorAlways ?? 'Always translate';
      case TranslateBehavior.ask:
        return l10n?.translateBehaviorAsk ?? 'Show a Translate option';
      case TranslateBehavior.never:
        return l10n?.translateBehaviorNever ?? 'Never translate';
    }
  }
}

class _LangPicker extends StatelessWidget {
  const _LangPicker({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: DropdownButton<String>(
        value: _supportedLangs.any((l) => l.code == value) ? value : 'en',
        isExpanded: true,
        onChanged: (v) {
          if (v != null) onChanged(v);
        },
        items: [
          for (final lang in _supportedLangs)
            DropdownMenuItem(
              value: lang.code,
              child: Text(lang.label),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        text,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _Lang {
  final String code;
  final String label;
  const _Lang(this.code, this.label);
}

/// Subset of LibreTranslate's supported pairs. Expand as we onboard.
const List<_Lang> _supportedLangs = [
  _Lang('en', 'English'),
  _Lang('es', 'Español'),
  _Lang('fr', 'Français'),
  _Lang('de', 'Deutsch'),
  _Lang('it', 'Italiano'),
  _Lang('pt', 'Português'),
  _Lang('nl', 'Nederlands'),
  _Lang('pl', 'Polski'),
  _Lang('ru', 'Русский'),
  _Lang('uk', 'Українська'),
  _Lang('tr', 'Türkçe'),
  _Lang('ar', 'العربية'),
  _Lang('he', 'עברית'),
  _Lang('hi', 'हिन्दी'),
  _Lang('bn', 'বাংলা'),
  _Lang('ja', '日本語'),
  _Lang('ko', '한국어'),
  _Lang('zh', '中文'),
  _Lang('vi', 'Tiếng Việt'),
  _Lang('id', 'Bahasa Indonesia'),
  _Lang('th', 'ไทย'),
];
