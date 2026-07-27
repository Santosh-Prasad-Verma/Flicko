import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:go_router/go_router.dart';
import '../../auth/application/auth_notifier.dart';
import '../../shared/presentation/widgets/user_avatar.dart';
import '../../shared/presentation/widgets/skeleton_loader.dart';
import '../../shared/presentation/widgets/flicko_error_state.dart';
import '../../../data/models/user_model.dart';
import 'package:mobile/features/direct_messages/presentation/screens/dm_chat_screen.dart';

class Notification {
  final String id;
  final String userId;
  final String type;
  final Map<String, dynamic>? content;
  final bool read;
  final String createdAt;

  Notification({
    required this.id,
    required this.userId,
    required this.type,
    this.content,
    required this.read,
    required this.createdAt,
  });

  factory Notification.fromJson(Map<String, dynamic> json) {
    return Notification(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String,
      content: json['content'] as Map<String, dynamic>?,
      read: json['read'] as bool? ?? false,
      createdAt: json['created_at'] as String,
    );
  }
}

// ── Design tokens ──
const _bgPrimary = Color(0xFF07040A);
const _bgCard = Color(0xFF0F0F12);
const _bgSurface = Color(0xFF14141A);
const _greenPunch = Color(0xFFC0EC54);
const _textPrimary = Colors.white;
const _textSecondary = Color(0xFF9CA3AF);
const _border = Color(0xFF1F1F24);

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final List<String> _tabs = ['All', 'Mentions', 'DMs', 'Friends'];
  String _activeTab = 'All';
  List<Notification> _notifications = [];
  Map<String, UserModel> _senderProfiles = {};
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentUserId;
  RealtimeChannel? _notificationsSubscription;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  void _setupRealtimeSubscription(String userId) {
    _notificationsSubscription = Supabase.instance.client
        .channel('public:notifications:user_id=eq.$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            _loadNotifications();
          },
        )
        ..subscribe();
  }

  @override
  void dispose() {
    _notificationsSubscription?.unsubscribe();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        throw Exception('User not authenticated');
      }

      _currentUserId = user.id;
      if (_notificationsSubscription == null) {
        _setupRealtimeSubscription(user.id);
      }

      final response = await Supabase.instance.client
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      final List<Notification> loadedNotifications = (response as List).map((n) => Notification.fromJson(n)).toList();

      // Extract unique user IDs of senders from notification content
      final userIds = loadedNotifications
          .map((n) => (n.content?['userId'] as String? ?? n.content?['senderId'] as String? ?? n.content?['sender_id'] as String?))
          .where((id) => id != null)
          .cast<String>()
          .toSet()
          .toList();

      final Map<String, UserModel> loadedProfiles = {};
      if (userIds.isNotEmpty) {
        final profilesRes = await Supabase.instance.client
            .from('profiles')
            .select('*')
            .inFilter('id', userIds);
        for (final p in profilesRes as List) {
          final userModel = UserModel.fromJson(p as Map<String, dynamic>);
          loadedProfiles[userModel.id] = userModel;
        }
      }

      setState(() {
        _notifications = loadedNotifications;
        _senderProfiles = loadedProfiles;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  List<Notification> get _filteredNotifications {
    return _notifications.where((n) {
      if (_activeTab == 'All') return true;
      if (_activeTab == 'Mentions') return n.type == 'mention';
      if (_activeTab == 'DMs') return n.type == 'dm';
      if (_activeTab == 'Friends') return n.type == 'friend_request';
      return true;
    }).toList();
  }

  int get _unreadCount => _notifications.where((n) => !n.read).length;

  Future<void> _markAsRead(String id) async {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = Notification(
          id: _notifications[index].id,
          userId: _notifications[index].userId,
          type: _notifications[index].type,
          content: _notifications[index].content,
          read: true,
          createdAt: _notifications[index].createdAt,
        );
      }
    });

    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read': true})
          .eq('id', id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark as read: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _markAllAsRead() async {
    final currentUserId = _currentUserId;
    if (currentUserId == null || _unreadCount == 0) return;

    setState(() {
      _notifications = _notifications.map((n) => Notification(
        id: n.id,
        userId: n.userId,
        type: n.type,
        content: n.content,
        read: true,
        createdAt: n.createdAt,
      )).toList();
    });

    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read': true})
          .eq('user_id', currentUserId)
          .eq('read', false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to mark all as read: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  String _getRelativeTime(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final diffInSeconds = (now.difference(date).inSeconds);

      if (diffInSeconds < 60) return 'Just now';
      if (diffInSeconds < 3600) return '${(diffInSeconds / 60).floor()}m';
      if (diffInSeconds < 86400) return '${(diffInSeconds / 3600).floor()}h';
      if (diffInSeconds < 2592000) return '${(diffInSeconds / 86400).floor()}d';
      return '${(diffInSeconds / 2592000).floor()}mo';
    } catch (_) {
      return 'Just now';
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'mention': return Icons.alternate_email;
      case 'dm': return Icons.chat_bubble;
      case 'friend_request': return Icons.person_add;
      case 'server_invite': return Icons.mail;
      case 'event': return Icons.calendar_today;
      case 'stream': return Icons.videocam;
      default: return Icons.notifications;
    }
  }

  Color _getTypeAccentColor(String type) {
    switch (type) {
      case 'mention': return _greenPunch;
      case 'dm': return const Color(0xFF3B82F6);
      case 'friend_request': return const Color(0xFF8B5CF6);
      case 'server_invite': return const Color(0xFFF59E0B);
      case 'event': return const Color(0xFFEC4899);
      case 'stream': return const Color(0xFFEF4444);
      default: return _greenPunch;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPrimary,
      appBar: AppBar(
        backgroundColor: _bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: _textPrimary, size: 26),
          onPressed: () {},
        ),
        centerTitle: true,
        title: Text(
          'FLICKO',
          style: GoogleFonts.outfit(
            color: _textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 22,
            letterSpacing: 2.0,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: _textSecondary, size: 26),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Large ACTIVITY Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NOTIFICATIONS',
                  style: GoogleFonts.outfit(
                    color: _textPrimary,
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                if (_unreadCount > 0)
                  TextButton(
                    onPressed: _markAllAsRead,
                    child: Text(
                      'Mark all read',
                      style: GoogleFonts.outfit(
                        color: _greenPunch,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Sub-tabs — horizontal scrollable pill chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final active = _activeTab == tab;
                return GestureDetector(
                  onTap: () => setState(() => _activeTab = tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: active ? _greenPunch : const Color(0xFF14141A),
                      border: Border.all(
                        color: active ? _greenPunch : Colors.white.withValues(alpha: 0.1),
                        width: 1.2,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: _greenPunch.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        tab,
                        style: GoogleFonts.outfit(
                          color: active ? Colors.black : _textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _notifications.isEmpty) {
      return const NotificationSkeleton(count: 6);
    }

    if (_errorMessage != null) {
      return FlickoErrorState.fromException(
        _errorMessage!,
        onRetry: _loadNotifications,
      );
    }

    final filtered = _filteredNotifications;
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 56, color: _textSecondary),
            const SizedBox(height: 16),
            Text(
              'No activities to show',
              style: GoogleFonts.outfit(
                color: _textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You\'re all caught up!',
              style: GoogleFonts.outfit(
                color: _textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: _greenPunch,
      backgroundColor: _bgSurface,
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: filtered.length,
        itemBuilder: (context, index) => _buildNotificationItem(filtered[index]),
      ),
    );
  }

  bool _isMediaUrl(String? url) {
    if (url == null) return false;
    final lower = url.toLowerCase();
    return lower.startsWith('http://') || lower.startsWith('https://');
  }

  String _getMediaType(String url) {
    final lower = url.toLowerCase();
    if (lower.contains('/sticker/')) return 'sticker';
    if (lower.endsWith('.gif') || lower.contains('.gif')) return 'gif';
    if (lower.endsWith('.png') || lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.webp')) return 'image';
    if (lower.endsWith('.mp4') || lower.endsWith('.mov') || lower.endsWith('.webm') || lower.endsWith('.avi')) return 'video';
    return 'link';
  }

  Widget _buildPreviewWidget(String preview) {
    if (_isMediaUrl(preview)) {
      final mediaType = _getMediaType(preview);
      if (mediaType == 'sticker' || mediaType == 'gif' || mediaType == 'image' || mediaType == 'video') {
        return ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 180, maxHeight: 120),
            decoration: BoxDecoration(
              color: _bgPrimary,
              border: Border.all(color: _border, width: 1.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Image.network(
                  preview,
                  fit: BoxFit.cover,
                  width: 180,
                  height: 120,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 180,
                      height: 120,
                      color: _bgPrimary,
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: _greenPunch,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      color: _bgSurface,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.broken_image_outlined, color: _textSecondary, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Failed to load media',
                            style: GoogleFonts.outfit(color: _textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                if (mediaType == 'video')
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(6),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
              ],
            ),
          ),
        );
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _bgPrimary,
        border: Border.all(color: _border, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        preview,
        style: GoogleFonts.outfit(
          color: _textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _handleNotificationTap(Notification notification) {
    _markAsRead(notification.id);
    final meta = notification.content ?? {};
    final channelId = meta['channelId'] as String? ?? meta['channel_id'] as String?;
    final serverId = meta['serverId'] as String? ?? meta['server_id'] as String?;
    final dmId = meta['dmId'] as String? ?? meta['dm_id'] as String?;
    final senderId = meta['userId'] as String? ?? meta['senderId'] as String? ?? meta['sender_id'] as String?;

    if (serverId != null && serverId.isNotEmpty && channelId != null && channelId.isNotEmpty) {
      context.push('/server/$serverId/channel/$channelId');
    } else {
      final targetUserId = dmId ?? senderId ?? channelId;
      if (targetUserId != null && targetUserId.isNotEmpty) {
        Navigator.of(context, rootNavigator: true).push(
          MaterialPageRoute(
            builder: (context) => DMChatScreen(userId: targetUserId),
          ),
        );
      } else {
        context.push('/dms');
      }
    }
  }

  Widget _buildNotificationItem(Notification notification) {
    final meta = notification.content ?? {};
    final senderId = meta['userId'] as String? ?? meta['senderId'] as String? ?? meta['sender_id'] as String?;
    final senderProfile = senderId != null ? _senderProfiles[senderId] : null;
    final String userName = (senderProfile?.displayName?.isNotEmpty == true)
        ? senderProfile!.displayName!
        : ((senderProfile?.username.isNotEmpty == true)
            ? senderProfile!.username
            : (meta['userName'] as String? ?? 'Someone'));
    var content = meta['content'] as String? ?? 'sent a notification';
    final preview = meta['preview'] as String?;
    final accentColor = _getTypeAccentColor(notification.type);

    if (content == 'sent you a direct message' && _isMediaUrl(preview)) {
      final mediaType = _getMediaType(preview!);
      if (mediaType == 'sticker') {
        content = 'sent you a sticker ⚡';
      } else if (mediaType == 'gif') {
        content = 'sent you a GIF 🎬';
      } else if (mediaType == 'image') {
        content = 'sent you a photo 📷';
      } else if (mediaType == 'video') {
        content = 'sent you a video 🎥';
      }
    }

    return GestureDetector(
      onTap: () => _handleNotificationTap(notification),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.read ? _bgCard : _bgSurface,
          border: Border.all(
            color: notification.read ? _border : accentColor.withValues(alpha: 0.3),
            width: 1.5,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // UserAvatar with Notification Type badge overlay
            Stack(
              clipBehavior: Clip.none,
              children: [
                UserAvatar(
                  imageUrl: senderProfile?.avatarUrl ?? meta['userAvatar'] as String?,
                  name: userName,
                  size: 46,
                  userId: senderId,
                  showStatus: false,
                  decoration: senderProfile?.avatarDecoration,
                ),
                Positioned(
                  right: -3,
                  bottom: -3,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: _bgPrimary,
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getTypeIcon(notification.type),
                        size: 10,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          userName,
                          style: GoogleFonts.outfit(
                            color: _textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!notification.read)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(right: 6),
                              decoration: const BoxDecoration(
                                color: _greenPunch,
                                shape: BoxShape.circle,
                              ),
                            ),
                          Text(
                            _getRelativeTime(notification.createdAt),
                            style: GoogleFonts.outfit(
                              color: _textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    content,
                    style: GoogleFonts.outfit(
                      color: _textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (preview != null) ...[
                    const SizedBox(height: 8),
                    _buildPreviewWidget(preview),
                  ],
                  if (notification.type == 'friend_request' && !notification.read) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _greenPunch,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => _handleAcceptFriend(notification.id, senderId),
                          child: Text(
                            'Accept',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _textSecondary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(color: _border, width: 1.5),
                          ),
                          onPressed: () => _handleDeclineFriend(notification.id, senderId),
                          child: Text(
                            'Decline',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleAcceptFriend(String notifId, String? senderId) async {
    final currentUserId = _currentUserId;
    if (senderId == null || currentUserId == null) return;

    try {
      await Supabase.instance.client
          .from('friend_requests')
          .update({'status': 'accepted'})
          .eq('sender_id', senderId)
          .eq('receiver_id', currentUserId);

      await Supabase.instance.client.from('friends').insert([
        {'user_id': currentUserId, 'friend_id': senderId, 'status': 'accepted'},
      ]);

      await Supabase.instance.client.from('friendships').insert([
        {'user_id': currentUserId, 'friend_id': senderId},
      ]);

      await _markAsRead(notifId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept friend: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _handleDeclineFriend(String notifId, String? senderId) async {
    final currentUserId = _currentUserId;
    if (senderId == null || currentUserId == null) return;

    try {
      await Supabase.instance.client
          .from('friend_requests')
          .update({'status': 'declined'})
          .eq('sender_id', senderId)
          .eq('receiver_id', currentUserId);

      await _markAsRead(notifId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to decline friend: ${e.toString()}'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}
