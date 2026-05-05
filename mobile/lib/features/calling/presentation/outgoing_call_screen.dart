import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'call_theme.dart';

/// Cyberpunk-styled outgoing call screen with radar sweep animation.
///
/// Shows a pulsing radar scanning for the callee, with live telemetry
/// and a "CONNECTING..." status that transitions to "RINGING..."
class OutgoingCallScreen extends StatefulWidget {
  final String calleeName;
  final String? calleeAvatarUrl;
  final String callType; // 'voice' or 'video'
  final VoidCallback? onCancel;
  final VoidCallback? onConnected;

  const OutgoingCallScreen({
    super.key,
    required this.calleeName,
    this.calleeAvatarUrl,
    this.callType = 'voice',
    this.onCancel,
    this.onConnected,
  });

  @override
  State<OutgoingCallScreen> createState() => _OutgoingCallScreenState();
}

class _OutgoingCallScreenState extends State<OutgoingCallScreen>
    with TickerProviderStateMixin {
  late AnimationController _radarController;
  late AnimationController _pulseController;
  late AnimationController _waveController;
  late AnimationController _tickerController;

  late Timer _statusTimer;
  int _ringCount = 0;
  String _statusText = 'INITIATING UPLINK';
  bool _isRinging = false;
  int _dotCount = 0;
  double _signalStrength = 0.0;



  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    _statusTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted) return;
      setState(() {
        _dotCount = (_dotCount + 1) % 4;
        _signalStrength = (_signalStrength + 0.02).clamp(0.0, 1.0);

        _ringCount++;
        if (_ringCount < 5) {
          _statusText = 'INITIATING UPLINK';
        } else if (_ringCount < 10) {
          _statusText = 'ROUTING SIGNAL';
        } else {
          _isRinging = true;
          _statusText = 'RINGING';
        }
      });
    });
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    _tickerController.dispose();
    _statusTimer.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
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
          _buildScanLine(),
          SafeArea(
            child: Column(
              children: [
                _buildTickerBar(),
                const SizedBox(height: 16),
                _buildTopStats(),
                const SizedBox(height: 20),
                // Call type badge
                _buildCallTypeBadge(),
                const SizedBox(height: 12),
                // Callee name
                Text(
                  widget.calleeName.toUpperCase(),
                  style: CallTheme.heading(size: 52),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                _buildStatusLine(),
                const SizedBox(height: 16),
                // Radar + Avatar
                Expanded(child: _buildRadarAvatar()),
                // Signal strength bar
                _buildSignalBar(),
                const SizedBox(height: 20),
                _buildActions(),
                const SizedBox(height: 16),
                _buildBottomBar(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanLine() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final h = MediaQuery.of(context).size.height;
        return Positioned(
          top: _pulseController.value * h,
          left: 0,
          right: 0,
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.transparent,
                CallTheme.neonGreen.withValues(alpha: 0.2),
                CallTheme.neonGreen.withValues(alpha: 0.5),
                CallTheme.neonGreen.withValues(alpha: 0.2),
                Colors.transparent,
              ]),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTickerBar() {
    const tickerText =
        'OUTBOUND ◆ PROTO: FLICKO-RTC/2.0 ◆ ENC: AES-256-GCM ◆ '
        'MESH: P2P-DIRECT ◆ STUN: OK ◆ TURN: STANDBY ◆ ';

    return Container(
      height: 24,
      color: CallTheme.neonGreen.withValues(alpha: 0.15),
      child: AnimatedBuilder(
        animation: _tickerController,
        builder: (context, _) {
          return ClipRect(
            child: OverflowBox(
              maxWidth: double.infinity,
              alignment: Alignment(-1 + _tickerController.value * 2, 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (_) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 24),
                    child: Text(
                      tickerText,
                      style: CallTheme.monoLabel(
                        color: CallTheme.neonGreen.withValues(alpha: 0.6),
                        size: 9,
                        weight: FontWeight.w600,
                      ),
                    ),
                  );
                }),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopStats() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CallTheme.techLabel('MODE: ${widget.callType.toUpperCase()}'),
              CallTheme.techLabel('RING: $_ringCount'),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CallTheme.techLabel(
                'SIG: ${(_signalStrength * 100).toInt()}%',
                color: _signalStrength > 0.5
                    ? CallTheme.neonGreen
                    : CallTheme.amber,
              ),
              CallTheme.techLabel('NAT: SYMMETRIC',
                  color: CallTheme.neonGreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCallTypeBadge() {
    final isVideo = widget.callType == 'video';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        border: Border.all(
          color: isVideo ? CallTheme.cyan : CallTheme.neonGreen,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isVideo ? Icons.videocam : Icons.call,
            color: isVideo ? CallTheme.cyan : CallTheme.neonGreen,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            isVideo ? 'VIDEO CALL' : 'VOICE CALL',
            style: CallTheme.monoLabel(
              color: isVideo ? CallTheme.cyan : CallTheme.neonGreen,
              size: 10,
              weight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusLine() {
    final dots = '.' * (_dotCount + 1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: _waveController,
          builder: (context, _) {
            final alpha =
                0.3 + 0.7 * (0.5 + 0.5 * sin(_waveController.value * 2 * pi));
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRinging
                    ? CallTheme.neonGreen.withValues(alpha: alpha)
                    : CallTheme.amber.withValues(alpha: alpha),
              ),
            );
          },
        ),
        Text(
          '$_statusText$dots',
          style: CallTheme.monoLabel(
            color: _isRinging ? CallTheme.neonGreen : CallTheme.amber,
            size: 13,
            weight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildRadarAvatar() {
    return Center(
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Radar sweep
            AnimatedBuilder(
              animation: _radarController,
              builder: (context, _) {
                return CustomPaint(
                  size: const Size(280, 280),
                  painter: RadarSweepPainter(
                    angle: _radarController.value * 2 * pi,
                    color: CallTheme.neonGreen,
                  ),
                );
              },
            ),
            // Expanding rings
            ...List.generate(3, (i) {
              return AnimatedBuilder(
                animation: _pulseController,
                builder: (context, _) {
                  final phase = (_pulseController.value + i * 0.33) % 1.0;
                  final scale = 0.4 + phase * 0.6;
                  final opacity = (1.0 - phase).clamp(0.0, 0.3);
                  return Transform.scale(
                    scale: scale,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              CallTheme.neonGreen.withValues(alpha: opacity),
                          width: 1,
                        ),
                      ),
                    ),
                  );
                },
              );
            }),
            // Avatar circle
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: CallTheme.surfaceDark,
                border: Border.all(color: CallTheme.neonGreen, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: CallTheme.neonGreen.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: widget.calleeAvatarUrl != null
                  ? ClipOval(
                      child: Image.network(
                        widget.calleeAvatarUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (c, e, s) => _avatarFallback(),
                      ),
                    )
                  : _avatarFallback(),
            ),
            // Target blip on radar edge
            if (_isRinging)
              AnimatedBuilder(
                animation: _radarController,
                builder: (context, _) {
                  final blipAngle =
                      _radarController.value * 2 * pi + pi / 4;
                  return Positioned(
                    left: 140 + 100 * cos(blipAngle) - 5,
                    top: 140 + 100 * sin(blipAngle) - 5,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: CallTheme.neonGreen,
                        boxShadow: [
                          BoxShadow(
                            color:
                                CallTheme.neonGreen.withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return Center(
      child: Text(
        widget.calleeName.isNotEmpty
            ? widget.calleeName[0].toUpperCase()
            : '?',
        style: CallTheme.heading(size: 40),
      ),
    );
  }

  Widget _buildSignalBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CallTheme.techLabel('SIGNAL ACQUISITION'),
              CallTheme.techLabel(
                '${(_signalStrength * 100).toInt()}%',
                color: CallTheme.neonGreen,
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: _signalStrength,
              minHeight: 4,
              backgroundColor: CallTheme.gridColor,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(CallTheme.neonGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          CallTheme.actionButton(
            icon: Icons.mic_off_outlined,
            label: 'MUTE',
            onTap: () {},
          ),
          CallTheme.actionButton(
            icon: Icons.volume_up_outlined,
            label: 'SPEAKER',
            onTap: () {},
          ),
          // Cancel button
          GestureDetector(
            onTap: () {
              widget.onCancel?.call();
              if (mounted) Navigator.of(context).pop();
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: CallTheme.red,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: CallTheme.red.withValues(alpha: 0.4),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.call_end, color: CallTheme.white, size: 30),
                ),
                const SizedBox(height: 6),
                Text(
                  'CANCEL',
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
            icon: Icons.message_outlined,
            label: 'MSG',
            onTap: () {},
          ),
          CallTheme.actionButton(
            icon: Icons.videocam_outlined,
            label: 'VIDEO',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CallTheme.bottomStat('ICE: CONNECTED'),
          CallTheme.bottomSeparator(),
          CallTheme.bottomStat('DTLS: SECURE'),
          CallTheme.bottomSeparator(),
          CallTheme.bottomStat('SRTP: ACTIVE'),
          CallTheme.bottomSeparator(),
          CallTheme.bottomStat(
            _isRinging ? 'RNG: ACTIVE' : 'RNG: WAIT',
            color: _isRinging ? CallTheme.neonGreen : CallTheme.textDim,
          ),
        ],
      ),
    );
  }
}
