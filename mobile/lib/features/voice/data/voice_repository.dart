import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/config/app_config.dart';

/// What the voice-token endpoint hands back.
///
/// [serverUrl] is authoritative: it comes from the same service that signed
/// [token], so the two cannot point at different LiveKit deployments. The
/// compile-time `AppConfig.livekitUrl` is only a fallback for responses that
/// omit the field — trusting it by default allowed a build configured for
/// LiveKit Cloud to join a room whose token was signed by the self-hosted SFU,
/// leaving each participant alone in an identically-named room.
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
  final SupabaseClient _supabase;

  VoiceRepository(this._supabase);

  /// Fetches a LiveKit JWT and the URL of the server that signed it.
  ///
  /// [video] and [screenShare] must reflect what the user is about to publish:
  /// the edge function uses them to seed `voice_states.is_video` /
  /// `is_streaming` and to create the `streams` row. Other members' UI reads
  /// those columns rather than the LiveKit track list, so omitting them left
  /// remote clients with no indication that anyone was sharing. Toggles made
  /// after joining are pushed by [syncPublishState].
  Future<VoiceConnectionInfo> fetchConnection(
    String channelId,
    String serverId, {
    bool video = false,
    bool screenShare = false,
    String? streamTitle,
  }) async {
    final response = await _supabase.functions.invoke(
      'voice-token',
      body: {
        'channelId': channelId,
        'serverId': serverId,
        'video': video,
        'screenShare': screenShare,
        if (streamTitle != null) 'streamTitle': streamTitle,
      },
    );

    if (response.status != 200) {
      throw Exception('Failed to fetch LiveKit token: ${response.data}');
    }

    final data = Map<String, dynamic>.from(response.data as Map);
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw Exception('Voice token response contained no token');
    }

    final issuedUrl = (data['serverUrl'] as String?)?.trim();
    final resolvedUrl =
        (issuedUrl != null && issuedUrl.isNotEmpty) ? issuedUrl : AppConfig.livekitUrl;
    if (resolvedUrl.isEmpty) {
      AppConfig.requireLivekitUrl();
    }

    return VoiceConnectionInfo(
      token: token,
      serverUrl: resolvedUrl,
      room: data['room'] as String?,
      streamId: data['streamId'] as String?,
    );
  }

  /// Fetches only the token. Retained for callers that do not need the server
  /// URL; prefer [fetchConnection] so URL and token stay in agreement.
  Future<String> getAccessToken(String channelId, String serverId) async {
    final info = await fetchConnection(channelId, serverId);
    return info.token;
  }

  /// Connects to a LiveKit room.
  ///
  /// Pass [serverUrl] from [fetchConnection] so the connection lands on the
  /// server that signed the token. Throws [LivekitConfigurationException] when
  /// no URL is available from either source. This previously fell back to
  /// `ws://localhost:7880`, which only ever resolved on the developer's own
  /// machine — on a real device it produced an opaque connection timeout
  /// instead of naming the missing setting. A voice call has no useful degraded
  /// mode, so failing with an actionable message is better than dialing an
  /// address that cannot work.
  Future<Room> connect(String token, {RoomOptions? options, String? serverUrl}) async {
    final url = (serverUrl != null && serverUrl.isNotEmpty) ? serverUrl : AppConfig.livekitUrl;
    if (url.isEmpty) {
      AppConfig.requireLivekitUrl();
    }

    final room = Room(roomOptions: options ?? const RoomOptions());
    await room.connect(url, token);
    return room;
  }

  /// Mirrors what the local participant is publishing into `voice_states`.
  ///
  /// Remote UI (the "sharing screen" badge, camera indicators) reads these
  /// columns, so without this a camera or screen-share toggle changed only the
  /// publisher's own screen and no other member was told. Permitted by the
  /// "Manage own voice state" RLS policy (`user_id = auth.uid()`).
  ///
  /// Best-effort: a failure here must not tear down a working media session, so
  /// the error is swallowed and the LiveKit track stays as the source of truth
  /// for the publisher.
  Future<void> syncPublishState(
    String channelId, {
    bool? isVideo,
    bool? isStreaming,
  }) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || (isVideo == null && isStreaming == null)) return;

    try {
      await _supabase
          .from('voice_states')
          .update({
            if (isVideo != null) 'is_video': isVideo,
            if (isStreaming != null) 'is_streaming': isStreaming,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('user_id', userId)
          .eq('channel_id', channelId);
    } catch (_) {
      // Intentionally ignored — see doc comment.
    }
  }
}

final voiceRepositoryProvider = Provider<VoiceRepository>((ref) {
  return VoiceRepository(Supabase.instance.client);
});
