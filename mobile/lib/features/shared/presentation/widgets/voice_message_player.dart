import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class VoiceMessagePlayer extends StatefulWidget {
  final String audioUrl;
  final String? fileName;

  const VoiceMessagePlayer({
    super.key,
    required this.audioUrl,
    this.fileName,
  });

  @override
  State<VoiceMessagePlayer> createState() => _VoiceMessagePlayerState();
}

class _VoiceMessagePlayerState extends State<VoiceMessagePlayer> {
  late AudioPlayer _player;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _isLoaded = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final duration = await _player.setUrl(widget.audioUrl);
      if (mounted) {
        setState(() {
          _duration = duration ?? Duration.zero;
          _isLoaded = true;
        });
      }

      _player.playerStateStream.listen((state) {
        if (!mounted) return;
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) {
            _player.seek(Duration.zero);
            _player.pause();
          }
        });
      });

      _player.positionStream.listen((pos) {
        if (!mounted) return;
        setState(() {
          _position = pos;
        });
      });

      _player.durationStream.listen((dur) {
        if (!mounted || dur == null) return;
        setState(() {
          _duration = dur;
        });
      });
    } catch (e) {
      debugPrint("Error loading voice note: $e");
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlay() {
    if (!_isLoaded) return;
    if (_isPlaying) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(
              'Failed to load voice note',
              style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Play/Pause button
          GestureDetector(
            onTap: _togglePlay,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(FlickoColors.emeraldGreen),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(FlickoColors.emeraldGreen).withValues(alpha: 0.3),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: !_isLoaded
                  ? const Center(
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                        ),
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: Colors.black,
                      size: 20,
                    ),
            ),
          ),
          const SizedBox(width: 12),
          // Waveform and progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform simulation
                SizedBox(
                  height: 20,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(15, (index) {
                      final double progressPercent = _duration.inMilliseconds > 0
                          ? _position.inMilliseconds / _duration.inMilliseconds
                          : 0.0;
                      final double barPercent = index / 15;
                      final bool isActive = progressPercent >= barPercent;

                      final List<double> heights = [
                        8, 12, 16, 10, 14, 18, 12, 10, 15, 17, 13, 11, 14, 10, 8
                      ];
                      final barHeight = heights[index];

                      return Flexible(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          margin: const EdgeInsets.symmetric(horizontal: 1.5),
                          height: barHeight,
                          width: 3,
                          decoration: BoxDecoration(
                            color: isActive
                                ? const Color(FlickoColors.emeraldGreen)
                                : Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(1.5),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 4),
                // Time stamps
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_position),
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _formatDuration(_duration),
                      style: GoogleFonts.inter(
                        color: Colors.white30,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
