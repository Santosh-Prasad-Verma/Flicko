import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:mime/mime.dart';
import 'package:logger/logger.dart';

class MediaProcessorService {
  static final _logger = Logger();

  /// Compresses an image and returns the compressed file
  static Future<File?> compressImage(File file, {int quality = 70}) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        format: CompressFormat.jpeg,
      );
      
      if (result == null) return null;
      return File(result.path);
    } catch (e) {
      _logger.e('Error compressing image: $e');
      return file; // Return original if compression fails
    }
  }

  /// Compresses a video and returns the compressed file
  static Future<File?> compressVideo(File file, {VideoQuality quality = VideoQuality.DefaultQuality}) async {
    try {
      final info = await VideoCompress.compressVideo(
        file.absolute.path,
        quality: quality,
        deleteOrigin: false,
      );
      
      if (info == null || info.file == null) return null;
      return info.file;
    } catch (e) {
      _logger.e('Error compressing video: $e');
      return file; // Return original if compression fails
    }
  }

  /// Smartly processes a file based on its mime type
  static Future<File> processMedia(File file) async {
    final mimeType = lookupMimeType(file.path);
    
    if (mimeType != null) {
      if (mimeType.startsWith('image/')) {
        // Skip compressing gifs to preserve animation
        if (mimeType == 'image/gif') return file;
        
        final compressed = await compressImage(file);
        if (compressed != null) {
          final originalSize = await file.length();
          final compressedSize = await compressed.length();
          _logger.i('Image compressed: ${originalSize / 1024}KB -> ${compressedSize / 1024}KB');
          return compressed;
        }
      } else if (mimeType.startsWith('video/')) {
        final compressed = await compressVideo(file);
        if (compressed != null) {
          final originalSize = await file.length();
          final compressedSize = await compressed.length();
          _logger.i('Video compressed: ${originalSize / 1024}KB -> ${compressedSize / 1024}KB');
          return compressed;
        }
      }
    }
    
    return file;
  }
  
  /// Cleans up temporary files generated during compression
  static Future<void> cleanup() async {
    try {
      await VideoCompress.deleteAllCache();
    } catch (e) {
      _logger.e('Error cleaning up media cache: $e');
    }
  }
}
