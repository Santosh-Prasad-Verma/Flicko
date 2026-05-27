import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../application/sonic_drip_notifier.dart';
import '../../data/lyrics_service.dart';
import '../../domain/music_models.dart';

/// Lyrics bottom sheet
class LyricsSheet extends ConsumerWidget {
  final Track track;

  const LyricsSheet({
    super.key,
    required this.track,
    // Kept for backwards compatibility with callers that still pass an
    // initial position; ignored in favour of the live state stream.
    Duration position = Duration.zero,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the live playback position so synced lyrics actually scroll.
    final position = ref.watch(
      sonicDripProvider.select((s) => s.playback.position),
    );

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Color(0xFF0C0C0E),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Album art
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 48,
                    height: 48,
                    color: const Color(0xFF52B788).withValues(alpha: 0.2),
                    child: track.imageUrl != null
                        ? Image.network(
                            track.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.music_note,
                              color: Color(0xFF52B788),
                            ),
                          )
                        : const Icon(Icons.music_note, color: Color(0xFF52B788)),
                  ),
                ),
                const SizedBox(width: 12),
                // Track info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        track.name,
                        style: GoogleFonts.inter(
                          color: const Color(0xFFFBF9FA),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        track.artistName,
                        style: GoogleFonts.inter(
                          color: const Color(0xFF71717A),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF71717A)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Lyrics
          Expanded(
            child: SyncedLyricsWidget(
              track: track,
              position: position,
              onSeek: (pos) {
                final dur = ref.read(sonicDripProvider).playback.duration;
                if (dur.inMilliseconds > 0) {
                  ref
                      .read(sonicDripProvider.notifier)
                      .seekTo(pos.inMilliseconds / dur.inMilliseconds);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
