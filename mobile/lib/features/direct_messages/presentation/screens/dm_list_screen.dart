import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/direct_messages/presentation/controllers/dm_controller.dart';
import 'package:mobile/features/direct_messages/presentation/widgets/dm_row.dart';
import 'package:mobile/features/shared/presentation/widgets/shared_widgets.dart';
import 'package:mobile/features/shared/presentation/widgets/skeleton_loader.dart';
import 'package:mobile/features/shared/presentation/widgets/pill_search_bar.dart';
import 'package:go_router/go_router.dart';

class DMListScreen extends ConsumerStatefulWidget {
  const DMListScreen({super.key});

  @override
  ConsumerState<DMListScreen> createState() => _DMListScreenState();
}

class _DMListScreenState extends ConsumerState<DMListScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dmControllerProvider);

    final filteredConversations = state.conversations.where((conv) {
      if (_searchQuery.isEmpty) return true;
      final name = (conv.participant.displayName ?? conv.participant.username).toLowerCase();
      final lastMsg = conv.lastMessage.toLowerCase();
      final q = _searchQuery.toLowerCase();
      return name.contains(q) || lastMsg.contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(FlickoColors.emeraldGreen).withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: -2,
            ),
          ],
        ),
        child: FloatingActionButton(
          backgroundColor: const Color(FlickoColors.emeraldGreen),
          foregroundColor: const Color(FlickoColors.black),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onPressed: () => context.push('/dms/new'),
          child: const Icon(Icons.edit_outlined, size: 22),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 16, 0),
              child: Row(
                children: [
                  // Flicko logo
                  Image.asset(
                    'assets/images/Flicko-for-black-background.png',
                    height: 28,
                    fit: BoxFit.contain,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── TITLE ──
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Messages',
                  style: TextStyle(
                    color: Color(FlickoColors.textPrimary),
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── INLINE SEARCH BAR ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: PillSearchBar(
                controller: _searchController,
                hintText: 'Filter conversations...',
                showBackArrow: false,
                showSearchIcon: true,
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val;
                  });
                },
                onClear: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
              ),
            ),

            const SizedBox(height: 12),

            // ── CONVERSATIONS ──
            Expanded(
              child: state.isLoading && state.conversations.isEmpty
                  ? const DMListSkeleton(count: 7)
                  : state.error != null
                      ? _buildErrorState(
                          context,
                          state.error!,
                          () => ref
                              .read(dmControllerProvider.notifier)
                              .fetchConversations())
                      : filteredConversations.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: () => ref
                                  .read(dmControllerProvider.notifier)
                                  .fetchConversations(),
                              color: const Color(FlickoColors.emeraldGreen),
                              backgroundColor:
                                  const Color(FlickoColors.bgSecondary),
                              child: ListView.builder(
                                padding: const EdgeInsets.fromLTRB(0, 4, 0, 100),
                                itemCount: filteredConversations.length,
                                itemBuilder: (context, index) {
                                  final conversation =
                                      filteredConversations[index];
                                  return DMRow(
                                    conversation: conversation,
                                    onTap: () => context
                                        .push('/dms/${conversation.id}'),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(FlickoColors.emeraldGreen).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 36,
                color: Color(FlickoColors.emeraldGreen),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isNotEmpty ? 'No matching messages' : 'No messages yet',
              style: const TextStyle(
                color: Color(FlickoColors.textPrimary),
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Try searching with a different term'
                  : 'Start a conversation with a friend\nand it will show up here',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(FlickoColors.textMuted),
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
      BuildContext context, String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: const Color(FlickoColors.danger).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(Icons.wifi_off_rounded,
                  size: 28,
                  color: const Color(FlickoColors.danger).withValues(alpha: 0.7)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Connection failed',
              style: TextStyle(
                color: Color(FlickoColors.textPrimary),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(
                  color: Color(FlickoColors.textMuted), fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(FlickoColors.emeraldGreen),
                  foregroundColor: const Color(FlickoColors.black),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const Text('Retry',
                    style: TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Clean icon button for the header
class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgTertiary),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color(FlickoColors.border),
              width: 1,
            ),
          ),
          child: Icon(icon, color: const Color(FlickoColors.textPrimary), size: 20),
        ),
      ),
    );
  }
}
