import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mobile/core/config/app_config.dart';

final livekitServiceProvider = Provider<LiveKitService>((ref) {
  return LiveKitService();
});

class LiveKitService {
  Room? _room;

  Room? get currentRoom => _room;

  Future<void> connect(String token, {RoomOptions? roomOptions, ConnectOptions? connectOptions}) async {
    final roomOps = roomOptions ?? const RoomOptions(
      adaptiveStream: true,
      dynacast: true,
    );

    final connOps = connectOptions ?? const ConnectOptions(
      autoSubscribe: true,
    );

    _room = Room(roomOptions: roomOps);

    await _room!.connect(
      AppConfig.livekitUrl,
      token,
      connectOptions: connOps,
    );
  }

  Future<void> disconnect() async {
    if (_room != null) {
      await _room!.disconnect();
      _room = null;
    }
  }
}
