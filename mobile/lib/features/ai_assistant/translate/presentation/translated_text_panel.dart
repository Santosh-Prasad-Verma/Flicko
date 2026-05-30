import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/ai_assistant/translate/application/translate_provider.dart';
import 'package:mobile/features/ai_assistant/translate/application/translate_settings_provider.dart';
import 'package:mobile/features/ai_assistant/translate/domain/translation.dart';
import 'package:mobile/features/sonic_music/localization/app_localizations.dart';

/// Inline panel rendered below a message bubble after it's been translated.
///
/// Shows the translated text, a small provider chip, and a "Show original"
/// toggle that hides the panel. Designed to slot into existing message
/// rendering without forking the bubble widget.
///
/// When the user's translate behavior is `always`, the panel auto-triggers
/// a translation on first build (one-shot). Otherwise it waits for the user
/// to explicitly tap Translate from the message-actions menu.
class TranslatedTextPanel extends ConsumerStatefulWidget {
  const TranslatedTextPanel({
    super.key,
    required this.messageId,
    required this.messageText,
    this.channelId,
    this.compact = false,
  });

  final String messageId;
  final String messageText;
  final String? channelId;
  final bool compact;

  @override
  ConsumerState<TranslatedTextPanel> createState() =>
      _TranslatedTextPanelState();
}

class _TranslatedTextPanelState extends ConsumerState<TranslatedTextPanel> {
  bool _autoTriggered = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoTranslate());
  }

  @override
  void didUpdateWidget(covariant TranslatedTextPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.messageId != widget.messageId) {
      _autoTriggered = false;
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAutoTranslate());
    }
  }

  void _maybeAutoTranslate() {
    if (_autoTriggered || !mounted) return;
    final asyncSettings = ref.read(translateUserSettingsProvider);
    final settings = asyncSettings.hasValue ? asyncSettings.value : null;
    if (settings?.behavior != TranslateBehavior.always) return;
    if (widget.messageText.trim().isEmpty) return;

    final state =
        ref.read(translationProvider(TranslateKey(widget.messageId)));
    if (state.status != TranslationStatus.idle) return;

    _autoTriggered = true;
    final target = ref.read(translateTargetLangProvider);
    ref
        .read(translationProvider(TranslateKey(widget.messageId)).notifier)
        .translate(
          text: widget.messageText,
          target: target,
          channelId: widget.channelId,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(translationProvider(TranslateKey(widget.messageId)));
    if (state.status == TranslationStatus.idle) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    if (state.status == TranslationStatus.loading) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: scheme.outline),
            ),
            const SizedBox(width: 8),
            Text(
              l10n?.translateInProgress ?? 'Translating…',
              style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      );
    }

    if (state.status == TranslationStatus.error) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          l10n?.translateErrorBody ?? "Couldn't translate. Tap retry from the menu.",
          style: theme.textTheme.labelSmall?.copyWith(color: scheme.error),
        ),
      );
    }

    final v = state.value!;
    final asyncSettings = ref.watch(translateUserSettingsProvider);
    final showProvider =
        (asyncSettings.hasValue ? asyncSettings.value : null)
                ?.showProviderChip ??
            true;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border(
            left: BorderSide(color: scheme.primary, width: 2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.translate, size: 12, color: scheme.outline),
                  const SizedBox(width: 6),
                  Text(
                    '${v.srcLang.toUpperCase()} → ${v.tgtLang.toUpperCase()}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.outline,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  if (showProvider) ...[
                    const SizedBox(width: 8),
                    Text(
                      v.provider,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: scheme.outline),
                    ),
                  ],
                  if (v.cached) ...[
                    const SizedBox(width: 6),
                    Text(
                      l10n?.translateCachedSuffix ?? '· cached',
                      style: theme.textTheme.labelSmall?.copyWith(color: scheme.outline),
                    ),
                  ],
                  const Spacer(),
                  InkWell(
                    onTap: () => ref
                        .read(translationProvider(TranslateKey(widget.messageId)).notifier)
                        .clear(),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Text(
                        l10n?.translateHide ?? 'Hide',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              SelectableText(
                v.text,
                style: widget.compact ? theme.textTheme.bodySmall : theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
