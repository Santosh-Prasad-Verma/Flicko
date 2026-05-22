import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/creator_repository.dart';
import '../../data/models/creator_post.dart';

class CreatorProfileState {
  final CreatorProfile? profile;
  final List<CreatorPost> posts;
  final bool isLoading;
  final bool isLoadMore;
  final bool hasMore;
  final String? cursor;
  final String? error;

  CreatorProfileState({
    this.profile,
    this.posts = const [],
    this.isLoading = false,
    this.isLoadMore = false,
    this.hasMore = true,
    this.cursor,
    this.error,
  });

  CreatorProfileState copyWith({
    CreatorProfile? profile,
    List<CreatorPost>? posts,
    bool? isLoading,
    bool? isLoadMore,
    bool? hasMore,
    String? cursor,
    String? error,
  }) {
    return CreatorProfileState(
      profile: profile ?? this.profile,
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadMore: isLoadMore ?? this.isLoadMore,
      hasMore: hasMore ?? this.hasMore,
      cursor: cursor ?? this.cursor,
      error: error,
    );
  }
}

class CreatorProfileNotifier extends Notifier<CreatorProfileState> {
  late final CreatorRepository _repository;
  late final String _userId;

  CreatorProfileNotifier(this._userId);

  @override
  CreatorProfileState build() {
    _repository = ref.watch(creatorRepositoryProvider);
    Future.microtask(() => loadProfile());
    return CreatorProfileState(isLoading: true);
  }

  String _buildCursor(CreatorPost post) {
    final ts = post.createdAt.millisecondsSinceEpoch ~/ 1000;
    final str = '$ts:${post.id}';
    return base64Encode(utf8.encode(str));
  }

  Future<void> loadProfile() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final profile = await _repository.getUserProfile(_userId);
      final postsList = await _repository.getUserPosts(_userId, limit: 20);

      final nextCursor = postsList.isNotEmpty ? _buildCursor(postsList.last) : null;
      final hasMore = postsList.length == 20;

      state = CreatorProfileState(
        profile: profile,
        posts: postsList,
        cursor: nextCursor,
        hasMore: hasMore,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  Future<void> fetchMorePosts() async {
    if (state.isLoading || state.isLoadMore || !state.hasMore) return;

    state = state.copyWith(isLoadMore: true, error: null);
    try {
      final postsList = await _repository.getUserPosts(
        _userId,
        cursor: state.cursor,
        limit: 20,
      );

      final nextCursor = postsList.isNotEmpty ? _buildCursor(postsList.last) : null;
      final hasMore = postsList.length == 20;

      final existingIds = state.posts.map((p) => p.id).toSet();
      final uniqueNew = postsList.where((p) => !existingIds.contains(p.id)).toList();

      state = state.copyWith(
        posts: [...state.posts, ...uniqueNew],
        cursor: nextCursor,
        hasMore: hasMore,
        isLoadMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadMore: false,
        error: e.toString(),
      );
    }
  }

  Future<void> toggleFollow() async {
    if (state.profile == null) return;
    final oldProfile = state.profile!;

    // Optimistically update
    final nextFollowing = !oldProfile.isFollowing;
    final nextFollowersCount = oldProfile.followerCount + (nextFollowing ? 1 : -1);

    state = state.copyWith(
      profile: oldProfile.copyWith(
        isFollowing: nextFollowing,
        followerCount: nextFollowersCount,
      ),
    );

    try {
      final actualFollowing = await _repository.toggleFollow(_userId);
      state = state.copyWith(
        profile: state.profile?.copyWith(
          isFollowing: actualFollowing,
        ),
      );
    } catch (_) {
      // Rollback
      state = state.copyWith(profile: oldProfile);
      rethrow;
    }
  }

  Future<void> toggleLike(String postId) async {
    final oldPosts = List<CreatorPost>.from(state.posts);

    state = state.copyWith(
      posts: state.posts.map((p) {
        if (p.id == postId) {
          final nextLiked = !p.likedByMe;
          return p.copyWith(
            likedByMe: nextLiked,
            likeCount: p.likeCount + (nextLiked ? 1 : -1),
          );
        }
        return p;
      }).toList(),
    );

    try {
      final actual = await _repository.toggleLike(postId);
      state = state.copyWith(
        posts: state.posts.map((p) {
          if (p.id == postId) {
            return p.copyWith(likedByMe: actual);
          }
          return p;
        }).toList(),
      );
    } catch (_) {
      state = state.copyWith(posts: oldPosts);
    }
  }

  Future<void> toggleRepost(String postId) async {
    final oldPosts = List<CreatorPost>.from(state.posts);

    state = state.copyWith(
      posts: state.posts.map((p) {
        if (p.id == postId) {
          final nextReposted = !p.repostedByMe;
          return p.copyWith(
            repostedByMe: nextReposted,
            repostCount: p.repostCount + (nextReposted ? 1 : -1),
          );
        }
        return p;
      }).toList(),
    );

    try {
      final actual = await _repository.toggleRepost(postId);
      state = state.copyWith(
        posts: state.posts.map((p) {
          if (p.id == postId) {
            return p.copyWith(repostedByMe: actual);
          }
          return p;
        }).toList(),
      );
    } catch (_) {
      state = state.copyWith(posts: oldPosts);
    }
  }
}

final creatorProfileProvider =
    NotifierProvider.autoDispose.family<CreatorProfileNotifier, CreatorProfileState, String>(
  CreatorProfileNotifier.new,
);
