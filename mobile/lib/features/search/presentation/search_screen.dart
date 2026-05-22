import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/services/user_search_service.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final searchResults = ref.watch(userSearchResultsProvider);

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary), fontSize: 16),
          onChanged: (value) {
            ref.read(userSearchQueryProvider.notifier).state = value;
          },
          decoration: InputDecoration(
            hintText: 'Search users...',
            hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 16),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close, color: Color(FlickoColors.textMuted)),
              onPressed: () {
                _searchController.clear();
                ref.read(userSearchQueryProvider.notifier).state = '';
              },
            ),
          const SizedBox(width: 8),
        ],
      ),
      body: searchResults.when(
        data: (users) {
          if (users.isEmpty && _searchController.text.isNotEmpty) {
            return _buildEmptyState('No users found');
          }
          if (_searchController.text.isEmpty) {
            return _buildEmptyState('Type to search for users');
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: UserAvatar(
                  imageUrl: user.avatarUrl,
                  name: user.displayName ?? user.username,
                  size: 40,
                  status: user.onlineStatus,
                  showStatus: true,
                ),
                title: Text(
                  user.displayName ?? user.username,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  '@${user.username}',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 14,
                  ),
                ),
                onTap: () {
                  context.push('/u/profile/${user.id}');
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Color(FlickoColors.blurple))),
        error: (error, _) => Center(
          child: Text('Error: $error', style: const TextStyle(color: Colors.red)),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search, size: 64, color: Color(FlickoColors.textMuted)),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
