import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/direct_messages/presentation/controllers/dm_controller.dart';
import 'package:mobile/features/direct_messages/presentation/widgets/dm_row.dart';
import 'package:mobile/features/direct_messages/presentation/widgets/online_friends_row.dart';
import 'package:mobile/features/shared/presentation/widgets/shared_widgets.dart';
import 'package:go_router/go_router.dart';

class DMListScreen extends ConsumerWidget {
  const DMListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dmControllerProvider);

    final onlineFriends = state.conversations
        .where((c) => c.participant.onlineStatus == 'online')
        .map((c) => c.participant)
        .toList();

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(FlickoColors.brandLime),
        foregroundColor: const Color(FlickoColors.black),
        shape: const RoundedRectangleBorder(),
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('New DM flow coming soon!')),
          );
        },
        child: const Icon(Icons.edit_outlined),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.menu,
                            color: Color(FlickoColors.textPrimary)),
                      ),
                      const Expanded(
                        child: Text(
                          'FLICKO',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(FlickoColors.textPrimary),
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.6,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => context.push('/search'),
                        icon: const Icon(Icons.search,
                            color: Color(FlickoColors.textPrimary)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'INBOX',
                      style: TextStyle(
                        color: Color(FlickoColors.textPrimary),
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 110,
                    child: Row(
                      children: [
                        Expanded(
                          child: OnlineFriendsRow(
                            friends: onlineFriends,
                            onFriendTap: (friend) =>
                                context.push('/dms/${friend.id}'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'New conversation flow coming soon!')),
                            );
                          },
                          child: Column(
                            children: [
                              Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: const Color(FlickoColors.bgSecondary),
                                  border: Border.all(
                                    color: const Color(FlickoColors.border),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  color: Color(FlickoColors.textPrimary),
                                  size: 28,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const SizedBox(
                                width: 64,
                                child: Text(
                                  'NEW',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(FlickoColors.textSecondary),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: state.isLoading && state.conversations.isEmpty
                  ? const LoadingSpinner(message: 'Loading messages...')
                  : state.error != null
                      ? _buildErrorState(
                          state.error!,
                          () => ref
                              .read(dmControllerProvider.notifier)
                              .fetchConversations())
                      : state.conversations.isEmpty
                          ? const EmptyState(
                              icon: Icons.chat_bubble_outline,
                              title: 'No conversations yet',
                              message:
                                  'Messages from friends will show up here',
                            )
                          : RefreshIndicator(
                              onRefresh: () => ref
                                  .read(dmControllerProvider.notifier)
                                  .fetchConversations(),
                              color: const Color(FlickoColors.brandLime),
                              child: CustomScrollView(
                                slivers: [
                                  const SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(
                                          FlickoSpacing.md,
                                          FlickoSpacing.lg,
                                          FlickoSpacing.md,
                                          FlickoSpacing.sm),
                                      child: Text(
                                        'DIRECT MESSAGES',
                                        style: TextStyle(
                                          color: Color(FlickoColors.brandLime),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.1,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final conversation =
                                            state.conversations[index];
                                        return DMRow(
                                          conversation: conversation,
                                          onTap: () => context
                                              .push('/dms/${conversation.id}'),
                                        );
                                      },
                                      childCount: state.conversations.length,
                                    ),
                                  ),
                                  const SliverPadding(
                                      padding: EdgeInsets.only(bottom: 100)),
                                ],
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error, VoidCallback onRetry) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline,
              size: 48,
              color: const Color(FlickoColors.danger).withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'Failed to load messages',
            style: const TextStyle(
                color: Color(FlickoColors.textPrimary),
                fontSize: 16,
                fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              error,
              style: const TextStyle(
                  color: Color(FlickoColors.textMuted), fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.blurple),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
