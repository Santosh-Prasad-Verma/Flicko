class CreatorPost {
  final String id;
  final String userId;
  final String username;
  final String? displayName;
  final String? avatar;
  final bool verified;
  final String content;
  final List<String> mediaUrls;
  final String? parentPostId;
  final String? rootPostId;
  final String category;
  final String? title;
  final String? acceptedAnswerId;
  final bool isDeleted;
  final bool flagged;
  final int replyCount;
  final int likeCount;
  final int repostCount;
  final String postType;
  final String visibility;
  final bool likedByMe;
  final bool repostedByMe;
  final DateTime createdAt;
  final DateTime updatedAt;

  CreatorPost({
    required this.id,
    required this.userId,
    required this.username,
    this.displayName,
    this.avatar,
    required this.verified,
    required this.content,
    required this.mediaUrls,
    this.parentPostId,
    this.rootPostId,
    required this.category,
    this.title,
    this.acceptedAnswerId,
    required this.isDeleted,
    required this.flagged,
    required this.replyCount,
    required this.likeCount,
    required this.repostCount,
    required this.postType,
    required this.visibility,
    required this.likedByMe,
    required this.repostedByMe,
    required this.createdAt,
    required this.updatedAt,
  });

  CreatorPost copyWith({
    String? id,
    String? userId,
    String? username,
    String? displayName,
    String? avatar,
    bool? verified,
    String? content,
    List<String>? mediaUrls,
    String? parentPostId,
    String? rootPostId,
    String? category,
    String? title,
    String? acceptedAnswerId,
    bool? isDeleted,
    bool? flagged,
    int? replyCount,
    int? likeCount,
    int? repostCount,
    String? postType,
    String? visibility,
    bool? likedByMe,
    bool? repostedByMe,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CreatorPost(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      verified: verified ?? this.verified,
      content: content ?? this.content,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      parentPostId: parentPostId ?? this.parentPostId,
      rootPostId: rootPostId ?? this.rootPostId,
      category: category ?? this.category,
      title: title ?? this.title,
      acceptedAnswerId: acceptedAnswerId ?? this.acceptedAnswerId,
      isDeleted: isDeleted ?? this.isDeleted,
      flagged: flagged ?? this.flagged,
      replyCount: replyCount ?? this.replyCount,
      likeCount: likeCount ?? this.likeCount,
      repostCount: repostCount ?? this.repostCount,
      postType: postType ?? this.postType,
      visibility: visibility ?? this.visibility,
      likedByMe: likedByMe ?? this.likedByMe,
      repostedByMe: repostedByMe ?? this.repostedByMe,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory CreatorPost.fromJson(Map<String, dynamic> json) {
    return CreatorPost(
      id: json['id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'anonymous',
      displayName: json['display_name'] as String?,
      avatar: json['avatar'] as String?,
      verified: json['verified'] as bool? ?? false,
      content: json['content'] as String? ?? '',
      mediaUrls: (json['media_urls'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      parentPostId: json['parent_post_id'] as String?,
      rootPostId: json['root_post_id'] as String?,
      category: json['category'] as String? ?? 'general',
      title: json['title'] as String?,
      acceptedAnswerId: json['accepted_answer_id'] as String?,
      isDeleted: json['is_deleted'] as bool? ?? false,
      flagged: json['flagged'] as bool? ?? false,
      replyCount: json['reply_count'] as int? ?? 0,
      likeCount: json['like_count'] as int? ?? 0,
      repostCount: json['repost_count'] as int? ?? 0,
      postType: json['post_type'] as String? ?? 'tweet',
      visibility: json['visibility'] as String? ?? 'public',
      likedByMe: json['liked_by_me'] as bool? ?? false,
      repostedByMe: json['reposted_by_me'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'username': username,
      'display_name': displayName,
      'avatar': avatar,
      'verified': verified,
      'content': content,
      'media_urls': mediaUrls,
      'parent_post_id': parentPostId,
      'root_post_id': rootPostId,
      'category': category,
      'title': title,
      'accepted_answer_id': acceptedAnswerId,
      'is_deleted': isDeleted,
      'flagged': flagged,
      'reply_count': replyCount,
      'like_count': likeCount,
      'repost_count': repostCount,
      'post_type': postType,
      'visibility': visibility,
      'liked_by_me': likedByMe,
      'reposted_by_me': repostedByMe,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class CreatorProfile {
  final String id;
  final String username;
  final String? displayName;
  final String? avatar;
  final String? bio;
  final bool verified;
  final int followerCount;
  final int followingCount;
  final int postCount;
  final bool isFollowing;
  final bool isBlocked;

  CreatorProfile({
    required this.id,
    required this.username,
    this.displayName,
    this.avatar,
    this.bio,
    required this.verified,
    required this.followerCount,
    required this.followingCount,
    required this.postCount,
    required this.isFollowing,
    required this.isBlocked,
  });

  CreatorProfile copyWith({
    String? id,
    String? username,
    String? displayName,
    String? avatar,
    String? bio,
    bool? verified,
    int? followerCount,
    int? followingCount,
    int? postCount,
    bool? isFollowing,
    bool? isBlocked,
  }) {
    return CreatorProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      verified: verified ?? this.verified,
      followerCount: followerCount ?? this.followerCount,
      followingCount: followingCount ?? this.followingCount,
      postCount: postCount ?? this.postCount,
      isFollowing: isFollowing ?? this.isFollowing,
      isBlocked: isBlocked ?? this.isBlocked,
    );
  }

  factory CreatorProfile.fromJson(Map<String, dynamic> json) {
    return CreatorProfile(
      id: json['id'] as String? ?? '',
      username: json['username'] as String? ?? 'anonymous',
      displayName: json['display_name'] as String?,
      avatar: json['avatar'] as String?,
      bio: json['bio'] as String?,
      verified: json['verified'] as bool? ?? false,
      followerCount: json['follower_count'] as int? ?? 0,
      followingCount: json['following_count'] as int? ?? 0,
      postCount: json['post_count'] as int? ?? 0,
      isFollowing: json['is_following'] as bool? ?? false,
      isBlocked: json['is_blocked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'display_name': displayName,
      'avatar': avatar,
      'bio': bio,
      'verified': verified,
      'follower_count': followerCount,
      'following_count': followingCount,
      'post_count': postCount,
      'is_following': isFollowing,
      'is_blocked': isBlocked,
    };
  }
}
