import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mobile/features/ai_assistant/summary/application/summary_provider.dart';
import 'package:mobile/features/ai_assistant/summary/domain/summary.dart';
import 'package:mobile/features/ai_assistant/summary/presentation/citation_peek_sheet.dart';
import 'package:mobile/features/sonic_music/localization/app_localizations.dart';

/// Card that streams bullets in as the LLM produces them.
class SummaryCard extends ConsumerWidget {
  const SummaryCard({super.key, required this.channelId});

  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(summaryControllerProvider(channelId));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Material(
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(state: s, channelId: channelId),
            const SizedBox(height: 8),
            _Body(state: s, channelId: channelId),
            if (s.status == SummaryStatus.done) ...[
              const SizedBox(height: 8),
              _FeedbackRow(channelId: channelId),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.state, required this.channelId});
  final Summary state;
  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);
    final isStreaming = state.status == SummaryStatus.streaming ||
        state.status == SummaryStatus.requesting;
    return Row(
      children: [
        Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
        const SizedBox(width: 8),
        Text(
          isStreaming
              ? (l10n?.summaryCatchingYouUp ?? 'Catching you up…')
              : (l10n?.summaryHeading ?? 'Catch-up'),
          style: theme.textTheme.titleSmall,
        ),
        if (state.cached) ...[
          const SizedBox(width: 8),
          _Chip(label: l10n?.summaryCachedChip ?? 'cached'),
        ],
        const Spacer(),
        IconButton(
          tooltip: l10n?.summaryDismiss ?? 'Dismiss',
          icon: const Icon(Icons.close, size: 18),
          onPressed: () =>
              ref.read(summaryControllerProvider(channelId).notifier).dismiss(),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.state, required this.channelId});
  final Summary state;
  final String channelId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    switch (state.status) {
      case SummaryStatus.idle:
      case SummaryStatus.requesting:
        return const _Skeleton();
      case SummaryStatus.streaming:
      case SummaryStatus.done:
        return _BulletList(state: state, channelId: channelId);
      case SummaryStatus.refused:
        return _RefusalBlock(state: state);
      case SummaryStatus.rateLimited:
        return _MessageBlock(
          icon: Icons.timer,
          title: l10n?.summaryRateLimitedTitle ?? 'Daily limit reached',
          body: l10n?.summaryRateLimitedBody ??
              'You can summarise up to 50 channels per day. Come back tomorrow or upgrade to Plus.',
        );
      case SummaryStatus.error:
        return _MessageBlock(
          icon: Icons.error_outline,
          title: l10n?.summaryErrorTitle ?? "Couldn't summarise this channel",
          body: state.errorMessage ??
              (l10n?.summaryErrorRetry ?? 'Try again in a moment.'),
        );
    }
  }
}

class _Skeleton extends StatelessWidget {
  const _Skeleton();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: List.generate(3, (i) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Container(
            height: 14,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        );
      }),
    );
  }
}

class _BulletList extends ConsumerWidget {
  const _BulletList({required this.state, required this.channelId});
  final Summary state;
  final String channelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.bullets.isEmpty) {
      return const _Skeleton();
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final b in state.bullets)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Semantics(
              button: b.citations.isNotEmpty,
              label: b.text,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: b.citations.isEmpty
                    ? null
                    : () => showCitationPeekSheet(context, b.citations),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 4, right: 8),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          b.text,
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      if (b.citations.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 8, top: 2),
                          child: Icon(
                            Icons.format_quote,
                            size: 14,
                            color: theme.colorScheme.outline,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (state.participants.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _participantsLine(state.participants),
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
      ],
    );
  }

  static String _participantsLine(List<String> p) {
    if (p.isEmpty) return '';
    if (p.length == 1) return '${p.first} contributed';
    if (p.length == 2) return '${p[0]} and ${p[1]} contributed';
    return '${p[0]}, ${p[1]} and ${p.length - 2} others contributed';
  }
}

class _FeedbackRow extends ConsumerStatefulWidget {
  const _FeedbackRow({required this.channelId});
  final String channelId;
  @override
  ConsumerState<_FeedbackRow> createState() => _FeedbackRowState();
}

class _FeedbackRowState extends ConsumerState<_FeedbackRow> {
  int? _rating;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Text(
          l10n?.summaryFeedbackPrompt ?? 'Was this helpful?',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: l10n?.summaryFeedbackHelpful ?? 'Helpful',
          isSelected: _rating == 1,
          icon: const Icon(Icons.thumb_up_outlined, size: 16),
          selectedIcon: const Icon(Icons.thumb_up, size: 16),
          onPressed: _rating == null ? () => _send(1) : null,
        ),
        IconButton(
          tooltip: l10n?.summaryFeedbackNotHelpful ?? 'Not helpful',
          isSelected: _rating == -1,
          icon: const Icon(Icons.thumb_down_outlined, size: 16),
          selectedIcon: const Icon(Icons.thumb_down, size: 16),
          onPressed: _rating == null ? () => _send(-1) : null,
        ),
      ],
    );
  }

  Future<void> _send(int v) async {
    setState(() => _rating = v);
    await ref
        .read(summaryControllerProvider(widget.channelId).notifier)
        .rate(v);
  }
}

class _MessageBlock extends StatelessWidget {
  const _MessageBlock({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2, right: 12),
          child: Icon(icon, size: 18, color: theme.colorScheme.outline),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(body, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}

class _RefusalBlock extends StatelessWidget {
  const _RefusalBlock({required this.state});
  final Summary state;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    String title = l10n?.summaryRefusedTitle ?? 'Not enough to summarise';
    String body = l10n?.summaryRefusedBody ??
        "There aren't enough recent messages here to make a useful summary yet.";
    if (state.errorCode == 'no_channel_access') {
      title = l10n?.summaryNoAccessTitle ?? "You don't have access here";
      body = l10n?.summaryNoAccessBody ??
          'Ask a moderator to grant you read permission first.';
    }
    return _MessageBlock(
      icon: Icons.info_outline,
      title: title,
      body: body,
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}
