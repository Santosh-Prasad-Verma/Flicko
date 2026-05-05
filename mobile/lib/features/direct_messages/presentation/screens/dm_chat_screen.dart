import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/direct_messages/presentation/controllers/dm_chat_controller.dart';
import 'package:mobile/features/direct_messages/presentation/controllers/dm_controller.dart';
import 'package:mobile/features/direct_messages/presentation/widgets/message_bubble.dart';
import 'package:mobile/features/direct_messages/presentation/widgets/dm_chat_input.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class DMChatScreen extends ConsumerStatefulWidget {
  final String userId;

  const DMChatScreen({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<DMChatScreen> createState() => _DMChatScreenState();
}

class _DMChatScreenState extends ConsumerState<DMChatScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(dmChatControllerProvider(widget.userId).notifier).fetchMessages(loadMore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dmChatControllerProvider(widget.userId));
    final convoState = ref.watch(dmControllerProvider);
    final conversation = convoState.conversations.cast<DMConversation?>().firstWhere(
      (c) => c?.id == widget.userId,
      orElse: () => null,
    );
    
    final participant = conversation?.participant;
    final participantName = participant?.displayName ?? participant?.name ?? 'Chat';

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        title: Row(
          children: [
            if (participant != null)
              Padding(
                padding: const EdgeInsets.only(right: FlickoSpacing.sm),
                child: UserAvatar(
                  imageUrl: participant.avatarUrl,
                  name: participantName,
                  size: 32,
                  showStatus: true,
                  // status: participant.status, // TODO: sync status
                ),
              ),
            Expanded(
              child: Text(
                participantName,
                style: const TextStyle(
                  color: Color(FlickoColors.textPrimary),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            color: const Color(FlickoColors.textSecondary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Voice calls coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.videocam),
            color: const Color(FlickoColors.textSecondary),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Video calls coming soon!'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.isLoading && state.messages.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true, // Newest at bottom
                    itemCount: state.messages.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.messages.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final message = state.messages[index];
                      return MessageBubble(message: message);
                    },
                  ),
          ),
          DMChatInput(
            onSend: (content, attachments) {
              ref.read(dmChatControllerProvider(widget.userId).notifier).sendMessage(
                content,
                attachments: attachments,
              );
            },
          ),
        ],
      ),
    );
  }
}
