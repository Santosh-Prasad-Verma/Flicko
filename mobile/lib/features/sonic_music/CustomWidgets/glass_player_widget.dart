import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:mobile/features/sonic_music/Helpers/playlist.dart';
import 'package:mobile/features/sonic_music/Screens/Player/audioplayer.dart';
import 'package:rxdart/rxdart.dart';
import 'package:share_plus/share_plus.dart';

class DraggableGlassPlayer extends StatefulWidget {
  const DraggableGlassPlayer({super.key});

  @override
  _DraggableGlassPlayerState createState() => _DraggableGlassPlayerState();
}

class _DraggableGlassPlayerState extends State<DraggableGlassPlayer> {
  final AudioPlayerHandler audioHandler = GetIt.I<AudioPlayerHandler>();
  Offset _position = const Offset(20, 120); // Initial position
  bool _isMinimized = false;

  late final Stream<Duration> _bufferedPositionStream = audioHandler.playbackState
      .map((state) => state.bufferedPosition)
      .distinct();
  late final Stream<Duration?> _durationStream =
      audioHandler.mediaItem.map((item) => item?.duration).distinct();
  late final Stream<PositionData> _positionDataStream =
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        AudioService.position,
        _bufferedPositionStream,
        _durationStream,
        (position, bufferedPosition, duration) =>
            PositionData(position, bufferedPosition, duration ?? Duration.zero),
      ).distinct();

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '$minutes:${twoDigits(seconds)}';
  }

  String _formatRemaining(Duration position, Duration duration) {
    final remaining = duration - position;
    if (remaining.isNegative) return '0:00';
    return '-${_formatDuration(remaining)}';
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox();

        return StreamBuilder<PlaybackState>(
          stream: audioHandler.playbackState,
          builder: (context, stateSnapshot) {
            final state = stateSnapshot.data;
            final isPlaying = state?.playing ?? false;
            
            // Only show widget if playing or paused (has active session)
            if (state == null || state.processingState == AudioProcessingState.idle) {
              return const SizedBox();
            }

            if (_isMinimized) {
              return Positioned(
                left: _position.dx,
                top: _position.dy,
                child: GestureDetector(
                  onPanUpdate: (details) {
                    setState(() {
                      _position += details.delta;
                      // Restrict boundaries
                      _position = Offset(
                        max(10, min(_position.dx, size.width - 70)),
                        max(50, min(_position.dy, size.height - 150)),
                      );
                    });
                  },
                  onTap: () {
                    setState(() {
                      _isMinimized = false;
                    });
                  },
                  child: Container(
                    height: 56,
                    width: 56,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0720).withOpacity(0.85),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1.5),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black45,
                          blurRadius: 10,
                          offset: Offset(0, 4),
                        )
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Center(
                          child: Icon(
                            isPlaying ? Icons.music_note_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }

            // Expanded Square Glassmorphic Widget (Image 2 design)
            return Positioned(
              left: _position.dx,
              top: _position.dy,
              child: GestureDetector(
                onPanUpdate: (details) {
                  setState(() {
                    _position += details.delta;
                    // Restrict boundaries
                    _position = Offset(
                      max(10, min(_position.dx, size.width - 300)),
                      max(50, min(_position.dy, size.height - 350)),
                    );
                  });
                },
                child: Container(
                  height: 240,
                  width: 280,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.92),
                    borderRadius: BorderRadius.circular(24.0),
                    border: Border.all(color: Colors.white.withOpacity(0.08), width: 1.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black54,
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      )
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24.0),
                    child: Stack(
                      children: [
                        // Blurred album artwork as background tint
                        Positioned.fill(
                          child: mediaItem.artUri.toString().startsWith('file')
                              ? Image.file(
                                  File(mediaItem.artUri!.toFilePath()),
                                  fit: BoxFit.cover,
                                )
                              : CachedNetworkImage(
                                  imageUrl: mediaItem.artUri.toString(),
                                  fit: BoxFit.cover,
                                  errorWidget: (context, _, __) => const ColoredBox(color: Color(0xFF0C0720)),
                                ),
                        ),
                        Positioned.fill(
                          child: BackdropFilter(
                            filter: ui.ImageFilter.blur(sigmaX: 25.0, sigmaY: 25.0),
                            child: Container(
                              color: Colors.black.withOpacity(0.85),
                            ),
                          ),
                        ),

                        // Main controls and layout
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              // Top Info Row (Artist Profile circle, Title, Artist, Share, Heart)
                              Row(
                                children: [
                                  // Rounded Artist Profile / Artwork circle
                                  Container(
                                    height: 36,
                                    width: 36,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white30, width: 1.0),
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(18),
                                      child: mediaItem.artUri.toString().startsWith('file')
                                          ? Image.file(
                                              File(mediaItem.artUri!.toFilePath()),
                                              fit: BoxFit.cover,
                                            )
                                          : CachedNetworkImage(
                                              imageUrl: mediaItem.artUri.toString(),
                                              fit: BoxFit.cover,
                                              errorWidget: (context, _, __) => const Icon(Icons.music_note_rounded, color: Colors.white70),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Song / Artist details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          mediaItem.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          mediaItem.artist ?? "Unknown",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.6),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Share Icon
                                  IconButton(
                                    icon: const Icon(Icons.share_outlined, color: Colors.white70, size: 18),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: () async {
                                      final url = mediaItem.extras?['perma_url']?.toString();
                                      if (url != null) {
                                        await Share.share(url);
                                      }
                                    },
                                  ),
                                  const SizedBox(width: 8),
                                  // Heart Icon (Likes)
                                  ValueListenableBuilder(
                                    valueListenable: Hive.box('Favorite Songs').listenable(),
                                    builder: (context, Box box, _) {
                                      final bool liked = checkPlaylist('Favorite Songs', mediaItem.id);
                                      return IconButton(
                                        icon: Icon(
                                          liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                          color: liked ? Colors.redAccent : Colors.white70,
                                          size: 18,
                                        ),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () {
                                          liked
                                              ? removeLiked(mediaItem.id)
                                              : addItemToPlaylist('Favorite Songs', mediaItem);
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),

                              // Progress Slider with time labels in the center
                              StreamBuilder<PositionData>(
                                stream: _positionDataStream,
                                builder: (context, posSnapshot) {
                                  final posData = posSnapshot.data ??
                                      PositionData(Duration.zero, Duration.zero, mediaItem.duration ?? Duration.zero);
                                  
                                  final double totalMs = posData.duration.inMilliseconds.toDouble();
                                  final double currentMs = min(posData.position.inMilliseconds.toDouble(), totalMs);

                                  return Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Time Labels Row
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              _formatDuration(posData.position),
                                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
                                            ),
                                            Text(
                                              _formatRemaining(posData.position, posData.duration),
                                              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Progress bar line
                                      SliderTheme(
                                        data: SliderTheme.of(context).copyWith(
                                          trackHeight: 2.5,
                                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 4.5),
                                          overlayShape: SliderComponentShape.noThumb,
                                          activeTrackColor: Colors.white,
                                          inactiveTrackColor: Colors.white24,
                                          thumbColor: Colors.white,
                                        ),
                                        child: Slider(
                                          max: totalMs > 0 ? totalMs : 100,
                                          value: currentMs,
                                          onChanged: (newVal) {
                                            audioHandler.seek(Duration(milliseconds: newVal.round()));
                                          },
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),

                              // Bottom Quick Control Buttons (Minimize, Skip Previous, Play/Pause, Skip Next, Maximize to screen)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // Minimize button
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.remove_circle_outline_rounded, color: Colors.white54, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _isMinimized = true;
                                      });
                                    },
                                  ),
                                  // Skip Previous
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.skip_previous_rounded, color: Colors.white, size: 28),
                                    onPressed: audioHandler.skipToPrevious,
                                  ),
                                  // Play/Pause circular container
                                  GestureDetector(
                                    onTap: isPlaying ? audioHandler.pause : audioHandler.play,
                                    child: Container(
                                      height: 44,
                                      width: 44,
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                        color: Colors.black,
                                        size: 28,
                                      ),
                                    ),
                                  ),
                                  // Skip Next
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.skip_next_rounded, color: Colors.white, size: 28),
                                    onPressed: audioHandler.skipToNext,
                                  ),
                                  // Maximize to full player screen
                                  IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    icon: const Icon(Icons.open_in_full_rounded, color: Colors.white70, size: 18),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        PageRouteBuilder(
                                          opaque: false,
                                          pageBuilder: (_, __, ___) => const PlayScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
