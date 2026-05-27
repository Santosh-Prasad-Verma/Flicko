import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Redesigned Incoming Call Screen (Glassmorphic, smooth, and modern)
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
  // State variables for toggles
  bool _isMuted = false;
  bool _isSpeakerOn = false;
  bool _isVideoOn = false;

  // Animation Controllers
  late AnimationController _orbController;
  late AnimationController _pulseController;
  late AnimationController _waveController;

  // Colors
  static const Color _bgBlack = Color(0xFF060608);
  static const Color _neonGreen = Color(0xFF52B788);
  static const Color _neonCyan = Color(0xFF00E5FF);
  static const Color _red = Color(0xFFFF3B3B);
  static const Color _white = Colors.white;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Orb movement animation
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    // Pulse animation for avatar rings
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Wave/breathing animation for general visual elements
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _isVideoOn = widget.callType == 'video';
  }

  @override
  void dispose() {
    _orbController.dispose();
    _pulseController.dispose();
    _waveController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final primaryColor = _isVideoOn ? _neonCyan : _neonGreen;

    return Scaffold(
      backgroundColor: _bgBlack,
      body: Stack(
        children: [
          // 1. Organic Glowing Background Orbs
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _orbController,
              builder: (context, _) {
                final val = _orbController.value;
                final orb1Align = Alignment(-0.6 + 0.3 * sin(val * pi * 2), -0.5 + 0.4 * cos(val * pi * 2));
                final orb2Align = Alignment(0.6 - 0.3 * cos(val * pi * 2), 0.5 - 0.4 * sin(val * pi * 2));

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

          // 2. Translucent Glass Overlay
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 45, sigmaY: 45),
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ),

          // 3. UI Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Top Title Bar
                  Column(
                    children: [
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isVideoOn ? Icons.videocam : Icons.call_received_rounded,
                            color: primaryColor,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            (_isVideoOn ? 'INCOMING VIDEO CALL' : 'INCOMING VOICE CALL'),
                            style: GoogleFonts.spaceMono(
                              color: _white.withValues(alpha: 0.4),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  // Middle Section: Avatar & Name
                  Column(
                    children: [
                      // Avatar with elegant rings
                      SizedBox(
                        width: 220,
                        height: 220,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Glowing breathing circles
                            ...List.generate(2, (i) {
                              return AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, _) {
                                  final progress = (_pulseController.value + i * 0.5) % 1.0;
                                  final scale = 1.0 + progress * 0.5;
                                  final opacity = (1.0 - progress).clamp(0.0, 0.35);
                                  return Transform.scale(
                                    scale: scale,
                                    child: Container(
                                      width: 140,
                                      height: 140,
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
                            // Core avatar shell
                            Container(
                              width: 136,
                              height: 136,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.03),
                                border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.3),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryColor.withValues(alpha: 0.1),
                                    blurRadius: 32,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(68),
                                child: widget.callerAvatarUrl != null
                                    ? Image.network(
                                        widget.callerAvatarUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, e, s) => _avatarFallback(),
                                      )
                                    : _avatarFallback(),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 36),

                      // Caller Name (Elegant outfit styling, normal case)
                      Text(
                        widget.callerName,
                        style: GoogleFonts.outfit(
                          color: _white,
                          fontSize: 44,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 10),

                      // Call Status
                      AnimatedBuilder(
                        animation: _waveController,
                        builder: (context, _) {
                          final breathe = 0.6 + 0.4 * _waveController.value;
                          return Text(
                            'Flicko Secure Calling',
                            style: GoogleFonts.inter(
                              color: _white.withValues(alpha: breathe * 0.4 + 0.3),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.3,
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  // Bottom Action Buttons Panel
                  Column(
                    children: [
                      // Sub-actions panel (frosted glass)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(32),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.05), width: 1),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildGlassToggleBtn(
                              icon: _isMuted ? Icons.mic_off : Icons.mic,
                              label: 'MUTE',
                              isActive: _isMuted,
                              onTap: () => setState(() => _isMuted = !_isMuted),
                            ),
                            _buildGlassToggleBtn(
                              icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
                              label: 'VIDEO',
                              isActive: _isVideoOn,
                              onTap: () => setState(() => _isVideoOn = !_isVideoOn),
                            ),
                            _buildGlassToggleBtn(
                              icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
                              label: 'SPEAKER',
                              isActive: _isSpeakerOn,
                              onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Primary pickup & hangup buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Decline Button
                          _buildPrimaryRoundBtn(
                            icon: Icons.call_end,
                            color: _red,
                            glowColor: _red,
                            label: 'DECLINE',
                            onTap: () {
                              widget.onDecline?.call();
                              Navigator.of(context).pop();
                            },
                          ),
                          // Accept Button
                          _buildPrimaryRoundBtn(
                            icon: Icons.call,
                            color: _neonGreen,
                            glowColor: _neonGreen,
                            label: 'ANSWER',
                            onTap: () {
                              widget.onAccept?.call();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback() {
    return Center(
      child: Text(
        widget.callerName.isNotEmpty ? widget.callerName[0].toUpperCase() : '?',
        style: GoogleFonts.outfit(
          color: _isVideoOn ? _neonCyan : _neonGreen,
          fontSize: 60,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildGlassToggleBtn({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final activeColor = _isVideoOn ? _neonCyan : _neonGreen;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? activeColor.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.03),
              border: Border.all(
                color: isActive ? activeColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.05),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? activeColor : _white.withValues(alpha: 0.65),
              size: 22,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.spaceMono(
              color: isActive ? activeColor : _white.withValues(alpha: 0.35),
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryRoundBtn({
    required IconData icon,
    required Color color,
    required Color glowColor,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.35),
                  blurRadius: 32,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.black,
              size: 32,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: GoogleFonts.spaceMono(
              color: _white.withValues(alpha: 0.4),
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
