import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/calling/presentation/incoming_call_overlay.dart';

/// Call signal types exchanged between caller and callee.
enum CallSignal {
  ring,
  accept,
  decline,
  cancel,
  connected,
  end,
}

/// Payload for a call signal event.
class CallSignalPayload {
  final CallSignal signal;
  final String callerId;
  final String callerName;
  final String? callerAvatarUrl;
  final String calleeId;
  final String callType; // 'voice' or 'video'
  final String roomName; // LiveKit room for accepted calls

  CallSignalPayload({
    required this.signal,
    required this.callerId,
    required this.callerName,
    this.callerAvatarUrl,
    required this.calleeId,
    required this.callType,
    required this.roomName,
  });

  factory CallSignalPayload.fromJson(Map<String, dynamic> json) {
    return CallSignalPayload(
      signal: CallSignal.values.firstWhere((s) => s.name == json['signal']),
      callerId: json['caller_id'] as String,
      callerName: json['caller_name'] as String,
      callerAvatarUrl: json['caller_avatar_url'] as String?,
      calleeId: json['callee_id'] as String,
      callType: json['call_type'] as String? ?? 'voice',
      roomName: json['room_name'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'signal': signal.name,
        'caller_id': callerId,
        'caller_name': callerName,
        'caller_avatar_url': callerAvatarUrl,
        'callee_id': calleeId,
        'call_type': callType,
        'room_name': roomName,
      };
}

/// Provider for the [CallSignalingService] singleton.
final callSignalingServiceProvider = Provider<CallSignalingService>((ref) {
  final supabase = Supabase.instance.client;
  return CallSignalingService(supabase);
});

/// Call Signaling Service
///
/// Uses Supabase Realtime Broadcast to send call signals (ring, accept,
/// decline, cancel, end) between callers and callees over DM channels.
///
/// Each user subscribes to a broadcast channel named `call:${theirUserId}`
/// and listens for incoming call signals. Outgoing signals are sent to
/// `call:${recipientUserId}`.
///
/// Flow:
///   Caller -> send ring to callee's channel
///   Callee -> receives ring, shows IncomingCallScreen
///   Callee -> sends accept or decline
///   Caller -> receives accept -> joins LiveKit room
///   Caller -> receives decline -> shows missed call
class CallSignalingService {
  final SupabaseClient _supabase;

  RealtimeChannel? _incomingChannel;
  String? _myUserId;

  final _signalController = StreamController<CallSignalPayload>.broadcast();
  Stream<CallSignalPayload> get onSignal => _signalController.stream;

  CallSignalingService(this._supabase);

  /// Initialize the service for the given user. Starts listening for incoming
  /// call signals on `call:{myUserId}`.
  Future<void> initialize(String myUserId) async {
    _myUserId = myUserId;
    await _startListening();
  }

  Future<void> _startListening() async {
    if (_myUserId == null || _myUserId!.isEmpty) return;

    _incomingChannel?.unsubscribe();

    debugPrint('[CallSignal] Subscribing to incoming calls on call:$_myUserId');

    _incomingChannel = _supabase
        .channel('call:$_myUserId')
        .onBroadcast(
          event: 'call_signal',
          callback: (payload) {
            try {
              final data = payload as Map<String, dynamic>;
              final signal = CallSignalPayload.fromJson(data);
              debugPrint('[CallSignal] Received: ${signal.signal.name} from ${signal.callerName}');
              _signalController.add(signal);
            } catch (e) {
              debugPrint('[CallSignal] Error parsing incoming signal: $e');
            }
          },
        )
        .subscribe((status, _) {
          debugPrint('[CallSignal] Subscription status: $status');
        });
  }

  /// Send a call signal to a recipient via their broadcast channel.
  Future<void> sendSignal(CallSignalPayload signal) async {
    if (_supabase == null) return;

    final recipientChannel = _supabase.channel('call:${signal.calleeId}');

    try {
      await recipientChannel.subscribe();
      await recipientChannel.sendBroadcastMessage(
        event: 'call_signal',
        payload: signal.toJson(),
      );
      debugPrint('[CallSignal] Sent ${signal.signal.name} to ${signal.calleeId}');
    } catch (e) {
      debugPrint('[CallSignal] Error sending signal: $e');
    } finally {
      await recipientChannel.unsubscribe();
    }
  }

  /// Generate a deterministic LiveKit room name for a DM pair.
  static String roomNameForDM(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return 'dm_call_${ids[0]}_${ids[1]}';
  }

  /// Clean up subscriptions.
  void dispose() {
    _incomingChannel?.unsubscribe();
    _signalController.close();
  }
}
