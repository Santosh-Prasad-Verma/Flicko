import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/calling/services/webrtc_call_service.dart';
import 'package:mobile/features/calling/presentation/flicko_call_screen.dart';

/// Redesigned Active Call Screen
///
/// Wraps WebRTC call state and delegates rendering to [DiscordCallScreen].
class ActiveCallScreen extends ConsumerStatefulWidget {
  final String peerName;
  final String? peerAvatarUrl;
  final bool isVideo;
  final String? roomName;
  final String? myUserId;
  final String? peerUserId;
  final bool isCaller;
  final VoidCallback? onHangUp;

  const ActiveCallScreen({
    super.key,
    required this.peerName,
    this.peerAvatarUrl,
    this.isVideo = false,
    this.roomName,
    this.myUserId,
    this.peerUserId,
    this.isCaller = false,
    this.onHangUp,
  });

  @override
  ConsumerState<ActiveCallScreen> createState() => _ActiveCallScreenState();
}

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen> {
  bool _endingCall = false;
  WebRtcCallService? _rtc;

  bool get _hasRtcSession =>
      widget.roomName != null &&
      widget.myUserId != null &&
      widget.peerUserId != null;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    if (_hasRtcSession) {
      _rtc = ref.read(webRtcCallServiceProvider);
      _rtc!.addListener(_handleRtcUpdate);
      _rtc!.startCall(
        roomName: widget.roomName!,
        myUserId: widget.myUserId!,
        peerUserId: widget.peerUserId!,
        isCaller: widget.isCaller,
        videoEnabled: widget.isVideo,
      );
    }
  }

  @override
  void dispose() {
    _rtc?.removeListener(_handleRtcUpdate);
    if (_hasRtcSession && !_endingCall) {
      unawaited(_rtc?.endCall(notifyPeer: true));
    }
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _handleRtcUpdate() {
    final rtc = _rtc;
    if (!mounted || rtc == null) return;
    if (!_endingCall && rtc.phase == WebRtcCallPhase.ended) {
      _endingCall = true;
      Navigator.of(context, rootNavigator: true).maybePop();
    }
  }

  Future<void> _hangUp() async {
    if (_endingCall) return;
    _endingCall = true;
    await _rtc?.endCall(notifyPeer: true);
    widget.onHangUp?.call();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlickoCallScreen(
      title: widget.roomName ?? widget.peerName,
      peerName: widget.peerName,
      peerAvatarUrl: widget.peerAvatarUrl,
      isVideoCall: widget.isVideo,
      onEndCall: () => unawaited(_hangUp()),
    );
  }
}
