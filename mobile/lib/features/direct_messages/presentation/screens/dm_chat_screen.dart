import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/direct_messages/presentation/controllers/dm_chat_controller.dart';
import 'package:mobile/features/direct_messages/presentation/controllers/dm_controller.dart';
import 'package:mobile/features/direct_messages/domain/dm_models.dart';
import 'package:mobile/features/direct_messages/presentation/widgets/message_bubble.dart';
import 'package:mobile/features/direct_messages/presentation/widgets/dm_chat_input.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:go_router/go_router.dart';

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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref
          .read(dmChatControllerProvider(widget.userId).notifier)
          .fetchMessages(loadMore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dmChatControllerProvider(widget.userId));
    final convoState = ref.watch(dmControllerProvider);
    final conversation =
        convoState.conversations.cast<DMConversation?>().firstWhere(
              (c) => c?.id == widget.userId,
              orElse: () => null,
            );

    final participant = conversation?.participant;
    final participantName =
        participant?.displayName ?? participant?.username ?? 'Chat';

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 14),
              decoration: const BoxDecoration(
                color: Color(FlickoColors.bgPrimary),
                border: Border(
                  bottom:
                      BorderSide(color: Color(FlickoColors.border), width: 1),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back,
                        color: Color(FlickoColors.textPrimary)),
                  ),
                  if (participant != null)
                    Padding(
                      padding: const EdgeInsets.only(right: FlickoSpacing.sm),
                      child: UserAvatar(
                        imageUrl: participant.avatarUrl,
                        name: participantName,
                        size: 34,
                        showStatus: false,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      participantName.toUpperCase(),
                      style: const TextStyle(
                        color: Color(FlickoColors.textPrimary),
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(FlickoColors.brandLime),
                      border: Border.all(
                          color: const Color(FlickoColors.black), width: 1.2),
                    ),
                    child: const Text(
                      'ONLINE',
                      style: TextStyle(
                        color: Color(FlickoColors.black),
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert,
                        color: Color(FlickoColors.textPrimary)),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: state.isLoading && state.messages.isEmpty
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(FlickoColors.brandLime),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(0, 12, 0, 20),
                    reverse: true,
                    itemCount: state.messages.length + (state.hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == state.messages.length) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: CircularProgressIndicator(
                              color: Color(FlickoColors.brandLime),
                            ),
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
              ref
                  .read(dmChatControllerProvider(widget.userId).notifier)
                  .sendMessage(
                    content,
                    localAttachments: attachments,
                  );
            },
          ),
        ],
      ),
    );
  }
}
