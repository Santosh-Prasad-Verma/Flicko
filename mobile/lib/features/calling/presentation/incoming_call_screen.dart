import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Cyberpunk-styled incoming call screen.
///
/// Full-screen overlay with tactical HUD elements, scanning animations,
/// viewfinder-framed avatar, and animated status readouts.
class IncomingCallScreen extends StatefulWidget {
  final String callerName;
  final String? callerAvatarUrl;
  final String? callType; // 'voice' or 'video'
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  const IncomingCallScreen({
    super.key,
    required this.callerName,
    this.callerAvatarUrl,
    this.callType = 'voice',
    this.onAccept,
    this.onDecline,
  });

  @override
  State<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends State<IncomingCallScreen> with TickerProviderStateMixin {
  // ── Design Tokens ──
  static const _bg = Color(0xFF0A0A0A);
  static const _neonGreen = Color(0xFFCBEF17);
  static const _gridColor = Color(0xFF1A1A1A);
  static const _textDim = Color(0xFF555555);
  static const _textMid = Color(0xFF888888);
  static const _red = Color(0xFFFF3B3B);
  static const _white = Colors.white;

  // ── Animation Controllers ──
  late AnimationController _pulseController;
  late AnimationController _scanController;
  late AnimationController _tickerController;
  late AnimationController _glitchController;
  late AnimationController _acceptPulseController;

  // ── Data Streams ──
  late Timer _dataTimer;
  double _coordX = 45.922;
  double _coordY = 88.114;
  double _coordZ = 0.000;
  double _bitrate = 4.2;
  int _latency = 12;
  int _dotCount = 0;
  bool _signalLocked = false;
  String _linkStatus = 'ESTABLISHING LINK';
  final _random = Random();

  @override
  void initState() {
    super.initState();

    // Immersive fullscreen
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Pulse ring animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();

    // Scanning line animation
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    // Ticker scroll animation
    _tickerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    // Glitch animation
    _glitchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    // Accept button pulse
    _acceptPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    // Simulate live data feed
    _dataTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (!mounted) return;
      setState(() {
        _coordX += (_random.nextDouble() - 0.5) * 0.01;
        _coordY += (_random.nextDouble() - 0.5) * 0.01;
        _coordZ += (_random.nextDouble() - 0.5) * 0.001;
        _bitrate = 3.8 + _random.nextDouble() * 1.2;
        _latency = 8 + _random.nextInt(12);
        _dotCount = (_dotCount + 1) % 4;

        // Lock signal after ~3 seconds
        if (!_signalLocked && _random.nextDouble() > 0.7) {
          _signalLocked = true;
          _linkStatus = 'LINK ESTABLISHED';
          _triggerGlitch();
        }
      });
    });
  }

  void _triggerGlitch() {
    _glitchController.forward(from: 0).then((_) {
      if (mounted) _glitchController.reverse();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scanController.dispose();
    _tickerController.dispose();
    _glitchController.dispose();
    _acceptPulseController.dispose();
    _dataTimer.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Layer 0: Grid background
          _buildGridBackground(),
          // Layer 1: Scan line
          _buildScanLine(),
          // Layer 2: Main content
          SafeArea(
            child: Column(
              children: [
                // ── Top Ticker Bar ──
                _buildTickerBar(),
                const SizedBox(height: 12),
                // ── Tech Readouts ──
                _buildTechReadouts(),
                const SizedBox(height: 16),
                // ── Caller Name ──
                _buildCallerName(),
                const SizedBox(height: 8),
                // ── Status Line ──
                _buildStatusLine(),
                const SizedBox(height: 24),
                // ── Avatar Viewfinder ──
                Expanded(child: _buildAvatarViewfinder()),
                // ── Security Tags ──
                _buildSecurityTags(),
                const SizedBox(height: 24),
                // ── Action Buttons ──
                _buildActionButtons(),
                const SizedBox(height: 16),
                // ── Bottom Status Bar ──
                _buildBottomStatusBar(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridBackground() {
    return CustomPaint(
      size: MediaQuery.of(context).size,
      painter: _GridPainter(gridColor: _gridColor),
    );
  }

  Widget _buildScanLine() {
    return AnimatedBuilder(
      animation: _scanController,
      builder: (context, child) {
        final screenHeight = MediaQuery.of(context).size.height;
        return Positioned(
          top: _scanController.value * screenHeight,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  _neonGreen.withValues(alpha: 0.3),
                  _neonGreen.withValues(alpha: 0.6),
                  _neonGreen.withValues(alpha: 0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTickerBar() {
    final tickerText = 'E: 88X-V  ◆  SIG: ${_signalLocked ? 'LOCKED' : 'SCANNING'}  ◆  '
        'LATENCY: ${_latency}MS  ◆  ZERO PACKET LOSS  ◆  '
        'CODEC: AV1-PRO  ◆  ENC: AES-256  ◆  '
        'NODE: FLICKO-EDGE-7  ◆  UPTIME: 99.97%  ◆  ';

    return Container(
      height: 28,
      color: _neonGreen,
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
                      style: GoogleFonts.jetBrainsMono(
                        color: _bg,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
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

  Widget _buildTechReadouts() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left column — coordinates
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _techLabel('X: ${_coordX.toStringAsFixed(3)}'),
              _techLabel('Y: ${_coordY.toStringAsFixed(3)}'),
              _techLabel('Z: ${_coordZ.toStringAsFixed(3)}'),
            ],
          ),
          // Right column — connection stats
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _techLabel('BITRATE: ${_bitrate.toStringAsFixed(1)}MBPS', color: _neonGreen),
              _techLabel('CODEC: AV1-PRO', color: _neonGreen),
            ],
          ),
        ],
      ),
    );
  }

  Widget _techLabel(String text, {Color color = _textMid}) {
    return Text(
      text,
      style: GoogleFonts.jetBrainsMono(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildCallerName() {
    return AnimatedBuilder(
      animation: _glitchController,
      builder: (context, child) {
        final glitchOffset = _glitchController.value * 4;
        return Stack(
          children: [
            // Glitch shadow (red)
            if (glitchOffset > 0)
              Transform.translate(
                offset: Offset(glitchOffset, -glitchOffset / 2),
                child: Text(
                  widget.callerName.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    color: _red.withValues(alpha: 0.5),
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    height: 1,
                  ),
                ),
              ),
            // Glitch shadow (green)
            if (glitchOffset > 0)
              Transform.translate(
                offset: Offset(-glitchOffset, glitchOffset / 2),
                child: Text(
                  widget.callerName.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    color: _neonGreen.withValues(alpha: 0.5),
                    fontSize: 64,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 4,
                    height: 1,
                  ),
                ),
              ),
            // Main name
            child!,
          ],
        );
      },
      child: Text(
        widget.callerName.toUpperCase(),
        style: GoogleFonts.spaceGrotesk(
          color: _white,
          fontSize: 64,
          fontWeight: FontWeight.w900,
          letterSpacing: 4,
          height: 1,
        ),
      ),
    );
  }

  Widget _buildStatusLine() {
    final dots = '.' * (_dotCount + 1);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Blinking signal square
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            final opacity = 0.3 + 0.7 * (0.5 + 0.5 * sin(_pulseController.value * 2 * pi));
            return Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 10),
              color: _signalLocked ? _neonGreen.withValues(alpha: opacity) : _textDim,
            );
          },
        ),
        Text(
          '${_linkStatus.padRight(20)}$dots',
          style: GoogleFonts.jetBrainsMono(
            color: _neonGreen,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarViewfinder() {
    return Center(
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final breathe = 1.0 + 0.015 * sin(_pulseController.value * 2 * pi);
          return Transform.scale(
            scale: breathe,
            child: child,
          );
        },
        child: SizedBox(
          width: 260,
          height: 260,
          child: Stack(
            children: [
              // Outer pulse rings
              ...List.generate(3, (i) {
                return AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final phase = (_pulseController.value + i * 0.33) % 1.0;
                    final scale = 1.0 + phase * 0.3;
                    final opacity = (1.0 - phase).clamp(0.0, 0.4);
                    return Center(
                      child: Transform.scale(
                        scale: scale,
                        child: Container(
                          width: 220,
                          height: 220,
                          decoration: BoxDecoration(
                            shape: BoxShape.rectangle,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _neonGreen.withValues(alpha: opacity),
                              width: 1,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
              // Corner brackets — viewfinder frame
              _buildCornerBracket(Alignment.topLeft),
              _buildCornerBracket(Alignment.topRight),
              _buildCornerBracket(Alignment.bottomLeft),
              _buildCornerBracket(Alignment.bottomRight),
              // Center crosshair lines
              Center(child: Container(width: 260, height: 1, color: _gridColor)),
              Center(child: Container(width: 1, height: 260, color: _gridColor)),
              // Avatar container
              Center(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFF151515),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
                  ),
                  child: widget.callerAvatarUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(7),
                          child: Image.network(
                            widget.callerAvatarUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => _buildAvatarFallback(),
                          ),
                        )
                      : _buildAvatarFallback(),
                ),
              ),
              // "Avatar" label
              Positioned(
                top: 30,
                left: 38,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  color: _bg.withValues(alpha: 0.7),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_outlined, color: _neonGreen, size: 12),
                      const SizedBox(width: 4),
                      Text(
                        'Avatar',
                        style: GoogleFonts.jetBrainsMono(
                          color: _textMid,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback() {
    return Center(
      child: Text(
        widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : '?',
        style: GoogleFonts.spaceGrotesk(
          color: _neonGreen,
          fontSize: 72,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  Widget _buildCornerBracket(Alignment alignment) {
    const bracketLength = 30.0;
    const bracketWidth = 3.0;
    final isTop = alignment.y < 0;
    final isLeft = alignment.x < 0;

    return Positioned(
      top: isTop ? 18 : null,
      bottom: isTop ? null : 18,
      left: isLeft ? 18 : null,
      right: isLeft ? null : 18,
      child: SizedBox(
        width: bracketLength,
        height: bracketLength,
        child: CustomPaint(
          painter: _CornerBracketPainter(
            color: _neonGreen,
            strokeWidth: bracketWidth,
            isTop: isTop,
            isLeft: isLeft,
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityTags() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildTag('SEC: LVL_4', false),
          const SizedBox(width: 12),
          _buildTag('PRTY: OVERRIDE', true),
        ],
      ),
    );
  }

  Widget _buildTag(String text, bool isHighlighted) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isHighlighted ? _neonGreen : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isHighlighted ? _neonGreen : _textDim,
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          color: isHighlighted ? _bg : _textMid,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Mute
          _actionButton(
            icon: Icons.mic_off_outlined,
            label: 'MUTE',
            onTap: () {},
          ),
          // Video
          _actionButton(
            icon: Icons.videocam_outlined,
            label: 'VIDEO',
            onTap: () {},
          ),
          // Decline (red)
          _declineButton(),
          // Accept (green pulse)
          _acceptButton(),
          // Speaker
          _actionButton(
            icon: Icons.volume_up_outlined,
            label: 'AUDIO',
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF2A2A2A), width: 1),
            ),
            child: Icon(icon, color: _white, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.jetBrainsMono(
              color: _textDim,
              fontSize: 8,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _declineButton() {
    return GestureDetector(
      onTap: () {
        widget.onDecline?.call();
        if (mounted) Navigator.of(context).pop();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _red,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.call_end, color: _white, size: 28),
          ),
          const SizedBox(height: 6),
          Text(
            'END',
            style: GoogleFonts.jetBrainsMono(
              color: _red,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _acceptButton() {
    return GestureDetector(
      onTap: () {
        widget.onAccept?.call();
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _acceptPulseController,
            builder: (context, child) {
              final glow = _acceptPulseController.value * 8;
              return Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _neonGreen,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _neonGreen.withValues(alpha: 0.4),
                      blurRadius: glow + 4,
                      spreadRadius: glow / 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.call, color: Color(0xFF0A0A0A), size: 28),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            'ACCEPT',
            style: GoogleFonts.jetBrainsMono(
              color: _neonGreen,
              fontSize: 8,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStatusBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _bottomStat('FRQ: 2.4G'),
          _bottomStatSeparator(),
          _bottomStat('BUF: 0MS'),
          _bottomStatSeparator(),
          _bottomStat('VOL: 85%'),
          _bottomStatSeparator(),
          Text(
            'LNK: ${_signalLocked ? 'OK' : '...'}',
            style: GoogleFonts.jetBrainsMono(
              color: _signalLocked ? _neonGreen : _textDim,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomStat(String text) {
    return Text(
      text,
      style: GoogleFonts.jetBrainsMono(
        color: _textDim,
        fontSize: 10,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _bottomStatSeparator() {
    return Text(
      '|',
      style: GoogleFonts.jetBrainsMono(
        color: const Color(0xFF2A2A2A),
        fontSize: 10,
      ),
    );
  }
}

// Grid Painter
class _GridPainter extends CustomPainter {
  final Color gridColor;

  _GridPainter({required this.gridColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 0.5;

    const spacing = 32.0;

    // Vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Corner Bracket Painter
class _CornerBracketPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final bool isTop;
  final bool isLeft;

  _CornerBracketPainter({
    required this.color,
    required this.strokeWidth,
    required this.isTop,
    required this.isLeft,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final path = Path();

    if (isTop && isLeft) {
      path.moveTo(0, size.height);
      path.lineTo(0, 0);
      path.lineTo(size.width, 0);
    } else if (isTop && !isLeft) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width, size.height);
    } else if (!isTop && isLeft) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height);
      path.lineTo(size.width, size.height);
    } else {
      path.moveTo(size.width, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
