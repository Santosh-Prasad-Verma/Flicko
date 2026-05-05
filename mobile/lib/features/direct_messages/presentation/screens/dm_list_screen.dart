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
    final theme = Theme.of(context);

    // Filter online friends for the row
    final onlineFriends = state.conversations
        .where((c) => c.participant.onlineStatus == 'online')
        .map((c) => c.participant)
        .toList();

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(FlickoSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Messages',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => context.push('/search'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(FlickoColors.bgTertiary),
                              borderRadius: BorderRadius.circular(FlickoRadius.md),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.search, size: 18, color: Color(FlickoColors.textMuted)),
                                SizedBox(width: 8),
                                Text(
                                  'Search',
                                  style: TextStyle(color: Color(FlickoColors.textMuted)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('New DM coming soon!')),
                      );
                    },
                    icon: const Icon(Icons.edit_note, size: 28),
                    color: const Color(FlickoColors.textSecondary),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(FlickoColors.bgTertiary),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: state.isLoading && state.conversations.isEmpty
                  ? const LoadingSpinner(message: 'Loading messages...')
                  : state.error != null
                      ? _buildErrorState(state.error!, () => ref.read(dmControllerProvider.notifier).fetchConversations())
                      : state.conversations.isEmpty
                          ? const EmptyState(
                              icon: Icons.chat_bubble_outline,
                              title: 'No conversations yet',
                              message: 'Messages from friends will show up here',
                            )
                          : RefreshIndicator(
                              onRefresh: () => ref.read(dmControllerProvider.notifier).fetchConversations(),
                              color: const Color(FlickoColors.blurple),
                              child: CustomScrollView(
                                slivers: [
                                  // Online Friends Row
                                  if (onlineFriends.isNotEmpty)
                                    SliverToBoxAdapter(
                                      child: OnlineFriendsRow(
                                        friends: onlineFriends,
                                        onFriendTap: (friend) => context.push('/dm/${friend.id}'),
                                      ),
                                    ),

                                  // List Sections
                                  const SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.fromLTRB(FlickoSpacing.md, FlickoSpacing.lg, FlickoSpacing.md, FlickoSpacing.sm),
                                      child: Text(
                                        'DIRECT MESSAGES',
                                        style: TextStyle(
                                          color: Color(FlickoColors.textMuted),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                  ),

                                  SliverList(
                                    delegate: SliverChildBuilderDelegate(
                                      (context, index) {
                                        final conversation = state.conversations[index];
                                        return DMRow(
                                          conversation: conversation,
                                          onTap: () => context.push('/dm/${conversation.id}'),
                                        );
                                      },
                                      childCount: state.conversations.length,
                                    ),
                                  ),
                                  
                                  const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
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
          Icon(Icons.error_outline, size: 48, color: const Color(FlickoColors.danger).withOpacity(0.5)),
          const SizedBox(height: 16),
          Text(
            'Failed to load messages',
            style: const TextStyle(color: Color(FlickoColors.textPrimary), fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              error,
              style: const TextStyle(color: Color(FlickoColors.textMuted), fontSize: 13),
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
