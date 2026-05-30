import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import 'package:mobile/data/models/flicko_message.dart';
import 'package:mobile/data/repositories/message_repository.dart';
import 'package:mobile/features/server_channels/chat/application/scroll_to_message.dart';
import 'package:mobile/features/sonic_music/localization/app_localizations.dart';

/// Bottom sheet listing the messages a bullet cites. Each row hydrates the
/// underlying message via [MessageRepository.getById] so users see real
/// authors and snippets, not raw uuids.
///
/// Tapping a row currently dismisses the sheet — wiring up scroll-to-message
/// in `chat_screen` is a follow-up that the chat list owner controls.
Future<void> showCitationPeekSheet(
  BuildContext context,
  List<String> messageIds,
) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) => _CitationPeekSheet(messageIds: messageIds),
  );
}

class _CitationPeekSheet extends StatelessWidget {
  const _CitationPeekSheet({required this.messageIds});

  final List<String> messageIds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n?.summaryCitedHeader ?? 'Cited messages',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: messageIds.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) =>
                    _CitationRow(messageId: messageIds[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lazy fetch of a single message, family-keyed by id.
final _hydratedCitationProvider =
    FutureProvider.autoDispose.family<FlickoMessage?, String>((ref, id) async {
  final repo = ref.watch(messageRepositoryProvider);
  return repo.getById(id);
});

class _CitationRow extends ConsumerWidget {
  const _CitationRow({required this.messageId});

  final String messageId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final hydrated = ref.watch(_hydratedCitationProvider(messageId));

    return hydrated.when(
      loading: () => const _SkeletonRow(),
      error: (_, __) => _MissingRow(messageId: messageId),
      data: (msg) {
        if (msg == null) return _MissingRow(messageId: messageId);
        final preview = _shorten(msg.content);
        final time = DateFormat.jm().format(msg.createdAt.toLocal());
        return ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.format_quote, size: 18),
          title: Row(
            children: [
              Flexible(
                child: Text(
                  _authorLabel(msg),
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(time,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.outline)),
            ],
          ),
          subtitle: Text(
            preview.isEmpty ? '(no text)' : preview,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () {
            // Hand off to the chat screen via a provider-broadcast intent;
            // the chat screen owns the ScrollController and the message list.
            final channelId = msg.channelId;
            if (channelId != null && channelId.isNotEmpty) {
              ref
                  .read(scrollToMessageProvider.notifier)
                  .request(channelId: channelId, messageId: msg.id);
            }
            Navigator.of(context).maybePop();
          },
        );
      },
    );
  }

  static String _shorten(String s) {
    final trimmed = s.trim();
    if (trimmed.length <= 140) return trimmed;
    return '${trimmed.substring(0, 137)}…';
  }

  static String _authorLabel(FlickoMessage m) {
    final a = m.author;
    if (a == null) return 'Unknown';
    if ((a.displayName ?? '').isNotEmpty) return a.displayName!;
    if (a.username.isNotEmpty) return a.username;
    return a.id;
  }
}

class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 12,
            width: 120,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingRow extends StatelessWidget {
  const _MissingRow({required this.messageId});
  final String messageId;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.warning_amber_outlined, size: 18),
      title: Text(
        l10n?.summaryCitedMissing ?? 'Message unavailable',
        style: theme.textTheme.labelMedium,
      ),
      subtitle: Text(
        '${l10n?.summaryCitedMissingBody ?? 'It may have been deleted.'} (id: ${messageId.length > 8 ? messageId.substring(0, 8) : messageId}…)',
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.outline),
      ),
    );
  }
}
