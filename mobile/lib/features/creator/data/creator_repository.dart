import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/data/clients/dio_client.dart';
import 'models/creator_post.dart';

class CreatorRepository {
  final Dio _dio;
  CreatorRepository(this._dio);

  // ── Post CRUD & Engagement ───────────────────────────────────────────────

  Future<CreatorPost> createPost({
    required String content,
    List<String>? mediaUrls,
    String? parentPostId,
    String? rootPostId,
    String? category,
    String? title,
    String? postType,
    String? visibility,
  }) async {
    final res = await _dio.post('/creator/posts', data: {
      'content': content,
      if (mediaUrls != null) 'media_urls': mediaUrls,
      if (parentPostId != null) 'parent_post_id': parentPostId,
      if (rootPostId != null) 'root_post_id': rootPostId,
      if (category != null) 'category': category,
      if (title != null) 'title': title,
      if (postType != null) 'post_type': postType,
      if (visibility != null) 'visibility': visibility,
    });
    return CreatorPost.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<void> deletePost(String postId) async {
    await _dio.delete('/creator/posts/$postId');
  }

  Future<bool> toggleLike(String postId) async {
    final res = await _dio.post('/creator/posts/$postId/like');
    final m = (res.data as Map).cast<String, dynamic>();
    return m['liked'] == true;
  }

  Future<bool> toggleRepost(String postId) async {
    final res = await _dio.post('/creator/posts/$postId/repost');
    final m = (res.data as Map).cast<String, dynamic>();
    return m['reposted'] == true;
  }

  Future<void> markAcceptedAnswer(String postId, String answerId) async {
    await _dio.post('/creator/posts/$postId/accept-answer', data: {
      'answer_id': answerId,
    });
  }

  // ── Profiles & Follows ───────────────────────────────────────────────────

  Future<CreatorProfile> getUserProfile(String targetUserId) async {
    final res = await _dio.get('/creator/profile/$targetUserId');
    return CreatorProfile.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<bool> toggleFollow(String targetUserId) async {
    final res = await _dio.post('/creator/users/$targetUserId/follow');
    final m = (res.data as Map).cast<String, dynamic>();
    return m['following'] == true;
  }

  Future<List<CreatorProfile>> getFollowers(String targetUserId, {String? cursor, int? limit}) async {
    final res = await _dio.get(
      '/creator/users/$targetUserId/followers',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        if (limit != null) 'limit': limit,
      },
    );
    final list = res.data as List<dynamic>;
    return list.map((item) => CreatorProfile.fromJson((item as Map).cast<String, dynamic>())).toList();
  }

  Future<List<CreatorProfile>> getFollowing(String targetUserId, {String? cursor, int? limit}) async {
    final res = await _dio.get(
      '/creator/users/$targetUserId/following',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        if (limit != null) 'limit': limit,
      },
    );
    final list = res.data as List<dynamic>;
    return list.map((item) => CreatorProfile.fromJson((item as Map).cast<String, dynamic>())).toList();
  }

  // ── Feeds & Queries ──────────────────────────────────────────────────────

  Future<CreatorPost> getPost(String postId) async {
    final res = await _dio.get('/creator/posts/$postId');
    return CreatorPost.fromJson((res.data as Map).cast<String, dynamic>());
  }

  Future<List<CreatorPost>> getFeed({String? cursor, int? limit}) async {
    final res = await _dio.get(
      '/creator/feed',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        if (limit != null) 'limit': limit,
      },
    );
    final list = res.data as List<dynamic>;
    return list.map((item) => CreatorPost.fromJson((item as Map).cast<String, dynamic>())).toList();
  }

  Future<List<CreatorPost>> getReplies(String postId) async {
    final res = await _dio.get('/creator/posts/$postId/replies');
    final list = res.data as List<dynamic>;
    return list.map((item) => CreatorPost.fromJson((item as Map).cast<String, dynamic>())).toList();
  }

  Future<List<CreatorPost>> getUserPosts(String targetUserId, {String? cursor, int? limit}) async {
    final res = await _dio.get(
      '/creator/users/$targetUserId/posts',
      queryParameters: {
        if (cursor != null) 'cursor': cursor,
        if (limit != null) 'limit': limit,
      },
    );
    final list = res.data as List<dynamic>;
    return list.map((item) => CreatorPost.fromJson((item as Map).cast<String, dynamic>())).toList();
  }

  Future<List<CreatorPost>> searchPosts(String query, {String? category, String? cursor, int? limit}) async {
    final res = await _dio.get(
      '/creator/search',
      queryParameters: {
        'q': query,
        if (category != null) 'category': category,
        if (cursor != null) 'cursor': cursor,
        if (limit != null) 'limit': limit,
      },
    );
    final list = res.data as List<dynamic>;
    return list.map((item) => CreatorPost.fromJson((item as Map).cast<String, dynamic>())).toList();
  }

  // ── Presigned Media Upload URL ───────────────────────────────────────────

  Future<Map<String, String>> generateUploadUrl({
    required String filename,
    required String contentType,
  }) async {
    final res = await _dio.post('/creator/media/upload-url', data: {
      'filename': filename,
      'content_type': contentType,
    });
    final m = (res.data as Map).cast<String, String>();
    return m;
  }
}

final creatorRepositoryProvider = Provider<CreatorRepository>((ref) {
  return CreatorRepository(ref.watch(dioProvider));
});
