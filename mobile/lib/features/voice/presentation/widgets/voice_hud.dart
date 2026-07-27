import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';

/// Discord-style Draggable Floating Voice Box Widget
/// Displayed when connected to a voice channel while navigating elsewhere in the app.
class VoiceHUD extends ConsumerStatefulWidget {
  const VoiceHUD({super.key});

  @override
  ConsumerState<VoiceHUD> createState() => _VoiceHUDState();
}

class _VoiceHUDState extends ConsumerState<VoiceHUD> {
  Offset? _position;

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceControllerProvider);

    if (!voiceState.isConnected && !voiceState.isConnecting) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;
    _position ??= Offset(size.width - 150, size.height - 220);

    final activeServerId = ref.read(voiceControllerProvider.notifier).activeServerId;
    final activeChannelId = voiceState.activeChannelId;
    final controller = ref.read(voiceControllerProvider.notifier);

    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (_position!.dx + details.delta.dx).clamp(8.0, size.width - 145.0),
              (_position!.dy + details.delta.dy).clamp(50.0, size.height - 180.0),
            );
          });
        },
        onTap: () {
          if (activeServerId != null && activeChannelId != null) {
            context.push('/server/$activeServerId/channel/$activeChannelId/voice');
          }
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 135,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1F22).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: voiceState.isConnected ? const Color(0xFF43B581) : Colors.amber,
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.6),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top status indicator & member count
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: voiceState.isConnected ? const Color(0xFF43B581) : Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        voiceState.isConnecting
                            ? 'Connecting...'
                            : '${voiceState.participants.length} in Voice',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Center Icon / Tap to open voice room
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.volume_up_rounded,
                    color: Color(0xFF43B581),
                    size: 22,
                  ),
                ),
                const SizedBox(height: 8),

                // Bottom Action Row: Mute & End Call
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: controller.toggleMute,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: voiceState.isMuted
                              ? const Color(0xFFED4245)
                              : Colors.white12,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          voiceState.isMuted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: controller.leaveChannel,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDA373C),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
