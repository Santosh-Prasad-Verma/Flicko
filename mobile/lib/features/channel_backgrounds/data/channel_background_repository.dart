import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide MultipartFile;
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/features/channel_backgrounds/domain/channel_background.dart';

class ChannelBackgroundRepository {
  Dio _getDio() {
    return Dio(BaseOptions(
      baseUrl: AppConfig.apiBaseUrl.endsWith('/') ? AppConfig.apiBaseUrl : '${AppConfig.apiBaseUrl}/',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${Supabase.instance.client.auth.currentSession?.accessToken ?? ""}',
      },
    ));
  }

  Future<ChannelBackground?> fetchBackground(String channelId) async {
    try {
      final dio = _getDio();
      final response = await dio.get('channels/$channelId/background');
      if (response.statusCode == 200) {
        return ChannelBackground.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    // Check local fallback file
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localFile = File('${appDir.path}/channel_bg_$channelId.png');
      if (localFile.existsSync()) {
        return ChannelBackground(
          id: 'local_$channelId',
          channelId: channelId,
          serverId: '',
          fileIdOriginal: localFile.path,
          blurhash: '',
          widthPx: 1080,
          heightPx: 1920,
          bytesOriginal: localFile.lengthSync(),
          mimeType: 'image/png',
          sha256: '',
          dominantColor: '#000000',
          meanLuminance: 0.5,
          focalX: 0.5,
          focalY: 0.5,
          status: 'ready',
        );
      }
    } catch (_) {}
    return null;
  }

  Future<ChannelBackground?> uploadBackground(String channelId, String filePath) async {
    try {
      final dio = _getDio();
      final file = File(filePath);
      final filename = filePath.split('/').last;

      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(
          file.path,
          filename: filename,
        ),
      });

      final response = await dio.post(
        'channels/$channelId/background',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      if (response.statusCode == 200) {
        return ChannelBackground.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}

    // Fallback: Copy file locally
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localFile = File('${appDir.path}/channel_bg_$channelId.png');
      await File(filePath).copy(localFile.path);

      return ChannelBackground(
        id: 'local_$channelId',
        channelId: channelId,
        serverId: '',
        fileIdOriginal: localFile.path,
        blurhash: '',
        widthPx: 1080,
        heightPx: 1920,
        bytesOriginal: localFile.lengthSync(),
        mimeType: 'image/png',
        sha256: '',
        dominantColor: '#000000',
        meanLuminance: 0.5,
        focalX: 0.5,
        focalY: 0.5,
        status: 'ready',
      );
    } catch (e) {
      return null;
    }
  }

  Future<bool> deleteBackground(String channelId) async {
    try {
      final dio = _getDio();
      await dio.delete('channels/$channelId/background');
    } catch (_) {}
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final localFile = File('${appDir.path}/channel_bg_$channelId.png');
      if (localFile.existsSync()) {
        localFile.deleteSync();
      }
    } catch (_) {}
    return true;
  }

  Future<ChannelBackgroundUserOverride?> fetchOverride(String channelId) async {
    try {
      final dio = _getDio();
      final response = await dio.get('channels/$channelId/background/override');
      if (response.statusCode == 200) {
        return ChannelBackgroundUserOverride.fromJson(response.data as Map<String, dynamic>);
      }
    } catch (_) {}
    return null;
  }

  Future<bool> setOverride(String channelId, double opacity, bool enabled) async {
    try {
      final dio = _getDio();
      final response = await dio.put(
        'channels/$channelId/background/override',
        data: {
          'opacity': opacity,
          'enabled': enabled,
        },
      );
      return response.statusCode == 204;
    } catch (_) {}
    return false;
  }
}
