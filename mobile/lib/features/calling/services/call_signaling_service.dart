import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Call signal types exchanged between caller and callee.
enum CallSignal { ring, accept, decline, cancel, connected, end }

/// Payload for a call signal event.
class CallSignalPayload {
  final CallSignal signal;
  final String callerId;
  final String callerName;
  final String? callerAvatarUrl;
  final String calleeId;
  final String callType; // 'voice' or 'video'
  final String roomName; // WebRTC signaling room for accepted calls

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
///   Caller -> receives accept -> both users join the WebRTC signaling room
///   Caller -> receives decline -> shows missed call
class CallSignalingService {
  final SupabaseClient _supabase;
  static const Duration _subscribeTimeout = Duration(seconds: 8);

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

    await _incomingChannel?.unsubscribe();

    debugPrint('[CallSignal] Subscribing to incoming calls on call:$_myUserId');

    _incomingChannel = _supabase
        .channel(
          'call:$_myUserId',
          opts: const RealtimeChannelConfig(ack: true),
        )
        .onBroadcast(
          event: 'call_signal',
          callback: (payload) {
            try {
              final signal = CallSignalPayload.fromJson(payload);
              debugPrint(
                '[CallSignal] Received: ${signal.signal.name} from ${signal.callerName}',
              );
              _signalController.add(signal);
            } catch (e) {
              debugPrint('[CallSignal] Error parsing incoming signal: $e');
            }
          },
        );

    await _subscribeChannel(
      _incomingChannel!,
      label: 'incoming call:$_myUserId',
    );
  }

  /// Send a call signal to a recipient via their broadcast channel.
  Future<void> sendSignal(CallSignalPayload signal) async {
    final recipientChannel = _supabase.channel(
      'call:${signal.calleeId}',
      opts: const RealtimeChannelConfig(ack: true),
    );

    try {
      await _subscribeChannel(
        recipientChannel,
        label: 'outgoing call:${signal.calleeId}',
      );
      final response = await recipientChannel.sendBroadcastMessage(
        event: 'call_signal',
        payload: signal.toJson(),
      );
      if (response != ChannelResponse.ok) {
        throw StateError('Supabase broadcast failed: $response');
      }
      debugPrint(
        '[CallSignal] Sent ${signal.signal.name} to ${signal.calleeId}',
      );
    } catch (e) {
      debugPrint('[CallSignal] Error sending signal: $e');
    } finally {
      await Future.delayed(const Duration(milliseconds: 500));
      await recipientChannel.unsubscribe();
    }
  }

  Future<void> _subscribeChannel(
    RealtimeChannel channel, {
    required String label,
  }) async {
    final completer = Completer<void>();
    channel.subscribe((status, error) {
      debugPrint('[CallSignal] $label subscription status: $status');
      if (status == RealtimeSubscribeStatus.subscribed) {
        if (!completer.isCompleted) completer.complete();
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.closed ||
          status == RealtimeSubscribeStatus.timedOut) {
        if (!completer.isCompleted) {
          completer.completeError(
            StateError('$label subscription failed: $status ${error ?? ''}'),
          );
        }
      }
    });
    await completer.future.timeout(
      _subscribeTimeout,
      onTimeout: () {
        throw TimeoutException('$label subscription timed out');
      },
    );
  }

  /// Generate a unique WebRTC room name for a DM pair.
  static String roomNameForDM(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return 'dm_call_${ids[0]}_${ids[1]}_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Clean up subscriptions.
  void dispose() {
    _incomingChannel?.unsubscribe();
    _signalController.close();
  }
}
