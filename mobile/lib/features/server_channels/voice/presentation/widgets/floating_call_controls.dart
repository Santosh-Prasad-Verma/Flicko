import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Floating Glassmorphic In-Call Action Control Bar
class FloatingCallControls extends StatelessWidget {
  final bool isMicMuted;
  final bool isCameraOff;
  final bool isScreenSharing;
  final bool isDeafened;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onToggleScreenShare;
  final VoidCallback onToggleDeafen;
  final VoidCallback onDisconnect;

  const FloatingCallControls({
    super.key,
    required this.isMicMuted,
    required this.isCameraOff,
    required this.isScreenSharing,
    required this.isDeafened,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onToggleScreenShare,
    required this.onToggleDeafen,
    required this.onDisconnect,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Mic Toggle
              _buildControlButton(
                icon: isMicMuted ? Icons.mic_off : Icons.mic,
                isActive: !isMicMuted,
                activeColor: const Color(FlickoColors.green),
                inactiveColor: Colors.redAccent,
                onTap: onToggleMic,
                tooltip: isMicMuted ? 'Unmute Mic' : 'Mute Mic',
              ),
              const SizedBox(width: 12),

              // Camera Toggle
              _buildControlButton(
                icon: isCameraOff ? Icons.videocam_off : Icons.videocam,
                isActive: !isCameraOff,
                activeColor: const Color(FlickoColors.blurple),
                inactiveColor: Colors.grey.shade700,
                onTap: onToggleCamera,
                tooltip: isCameraOff ? 'Turn Camera On' : 'Turn Camera Off',
              ),
              const SizedBox(width: 12),

              // Screen Share Toggle
              _buildControlButton(
                icon: isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
                isActive: isScreenSharing,
                activeColor: Colors.orangeAccent,
                inactiveColor: Colors.grey.shade700,
                onTap: onToggleScreenShare,
                tooltip: isScreenSharing ? 'Stop Screen Share' : 'Share Screen',
              ),
              const SizedBox(width: 12),

              // Deafen Toggle
              _buildControlButton(
                icon: isDeafened ? Icons.volume_off : Icons.volume_up,
                isActive: !isDeafened,
                activeColor: Colors.blueAccent,
                inactiveColor: Colors.redAccent,
                onTap: onToggleDeafen,
                tooltip: isDeafened ? 'Undeafen' : 'Deafen',
              ),
              const SizedBox(width: 16),

              // Disconnect Call Button
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.all(12),
                ),
                icon: const Icon(Icons.call_end, color: Colors.white, size: 22),
                onPressed: onDisconnect,
                tooltip: 'Disconnect Call',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
    required String tooltip,
  }) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive
                ? activeColor.withValues(alpha: 0.25)
                : inactiveColor.withValues(alpha: 0.3),
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? activeColor : inactiveColor,
              width: 1.5,
            ),
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive ? activeColor : Colors.white70,
          ),
        ),
      ),
    );
  }
}
