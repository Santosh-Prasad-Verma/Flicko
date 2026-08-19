import 'package:dio/dio.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/app_config.dart';
import 'package:mobile/data/clients/dio_client.dart';

class VoiceConnectionInfo {
  const VoiceConnectionInfo({
    required this.token,
    required this.serverUrl,
    this.room,
    this.streamId,
  });

  final String token;
  final String serverUrl;
  final String? room;
  final String? streamId;
}

class VoiceRepository {
  final Dio _dio;

  VoiceRepository(this._dio);

  Future<VoiceConnectionInfo> fetchConnection(
    String channelId,
    String serverId, {
    bool video = false,
    bool screenShare = false,
    String? streamTitle,
  }) async {
    try {
      final response = await _dio.post(
        '/api/v1/voice/token',
        data: {
          'channelId': channelId,
          'serverId': serverId,
          'video': video,
          'screenShare': screenShare,
          if (streamTitle != null) 'streamTitle': streamTitle,
        },
      );

      if (response.statusCode == 200 && response.data != null) {
        final data = Map<String, dynamic>.from(response.data as Map);
        final token = data['token'] as String?;
        if (token != null && token.isNotEmpty) {
          final issuedUrl = (data['serverUrl'] as String?)?.trim();
          final resolvedUrl = (issuedUrl != null && issuedUrl.isNotEmpty) ? issuedUrl : AppConfig.livekitUrl;
          return VoiceConnectionInfo(
            token: token,
            serverUrl: resolvedUrl,
            room: data['room'] as String?,
            streamId: data['streamId'] as String?,
          );
        }
      }
    } catch (_) {}

    // Fallback token issue for local/offline dev
    return VoiceConnectionInfo(
      token: 'dev_voice_token_${DateTime.now().millisecondsSinceEpoch}',
      serverUrl: AppConfig.livekitUrl,
      room: 'channel_$channelId',
    );
  }

  Future<String> getAccessToken(String channelId, String serverId) async {
    final info = await fetchConnection(channelId, serverId);
    return info.token;
  }

  Future<Room> connect(String token, {RoomOptions? options, String? serverUrl}) async {
    final url = (serverUrl != null && serverUrl.isNotEmpty) ? serverUrl : AppConfig.livekitUrl;
    if (url.isEmpty) {
      AppConfig.requireLivekitUrl();
    }

    final room = Room(roomOptions: options ?? const RoomOptions());
    await room.connect(url, token);
    return room;
  }

  Future<void> syncPublishState(
    String channelId, {
    bool? isVideo,
    bool? isStreaming,
  }) async {
    try {
      await _dio.post('/api/v1/voice/state', data: {
        'channel_id': channelId,
        if (isVideo != null) 'is_video': isVideo,
        if (isStreaming != null) 'is_streaming': isStreaming,
      });
    } catch (_) {}
  }
}

final voiceRepositoryProvider = Provider<VoiceRepository>((ref) {
  return VoiceRepository(ref.watch(dioProvider));
});
