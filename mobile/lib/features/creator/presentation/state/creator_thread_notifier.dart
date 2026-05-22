import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/creator_repository.dart';
import '../../data/models/creator_post.dart';

class CreatorThreadState {
  final CreatorPost? rootPost;
  final Map<String, List<CreatorPost>> replies; // parentPostId -> direct replies
  final Set<String> loadingReplyIds; // sub-threads currently fetching replies
  final bool isLoadingRoot;
  final String? error;

  CreatorThreadState({
    this.rootPost,
    this.replies = const {},
    this.loadingReplyIds = const {},
    this.isLoadingRoot = false,
    this.error,
  });

  CreatorThreadState copyWith({
    CreatorPost? rootPost,
    Map<String, List<CreatorPost>>? replies,
    Set<String>? loadingReplyIds,
    bool? isLoadingRoot,
    String? error,
  }) {
    return CreatorThreadState(
      rootPost: rootPost ?? this.rootPost,
      replies: replies ?? this.replies,
      loadingReplyIds: loadingReplyIds ?? this.loadingReplyIds,
      isLoadingRoot: isLoadingRoot ?? this.isLoadingRoot,
      error: error,
    );
  }
}

class CreatorThreadNotifier extends Notifier<CreatorThreadState> {
  late final CreatorRepository _repository;
  late final String _threadId;

  CreatorThreadNotifier(this._threadId);

  @override
  CreatorThreadState build() {
    _repository = ref.watch(creatorRepositoryProvider);
    // Auto-fetch root post and its direct replies on build
    Future.microtask(() => loadThread());
    return CreatorThreadState(isLoadingRoot: true);
  }

  Future<void> loadThread() async {
    state = state.copyWith(isLoadingRoot: true, error: null);
    try {
      final rootPost = await _repository.getPost(_threadId);
      final repliesList = await _repository.getReplies(_threadId);

      final nextReplies = Map<String, List<CreatorPost>>.from(state.replies);
      nextReplies[_threadId] = repliesList;

      state = CreatorThreadState(
        rootPost: rootPost,
        replies: nextReplies,
        isLoadingRoot: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingRoot: false,
        error: e.toString(),
      );
    }
  }

  Future<void> loadRepliesFor(String parentPostId) async {
    if (state.loadingReplyIds.contains(parentPostId)) return;

    state = state.copyWith(
      loadingReplyIds: {...state.loadingReplyIds, parentPostId},
    );

    try {
      final repliesList = await _repository.getReplies(parentPostId);
      final nextReplies = Map<String, List<CreatorPost>>.from(state.replies);
      nextReplies[parentPostId] = repliesList;

      state = state.copyWith(
        replies: nextReplies,
        loadingReplyIds: state.loadingReplyIds.where((id) => id != parentPostId).toSet(),
      );
    } catch (e) {
      state = state.copyWith(
        loadingReplyIds: state.loadingReplyIds.where((id) => id != parentPostId).toSet(),
        error: e.toString(),
      );
    }
  }

  Future<void> toggleLike(String postId) async {
    // If it's the root post, toggle it
    if (state.rootPost?.id == postId) {
      final oldRoot = state.rootPost!;
      final nextLiked = !oldRoot.likedByMe;
      state = state.copyWith(
        rootPost: oldRoot.copyWith(
          likedByMe: nextLiked,
          likeCount: oldRoot.likeCount + (nextLiked ? 1 : -1),
        ),
      );

      try {
        final actual = await _repository.toggleLike(postId);
        state = state.copyWith(rootPost: state.rootPost?.copyWith(likedByMe: actual));
      } catch (_) {
        state = state.copyWith(rootPost: oldRoot);
      }
      return;
    }

    // Otherwise, check in the replies lists
    final nextReplies = Map<String, List<CreatorPost>>.from(state.replies);
    String? foundParentId;
    int? foundIndex;
    CreatorPost? oldPost;

    for (final entry in nextReplies.entries) {
      final index = entry.value.indexWhere((p) => p.id == postId);
      if (index != -1) {
        foundParentId = entry.key;
        foundIndex = index;
        oldPost = entry.value[index];
        break;
      }
    }

    if (foundParentId != null && foundIndex != null && oldPost != null) {
      final nextLiked = !oldPost.likedByMe;
      final newPost = oldPost.copyWith(
        likedByMe: nextLiked,
        likeCount: oldPost.likeCount + (nextLiked ? 1 : -1),
      );
      nextReplies[foundParentId]![foundIndex] = newPost;
      state = state.copyWith(replies: nextReplies);

      try {
        final actual = await _repository.toggleLike(postId);
        final currentReplies = Map<String, List<CreatorPost>>.from(state.replies);
        currentReplies[foundParentId]![foundIndex] = newPost.copyWith(likedByMe: actual);
        state = state.copyWith(replies: currentReplies);
      } catch (_) {
        final currentReplies = Map<String, List<CreatorPost>>.from(state.replies);
        currentReplies[foundParentId]![foundIndex] = oldPost;
        state = state.copyWith(replies: currentReplies);
      }
    }
  }

  Future<void> toggleRepost(String postId) async {
    // Root post
    if (state.rootPost?.id == postId) {
      final oldRoot = state.rootPost!;
      final nextReposted = !oldRoot.repostedByMe;
      state = state.copyWith(
        rootPost: oldRoot.copyWith(
          repostedByMe: nextReposted,
          repostCount: oldRoot.repostCount + (nextReposted ? 1 : -1),
        ),
      );

      try {
        final actual = await _repository.toggleRepost(postId);
        state = state.copyWith(rootPost: state.rootPost?.copyWith(repostedByMe: actual));
      } catch (_) {
        state = state.copyWith(rootPost: oldRoot);
      }
      return;
    }

    // Check replies
    final nextReplies = Map<String, List<CreatorPost>>.from(state.replies);
    String? foundParentId;
    int? foundIndex;
    CreatorPost? oldPost;

    for (final entry in nextReplies.entries) {
      final index = entry.value.indexWhere((p) => p.id == postId);
      if (index != -1) {
        foundParentId = entry.key;
        foundIndex = index;
        oldPost = entry.value[index];
        break;
      }
    }

    if (foundParentId != null && foundIndex != null && oldPost != null) {
      final nextReposted = !oldPost.repostedByMe;
      final newPost = oldPost.copyWith(
        repostedByMe: nextReposted,
        repostCount: oldPost.repostCount + (nextReposted ? 1 : -1),
      );
      nextReplies[foundParentId]![foundIndex] = newPost;
      state = state.copyWith(replies: nextReplies);

      try {
        final actual = await _repository.toggleRepost(postId);
        final currentReplies = Map<String, List<CreatorPost>>.from(state.replies);
        currentReplies[foundParentId]![foundIndex] = newPost.copyWith(repostedByMe: actual);
        state = state.copyWith(replies: currentReplies);
      } catch (_) {
        final currentReplies = Map<String, List<CreatorPost>>.from(state.replies);
        currentReplies[foundParentId]![foundIndex] = oldPost;
        state = state.copyWith(replies: currentReplies);
      }
    }
  }

  Future<void> submitReply({
    required String content,
    required String parentId,
  }) async {
    try {
      final newReply = await _repository.createPost(
        content: content,
        parentPostId: parentId,
        rootPostId: _threadId,
        postType: 'tweet', // replies are standard posts
      );

      // Append to the local replies map
      final nextReplies = Map<String, List<CreatorPost>>.from(state.replies);
      final currentList = nextReplies[parentId] ?? [];
      nextReplies[parentId] = [...currentList, newReply];

      // Update reply count of parent post if it exists
      CreatorPost? updatedRoot;
      if (state.rootPost?.id == parentId) {
        updatedRoot = state.rootPost!.copyWith(
          replyCount: state.rootPost!.replyCount + 1,
        );
      }

      state = state.copyWith(
        replies: nextReplies,
        rootPost: updatedRoot,
      );
    } catch (e) {
      rethrow;
    }
  }

  Future<void> acceptAnswer(String answerId) async {
    if (state.rootPost == null) return;
    final oldRoot = state.rootPost!;

    state = state.copyWith(
      rootPost: oldRoot.copyWith(acceptedAnswerId: answerId),
    );

    try {
      await _repository.markAcceptedAnswer(_threadId, answerId);
    } catch (_) {
      state = state.copyWith(rootPost: oldRoot);
      rethrow;
    }
  }
}

final creatorThreadProvider =
    NotifierProvider.autoDispose.family<CreatorThreadNotifier, CreatorThreadState, String>(
  CreatorThreadNotifier.new,
);
