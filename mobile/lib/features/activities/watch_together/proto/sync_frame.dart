import 'dart:typed_data';
import 'package:msgpack_dart/msgpack_dart.dart' as msgpack;

class SyncFrame {
  final int version;
  final String type; // "anchor" | "reaction" | "heartbeat"
  final String sessionId;
  final String hostId;
  final int positionMs;
  final bool playing;
  final double rate;
  final int wallClockMs;
  final int seq;

  SyncFrame({
    required this.version,
    required this.type,
    required this.sessionId,
    required this.hostId,
    required this.positionMs,
    required this.playing,
    required this.rate,
    required this.wallClockMs,
    required this.seq,
  });

  Map<String, dynamic> toMap() {
    return {
      'v': version,
      'type': type,
      'session_id': sessionId,
      'host_id': hostId,
      'position_ms': positionMs,
      'playing': playing,
      'rate': rate,
      'wall_clock_ms': wallClockMs,
      'seq': seq,
    };
  }

  factory SyncFrame.fromMap(Map<dynamic, dynamic> map) {
    return SyncFrame(
      version: map['v'] as int? ?? 1,
      type: map['type'] as String? ?? 'anchor',
      sessionId: map['session_id'] as String? ?? '',
      hostId: map['host_id'] as String? ?? '',
      positionMs: map['position_ms'] as int? ?? 0,
      playing: map['playing'] as bool? ?? false,
      rate: (map['rate'] as num? ?? 1.0).toDouble(),
      wallClockMs: map['wall_clock_ms'] as int? ?? 0,
      seq: map['seq'] as int? ?? 0,
    );
  }

  Uint8List toMsgpack() {
    final serialized = msgpack.serialize(toMap());
    return Uint8List.fromList(serialized);
  }

  factory SyncFrame.fromMsgpack(Uint8List bytes) {
    final deserialized = msgpack.deserialize(bytes);
    if (deserialized is Map) {
      return SyncFrame.fromMap(deserialized);
    }
    throw FormatException('Invalid Msgpack format for SyncFrame');
  }
}
