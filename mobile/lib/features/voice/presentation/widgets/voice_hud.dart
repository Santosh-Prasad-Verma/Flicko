import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';

class VoiceHUD extends ConsumerWidget {
  const VoiceHUD({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceControllerProvider);

    if (!voiceState.isConnected && !voiceState.isConnecting) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
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
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                if (voiceState.isConnected)
                  Text(
                    '${voiceState.participants.length} in call',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          _buildActionButtons(ref, voiceState),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(voiceState) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgTertiary),
        shape: BoxShape.circle,
      ),
      child: Icon(
        voiceState.isConnecting ? Icons.hourglass_empty : Icons.wifi_calling_3,
        color: voiceState.isConnected ? const Color(FlickoColors.green) : const Color(FlickoColors.textMuted),
        size: 20,
      ),
    );
  }

  Widget _buildActionButtons(WidgetRef ref, voiceState) {
    final controller = ref.read(voiceControllerProvider.notifier);
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(
            voiceState.isMuted ? Icons.mic_off : Icons.mic,
            color: voiceState.isMuted ? Colors.red : Colors.white,
          ),
          onPressed: controller.toggleMute,
        ),
        IconButton(
          icon: Icon(
            voiceState.isDeafened ? Icons.headset_off : Icons.headset,
            color: voiceState.isDeafened ? Colors.red : Colors.white,
          ),
          onPressed: controller.toggleDeafen,
        ),
        IconButton(
          icon: const Icon(Icons.call_end, color: Colors.red),
          onPressed: controller.leaveChannel,
        ),
      ],
    );
  }
}
