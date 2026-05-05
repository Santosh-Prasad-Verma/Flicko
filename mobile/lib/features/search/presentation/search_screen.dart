import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';

/// Search Screen
///
/// Discord-style global search with tabs for Users, Channels, Messages, and Music.
/// Mirrors the React Native search.tsx screen.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  SearchTab _activeTab = SearchTab.users;
  bool _isLoading = false;
  String? _error;

  // Mock data for demonstration
  final List<SearchUser> _users = [
    SearchUser(
      id: '1',
      username: 'alice',
      displayName: 'Alice',
      avatarUrl: null,
      status: 'online',
      isFriend: true,
    ),
    SearchUser(
      id: '2',
      username: 'bob',
      displayName: 'Bob',
      avatarUrl: null,
      status: 'idle',
      isFriend: false,
      hasPendingRequest: true,
    ),
    SearchUser(
      id: '3',
      username: 'charlie',
      displayName: 'Charlie',
      avatarUrl: null,
      status: 'dnd',
      isFriend: false,
    ),
  ];

  final List<SearchableChannel> _channels = [
    SearchableChannel(
      id: '1',
      name: 'general',
      type: 'text',
      serverId: 'srv1',
      serverName: 'My Server',
    ),
    SearchableChannel(
      id: '2',
      name: 'voice-chat',
      type: 'voice',
      serverId: 'srv1',
      serverName: 'My Server',
    ),
  ];

  final List<MessageResult> _messages = [
    MessageResult(
      id: '1',
      content: 'Hey everyone! How\'s it going?',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      channelId: '1',
      author: MessageAuthor(username: 'alice', displayName: 'Alice'),
      channel: MessageChannel(name: 'general', serverId: 'srv1'),
    ),
    MessageResult(
      id: '2',
      content: 'Anyone up for a game tonight?',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      channelId: '1',
      author: MessageAuthor(username: 'bob', displayName: 'Bob'),
      channel: MessageChannel(name: 'general', serverId: 'srv1'),
    ),
  ];

  List<SearchUser> get _filteredUsers {
    if (_searchController.text.isEmpty) return _users;
    final query = _searchController.text.toLowerCase();
    return _users.where((u) =>
      u.username.toLowerCase().contains(query) ||
      (u.displayName?.toLowerCase().contains(query) ?? false)
    ).toList();
  }

  List<SearchableChannel> get _filteredChannels {
    if (_searchController.text.isEmpty) return _channels;
    final query = _searchController.text.toLowerCase();
    return _channels.where((c) =>
      c.name.toLowerCase().contains(query) ||
      c.serverName.toLowerCase().contains(query)
    ).toList();
  }

  List<MessageResult> get _filteredMessages {
    if (_searchController.text.isEmpty) return [];
    final query = _searchController.text.toLowerCase();
    return _messages.where((m) =>
      m.content.toLowerCase().contains(query)
    ).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          autofocus: true,
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: 'Search...',
            hintStyle: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
            ),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Color(FlickoColors.textMuted)),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
        ),
      ),
      body: Column(
        children: [
          // Tab bar
          _buildTabBar(),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      (SearchTab.users, 'Users', Icons.person),
      (SearchTab.channels, 'Channels', Icons.folder),
      (SearchTab.messages, 'Messages', Icons.message),
      (SearchTab.music, 'Music', Icons.music_note),
    ];

    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        border: Border(
          bottom: BorderSide(color: Color(FlickoColors.bgTertiary)),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tabs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (tab, label, icon) = tabs[index];
          final isActive = _activeTab == tab;

          return GestureDetector(
            onTap: () => setState(() => _activeTab = tab),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(FlickoColors.blurple)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 18,
                    color: isActive
                        ? Colors.white
                        : const Color(FlickoColors.textMuted),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: isActive
                          ? Colors.white
                          : const Color(FlickoColors.textMuted),
                      fontSize: 14,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Color(FlickoColors.textMuted),
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_activeTab) {
      case SearchTab.users:
        return _buildUsersList();
      case SearchTab.channels:
        return _buildChannelsList();
      case SearchTab.messages:
        return _buildMessagesList();
      case SearchTab.music:
        return _buildMusicPlaceholder();
    }
  }

  Widget _buildUsersList() {
    final users = _filteredUsers;

    if (users.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? 'Start typing to search users'
              : 'No users found',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        return _buildUserTile(user);
      },
    );
  }

  Widget _buildUserTile(SearchUser user) {
    return InkWell(
      onTap: () {
        // Navigate to user profile
        context.push('/profile/${user.id}');
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            UserAvatar(
              imageUrl: user.avatarUrl,
              size: 48,
              status: user.status,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName ?? user.username,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (user.displayName != null)
                    Text(
                      '@${user.username}',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            // Friend status indicator
            if (user.isFriend)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.green).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Friend',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.green),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else if (user.hasPendingRequest)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.yellow).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Pending',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.yellow),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              IconButton(
                icon: const Icon(
                  Icons.person_add,
                  color: Color(FlickoColors.blurple),
                ),
                onPressed: () {
                  // Send friend request
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Friend request sent to ${user.username}',
                        style: GoogleFonts.inter(),
                      ),
                      backgroundColor: const Color(FlickoColors.success),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildChannelsList() {
    final channels = _filteredChannels;

    if (channels.isEmpty) {
      return Center(
        child: Text(
          'No channels found',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: channels.length,
      itemBuilder: (context, index) {
        final channel = channels[index];
        return _buildChannelTile(channel);
      },
    );
  }

  Widget _buildChannelTile(SearchableChannel channel) {
    return InkWell(
      onTap: () {
        // Navigate to channel
        context.push('/server/${channel.serverId}/channel/${channel.id}');
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              channel.type == 'voice' ? Icons.volume_up : Icons.tag,
              color: const Color(FlickoColors.textMuted),
              size: 24,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${channel.name}',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    channel.serverName,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Color(FlickoColors.textMuted),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    final messages = _filteredMessages;

    if (_searchController.text.length < 2) {
      return Center(
        child: Text(
          'Type at least 2 characters to search messages',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 16,
          ),
        ),
      );
    }

    if (messages.isEmpty) {
      return Center(
        child: Text(
          'No messages found',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 16,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        return _buildMessageTile(message);
      },
    );
  }

  Widget _buildMessageTile(MessageResult message) {
    return InkWell(
      onTap: () {
        // Navigate to message
        context.push('/server/${message.channel!.serverId}/channel/${message.channelId}');
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                UserAvatar(
                  imageUrl: null,
                  size: 32,
                  status: 'offline',
                ),
                const SizedBox(width: 8),
                Text(
                  message.author!.displayName ?? message.author!.username,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatTime(message.createdAt),
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(
                message.content,
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textSecondary),
                  fontSize: 14,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Text(
                '#${message.channel!.name}',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMusicPlaceholder() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.music_note,
            size: 64,
            color: Color(FlickoColors.textMuted),
          ),
          const SizedBox(height: 16),
          Text(
            'Music Search',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for tracks, albums, and artists\n(Integration with music API coming soon)',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${date.month}/${date.day}/${date.year}';
    }
  }
}

/// Search tab types
enum SearchTab {
  users,
  channels,
  messages,
  music,
}

/// Search User Model
class SearchUser {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String status;
  final bool isFriend;
  final bool hasPendingRequest;

  SearchUser({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.status,
    this.isFriend = false,
    this.hasPendingRequest = false,
  });
}

/// Searchable Channel Model
class SearchableChannel {
  final String id;
  final String name;
  final String type;
  final String serverId;
  final String serverName;

  SearchableChannel({
    required this.id,
    required this.name,
    required this.type,
    required this.serverId,
    required this.serverName,
  });
}

/// Message Result Model
class MessageResult {
  final String id;
  final String content;
  final DateTime createdAt;
  final String channelId;
  final MessageAuthor? author;
  final MessageChannel? channel;

  MessageResult({
    required this.id,
    required this.content,
    required this.createdAt,
    required this.channelId,
    this.author,
    this.channel,
  });
}

/// Message Author Model
class MessageAuthor {
  final String username;
  final String? displayName;

  MessageAuthor({
    required this.username,
    this.displayName,
  });
}

/// Message Channel Model
class MessageChannel {
  final String name;
  final String serverId;

  MessageChannel({
    required this.name,
    required this.serverId,
  });
}
