import 'dart:io';
import 'package:dio/dio.dart';
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
    return null;
  }

  Future<bool> deleteBackground(String channelId) async {
    try {
      final dio = _getDio();
      final response = await dio.delete('channels/$channelId/background');
      return response.statusCode == 204;
    } catch (_) {}
    return false;
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
