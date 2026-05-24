import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/calling/presentation/incoming_call_overlay.dart';
import 'package:mobile/features/calling/services/call_signaling_service.dart';
import 'package:mobile/features/calling/services/webrtc_call_service.dart';

class CallSignalListener extends ConsumerStatefulWidget {
  final Widget child;

  const CallSignalListener({
    super.key,
    required this.child,
  });

  @override
  ConsumerState<CallSignalListener> createState() => _CallSignalListenerState();
}

class _CallSignalListenerState extends ConsumerState<CallSignalListener> {
  StreamSubscription<CallSignalPayload>? _signalSub;
  CallSignalingService? _signalingService;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_initialize);
  }

  @override
  void dispose() {
    _signalSub?.cancel();
    super.dispose();
  }

  Future<void> _initialize() async {
    final myUserId = ref.read(currentUserIdProvider);
    if (myUserId == null || myUserId.isEmpty) return;

    _myUserId = myUserId;
    _signalingService = ref.read(callSignalingServiceProvider);
    await _signalingService!.initialize(myUserId);
    _signalSub?.cancel();
    _signalSub = _signalingService!.onSignal.listen(_handleSignal);
  }

  String _currentUserName() {
    return ref.read(authNotifierProvider).maybeWhen(
          authenticated: (user, profile) =>
              profile?.displayName ??
              profile?.username ??
              user.email?.split('@').first ??
              'Flicko User',
          orElse: () => 'Flicko User',
        );
  }

  String? _currentUserAvatarUrl() {
    return ref.read(authNotifierProvider).maybeWhen(
          authenticated: (_, profile) => profile?.avatarUrl,
          orElse: () => null,
        );
  }

  Future<void> _sendSignal({
    required CallSignal signal,
    required String calleeId,
    required String callerId,
    required String roomName,
    required String callType,
    String? callerName,
    String? callerAvatarUrl,
  }) async {
    final service = _signalingService;
    if (service == null) return;
    await service.sendSignal(
      CallSignalPayload(
        signal: signal,
        callerId: callerId,
        callerName: callerName ?? _currentUserName(),
        callerAvatarUrl: callerAvatarUrl ?? _currentUserAvatarUrl(),
        calleeId: calleeId,
        callType: callType,
        roomName: roomName,
      ),
    );
  }

  void _handleSignal(CallSignalPayload signal) {
    if (!mounted || _myUserId == null) return;
    if (signal.callerId == _myUserId && signal.signal == CallSignal.ring) {
      return;
    }

    switch (signal.signal) {
      case CallSignal.ring:
        _showIncoming(signal);
        break;
      case CallSignal.accept:
        _showAcceptedAsCaller(signal);
        break;
      case CallSignal.decline:
        _dismissTopRoute();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${signal.callerName} declined the call')),
        );
        break;
      case CallSignal.cancel:
        _dismissTopRoute();
        break;
      case CallSignal.end:
        unawaited(
            ref.read(webRtcCallServiceProvider).endCall(notifyPeer: false));
        _dismissTopRoute();
        break;
      case CallSignal.connected:
        break;
    }
  }

  void _showIncoming(CallSignalPayload signal) {
    final isVideo = signal.callType == 'video';
    CallOverlay.showIncoming(
      context,
      callerName: signal.callerName,
      callerAvatarUrl: signal.callerAvatarUrl,
      callType: signal.callType,
      onAccept: () {
        unawaited(
          _sendSignal(
            signal: CallSignal.accept,
            calleeId: signal.callerId,
            callerId: _myUserId!,
            roomName: signal.roomName,
            callType: signal.callType,
          ),
        );
        CallOverlay.acceptCall(
          context,
          peerName: signal.callerName,
          peerAvatarUrl: signal.callerAvatarUrl,
          isVideo: isVideo,
          roomName: signal.roomName,
          myUserId: _myUserId!,
          peerUserId: signal.callerId,
          isCaller: false,
          onHangUp: () {
            unawaited(
              _sendSignal(
                signal: CallSignal.end,
                calleeId: signal.callerId,
                callerId: _myUserId!,
                roomName: signal.roomName,
                callType: signal.callType,
              ),
            );
          },
        );
      },
      onDecline: () {
        unawaited(
          _sendSignal(
            signal: CallSignal.decline,
            calleeId: signal.callerId,
            callerId: _myUserId!,
            roomName: signal.roomName,
            callType: signal.callType,
          ),
        );
      },
    );
  }

  void _showAcceptedAsCaller(CallSignalPayload signal) {
    CallOverlay.acceptCall(
      context,
      peerName: signal.callerName.isEmpty ? 'Friend' : signal.callerName,
      peerAvatarUrl: signal.callerAvatarUrl,
      isVideo: signal.callType == 'video',
      roomName: signal.roomName,
      myUserId: _myUserId!,
      peerUserId: signal.callerId,
      isCaller: true,
      onHangUp: () {
        unawaited(
          _sendSignal(
            signal: CallSignal.end,
            calleeId: signal.callerId,
            callerId: _myUserId!,
            roomName: signal.roomName,
            callType: signal.callType,
          ),
        );
      },
    );
  }

  void _dismissTopRoute() {
    final navigator = Navigator.of(context, rootNavigator: true);
    if (navigator.canPop()) {
      navigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
