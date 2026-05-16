import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:path/path.dart' as path;
import 'package:mobile/core/config/app_config.dart';

/// Appwrite Storage Service for image upload and management
/// 
/// Handles uploading images to Appwrite Storage buckets.
/// Used for profile avatars and banners.
class AppwriteStorageService {
  static final AppwriteStorageService instance = AppwriteStorageService();

  late final Client _client;
  late final Storage _storage;

  AppwriteStorageService() {
    _client = Client()
      ..setEndpoint(AppConfig.appwritePublicEndpoint)
      ..setProject(AppConfig.appwriteProjectId);
      // Removed setSelfSigned(status: true) unless it's a local development server without SSL
      
    _storage = Storage(_client);
  }

  /// Upload an image file to Appwrite storage bucket
  /// 
  /// [file] - The image file to upload
  /// Returns the secure URL of the uploaded image to be used for display
  Future<String> uploadImage(File file) async {
    try {
      final fileName = path.basename(file.path);
      
      // We use unique ID generation for the file ID
      final uploadedFile = await _storage.createFile(
        bucketId: AppConfig.appwriteBucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(path: file.path, filename: fileName),
      );

      // Return the file view URL. We assume the bucket is public string read-only.
      return '${AppConfig.appwritePublicEndpoint}/storage/buckets/${AppConfig.appwriteBucketId}/files/${uploadedFile.$id}/view?project=${AppConfig.appwriteProjectId}';
    } catch (e) {
      throw Exception('Appwrite upload error: $e');
    }
  }

  Future<String> uploadFile({
    required String bucketId,
    required String fileName,
    required List<int> fileBytes,
    String? mimeType,
  }) async {
    try {
      final uploadedFile = await _storage.createFile(
        bucketId: bucketId,
        fileId: ID.unique(),
        file: InputFile.fromBytes(
          bytes: fileBytes,
          filename: fileName,
          contentType: mimeType,
        ),
      );

      return '${AppConfig.appwritePublicEndpoint}/storage/buckets/$bucketId/files/${uploadedFile.$id}/view?project=${AppConfig.appwriteProjectId}';
    } catch (e) {
      throw Exception('Appwrite upload error: $e');
    }
  }

  /// Delete an image from Appwrite storage bucket
  /// 
  /// [fileId] - The ID of the file to delete (extracted from URL)
  Future<void> deleteImage(String fileId) async {
    try {
      await _storage.deleteFile(
        bucketId: AppConfig.appwriteBucketId,
        fileId: fileId,
      );
    } catch (e) {
      throw Exception('Appwrite delete error: $e');
    }
  }

  /// Check if Appwrite is properly configured
  bool get isConfigured {
    return AppConfig.appwriteProjectId.isNotEmpty &&
        AppConfig.appwritePublicEndpoint.isNotEmpty &&
        AppConfig.appwriteBucketId.isNotEmpty;
  }
}
