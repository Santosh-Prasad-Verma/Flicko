import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/voice/application/music_notifier.dart';
import 'music_search_sheet.dart';
import 'package:google_fonts/google_fonts.dart';

class VoiceMusicControls extends ConsumerWidget {
  const VoiceMusicControls({super.key});

  void _showSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MusicSearchSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicNotifierProvider);
    final nowPlaying = state.nowPlaying;

    if (nowPlaying == null) {
      return Padding(
        padding: const EdgeInsets.all(FlickoSpacing.md),
        child: ElevatedButton.icon(
          onPressed: () => _showSearch(context),
          icon: const Icon(Icons.music_note),
          label: const Text('Play Music'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(FlickoColors.bgSecondary),
            foregroundColor: const Color(FlickoColors.textPrimary),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FlickoRadius.md),
            ),
          ),
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(FlickoSpacing.md),
      padding: const EdgeInsets.all(FlickoSpacing.md),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(FlickoRadius.lg),
        border: Border.all(color: const Color(FlickoColors.border).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Track Info
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(FlickoRadius.sm),
                  image: nowPlaying.imageUrl != null
                      ? DecorationImage(
                          image: NetworkImage(nowPlaying.imageUrl!),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: nowPlaying.imageUrl == null
                    ? const Icon(Icons.music_note, color: Color(FlickoColors.accentPrimary))
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nowPlaying.name,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      nowPlaying.artistName,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _showSearch(context),
                icon: const Icon(Icons.queue_music, color: Color(FlickoColors.accentPrimary)),
                tooltip: 'Add to queue',
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Progress (Mock)
          LinearProgressIndicator(
            value: 0.3, // Mock value
            backgroundColor: const Color(FlickoColors.bgPrimary),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(FlickoColors.accentPrimary)),
            minHeight: 4,
            borderRadius: BorderRadius.circular(2),
          ),

          const SizedBox(height: 16),

          // Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () {}, // Shuffle logic
                icon: const Icon(Icons.shuffle, size: 20),
                color: const Color(FlickoColors.textMuted),
              ),
              IconButton(
                onPressed: () {}, // Skip back
                icon: const Icon(Icons.skip_previous, size: 28),
                color: const Color(FlickoColors.textPrimary),
              ),
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(FlickoColors.accentPrimary).withValues(alpha: 0.1),
                ),
                child: IconButton(
                  onPressed: () => ref.read(musicNotifierProvider.notifier).togglePlayPause(),
                  icon: Icon(
                    state.isPaused ? Icons.play_arrow : Icons.pause,
                    size: 32,
                  ),
                  color: const Color(FlickoColors.accentPrimary),
                ),
              ),
              IconButton(
                onPressed: () => ref.read(musicNotifierProvider.notifier).skipForward(),
                icon: const Icon(Icons.skip_next, size: 28),
                color: const Color(FlickoColors.textPrimary),
              ),
              IconButton(
                onPressed: () => ref.read(musicNotifierProvider.notifier).stop(),
                icon: const Icon(Icons.stop, size: 20),
                color: const Color(FlickoColors.textDanger),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
