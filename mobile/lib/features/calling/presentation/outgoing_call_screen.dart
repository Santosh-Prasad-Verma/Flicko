import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Flicko Outgoing Call Screen (Styled to match Flicko dark-first theme system)
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

class _OutgoingCallScreenState extends State<OutgoingCallScreen> with TickerProviderStateMixin {
  bool _isMuted = false;
  bool _isSpeakerOn = true;
  bool _isVideoOn = false;

  late AnimationController _pulseController;
  late Timer _statusTimer;

  int _ringCount = 0;
  String _statusText = 'Calling';
  int _dotCount = 0;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _statusTimer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (!mounted) return;
      setState(() {
        _dotCount = (_dotCount + 1) % 4;
        _ringCount++;
        if (_ringCount < 4) {
          _statusText = 'Calling';
        } else if (_ringCount < 8) {
          _statusText = 'Connecting';
        } else {
          _statusText = 'Ringing';
        }
      });
    });

    _isVideoOn = widget.callType == 'video';
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _statusTimer.cancel();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brandGreen = Color(FlickoColors.brandLime);
    const bgPrimary = Color(FlickoColors.bgPrimary);
    const bgSecondary = Color(FlickoColors.bgSecondary);
    const bgTertiary = Color(FlickoColors.bgTertiary);
    final dots = '.' * (_dotCount + 1);

    return Scaffold(
      backgroundColor: bgPrimary,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Top Bar Header
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isVideoOn ? Icons.videocam_rounded : Icons.call_made_rounded,
                      color: brandGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isVideoOn ? 'Flicko Video Call' : 'Flicko Voice Call',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),

              // Middle Section: Avatar & Callee Details
              Column(
                children: [
                  // Pulsing Glowing Avatar Container
                  SizedBox(
                    width: 200,
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ...List.generate(2, (i) {
                          return AnimatedBuilder(
                            animation: _pulseController,
                            builder: (context, _) {
                              final progress = (_pulseController.value + i * 0.5) % 1.0;
                              final scale = 1.0 + progress * 0.45;
                              final opacity = (1.0 - progress).clamp(0.0, 0.4);
                              return Transform.scale(
                                scale: scale,
                                child: Container(
                                  width: 128,
                                  height: 128,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: brandGreen.withValues(alpha: opacity),
                                      width: 2.0,
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                        Container(
                          width: 128,
                          height: 128,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: bgSecondary,
                            border: Border.all(
                              color: brandGreen,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: brandGreen.withValues(alpha: 0.25),
                                blurRadius: 28,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(64),
                            child: widget.calleeAvatarUrl != null && widget.calleeAvatarUrl!.isNotEmpty
                                ? Image.network(
                                    widget.calleeAvatarUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (c, e, s) => _avatarFallback(),
                                  )
                                : _avatarFallback(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Callee Name
                  Text(
                    widget.calleeName,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),

                  // Call Status
                  Text(
                    '$_statusText$dots',
                    style: GoogleFonts.inter(
                      color: brandGreen,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              // Bottom Action Controls Panel
              Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: bgSecondary,
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: bgTertiary, width: 1.5),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildActionBtn(
                          icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                          label: 'Mute',
                          isActive: _isMuted,
                          onTap: () => setState(() => _isMuted = !_isMuted),
                        ),
                        _buildActionBtn(
                          icon: _isVideoOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                          label: 'Camera',
                          isActive: _isVideoOn,
                          onTap: () => setState(() => _isVideoOn = !_isVideoOn),
                        ),
                        _buildActionBtn(
                          icon: _isSpeakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
                          label: 'Speaker',
                          isActive: _isSpeakerOn,
                          onTap: () => setState(() => _isSpeakerOn = !_isSpeakerOn),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Decline / End Call Button
                  GestureDetector(
                    onTap: () {
                      widget.onCancel?.call();
                      Navigator.of(context).pop();
                    },
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(FlickoColors.danger),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x60ED4245),
                            blurRadius: 24,
                            spreadRadius: 2,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.call_end_rounded,
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avatarFallback() {
    return Center(
      child: Text(
        widget.calleeName.isNotEmpty ? widget.calleeName[0].toUpperCase() : '?',
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.brandLime),
          fontSize: 48,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionBtn({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    const brandGreen = Color(FlickoColors.brandLime);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive ? brandGreen.withValues(alpha: 0.18) : const Color(FlickoColors.bgTertiary),
              border: Border.all(
                color: isActive ? brandGreen : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: isActive ? brandGreen : Colors.white70,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.inter(
              color: isActive ? brandGreen : Colors.white54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
