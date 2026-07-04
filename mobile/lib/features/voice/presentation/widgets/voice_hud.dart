import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_state.dart';
import 'voice_synth_board_sheet.dart';

/// Floating Voice HUD bar displayed when connected to a voice channel in the background.
/// Features full controls, vocal synthesizer access, tap-to-navigate, and expandable/collapsible pill modes.
class VoiceHUD extends ConsumerStatefulWidget {
  const VoiceHUD({super.key});

  @override
  ConsumerState<VoiceHUD> createState() => _VoiceHUDState();
}

class _VoiceHUDState extends ConsumerState<VoiceHUD> {
  bool _isMinimized = false;

  void _toggleMinimized() {
    setState(() {
      _isMinimized = !_isMinimized;
    });
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceControllerProvider);

    if (!voiceState.isConnected && !voiceState.isConnecting) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: _isMinimized
          ? const EdgeInsets.symmetric(horizontal: 14, vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF121215).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(_isMinimized ? 24 : 16),
        border: Border.all(
          color: const Color(FlickoColors.green).withValues(alpha: _isMinimized ? 0.4 : 0.25),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isMinimized
          ? _buildMinimizedPill(context, ref, voiceState)
          : _buildExpandedHud(context, ref, voiceState),
    );
  }

  /// Compact 1-line pill view when minimized to minimize screen footprint
  Widget _buildMinimizedPill(BuildContext context, WidgetRef ref, VoiceState voiceState) {
    final controller = ref.read(voiceControllerProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Pulsing active call indicator
        GestureDetector(
          onTap: _toggleMinimized,
          behavior: HitTestBehavior.opaque,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: voiceState.isConnected ? const Color(FlickoColors.green) : Colors.amber,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (voiceState.isConnected ? const Color(FlickoColors.green) : Colors.amber)
                          .withValues(alpha: 0.6),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                voiceState.isConnecting ? 'Connecting...' : 'Voice (${voiceState.participants.length})',
                style: GoogleFonts.spaceMono(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        // Quick Mute button
        IconButton(
          icon: Icon(
            voiceState.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
            color: voiceState.isMuted ? Colors.redAccent : const Color(FlickoColors.green),
            size: 18,
          ),
          onPressed: controller.toggleMute,
          tooltip: voiceState.isMuted ? 'Unmute' : 'Mute',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: 4),
        // Expand button
        IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_up_rounded,
            color: Colors.white70,
            size: 22,
          ),
          onPressed: _toggleMinimized,
          tooltip: 'Expand Controls',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
        const SizedBox(width: 4),
        // Leave call button
        IconButton(
          icon: const Icon(
            Icons.call_end_rounded,
            color: Colors.redAccent,
            size: 18,
          ),
          onPressed: controller.leaveChannel,
          tooltip: 'Leave Call',
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        ),
      ],
    );
  }

  /// Full expanded HUD controls
  Widget _buildExpandedHud(BuildContext context, WidgetRef ref, VoiceState voiceState) {
    return Row(
      children: [
        _buildStatusIndicator(voiceState),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                voiceState.isConnecting ? 'Connecting...' : 'Voice Connected',
                style: GoogleFonts.spaceMono(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (voiceState.isConnected)
                Text(
                  '${voiceState.participants.length} in call',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        _buildActionButtons(context, ref, voiceState),
      ],
    );
  }

  Widget _buildStatusIndicator(VoiceState voiceState) {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgTertiary),
        shape: BoxShape.circle,
      ),
      child: Icon(
        voiceState.isConnecting ? Icons.hourglass_empty_rounded : Icons.wifi_calling_3_rounded,
        color: voiceState.isConnected ? const Color(FlickoColors.green) : const Color(FlickoColors.textMuted),
        size: 18,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref, VoiceState voiceState) {
    final controller = ref.read(voiceControllerProvider.notifier);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _hudButton(
          icon: Icons.tune_rounded,
          color: const Color(FlickoColors.green),
          tooltip: 'Vocal Synthesizer',
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const VoiceSynthBoardSheet(),
            );
          },
        ),
        _hudButton(
          icon: voiceState.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          color: voiceState.isMuted ? Colors.redAccent : Colors.white,
          tooltip: voiceState.isMuted ? 'Unmute' : 'Mute',
          onPressed: controller.toggleMute,
        ),
        _hudButton(
          icon: voiceState.isDeafened ? Icons.headset_off_rounded : Icons.headset_rounded,
          color: voiceState.isDeafened ? Colors.redAccent : Colors.white,
          tooltip: voiceState.isDeafened ? 'Undeafen' : 'Deafen',
          onPressed: controller.toggleDeafen,
        ),
        _hudButton(
          icon: Icons.keyboard_arrow_down_rounded,
          color: Colors.white70,
          tooltip: 'Minimize',
          onPressed: _toggleMinimized,
        ),
        _hudButton(
          icon: Icons.call_end_rounded,
          color: Colors.redAccent,
          tooltip: 'Leave Call',
          onPressed: controller.leaveChannel,
        ),
      ],
    );
  }

  Widget _hudButton({
    required IconData icon,
    required Color color,
    VoidCallback? onPressed,
    String? tooltip,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 1.0),
      child: IconButton(
        icon: Icon(icon, color: color, size: 19),
        onPressed: onPressed,
        tooltip: tooltip,
        padding: const EdgeInsets.all(6.0),
        constraints: const BoxConstraints(),
        splashRadius: 16,
      ),
    );
  }
}
