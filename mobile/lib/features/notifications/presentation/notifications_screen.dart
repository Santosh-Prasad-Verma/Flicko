import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../auth/application/auth_notifier.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/button.dart';

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

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  final List<String> _tabs = ['All', 'Mentions', 'DMs', 'Friends'];
  String _activeTab = 'All';
  List<Notification> _notifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
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

      final response = await Supabase.instance.client
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _notifications = (response as List).map((n) => Notification.fromJson(n)).toList();
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
            backgroundColor: const Color(FlickoColors.danger),
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
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    }
  }

  String _getRelativeTime(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final diffInSeconds = (now.difference(date).inSeconds);

    if (diffInSeconds < 60) return '${diffInSeconds}s ago';
    if (diffInSeconds < 3600) return '${(diffInSeconds / 60).floor()}m ago';
    if (diffInSeconds < 86400) return '${(diffInSeconds / 3600).floor()}h ago';
    return '${(diffInSeconds / 86400).floor()}d ago';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Notifications',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _unreadCount > 0 ? _markAllAsRead : null,
            child: Text(
              'Mark all read',
              style: GoogleFonts.inter(
                color: _unreadCount > 0 ? const Color(FlickoColors.blurple) : const Color(FlickoColors.textMuted),
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(FlickoColors.bgTertiary))),
      ),
      child: Row(
        children: _tabs.map((tab) {
          final active = _activeTab == tab;
          return Expanded(
            child: InkWell(
              onTap: () => setState(() => _activeTab = tab),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: active ? const Color(FlickoColors.blurple) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    color: active ? const Color(FlickoColors.textPrimary) : const Color(FlickoColors.textMuted),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
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
            Text('Error loading notifications', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16)),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            Button(
              title: 'Retry',
              onPress: _loadNotifications,
              variant: ButtonVariant.primary,
            ),
          ],
        ),
      );
    }

    if (_filteredNotifications.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.notifications_none, size: 48, color: Color(FlickoColors.textMuted)),
            const SizedBox(height: 16),
            Text('No notifications to show', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        itemCount: _filteredNotifications.length,
        itemBuilder: (context, index) => _buildNotificationItem(_filteredNotifications[index]),
      ),
    );
  }

  Widget _buildNotificationItem(Notification notification) {
    final meta = notification.content ?? {};
    return InkWell(
      onTap: () => _markAsRead(notification.id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: notification.read ? Colors.transparent : const Color(FlickoColors.bgSecondary),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!notification.read)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 8, top: 16),
                decoration: const BoxDecoration(
                  color: Color(FlickoColors.blurple),
                  shape: BoxShape.circle,
                ),
              ),
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgTertiary),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getTypeIcon(notification.type),
                size: 18,
                color: const Color(FlickoColors.textMuted),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (meta['channelName'] != null)
                    Text(
                      '#${meta['channelName']}',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 12,
                      ),
                    ),
                  Text(
                    notification.type == 'event'
                        ? (meta['content'] as String? ?? '')
                        : '${meta['userName'] ?? 'Someone'} ${meta['content'] ?? 'sent a notification'}',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meta['preview'] != null)
                    Text(
                      meta['preview'] as String,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (notification.type == 'friend_request' && !notification.read)
                    Row(
                      children: [
                        Button(
                          title: 'Accept',
                          onPress: () => _handleAcceptFriend(notification.id, meta['userId'] as String?),
                          variant: ButtonVariant.primary,
                          size: ButtonSize.sm,
                        ),
                        const SizedBox(width: 8),
                        Button(
                          title: 'Decline',
                          onPress: () => _handleDeclineFriend(notification.id, meta['userId'] as String?),
                          variant: ButtonVariant.ghost,
                          size: ButtonSize.sm,
                        ),
                      ],
                    ),
                ],
              ),
            ),
            Text(
              _getRelativeTime(notification.createdAt),
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 12,
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

      await Supabase.instance.client.from('friendships').insert([
        {'user_id': currentUserId, 'friend_id': senderId},
        {'user_id': senderId, 'friend_id': currentUserId},
      ]);

      await _markAsRead(notifId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept friend: ${e.toString()}'),
            backgroundColor: const Color(FlickoColors.danger),
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
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    }
  }
}
