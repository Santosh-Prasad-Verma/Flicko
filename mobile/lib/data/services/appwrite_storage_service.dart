import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/data/clients/appwrite_client.dart';

final appwriteStorageServiceProvider = Provider<AppwriteStorageService>((ref) {
  return AppwriteStorageService(
    ref.watch(appwriteStorageProvider),
    AppConfig.appwriteBucketId,
  );
});

/// Storage Service using Appwrite
class AppwriteStorageService {
  final Storage _storage;
  final String _bucketId;

  AppwriteStorageService(this._storage, this._bucketId);

  Future<Map<String, String>> uploadImage(File file) async {
    try {
      final fileId = ID.unique();
      
      await _storage.createFile(
        bucketId: _bucketId,
        fileId: fileId,
        file: InputFile.fromPath(path: file.path),
        permissions: [
          Permission.read(Role.any()),
          Permission.write(Role.any()),
        ],
      );

      // Construct public view URL
      // Appwrite self-hosted/cloud public URL format:
      // [endpoint]/storage/buckets/[bucketId]/files/[fileId]/view?project=[projectId]
      return {
        'url': '${AppConfig.appwritePublicEndpoint}/storage/buckets/$_bucketId/files/$fileId/view?project=${AppConfig.appwriteProjectId}',
        'fileId': fileId,
        'bucketId': _bucketId,
      };
    } catch (e) {
      debugPrint('Appwrite Upload error: $e');
      throw Exception('Upload error: $e');
    }
  }

  Future<Map<String, String>> uploadAttachment(File file, String userId, String channelId) async {
    try {
      final fileId = ID.unique();
      
      await _storage.createFile(
        bucketId: _bucketId,
        fileId: fileId,
        file: InputFile.fromPath(path: file.path),
        permissions: [
          Permission.read(Role.any()),
          Permission.write(Role.any()),
        ],
      );
      
      return {
        'url': '${AppConfig.appwritePublicEndpoint}/storage/buckets/$_bucketId/files/$fileId/view?project=${AppConfig.appwriteProjectId}',
        'fileId': fileId,
        'bucketId': _bucketId,
      };
    } catch (e) {
      debugPrint('Appwrite Attachment upload error: $e');
      throw Exception('Attachment upload error: $e');
    }
  }

  Future<void> deleteImage(String fileUrl) async {
    try {
      // Extract fileId from the URL if possible
      // Example: .../files/FILE_ID/view?project=...
      final uri = Uri.parse(fileUrl);
      final segments = uri.pathSegments;
      final fileIndex = segments.indexOf('files');
      
      if (fileIndex != -1 && fileIndex + 1 < segments.length) {
        final fileId = segments[fileIndex + 1];
        await _storage.deleteFile(
          bucketId: _bucketId,
          fileId: fileId,
        );
      }
    } catch (e) {
      debugPrint('Appwrite Delete error: $e');
    }
  }

  bool get isConfigured => AppConfig.appwriteProjectId.isNotEmpty && AppConfig.appwriteBucketId.isNotEmpty;
}
