import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/ai_assistant/summary/application/summary_provider.dart';
import 'package:mobile/features/ai_assistant/summary/domain/summary.dart';
import 'package:mobile/features/ai_assistant/summary/presentation/summary_card.dart';
import 'package:mobile/features/sonic_music/localization/app_localizations.dart';

/// "✦ Catch me up" pill rendered in [ChannelMessagesScreen] when the user
/// has unread messages above the unread separator.
///
/// Tap → kicks off a generation; the same widget then expands into the
/// [SummaryCard]. Tapping the card's close button collapses back to the pill.
class CatchMeUpPill extends ConsumerWidget {
  const CatchMeUpPill({
    super.key,
    required this.channelId,
    required this.serverId,
    this.lastReadAt,
    this.lastReadMsgId,
  });

  final String channelId;
  final String serverId;
  final DateTime? lastReadAt;
  final String? lastReadMsgId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(summaryControllerProvider(channelId));
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    if (summary.status == SummaryStatus.idle) {
      return _PillButton(
        label: l10n?.summaryCatchMeUp ?? 'Catch me up',
        semanticLabel:
            l10n?.summarySemanticPill ?? 'Catch me up on missed messages',
        onTap: () {
          ref.read(summaryControllerProvider(channelId).notifier).start(
                serverId: serverId,
                since: lastReadAt,
                anchorMsgId: lastReadMsgId,
              );
        },
        theme: theme,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SummaryCard(channelId: channelId),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.onTap,
    required this.theme,
    required this.label,
    required this.semanticLabel,
  });
  final VoidCallback onTap;
  final ThemeData theme;
  final String label;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Semantics(
          button: true,
          label: semanticLabel,
          child: Material(
            color: scheme.primaryContainer,
            shape: const StadiumBorder(),
            elevation: 0,
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 18, color: scheme.onPrimaryContainer),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
