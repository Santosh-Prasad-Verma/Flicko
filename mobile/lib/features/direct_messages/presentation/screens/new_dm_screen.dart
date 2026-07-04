import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/models/user_model.dart';
import 'package:mobile/features/direct_messages/data/dm_repository.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

class NewDMScreen extends ConsumerStatefulWidget {
  const NewDMScreen({super.key});

  @override
  ConsumerState<NewDMScreen> createState() => _NewDMScreenState();
}

class _NewDMScreenState extends ConsumerState<NewDMScreen> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  List<UserModel> _results = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    // Auto-focus the search bar on open
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
        _hasSearched = false;
      });
      return;
    }
    setState(() => _isLoading = true);
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query.trim());
    });
  }

  Future<void> _performSearch(String query) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    try {
      final repo = ref.read(dmRepositoryProvider);
      final users = await repo.searchUsers(query, userId);
      if (mounted) {
        setState(() {
          _results = users;
          _isLoading = false;
          _hasSearched = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _results = [];
          _isLoading = false;
          _hasSearched = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: SafeArea(
        child: Column(
          children: [
            // ── HEADER ──
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => context.pop(),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      color: Color(FlickoColors.textPrimary),
                      size: 22,
                    ),
                    splashRadius: 20,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'New Message',
                    style: TextStyle(
                      color: Color(FlickoColors.textPrimary),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── SEARCH BAR ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.bgTertiary),
                  borderRadius: BorderRadius.circular(FlickoRadius.xl),
                  border: Border.all(
                    color: const Color(FlickoColors.border),
                    width: 1,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _focusNode,
                  onChanged: _onSearchChanged,
                  style: const TextStyle(
                    color: Color(FlickoColors.textPrimary),
                    fontSize: 15,
                    fontFamily: 'Inter',
                  ),
                  cursorColor: const Color(FlickoColors.emeraldGreen),
                  decoration: InputDecoration(
                    hintText: 'Search by username or display name...',
                    hintStyle: TextStyle(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 15,
                      fontFamily: 'Inter',
                    ),
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(left: 14, right: 10),
                      child: Icon(
                        Icons.search_rounded,
                        color: Color(FlickoColors.textMuted),
                        size: 20,
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              _onSearchChanged('');
                            },
                            child: const Padding(
                              padding: EdgeInsets.only(right: 10),
                              child: Icon(
                                Icons.close_rounded,
                                color: Color(FlickoColors.textMuted),
                                size: 18,
                              ),
                            ),
                          )
                        : null,
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 36,
                      minHeight: 36,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── RESULTS ──
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(FlickoColors.emeraldGreen),
                        strokeWidth: 2.5,
                      ),
                    )
                  : _hasSearched && _results.isEmpty
                      ? _buildEmptyResults()
                      : !_hasSearched
                          ? _buildPrompt()
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              itemCount: _results.length,
                              itemBuilder: (context, index) {
                                return _UserTile(
                                  user: _results[index],
                                  onTap: () => context.push('/dms/${_results[index].id}'),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrompt() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(FlickoColors.emeraldGreen).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Icon(
                Icons.person_search_rounded,
                size: 32,
                color: Color(FlickoColors.emeraldGreen),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Find someone to message',
              style: TextStyle(
                color: Color(FlickoColors.textPrimary),
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Search by username or display name\nto start a conversation',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(FlickoColors.textMuted),
                fontSize: 13,
                height: 1.5,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyResults() {
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
                color: const Color(FlickoColors.textMuted).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 28,
                color: Color(FlickoColors.textMuted),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No users found',
              style: TextStyle(
                color: Color(FlickoColors.textPrimary),
                fontSize: 17,
                fontWeight: FontWeight.w600,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try a different search term',
              style: TextStyle(
                color: Color(FlickoColors.textMuted),
                fontSize: 13,
                fontFamily: 'Inter',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single user row in the search results list.
class _UserTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const _UserTile({required this.user, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final displayName = user.displayName ?? user.username;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(FlickoRadius.lg),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(FlickoRadius.lg),
            ),
            child: Row(
              children: [
                // ── AVATAR ──
                _buildAvatar(),
                const SizedBox(width: 12),

                // ── NAME / USERNAME ──
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          color: Color(FlickoColors.textPrimary),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '@${user.username}',
                        style: const TextStyle(
                          color: Color(FlickoColors.textSecondary),
                          fontSize: 13,
                          fontFamily: 'Inter',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // ── ARROW ──
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(FlickoColors.textMuted),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(FlickoRadius.xl),
        color: const Color(FlickoColors.bgTertiary),
        border: Border.all(
          color: const Color(FlickoColors.border),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(FlickoRadius.xl),
        child: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
            ? Image.network(
                user.avatarUrl!,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _avatarFallback(),
              )
            : _avatarFallback(),
      ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: 44,
      height: 44,
      color: const Color(FlickoColors.bgTertiary),
      alignment: Alignment.center,
      child: Text(
        (user.displayName ?? user.username).isNotEmpty
            ? (user.displayName ?? user.username)[0].toUpperCase()
            : '?',
        style: const TextStyle(
          color: Color(FlickoColors.emeraldGreen),
          fontSize: 18,
          fontWeight: FontWeight.w700,
          fontFamily: 'Inter',
        ),
      ),
    );
  }
}
