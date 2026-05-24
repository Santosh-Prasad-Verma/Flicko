import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/calling/services/webrtc_call_service.dart';
import 'call_theme.dart';

/// Active in-call screen with cyberpunk HUD.
///
/// Supports both voice and video calls. Video mode shows full-screen
/// remote video with PiP self-view. Voice mode shows animated
/// waveform visualizer around the avatar.
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

class _ActiveCallScreenState extends ConsumerState<ActiveCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _waveController;
  late AnimationController _pulseController;
  late AnimationController _tickerController;
  late Timer _timerTick;

  int _elapsedSeconds = 0;
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isVideoOn = false;
  bool _isHolding = false;
  bool _endingCall = false;
  WebRtcCallService? _rtc;
  Future<void>? _startCallFuture;
  double _bitrate = 4.2;
  int _packetLoss = 0;
  int _jitter = 2;
  final _random = Random();

  // PiP drag position
  Offset _pipOffset = const Offset(16, 100);

  bool get _hasRtcSession =>
      widget.roomName != null &&
      widget.myUserId != null &&
      widget.peerUserId != null;

  @override
  void initState() {
    super.initState();
    _isVideoOn = widget.isVideo;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();

    if (_hasRtcSession) {
      _rtc = ref.read(webRtcCallServiceProvider);
      _rtc!.addListener(_handleRtcUpdate);
      _isSpeaker = _rtc!.speakerEnabled;
      _startCallFuture = _rtc!.startCall(
        roomName: widget.roomName!,
        myUserId: widget.myUserId!,
        peerUserId: widget.peerUserId!,
        isCaller: widget.isCaller,
        videoEnabled: widget.isVideo,
      );
    }

    _timerTick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedSeconds++;
        _bitrate = 3.5 + _random.nextDouble() * 1.5;
        _packetLoss = _random.nextInt(3);
        _jitter = 1 + _random.nextInt(5);
      });
    });
  }

  @override
  void dispose() {
    _rtc?.removeListener(_handleRtcUpdate);
    if (_hasRtcSession && !_endingCall) {
      unawaited(_rtc?.endCall(notifyPeer: true));
    }
    _waveController.dispose();
    _pulseController.dispose();
    _tickerController.dispose();
    _timerTick.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _handleRtcUpdate() {
    final rtc = _rtc;
    if (!mounted || rtc == null) return;
    setState(() {
      _isMuted = rtc.isMuted;
      _isSpeaker = rtc.speakerEnabled;
      _isVideoOn = widget.isVideo && rtc.cameraEnabled;
    });
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

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CallTheme.bg,
      body: Stack(
        children: [
          CustomPaint(
            size: MediaQuery.of(context).size,
            painter: GridPainter(),
          ),
          if (widget.isVideo) _buildRemoteVideoStage(),
          if (!widget.isVideo) _buildHiddenRemoteAudioRenderer(),
          // Main content
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const SizedBox(height: 8),
                _buildConnectionStats(),
                const Spacer(),
                if (!widget.isVideo) _buildVoiceVisualizer(),
                const Spacer(),
                _buildControls(),
                const SizedBox(height: 16),
                _buildBottomTelemetry(),
                const SizedBox(height: 8),
              ],
            ),
          ),
          // PiP self-view (video mode only)
          if (widget.isVideo) _buildPiPView(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Status indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, _) {
              final alpha = 0.5 + 0.5 * sin(_pulseController.value * 2 * pi);
              return Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isHolding
                      ? CallTheme.amber.withValues(alpha: alpha)
                      : CallTheme.neonGreen.withValues(alpha: alpha),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          // Encrypted badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              border: Border.all(
                color: CallTheme.neonGreen.withValues(alpha: 0.4),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, color: CallTheme.neonGreen, size: 10),
                const SizedBox(width: 4),
                Text(
                  'E2E ENCRYPTED',
                  style: CallTheme.monoLabel(
                    color: CallTheme.neonGreen,
                    size: 8,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: CallTheme.neonGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: CallTheme.neonGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              _formatTime(_elapsedSeconds),
              style: GoogleFonts.jetBrainsMono(
                color: CallTheme.neonGreen,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRemoteVideoStage() {
    final rtc = _rtc;
    final showRemote = rtc != null && rtc.renderersReady && rtc.hasRemoteVideo;

    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (showRemote)
            RTCVideoView(
              rtc.remoteRenderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
            )
          else
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF07100C), CallTheme.bg],
                ),
              ),
              child: Center(
                child: FutureBuilder<void>(
                  future: _startCallFuture,
                  builder: (context, snapshot) {
                    final status = rtc?.phaseLabel ?? 'PREPARING MEDIA';
                    final error = rtc?.error ?? snapshot.error?.toString();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.videocam_outlined,
                          color: error == null
                              ? CallTheme.neonGreen
                              : CallTheme.red,
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          error == null ? status : 'VIDEO LINK FAILED',
                          style: CallTheme.monoLabel(
                            color: error == null
                                ? CallTheme.neonGreen
                                : CallTheme.red,
                            size: 13,
                            weight: FontWeight.w700,
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 36),
                            child: Text(
                              error,
                              textAlign: TextAlign.center,
                              style: CallTheme.monoLabel(size: 10),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.30),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.70),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.peerName.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  color: CallTheme.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _isHolding
                    ? '◆ ON HOLD'
                    : '◆ ${widget.isVideo ? 'VIDEO' : 'VOICE'} ACTIVE',
                style: CallTheme.monoLabel(
                  color: _isHolding ? CallTheme.amber : CallTheme.neonGreen,
                  size: 10,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CallTheme.techLabel(
                '${_bitrate.toStringAsFixed(1)} MBPS',
                color: CallTheme.neonGreen,
              ),
              CallTheme.techLabel('LOSS: $_packetLoss%'),
              CallTheme.techLabel('JITTER: ${_jitter}MS'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVoiceVisualizer() {
    return SizedBox(
      width: 280,
      height: 280,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Audio wave rings
          ...List.generate(4, (i) {
            return AnimatedBuilder(
              animation: _waveController,
              builder: (context, _) {
                final phase = (_waveController.value + i * 0.25) % 1.0;
                final scale = 0.6 + phase * 0.5;
                final opacity = _isMuted ? 0.05 : (1.0 - phase) * 0.25;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: CallTheme.neonGreen.withValues(alpha: opacity),
                        width: 1.5,
                      ),
                    ),
                  ),
                );
              },
            );
          }),
          // Waveform bars
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(280, 280),
                painter: _WaveformPainter(
                  phase: _waveController.value,
                  color: CallTheme.neonGreen,
                  isMuted: _isMuted,
                ),
              );
            },
          ),
          // Center avatar
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CallTheme.surfaceDark,
              border: Border.all(
                color: _isMuted ? CallTheme.textDim : CallTheme.neonGreen,
                width: 2,
              ),
            ),
            child: widget.peerAvatarUrl != null
                ? ClipOval(
                    child: Image.network(
                      widget.peerAvatarUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => _avatarFallback(),
                    ),
                  )
                : _avatarFallback(),
          ),
          // Muted overlay
          if (_isMuted)
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CallTheme.bg.withValues(alpha: 0.6),
              ),
              child: const Icon(Icons.mic_off, color: CallTheme.red, size: 36),
            ),
        ],
      ),
    );
  }

  Widget _buildHiddenRemoteAudioRenderer() {
    final rtc = _rtc;
    if (rtc == null || !rtc.renderersReady) return const SizedBox.shrink();

    return Positioned(
      left: 0,
      top: 0,
      width: 1,
      height: 1,
      child: IgnorePointer(
        child: Opacity(opacity: 0.01, child: RTCVideoView(rtc.remoteRenderer)),
      ),
    );
  }

  Widget _avatarFallback() {
    return Center(
      child: Text(
        widget.peerName.isNotEmpty ? widget.peerName[0].toUpperCase() : '?',
        style: CallTheme.heading(size: 40),
      ),
    );
  }

  Widget _buildPiPView() {
    return Positioned(
      right: _pipOffset.dx,
      top: _pipOffset.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _pipOffset = Offset(
              _pipOffset.dx - details.delta.dx,
              _pipOffset.dy + details.delta.dy,
            );
          });
        },
        child: Container(
          width: 120,
          height: 170,
          decoration: BoxDecoration(
            color: CallTheme.surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: CallTheme.neonGreen, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: CallTheme.bg.withValues(alpha: 0.8),
                blurRadius: 20,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                if (_rtc != null &&
                    _rtc!.renderersReady &&
                    _rtc!.hasLocalVideo &&
                    _isVideoOn)
                  Positioned.fill(
                    child: RTCVideoView(
                      _rtc!.localRenderer,
                      mirror: true,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    ),
                  )
                else
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.person,
                          color: CallTheme.textDim,
                          size: 40,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _isVideoOn ? 'STARTING' : 'CAM OFF',
                          style: CallTheme.monoLabel(
                            size: 8,
                            weight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                // HUD label
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    color: CallTheme.bg.withValues(alpha: 0.7),
                    child: Text(
                      'LOCAL',
                      style: CallTheme.monoLabel(
                        color: CallTheme.neonGreen,
                        size: 7,
                        weight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          CallTheme.actionButton(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            label: _isMuted ? 'UNMUTE' : 'MUTE',
            isActive: _isMuted,
            activeColor: CallTheme.red,
            onTap: () {
              if (_rtc != null) {
                unawaited(_rtc!.setMicrophoneEnabled(_isMuted));
              } else {
                setState(() => _isMuted = !_isMuted);
              }
            },
          ),
          CallTheme.actionButton(
            icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
            label: 'VIDEO',
            isActive: _isVideoOn,
            onTap: () {
              if (_rtc != null) {
                unawaited(_rtc!.setCameraEnabled(!_isVideoOn));
              } else {
                setState(() => _isVideoOn = !_isVideoOn);
              }
            },
          ),
          // Hang up
          GestureDetector(
            onTap: () => unawaited(_hangUp()),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: CallTheme.red,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: CallTheme.red.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.call_end,
                    color: CallTheme.white,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'END',
                  style: CallTheme.monoLabel(
                    color: CallTheme.red,
                    size: 8,
                    weight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          CallTheme.actionButton(
            icon: _isSpeaker ? Icons.volume_up : Icons.volume_down,
            label: 'SPEAKER',
            isActive: _isSpeaker,
            onTap: () {
              if (_rtc != null) {
                unawaited(_rtc!.setSpeakerEnabled(!_isSpeaker));
              } else {
                setState(() => _isSpeaker = !_isSpeaker);
              }
            },
          ),
          CallTheme.actionButton(
            icon: widget.isVideo
                ? Icons.cameraswitch
                : (_isHolding ? Icons.play_arrow : Icons.pause),
            label: widget.isVideo ? 'FLIP' : (_isHolding ? 'RESUME' : 'HOLD'),
            isActive: widget.isVideo ? false : _isHolding,
            activeColor: CallTheme.amber,
            onTap: () {
              if (widget.isVideo && _rtc != null) {
                unawaited(_rtc!.switchCamera());
              } else {
                setState(() => _isHolding = !_isHolding);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTelemetry() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CallTheme.bottomStat('OPUS @ 48KHZ'),
          CallTheme.bottomSeparator(),
          CallTheme.bottomStat('BUF: ${2 + _random.nextInt(3)}MS'),
          CallTheme.bottomSeparator(),
          CallTheme.bottomStat('E2E: 256-BIT'),
          CallTheme.bottomSeparator(),
          CallTheme.bottomStat('LINK: STABLE', color: CallTheme.neonGreen),
        ],
      ),
    );
  }
}

// Waveform Painter
class _WaveformPainter extends CustomPainter {
  final double phase;
  final Color color;
  final bool isMuted;

  _WaveformPainter({
    required this.phase,
    required this.color,
    required this.isMuted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isMuted) return;

    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = 65.0;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw circular waveform
    final path = Path();
    const segments = 64;

    for (int i = 0; i <= segments; i++) {
      final angle = (i / segments) * 2 * pi;
      final wave =
          sin(angle * 8 + phase * 2 * pi) *
          (6 + 4 * sin(phase * 2 * pi + angle * 3));
      final r = baseRadius + wave;
      final x = center.dx + r * cos(angle);
      final y = center.dy + r * sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.isMuted != isMuted;
}
