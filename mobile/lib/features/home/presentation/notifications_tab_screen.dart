import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';
import 'package:mobile/features/shared/presentation/widgets/avatar.dart';

/// Notifications Tab Screen
///
/// Tab version of NotificationCenter with tabs: All, Mentions, DMs, Friends.
/// Shows real-time notifications with filter tabs.
class NotificationsTabScreen extends ConsumerStatefulWidget {
  const NotificationsTabScreen({super.key});

  @override
  ConsumerState<NotificationsTabScreen> createState() => _NotificationsTabScreenState();
}

class _NotificationsTabScreenState extends ConsumerState<NotificationsTabScreen> {
  final List<String> _tabs = const ['All', 'Mentions', 'DMs', 'Friends'];
  String _activeTab = 'All';
  
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;
  bool _refreshing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final user = ref.read(authProvider).user;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('notifications')
          .select('*')
          .eq('user_id', user.id)
          .order('created_at', ascending: false)
          .limit(50);

      setState(() {
        _notifications = (data as List<dynamic>).cast<Map<String, dynamic>>();
        _isLoading = false;
        _refreshing = false;
        _error = null;
      });
    } catch (e) {
      debugPrint('Error loading notifications: $e');
      setState(() {
        _isLoading = false;
        _refreshing = false;
        _error = e.toString();
      });
    }
  }

  List<Map<String, dynamic>> get _filteredNotifications {
    switch (_activeTab) {
      case 'Mentions':
        return _notifications.where((n) => n['type'] == 'mention').toList();
      case 'DMs':
        return _notifications.where((n) => n['type'] == 'dm').toList();
      case 'Friends':
        return _notifications.where((n) => n['type'] == 'friend_request').toList();
      default:
        return _notifications;
    }
  }

  int get _unreadCount => _notifications.where((n) => !(n['read'] as bool? ?? true)).length;

  Future<void> _markAsRead(String id) async {
    setState(() {
      _notifications = _notifications.map((n) {
        if (n['id'] == id) {
          return {...n, 'read': true};
        }
        return n;
      }).toList();
    });

    try {
      final supabase = Supabase.instance.client;
      await supabase.from('notifications').update({'read': true}).eq('id', id);
    } catch (e) {
      debugPrint('Error marking as read: $e');
    }
  }

  Future<void> _markAllAsRead() async {
    final user = ref.read(authProvider).user;
    if (user == null || _unreadCount == 0) return;

    setState(() {
      _notifications = _notifications.map((n) => {...n, 'read': true}).toList();
    });

    try {
      final supabase = Supabase.instance.client;
      await supabase
          .from('notifications')
          .update({'read': true})
          .eq('user_id', user.id)
          .eq('read', false);
    } catch (e) {
      debugPrint('Error marking all as read: $e');
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'mention':
        return Icons.alternate_email;
      case 'dm':
        return Icons.chat_bubble_outline;
      case 'friend_request':
        return Icons.person_add_outlined;
      case 'server_invite':
        return Icons.mail_outline;
      case 'event':
        return Icons.calendar_today;
      case 'stream':
        return Icons.videocam_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  String _getRelativeTime(String dateString) {
    final date = DateTime.parse(dateString);
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildNotificationRow(Map<String, dynamic> notification) {
    final isRead = notification['read'] as bool? ?? true;
    final type = notification['type'] as String? ?? 'other';
    final meta = (notification['content'] as Map<String, dynamic>?) ?? {};

    return InkWell(
      onTap: () => _markAsRead(notification['id'] as String),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isRead ? null : const Color(FlickoColors.bgSecondary),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread dot
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 8, right: 8),
                decoration: const BoxDecoration(
                  color: Color(FlickoColors.blurple),
                  shape: BoxShape.circle,
                ),
              )
            else
              const SizedBox(width: 16),

            // Icon/Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgTertiary),
                borderRadius: BorderRadius.circular(20),
              ),
              child: meta['userAvatar'] != null
                  ? Avatar(
                      name: meta['userName'] as String? ?? 'User',
                      imageUrl: meta['userAvatar'] as String?,
                      size: 40,
                    )
                  : Icon(
                      _getTypeIcon(type),
                      color: const Color(FlickoColors.textMuted),
                      size: 20,
                    ),
            ),

            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if ((type == 'mention' || type == 'event') && meta['channelName'] != null)
                    Text(
                      '#${meta['channelName']}',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 12,
                      ),
                    ),
                  RichText(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                        fontSize: 14,
                        height: 1.4,
                      ),
                      children: [
                        TextSpan(
                          text: meta['userName'] ?? 'Someone',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const TextSpan(text: ' '),
                        TextSpan(
                          text: type == 'event'
                              ? meta['content'] as String? ?? 'sent a notification'
                              : meta['content'] as String? ?? 'sent a notification',
                        ),
                      ],
                    ),
                  ),
                  if (meta['preview'] != null)
                    Text(
                      meta['preview'] as String,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                  // Friend request actions
                  if (type == 'friend_request' && !isRead)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          ElevatedButton(
                            onPressed: () {
                              // Accept friend request
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(FlickoColors.blurple),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              minimumSize: const Size(0, 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: Text(
                              'Accept',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              // Decline friend request
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(FlickoColors.bgTertiary),
                              foregroundColor: const Color(FlickoColors.textMuted),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              minimumSize: const Size(0, 32),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: Text(
                              'Decline',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),

            // Time
            Text(
              _getRelativeTime(notification['created_at'] as String),
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

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(16, topPadding + 8, 16, 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: const Color(FlickoColors.border),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.search, color: Color(FlickoColors.textPrimary)),
                  onPressed: () => context.push('/search'),
                ),
                const Spacer(),
                if (_unreadCount > 0)
                  GestureDetector(
                    onTap: _markAllAsRead,
                    child: Text(
                      'Mark all read',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.blurple),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Filter Tabs
          Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: const Color(FlickoColors.border),
                  width: 0.5,
                ),
              ),
            ),
            child: Row(
              children: _tabs.map((tab) {
                final isActive = _activeTab == tab;
                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _activeTab = tab),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: isActive
                                ? const Color(FlickoColors.blurple)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                      ),
                      child: Text(
                        tab,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: isActive
                              ? const Color(FlickoColors.textPrimary)
                              : const Color(FlickoColors.textMuted),
                          fontSize: 14,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(FlickoColors.blurple)),
                    ),
                  )
                : _error != null
                    ? _buildErrorView()
                    : _filteredNotifications.isEmpty
                        ? _buildEmptyView()
                        : RefreshIndicator(
                            onRefresh: () async {
                              setState(() => _refreshing = true);
                              await _loadNotifications();
                            },
                            color: const Color(FlickoColors.blurple),
                            child: ListView.builder(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: _filteredNotifications.length,
                              itemBuilder: (context, index) {
                                return _buildNotificationRow(_filteredNotifications[index]);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgTertiary),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.error_outline,
              color: Color(FlickoColors.danger),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Could not load notifications',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _error = null;
              });
              _loadNotifications();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.blurple),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Tap to retry',
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgTertiary),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              color: Color(FlickoColors.textMuted),
              size: 40,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No notifications',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _activeTab == 'All'
                ? "You're all caught up! Notifications will appear here."
                : 'No ${_activeTab.toLowerCase()} notifications to show.',
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
}
