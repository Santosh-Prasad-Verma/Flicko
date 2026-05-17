import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../application/sonic_drip_notifier.dart';
import '../../domain/music_models.dart';

class QueueList extends ConsumerWidget {
  final List<Track> queue;
  const QueueList({super.key, required this.queue});

  static const _lime = Color(0xFFCBEF17);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              color: _lime,
              child: Text(
                'QUEUE_MANIFEST',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Divider(
                color: Colors.white.withValues(alpha: 0.15),
                thickness: 2,
              ),
            ),
            if (queue.isNotEmpty) ...[
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => ref.read(sonicDripProvider.notifier).clearQueue(),
                child: Text(
                  'CLEAR',
                  style: GoogleFonts.robotoMono(
                    color: Colors.red.withValues(alpha: 0.6),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        if (queue.isEmpty)
          _EmptyQueue()
        else
          ...queue.asMap().entries.map(
                (entry) => _QueueItem(
                  index: entry.key,
                  track: entry.value,
                ),
              ),
      ],
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 2,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.queue_music_rounded,
            color: Colors.white.withValues(alpha: 0.08),
            size: 40,
          ),
          const SizedBox(height: 14),
          Text(
            'QUEUE_BUFFER_EMPTY',
            style: GoogleFonts.robotoMono(
              color: Colors.white.withValues(alpha: 0.1),
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tap ADD_TO_DRIP to search and add tracks',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.2),
              fontSize: 11,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _QueueItem extends ConsumerWidget {
  final int index;
  final Track track;

  const _QueueItem({required this.index, required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTrack = ref.watch(
      sonicDripProvider.select((s) => s.playback.currentTrack),
    );
    final isCurrent = currentTrack?.id == track.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(
          color: isCurrent ? const Color(0xFFCBEF17) : Colors.white,
          width: isCurrent ? 2.5 : 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isCurrent ? const Color(0xFFCBEF17) : Colors.white,
            offset: const Offset(3, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Index / playing indicator
          SizedBox(
            width: 28,
            height: 28,
            child: isCurrent
                ? Container(
                    color: const Color(0xFFCBEF17),
                    child: const Icon(Icons.equalizer, color: Colors.black, size: 16),
                  )
                : Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFCBEF17), width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.robotoMono(
                          color: const Color(0xFFCBEF17),
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(width: 16),
          // Track info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.name.toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    color: isCurrent ? const Color(0xFFCBEF17) : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  track.artistName.toUpperCase(),
                  style: GoogleFonts.robotoMono(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Duration
          if (track.durationMs != null)
            Text(
              track.durationFormatted,
              style: GoogleFonts.robotoMono(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 11,
              ),
            ),
          const SizedBox(width: 8),
          // Remove button
          GestureDetector(
            onTap: () => ref.read(sonicDripProvider.notifier).removeFromQueue(track.id),
            child: Icon(
              Icons.close,
              color: Colors.white.withValues(alpha: 0.3),
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
