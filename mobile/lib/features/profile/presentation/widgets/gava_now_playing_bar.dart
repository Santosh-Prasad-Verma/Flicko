import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Gava" — a slim now-playing bar with a hand-drawn equalizer animation
/// that pulses with the music. Sits below the banner on the profile screen
/// and only renders when [trackTitle] is non-null.
///
/// Pure-paint, no audio APIs, so it's safe to embed anywhere.
class GavaNowPlayingBar extends StatefulWidget {
  final String? trackTitle;
  final String? artist;
  final String? artworkUrl;
  final bool isPlaying;
  final Color accent;
  final VoidCallback? onTap;

  const GavaNowPlayingBar({
    super.key,
    required this.trackTitle,
    this.artist,
    this.artworkUrl,
    this.isPlaying = true,
    this.accent = const Color(0xFFC0F500),
    this.onTap,
  });

  @override
  State<GavaNowPlayingBar> createState() => _GavaNowPlayingBarState();
}

class _GavaNowPlayingBarState extends State<GavaNowPlayingBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _syncRunningState();
  }

  @override
  void didUpdateWidget(covariant GavaNowPlayingBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isPlaying != widget.isPlaying ||
        oldWidget.trackTitle != widget.trackTitle) {
      _syncRunningState();
    }
  }

  void _syncRunningState() {
    if (widget.trackTitle != null && widget.isPlaying) {
      if (!_ctrl.isAnimating) _ctrl.repeat();
    } else {
      _ctrl.stop();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.trackTitle == null) return const SizedBox.shrink();

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF0C0C0E),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: widget.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              _buildArtwork(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.graphic_eq_rounded,
                            color: widget.accent, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          'GAVA',
                          style: GoogleFonts.spaceMono(
                            color: widget.accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.trackTitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.artist != null && widget.artist!.isNotEmpty)
                      Text(
                        widget.artist!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.55),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 32,
                height: 32,
                child: AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) => CustomPaint(
                    painter: _EqualizerPainter(
                      progress: _ctrl.value,
                      color: widget.accent,
                      paused: !widget.isPlaying,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildArtwork() {
    final url = widget.artworkUrl;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1D),
        borderRadius: BorderRadius.circular(8),
        image: (url != null && url.isNotEmpty)
            ? DecorationImage(image: NetworkImage(url), fit: BoxFit.cover)
            : null,
      ),
      alignment: Alignment.center,
      child: (url == null || url.isEmpty)
          ? Icon(Icons.music_note_rounded,
              color: widget.accent.withValues(alpha: 0.7), size: 22)
          : null,
    );
  }
}

/// 4-bar equalizer that bounces using a sine wave per-bar.
class _EqualizerPainter extends CustomPainter {
  final double progress;
  final Color color;
  final bool paused;

  _EqualizerPainter({
    required this.progress,
    required this.color,
    required this.paused,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const barCount = 4;
    final barWidth = size.width / (barCount * 2 - 1);
    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < barCount; i++) {
      final phase = i * (math.pi / barCount);
      final sample = paused
          ? 0.25
          : 0.35 + 0.55 * (math.sin(progress * 2 * math.pi + phase).abs());
      final h = size.height * sample;
      final x = i * 2 * barWidth;
      final y = (size.height - h) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, barWidth, h),
          const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _EqualizerPainter old) =>
      old.progress != progress || old.paused != paused;
}
