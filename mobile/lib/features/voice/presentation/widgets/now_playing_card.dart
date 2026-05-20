import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/music_models.dart';

class NowPlayingCard extends StatelessWidget {
  final Track? track;
  final PlaybackStatus status;

  const NowPlayingCard({
    super.key,
    required this.track,
    required this.status,
  });

  static const _lime = Color(0xFF52B788);
  static const _grey = Color(0xFF1A1A1A);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: Colors.white, width: 3.5),
        boxShadow: const [BoxShadow(color: _lime, offset: Offset(8, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AlbumArt(imageUrl: track?.imageUrl, status: status),
          _TrackInfo(track: track),
        ],
      ),
    );
  }
}

class _AlbumArt extends StatelessWidget {
  final String? imageUrl;
  final PlaybackStatus status;

  const _AlbumArt({required this.imageUrl, required this.status});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          border: const Border(bottom: BorderSide(color: Colors.white, width: 3.5)),
          image: imageUrl != null
              ? DecorationImage(
                  image: NetworkImage(imageUrl!),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: imageUrl == null ? _EmptyArt(status: status) : null,
      ),
    );
  }
}

class _EmptyArt extends StatelessWidget {
  final PlaybackStatus status;
  const _EmptyArt({required this.status});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.waves_rounded,
            color: const Color(0xFF52B788).withValues(alpha: 0.25),
            size: 120,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF52B788), width: 1.5),
            ),
            child: Text(
              status == PlaybackStatus.loading ? 'LOADING...' : 'NO_SIGNAL',
              style: GoogleFonts.robotoMono(
                color: const Color(0xFF52B788),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackInfo extends StatelessWidget {
  final Track? track;
  const _TrackInfo({required this.track});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                color: const Color(0xFF52B788),
                child: Text(
                  'AUDIO_OUT',
                  style: GoogleFonts.robotoMono(
                    color: Colors.black,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (track?.albumName != null)
                Flexible(
                  child: Text(
                    track!.albumName!.toUpperCase(),
                    style: GoogleFonts.robotoMono(
                      color: Colors.white.withValues(alpha: 0.35),
                      fontSize: 9,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            (track?.name ?? 'IDLE_STATE').toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 0.95,
              letterSpacing: -1.5,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Text(
            (track?.artistName ?? 'SYSTEM_WAITING...').toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF52B788),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
