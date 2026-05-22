import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../application/sonic_drip_notifier.dart';
import '../../domain/music_models.dart';

class PlaybackControls extends ConsumerWidget {
  final SonicDripState state;
  const PlaybackControls({super.key, required this.state});

  static const _lime = Color(0xFF52B788);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(sonicDripProvider.notifier);
    final isPlaying = state.playback.status == PlaybackStatus.playing;
    final shuffle = state.playback.shuffle;
    final repeat = state.playback.repeat;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: const [BoxShadow(color: Colors.white, offset: Offset(5, 5))],
      ),
      child: Column(
        children: [
          // Main controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ControlBtn(
                icon: Icons.shuffle_rounded,
                onTap: notifier.toggleShuffle,
                size: 48,
                isActive: shuffle,
                activeColor: _lime,
              ),
              _ControlBtn(
                icon: Icons.skip_previous_rounded,
                onTap: notifier.skipPrevious,
                size: 56,
              ),
              _ControlBtn(
                icon: isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                onTap: notifier.togglePlayPause,
                size: 80,
                isPrimary: true,
              ),
              _ControlBtn(
                icon: Icons.skip_next_rounded,
                onTap: notifier.skipNext,
                size: 56,
              ),
              _ControlBtn(
                icon: Icons.repeat_rounded,
                onTap: notifier.toggleRepeat,
                size: 48,
                isActive: repeat,
                activeColor: _lime,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Autoplay / Radio Mode Toggle
          GestureDetector(
            onTap: notifier.toggleAutoplay,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: state.playback.autoplay ? _lime.withValues(alpha: 0.1) : Colors.black,
                border: Border.all(
                  color: state.playback.autoplay ? _lime : Colors.white.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.radio_rounded,
                        color: state.playback.autoplay ? _lime : Colors.white54,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'AUTOPLAY_RADIO_MODE',
                        style: GoogleFonts.spaceGrotesk(
                          color: state.playback.autoplay ? _lime : Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 11,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    color: state.playback.autoplay ? _lime : Colors.white24,
                    child: Text(
                      state.playback.autoplay ? 'ACTIVE' : 'OFF',
                      style: GoogleFonts.robotoMono(
                        color: state.playback.autoplay ? Colors.black : Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // Volume row
          Row(
            children: [
              const Icon(Icons.volume_down, color: Colors.white, size: 18),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: _lime,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.15),
                    thumbColor: _lime,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape: SliderComponentShape.noOverlay,
                    trackHeight: 3,
                  ),
                  child: Slider(
                    value: state.playback.volume,
                    onChanged: notifier.setVolume,
                  ),
                ),
              ),
              const Icon(Icons.volume_up, color: Colors.white, size: 18),
            ],
          ),
        ],
      ),
    );
  }
}

class _ControlBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final double size;
  final bool isPrimary;
  final bool isActive;
  final Color activeColor;

  const _ControlBtn({
    required this.icon,
    required this.onTap,
    required this.size,
    this.isPrimary = false,
    this.isActive = false,
    this.activeColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isPrimary
        ? const Color(0xFF52B788)
        : isActive
            ? activeColor.withValues(alpha: 0.15)
            : Colors.black;

    final iconColor = isPrimary
        ? Colors.black
        : isActive
            ? activeColor
            : Colors.white;

    final borderColor = isPrimary
        ? Colors.black
        : isActive
            ? activeColor
            : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          border: Border.all(color: borderColor, width: 2.5),
          boxShadow: [BoxShadow(color: borderColor, offset: const Offset(3, 3))],
        ),
        child: Icon(icon, size: size * 0.45, color: iconColor),
      ),
    );
  }
}
