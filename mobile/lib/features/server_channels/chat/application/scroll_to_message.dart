import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A "scroll-to-message" intent broadcast by features outside the chat
/// screen (e.g. the AI summary citation-peek sheet).
///
/// The chat screen owns the [ScrollController] and the message list, so it
/// has to perform the actual scroll. Other widgets push an intent here, the
/// chat screen consumes it via [ref.listen] and clears the target afterwards.
class ScrollToMessageIntent {
  final String channelId;
  final String messageId;
  final DateTime issuedAt;

  ScrollToMessageIntent({
    required this.channelId,
    required this.messageId,
    required this.issuedAt,
  });
}

/// Holds the most recent intent (or null when consumed/cleared). The chat
/// screen for `channelId` listens to this provider, scrolls when an intent
/// arrives whose `channelId` matches, then sets state back to null.
final scrollToMessageProvider = NotifierProvider<ScrollToMessageController, ScrollToMessageIntent?>(
  ScrollToMessageController.new,
);

class ScrollToMessageController extends Notifier<ScrollToMessageIntent?> {
  @override
  ScrollToMessageIntent? build() => null;

  void request({required String channelId, required String messageId}) {
    state = ScrollToMessageIntent(
      channelId: channelId,
      messageId: messageId,
      issuedAt: DateTime.now(),
    );
  }

  void consume() => state = null;
}
