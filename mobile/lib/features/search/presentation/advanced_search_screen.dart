import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';

class AdvancedSearchScreen extends ConsumerStatefulWidget {
  final String? serverId;
  final String? channelId;

  const AdvancedSearchScreen({
    super.key,
    this.serverId,
    this.channelId,
  });

  @override
  ConsumerState<AdvancedSearchScreen> createState() => _AdvancedSearchScreenState();
}

class _AdvancedSearchScreenState extends ConsumerState<AdvancedSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<Map<String, dynamic>> _results = [];
  String? _errorMessage;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _errorMessage = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _errorMessage = null;
    });

    try {
      // Search messages in Supabase
      final queryBuilder = Supabase.instance.client
          .from('messages')
          .select('*, profiles!inner(username, display_name, avatar_url)')
          .ilike('content', '%$query%')
          .order('created_at', ascending: false)
          .limit(50);

      if (widget.channelId != null) {
        queryBuilder.eq('channel_id', widget.channelId);
      }

      if (widget.serverId != null) {
        queryBuilder.eq('server_id', widget.serverId);
      }

      final response = await queryBuilder;

      setState(() {
        _results = (response as List).cast<Map<String, dynamic>>();
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSearching = false;
        _results = [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        title: Text(
          'Search Messages',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          const SizedBox(height: 16),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          if (value.length >= 2) {
            _performSearch(value);
          }
        },
        decoration: InputDecoration(
          hintText: 'Search messages...',
          hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
          prefixIcon: const Icon(Icons.search, color: Color(FlickoColors.textMuted)),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(FlickoColors.textMuted)),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {
                      _results = [];
                      _errorMessage = null;
                    });
                  },
                )
              : null,
          filled: true,
          fillColor: const Color(FlickoColors.bgSecondary),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    if (_isSearching) {
      return const Center(
        child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(FlickoColors.danger)),
            const SizedBox(height: 16),
            Text(
              'Error searching messages',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Color(FlickoColors.textMuted)),
            const SizedBox(height: 16),
            Text(
              'No messages found',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search, size: 48, color: Color(FlickoColors.textMuted)),
            const SizedBox(height: 16),
            Text(
              'Search for messages',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Type at least 2 characters to search',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _results.length,
      itemBuilder: (context, index) => _buildMessageCard(_results[index]),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> message) {
    final profile = message['profiles'] as Map<String, dynamic>?;
    final username = profile?['username'] ?? 'Unknown';
    final displayName = profile?['display_name'] ?? username;
    final avatarUrl = profile?['avatar_url'];
    final content = message['content'] as String;
    final createdAt = message['created_at'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                child: avatarUrl == null
                    ? Text(
                        username[0].toUpperCase(),
                        style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      createdAt != null ? _formatDate(createdAt) : '',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
