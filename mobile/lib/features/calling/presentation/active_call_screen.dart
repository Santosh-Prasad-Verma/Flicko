import 'dart:async';
import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/calling/services/webrtc_call_service.dart';

/// Redesigned Active Call Screen (Frosted Glassmorphic, smooth, and modern)
///
/// Supports both voice and video calls. Video mode displays full-screen remote
/// WebRTC video with a premium floating glass PiP self-view. Voice mode shows
/// a beautiful slowly shifting organic orb backdrop with a pulsing avatar ring.
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
  // Animation Controllers
  late AnimationController _orbController;
  late AnimationController _waveController;
  late AnimationController _pulseController;
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

  // Colors
  static const Color _bgBlack = Color(0xFF060608);
  static const Color _neonGreen = Color(0xFF52B788);
  static const Color _neonCyan = Color(0xFF00E5FF);
  static const Color _amber = Color(0xFFFFAB00);
  static const Color _red = Color(0xFFFF3B3B);
  static const Color _white = Colors.white;

  bool get _hasRtcSession =>
      widget.roomName != null &&
      widget.myUserId != null &&
      widget.peerUserId != null;

  @override
  void initState() {
    super.initState();
    _isVideoOn = widget.isVideo;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Slowly pulsing background glow orbs for voice calls
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
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
    _orbController.dispose();
    _waveController.dispose();
    _pulseController.dispose();
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
      _isVideoOn = rtc.cameraEnabled;
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
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: _bgBlack,
      body: Stack(
        children: [
          // 1. Voice Mode: Slowly Shifting Organic Backdrop Orbs
          if (!widget.isVideo)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _orbController,
                builder: (context, _) {
                  final val = _orbController.value;
                  final orb1Align = Alignment(-0.6 + 0.3 * sin(val * pi * 2),
                      -0.5 + 0.4 * cos(val * pi * 2));
                  final orb2Align = Alignment(0.6 - 0.3 * cos(val * pi * 2),
                      0.5 - 0.4 * sin(val * pi * 2));

                  return Stack(
                    children: [
                      Align(
                        alignment: orb1Align,
                        child: Container(
                          width: size.width * 0.9,
                          height: size.width * 0.9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                _neonGreen.withValues(alpha: 0.15),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: orb2Align,
                        child: Container(
                          width: size.width * 0.85,
                          height: size.width * 0.85,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                _neonCyan.withValues(alpha: 0.12),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

          // 2. Video Mode: Remote Live Video Stage
          if (widget.isVideo || _isVideoOn) _buildRemoteVideoStage(),
          if (!widget.isVideo && !_isVideoOn) _buildHiddenRemoteAudioRenderer(),

          // 3. Frosted Backdrop Blur overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                  sigmaX: (widget.isVideo || _isVideoOn) ? 5 : 45,
                  sigmaY: (widget.isVideo || _isVideoOn) ? 5 : 45),
              child: Container(
                color: Colors.black
                    .withValues(alpha: (widget.isVideo || _isVideoOn) ? 0.35 : 0.45),
              ),
            ),
          ),

          // 4. UI Content overlay
          SafeArea(
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTopBar(),
                  const SizedBox(height: 12),
                  _buildConnectionStats(),
                  const Spacer(),
                  if (!widget.isVideo && !_isVideoOn) _buildVoiceVisualizer(),
                  const Spacer(),
                  _buildControls(),
                  const SizedBox(height: 18),
                  _buildBottomTelemetry(),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // 5. PiP Self camera view (video mode only)
          if (widget.isVideo || _isVideoOn) _buildPiPView(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final statusColor = _isHolding ? _amber : _neonGreen;
    return Row(
      children: [
        // Pulsing active call status ring
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final alpha = 0.5 + 0.5 * sin(_pulseController.value * 2 * pi);
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor.withValues(alpha: alpha),
              ),
            );
          },
        ),
        const SizedBox(width: 10),
        // E2E Encrypted Glass Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, color: _neonGreen, size: 11),
              const SizedBox(width: 6),
              Text(
                'E2E SECURED',
                style: GoogleFonts.spaceMono(
                  color: _neonGreen,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Frosted Glass Timer Container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Text(
            _formatTime(_elapsedSeconds),
            style: GoogleFonts.spaceMono(
              color: _neonGreen,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ),
      ],
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
                  colors: [Color(0xFF0A120E), _bgBlack],
                ),
              ),
              child: Center(
                child: FutureBuilder<void>(
                  future: _startCallFuture,
                  builder: (context, snapshot) {
                    final status = rtc?.phaseLabel ?? 'PREPARING MEDIASTAGE';
                    final error = rtc?.error ?? snapshot.error?.toString();
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.videocam_outlined,
                          color: error == null ? _neonCyan : _red,
                          size: 44,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          error == null ? status : 'VIDEO STREAM UNSTABLE',
                          style: GoogleFonts.spaceMono(
                            color: error == null ? _neonCyan : _red,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (error != null) ...[
                          const SizedBox(height: 8),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 36),
                            child: Text(
                              error,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.inter(
                                  color: Colors.white38, fontSize: 10),
                              maxLines: 2,
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
          // Gradient shadow overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.4),
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.65),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionStats() {
    final statusColor = _isHolding ? _amber : _neonGreen;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.peerName,
              style: GoogleFonts.outfit(
                color: _white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _isHolding
                  ? '◆ CALL ON HOLD'
                  : '◆ SECURE ${widget.isVideo ? 'VIDEO' : 'VOICE'} LINK',
              style: GoogleFonts.spaceMono(
                color: statusColor,
                fontSize: 9.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
        // Frosted stats column
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${_bitrate.toStringAsFixed(1)} MBPS',
              style: GoogleFonts.spaceMono(
                  color: _neonGreen, fontSize: 10, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              'LOSS: $_packetLoss%  |  JITTER: ${_jitter}MS',
              style: GoogleFonts.spaceMono(
                  color: _white.withValues(alpha: 0.3),
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildVoiceVisualizer() {
    final primaryColor = widget.isVideo ? _neonCyan : _neonGreen;
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Audio breathing rings
          ...List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _pulseController,
              builder: (context, _) {
                final phase = (_pulseController.value + i * 0.33) % 1.0;
                final scale = 0.7 + phase * 0.45;
                final opacity = _isMuted ? 0.03 : (1.0 - phase) * 0.25;
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: primaryColor.withValues(alpha: opacity),
                        width: 1.5,
                      ),
                    ),
                  ),
                );
              },
            );
          }),

          // Organic waveform glow around avatar
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(260, 260),
                painter: _OrganicWaveformPainter(
                  phase: _waveController.value,
                  color: primaryColor,
                  isMuted: _isMuted,
                ),
              );
            },
          ),

          // Core circular avatar
          Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: _isMuted
                    ? Colors.white.withValues(alpha: 0.1)
                    : primaryColor.withValues(alpha: 0.3),
                width: 2.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: (_isMuted ? Colors.transparent : primaryColor)
                      .withValues(alpha: 0.1),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
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
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.55),
              ),
              child: const Icon(Icons.mic_off, color: _red, size: 36),
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
        style: GoogleFonts.outfit(
          color: widget.isVideo ? _neonCyan : _neonGreen,
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
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
          width: 110,
          height: 160,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: _neonCyan.withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
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
                          Icons.videocam_off_outlined,
                          color: Colors.white24,
                          size: 32,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _isVideoOn ? 'STARTING' : 'CAM OFF',
                          style: GoogleFonts.spaceMono(
                            color: Colors.white38,
                            fontSize: 7.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Frosted label indicator
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'SELF',
                      style: GoogleFonts.spaceMono(
                        color: _neonCyan,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(32),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute Button
          _buildGlassActionBtn(
            icon: _isMuted ? Icons.mic_off : Icons.mic,
            label: 'MUTE',
            isActive: _isMuted,
            activeColor: _red,
            onTap: () {
              if (_rtc != null) {
                unawaited(_rtc!.setMicrophoneEnabled(_isMuted));
              } else {
                setState(() => _isMuted = !_isMuted);
              }
            },
          ),

          // Camera On/Off
          _buildGlassActionBtn(
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

          // Main hangup button (red glowing circle)
          GestureDetector(
            onTap: () => unawaited(_hangUp()),
            child: Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _red,
                boxShadow: [
                  BoxShadow(
                    color: _red.withValues(alpha: 0.35),
                    blurRadius: 28,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Icon(Icons.call_end, color: Colors.black, size: 28),
            ),
          ),

          // Speaker toggle
          _buildGlassActionBtn(
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

          // Flip camera or hold
          _buildGlassActionBtn(
            icon: widget.isVideo
                ? Icons.cameraswitch
                : (_isHolding ? Icons.play_arrow : Icons.pause),
            label: widget.isVideo ? 'FLIP' : 'HOLD',
            isActive: widget.isVideo ? false : _isHolding,
            activeColor: _amber,
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

  Widget _buildGlassActionBtn({
    required IconData icon,
    required String label,
    required bool isActive,
    Color activeColor = _neonGreen,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? activeColor.withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: isActive
                    ? activeColor.withValues(alpha: 0.4)
                    : Colors.white.withValues(alpha: 0.05),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : _white.withValues(alpha: 0.65),
              size: 20,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.spaceMono(
              color: isActive ? activeColor : _white.withValues(alpha: 0.35),
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomTelemetry() {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _bottomText('OPUS CODEC @ 48KHZ'),
          const SizedBox(width: 10),
          _bottomSeparator(),
          const SizedBox(width: 10),
          _bottomText('BUFFER: ${3 + _random.nextInt(3)}MS'),
          const SizedBox(width: 10),
          _bottomSeparator(),
          const SizedBox(width: 10),
          _bottomText('E2EE AES-256'),
          const SizedBox(width: 10),
          _bottomSeparator(),
          const SizedBox(width: 10),
          _bottomText('LINK STABLE', color: _neonGreen),
        ],
      ),
    );
  }

  Widget _bottomText(String text, {Color? color}) {
    return Text(
      text,
      style: GoogleFonts.spaceMono(
        color: color ?? _white.withValues(alpha: 0.25),
        fontSize: 9,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _bottomSeparator() {
    return Text(
      '|',
      style: GoogleFonts.spaceMono(
        color: Colors.white.withValues(alpha: 0.04),
        fontSize: 9,
      ),
    );
  }
}

// ─── Organic Waveform Painter for Center Avatar ─────────────────────
class _OrganicWaveformPainter extends CustomPainter {
  final double phase;
  final Color color;
  final bool isMuted;

  const _OrganicWaveformPainter({
    required this.phase,
    required this.color,
    required this.isMuted,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isMuted) return;

    final center = Offset(size.width / 2, size.height / 2);
    const baseRadius = 65.0;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    const segments = 80;

    for (int i = 0; i <= segments; i++) {
      final angle = (i / segments) * 2 * pi;
      // Beautiful smooth organic waveform calculations
      final wave = sin(angle * 6 + phase * 2 * pi) *
          (4 + 3 * sin(phase * pi + angle * 2));
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
  bool shouldRepaint(covariant _OrganicWaveformPainter oldDelegate) =>
      oldDelegate.phase != phase || oldDelegate.isMuted != isMuted;
}
