import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_lyric/lyrics_reader.dart';
import 'package:flutter_lyric/lyrics_reader_model.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Glassmorphic Synchronized LRC Lyric View Widget
class SynchronizedLyricsView extends StatefulWidget {
  final String lrcLyrics;
  final Stream<Duration> positionStream;
  final Duration currentPosition;
  final VoidCallback? onTapBack;

  const SynchronizedLyricsView({
    super.key,
    required this.lrcLyrics,
    required this.positionStream,
    required this.currentPosition,
    this.onTapBack,
  });

  @override
  State<SynchronizedLyricsView> createState() => _SynchronizedLyricsViewState();
}

class _SynchronizedLyricsViewState extends State<SynchronizedLyricsView> {
  LyricsReaderModel? _lyricsModel;
  final LyricUI _lyricUI = FlickoLyricUI();

  @override
  void initState() {
    super.initState();
    _parseLyrics();
  }

  @override
  void didUpdateWidget(covariant SynchronizedLyricsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.lrcLyrics != widget.lrcLyrics) {
      _parseLyrics();
    }
  }

  void _parseLyrics() {
    if (widget.lrcLyrics.trim().isEmpty) {
      _lyricsModel = null;
      return;
    }
    _lyricsModel = LyricsModelBuilder.create()
        .bindLyricToMain(widget.lrcLyrics)
        .getModel();
  }

  @override
  Widget build(BuildContext context) {
    if (_lyricsModel == null || widget.lrcLyrics.trim().isEmpty) {
      return _buildEmptyLyricsCard();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary).withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.5,
            ),
          ),
          child: Stack(
            children: [
              StreamBuilder<Duration>(
                stream: widget.positionStream,
                initialData: widget.currentPosition,
                builder: (context, snapshot) {
                  final progress = (snapshot.data ?? widget.currentPosition).inMilliseconds;
                  return LyricsReader(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    model: _lyricsModel,
                    position: progress,
                    lyricUi: _lyricUI,
                    playing: true,
                    emptyBuilder: () => _buildEmptyLyricsCard(),
                  );
                },
              ),
              if (widget.onTapBack != null)
                Positioned(
                  top: 16,
                  right: 16,
                  child: IconButton(
                    icon: const Icon(Icons.flip_to_front, color: Colors.white70),
                    onPressed: widget.onTapBack,
                    tooltip: 'Flip back to player',
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyLyricsCard() {
    return Container(
      alignment: Alignment.center,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_note_outlined, size: 48, color: Colors.white.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text(
            'No Lyrics Available',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enjoy the music!',
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom Glassmorphic Lyric UI theme for LyricsReader
class FlickoLyricUI extends UINetease {
  @override
  TextStyle getPlayingMainTextStyle() {
    return GoogleFonts.inter(
      color: const Color(FlickoColors.green),
      fontSize: 22,
      fontWeight: FontWeight.bold,
      shadows: [
        BoxShadow(
          color: const Color(FlickoColors.green).withValues(alpha: 0.6),
          blurRadius: 12,
        ),
      ],
    );
  }

  @override
  TextStyle getOtherMainTextStyle() {
    return GoogleFonts.inter(
      color: Colors.white.withValues(alpha: 0.45),
      fontSize: 16,
      fontWeight: FontWeight.w400,
    );
  }

  @override
  double getInlineSpace() => 32;

  @override
  double getLineSpace() => 18;

  @override
  LyricAlign getLyricHorizontalAlign() => LyricAlign.CENTER;

  @override
  LyricBaseLine getBiasBaseLine() => LyricBaseLine.CENTER;

  @override
  Color getLyricHightlightColor() => const Color(FlickoColors.green);
}
