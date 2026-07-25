/// Domain models for the Friends feature.
///
/// These models are used across the data, application, and presentation layers.
/// They map directly to the Supabase `friends`, `friend_requests`, and
/// `friendships` tables combined with profile joins.
library;

class Friend {
  final String id;
  final String friendshipId;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String status;
  final String statusMessage;
  final bool isOnline;
  final DateTime? lastSeen;
  final DateTime createdAt;

  Friend({
    required this.id,
    required this.friendshipId,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.status,
    required this.statusMessage,
    required this.isOnline,
    this.lastSeen,
    required this.createdAt,
  });

  /// Constructs a [Friend] from a Supabase row that joins `friends` with `profiles`.
  ///
  /// Expected shape (from a query like):
  /// ```sql
  /// SELECT f.*, p.username, p.display_name, p.avatar, p.online_status, p.custom_status
  /// FROM friends f
  /// JOIN profiles p ON p.id = f.friend_id
  /// WHERE f.user_id = :userId AND f.status = 'accepted'
  /// ```
  factory Friend.fromJson(Map<String, dynamic> json) {
    final profile = json['profile'] as Map<String, dynamic>?;
    final onlineStatus = profile?['online_status'] as String? ??
        json['online_status'] as String? ??
        'offline';
    final isOnline = onlineStatus == 'online' || onlineStatus == 'idle' || onlineStatus == 'dnd';

    String statusMessage;
    switch (onlineStatus) {
      case 'online':
        statusMessage = profile?['custom_status'] as String? ??
            json['custom_status'] as String? ??
            'Online';
        break;
      case 'idle':
        statusMessage = 'Idle';
        break;
      case 'dnd':
        statusMessage = 'Do Not Disturb';
        break;
      default:
        statusMessage = 'Offline';
    }

    return Friend(
      id: (profile?['id'] ?? json['friend_id'] ?? json['id']) as String,
      friendshipId: json['id'] as String? ?? '',
      username: (profile?['username'] ?? json['username'] ?? 'unknown') as String,
      displayName: profile?['display_name'] as String? ?? json['display_name'] as String?,
      avatarUrl: profile?['avatar'] as String? ?? json['avatar'] as String?,
      status: onlineStatus,
      statusMessage: statusMessage,
      isOnline: isOnline,
      lastSeen: _tryParseDateTime(json['last_seen'] ?? profile?['last_seen']),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class FriendRequest {
  final String id;
  final FriendUser user;
  final DateTime createdAt;
  final String status;
  final String? message;
  final bool isIncoming;

  FriendRequest({
    required this.id,
    required this.user,
    required this.createdAt,
    required this.status,
    this.message,
    required this.isIncoming,
  });

  /// Constructs a [FriendRequest] from a Supabase row with profile join.
  ///
  /// [currentUserId] is needed to determine if this is incoming or outgoing.
  factory FriendRequest.fromJson(Map<String, dynamic> json, String currentUserId) {
    final senderId = json['sender_id'] as String;
    final isIncoming = senderId != currentUserId;

    // The joined profile is the *other* user (sender if incoming, receiver if outgoing).
    final profile = (isIncoming
        ? json['sender_profile']
        : json['receiver_profile']) as Map<String, dynamic>?;

    return FriendRequest(
      id: json['id'] as String,
      user: FriendUser.fromJson(profile ?? {}, fallbackId: isIncoming ? senderId : json['receiver_id'] as String),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      status: json['status'] as String? ?? 'pending',
      message: json['message'] as String?,
      isIncoming: isIncoming,
    );
  }
}

class FriendUser {
  final String id;
  final String username;
  final String? displayName;
  final String? avatarUrl;
  final String status;
  final int? mutualFriends;

  FriendUser({
    required this.id,
    required this.username,
    this.displayName,
    this.avatarUrl,
    required this.status,
    this.mutualFriends,
  });

  factory FriendUser.fromJson(Map<String, dynamic> json, {String? fallbackId}) {
    return FriendUser(
      id: json['id'] as String? ?? fallbackId ?? '',
      username: json['username'] as String? ?? 'unknown',
      displayName: json['display_name'] as String?,
      avatarUrl: json['avatar'] as String?,
      status: json['online_status'] as String? ?? 'offline',
      mutualFriends: json['mutual_friends'] as int?,
    );
  }
}

DateTime? _tryParseDateTime(dynamic val) {
  if (val == null) return null;
  if (val is DateTime) return val;
  if (val is String) return DateTime.tryParse(val);
  return null;
}
