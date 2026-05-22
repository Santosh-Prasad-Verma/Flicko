import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/creator_repository.dart';
import '../../data/models/creator_post.dart';

class CreatorFeedState {
  final List<CreatorPost> posts;
  final bool isLoading;
  final bool isLoadMore;
  final bool hasMore;
  final String? cursor;
  final String? error;

  CreatorFeedState({
    this.posts = const [],
    this.isLoading = false,
    this.isLoadMore = false,
    this.hasMore = true,
    this.cursor,
    this.error,
  });

  CreatorFeedState copyWith({
    List<CreatorPost>? posts,
    bool? isLoading,
    bool? isLoadMore,
    bool? hasMore,
    String? cursor,
    String? error,
  }) {
    return CreatorFeedState(
      posts: posts ?? this.posts,
      isLoading: isLoading ?? this.isLoading,
      isLoadMore: isLoadMore ?? this.isLoadMore,
      hasMore: hasMore ?? this.hasMore,
      cursor: cursor ?? this.cursor,
      error: error,
    );
  }
}

class CreatorFeedNotifier extends Notifier<CreatorFeedState> {
  late final CreatorRepository _repository;

  @override
  CreatorFeedState build() {
    _repository = ref.watch(creatorRepositoryProvider);
    return CreatorFeedState();
  }

  String _buildCursor(CreatorPost post) {
    final ts = post.createdAt.millisecondsSinceEpoch ~/ 1000;
    final str = '$ts:${post.id}';
    return base64Encode(utf8.encode(str));
  }

  Future<void> fetchFeed({bool isRefresh = false}) async {
    if (isRefresh) {
      state = state.copyWith(isLoading: true, hasMore: true, cursor: null, error: null);
    } else {
      if (state.isLoading || state.isLoadMore || !state.hasMore) return;
      state = state.copyWith(isLoadMore: true, error: null);
    }

    try {
      final postsList = await _repository.getFeed(
        cursor: state.cursor,
        limit: 20,
      );

      final nextCursor = postsList.isNotEmpty ? _buildCursor(postsList.last) : null;
      final hasMore = postsList.length == 20;

      if (isRefresh) {
        state = CreatorFeedState(
          posts: postsList,
          cursor: nextCursor,
          hasMore: hasMore,
          isLoading: false,
        );
      } else {
        final existingIds = state.posts.map((p) => p.id).toSet();
        final uniqueNew = postsList.where((p) => !existingIds.contains(p.id)).toList();

        state = state.copyWith(
          posts: [...state.posts, ...uniqueNew],
          cursor: nextCursor,
          hasMore: hasMore,
          isLoadMore: false,
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadMore: false,
        error: e.toString(),
      );
    }
  }

  // Optimistic Like with Rollback
  Future<void> toggleLike(String postId) async {
    final oldPostsList = List<CreatorPost>.from(state.posts);

    // Optimistically update the list
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
      final actualLiked = await _repository.toggleLike(postId);
      // Synchronize with the server's actual state
      state = state.copyWith(
        posts: state.posts.map((p) {
          if (p.id == postId) {
            return p.copyWith(
              likedByMe: actualLiked,
            );
          }
          return p;
        }).toList(),
      );
    } catch (e) {
      // Rollback on failure
      state = state.copyWith(posts: oldPostsList);
    }
  }

  // Optimistic Repost with Rollback
  Future<void> toggleRepost(String postId) async {
    final oldPostsList = List<CreatorPost>.from(state.posts);

    // Optimistically update the list
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
      final actualReposted = await _repository.toggleRepost(postId);
      // Synchronize with the server's actual state
      state = state.copyWith(
        posts: state.posts.map((p) {
          if (p.id == postId) {
            return p.copyWith(
              repostedByMe: actualReposted,
            );
          }
          return p;
        }).toList(),
      );
    } catch (e) {
      // Rollback on failure
      state = state.copyWith(posts: oldPostsList);
    }
  }

  Future<void> createPost({
    required String content,
    List<String>? mediaUrls,
    String? category,
    String? title,
    String? postType,
    String? visibility,
  }) async {
    try {
      final newPost = await _repository.createPost(
        content: content,
        mediaUrls: mediaUrls,
        category: category,
        title: title,
        postType: postType,
        visibility: visibility,
      );

      // Prepend to top of feed if successful
      state = state.copyWith(
        posts: [newPost, ...state.posts],
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deletePost(String postId) async {
    final oldPostsList = List<CreatorPost>.from(state.posts);

    // Optimistically remove from feed
    state = state.copyWith(
      posts: state.posts.where((p) => p.id != postId).toList(),
    );

    try {
      await _repository.deletePost(postId);
    } catch (e) {
      // Rollback
      state = state.copyWith(posts: oldPostsList);
      rethrow;
    }
  }
}

final creatorFeedProvider =
    NotifierProvider.autoDispose<CreatorFeedNotifier, CreatorFeedState>(
  CreatorFeedNotifier.new,
);
