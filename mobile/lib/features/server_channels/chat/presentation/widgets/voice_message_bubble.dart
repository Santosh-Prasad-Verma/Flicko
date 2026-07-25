import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Glassmorphic Voice Message Player Bubble for Chat
class VoiceMessageBubble extends StatefulWidget {
  final String audioUrl;
  final Duration? duration;
  final bool isMe;

  const VoiceMessageBubble({
    super.key,
    required this.audioUrl,
    this.duration,
    this.isMe = false,
  });

  @override
  State<VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<VoiceMessageBubble> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _totalDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _initAudio();
  }

  Future<void> _initAudio() async {
    try {
      if (widget.duration != null) {
        _totalDuration = widget.duration!;
      }
      final duration = await _audioPlayer.setUrl(widget.audioUrl);
      if (duration != null && mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }

      _audioPlayer.playerStateStream.listen((state) {
        if (mounted) {
          setState(() {
            _isPlaying = state.playing && state.processingState != ProcessingState.completed;
            if (state.processingState == ProcessingState.completed) {
              _position = Duration.zero;
              _audioPlayer.seek(Duration.zero);
            }
          });
        }
      });

      _audioPlayer.positionStream.listen((pos) {
        if (mounted) {
          setState(() {
            _position = pos;
          });
        }
      });
    } catch (e) {
      debugPrint('Error playing voice message: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _togglePlayPause() async {
    if (_isPlaying) {
      await _audioPlayer.pause();
    } else {
      await _audioPlayer.play();
    }
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalDuration.inMilliseconds > 0
        ? (_position.inMilliseconds / _totalDuration.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;

    return Container(
      width: 240,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMe
            ? const Color(FlickoColors.blurple).withValues(alpha: 0.35)
            : const Color(FlickoColors.bgSecondary).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isMe
              ? const Color(FlickoColors.blurple).withValues(alpha: 0.5)
              : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          // Play/Pause button
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: const Color(FlickoColors.green),
              padding: const EdgeInsets.all(8),
            ),
            icon: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.black,
              size: 20,
            ),
            onPressed: _togglePlayPause,
          ),
          const SizedBox(width: 8),

          // Waveform & Seek slider
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 3,
                    thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                    overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                    activeTrackColor: const Color(FlickoColors.green),
                    inactiveTrackColor: Colors.white24,
                    thumbColor: Colors.white,
                  ),
                  child: Slider(
                    value: progress,
                    onChanged: (val) {
                      final targetMs = (val * _totalDuration.inMilliseconds).toInt();
                      _audioPlayer.seek(Duration(milliseconds: targetMs));
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 4, right: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(_position),
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                      ),
                      Text(
                        _formatDuration(_totalDuration),
                        style: GoogleFonts.inter(color: Colors.white38, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
