import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class MusicBarWidget extends StatefulWidget {
  const MusicBarWidget({super.key});

  @override
  State<MusicBarWidget> createState() => _MusicBarWidgetState();
}

class _MusicBarWidgetState extends State<MusicBarWidget> with SingleTickerProviderStateMixin {
  bool _isPlaying = true;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _togglePlay() {
    setState(() {
      _isPlaying = !_isPlaying;
      if (_isPlaying) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.music_note, color: Color(FlickoColors.blurple)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Now Playing - Favorite Track',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.skip_previous, color: Color(FlickoColors.textMuted))),
              IconButton(
                onPressed: _togglePlay,
                icon: Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: const Color(FlickoColors.textPrimary), size: 36),
              ),
              IconButton(onPressed: () {}, icon: const Icon(Icons.skip_next, color: Color(FlickoColors.textMuted))),
              const Spacer(),
              _buildGlavaAnimation(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGlavaAnimation() {
    return SizedBox(
      height: 30,
      width: 80,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(8, (index) {
          return AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final randomHeight = _isPlaying ? (sin(_animationController.value * pi * (index + 1)) * 15 + 15).abs() : 5.0;
              return Container(
                width: 6,
                height: randomHeight,
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.blurple),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
