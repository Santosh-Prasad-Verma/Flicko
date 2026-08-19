import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:mobile/data/clients/dio_client.dart';

enum CallSignal { ring, accept, decline, cancel, connected, end }

class CallSignalPayload {
  final CallSignal signal;
  final String callerId;
  final String callerName;
  final String? callerAvatarUrl;
  final String calleeId;
  final String callType;
  final String roomName;

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

final callSignalingServiceProvider = Provider<CallSignalingService>((ref) {
  return CallSignalingService(ref.watch(dioProvider));
});

class CallSignalingService {
  final Dio _dio;
  String? _myUserId;

  final _signalController = StreamController<CallSignalPayload>.broadcast();
  Stream<CallSignalPayload> get onSignal => _signalController.stream;

  CallSignalingService(this._dio);

  Future<void> initialize(String myUserId) async {
    _myUserId = myUserId;
    debugPrint('[CallSignal] Initialized signaling service for $_myUserId');
  }

  Future<void> sendSignal(CallSignalPayload signal) async {
    try {
      await _dio.post('/api/v1/calls/signal', data: signal.toJson());
      debugPrint('[CallSignal] Sent ${signal.signal.name} to ${signal.calleeId}');
    } catch (e) {
      debugPrint('[CallSignal] Error sending signal via REST API: $e');
    }
  }

  static String roomNameForDM(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return 'dm_call_${ids[0]}_${ids[1]}_${DateTime.now().millisecondsSinceEpoch}';
  }

  void dispose() {
    _signalController.close();
  }
}
