import 'dart:io';
import 'package:appwrite/appwrite.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/environment.dart';

class AppwriteStorageService {
  final Storage _storage;

  AppwriteStorageService(Client client) : _storage = Storage(client);

  /// Default bucket id, could also be pulled from Environment if configured
  static const String bucketId = 'attachments';

  Future<String> uploadAttachment(File file, String userId, String channelId) async {
    final fileName = '${userId}_${DateTime.now().millisecondsSinceEpoch}';
    
    try {
      final result = await _storage.createFile(
        bucketId: bucketId,
        fileId: ID.unique(),
        file: InputFile.fromPath(path: file.path, filename: fileName),
      );
      
      // Get the preview/view URL from the created file.
      // E.g. https://<ENDPOINT>/v1/storage/buckets/<BUCKET_ID>/files/<FILE_ID>/view?project=<PROJECT_ID>
      final String fileUrl = '${Environment.appwritePublicEndpoint}/storage/buckets/$bucketId/files/${result.$id}/view?project=${Environment.appwriteProjectId}';
      
      return fileUrl;
    } catch (e) {
      rethrow;
    }
  }
}

final appwriteClientProvider = Provider<Client>((ref) {
  final client = Client()
    ..setEndpoint(Environment.appwritePublicEndpoint)
    ..setProject(Environment.appwriteProjectId);
  return client;
});

final appwriteStorageServiceProvider = Provider<AppwriteStorageService>((ref) {
  return AppwriteStorageService(ref.watch(appwriteClientProvider));
});
