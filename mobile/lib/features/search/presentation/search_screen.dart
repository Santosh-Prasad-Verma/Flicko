import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/services/user_search_service.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/features/shared/presentation/widgets/pill_search_bar.dart';

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

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF0A0A0A),
            Color(0xFF0F0F12),
            Color(0xFF060608),
          ],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          toolbarHeight: 64,
          titleSpacing: 16,
          flexibleSpace: ClipRRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(color: Colors.black.withValues(alpha: 0.4)),
            ),
          ),
          title: PillSearchBar(
            controller: _searchController,
            hintText: 'Search users...',
            autofocus: true,
            onBackPressed: () => context.pop(),
            onChanged: (value) {
              ref.read(userSearchQueryProvider.notifier).state = value;
              setState(() {});
            },
            onClear: () {
              ref.read(userSearchQueryProvider.notifier).state = '';
              setState(() {});
            },
          ),
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
              padding: const EdgeInsets.symmetric(vertical: 12),
              itemCount: users.length,
              itemBuilder: (context, index) {
                final user = users[index];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.04),
                      width: 0.5,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        leading: UserAvatar(
                          imageUrl: user.avatarUrl,
                          name: user.displayName ?? user.username,
                          size: 44,
                          status: user.onlineStatus,
                          showStatus: true,
                        ),
                        title: Text(
                          user.displayName ?? user.username,
                          style: GoogleFonts.inter(
                            color: const Color(0xFFE4E4E7),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          '@${user.username}',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.35),
                            fontSize: 13,
                          ),
                        ),
                        trailing: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: const Color(0xFF52B788).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(0xFF52B788),
                            size: 18,
                          ),
                        ),
                        onTap: () {
                          context.push('/profile/${user.id}');
                        },
                      ),
                    ),
                  ),
                );
              },
            );
          },
          loading: () => Center(
            child: CircularProgressIndicator(
              color: const Color(0xFF52B788).withValues(alpha: 0.7),
              strokeWidth: 2,
            ),
          ),
          error: (error, _) => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Error: $error',
                style: GoogleFonts.inter(color: const Color(FlickoColors.danger), fontSize: 14),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: const Color(0xFF52B788).withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.search_rounded,
              size: 32,
              color: const Color(0xFF52B788).withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.3),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
