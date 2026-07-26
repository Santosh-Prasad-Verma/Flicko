import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/server_channels/voice/presentation/controllers/watch_together_controller.dart';
import 'dart:ui';

class WatchTogetherScreen extends ConsumerStatefulWidget {
  final String serverId;
  final String channelId;

  const WatchTogetherScreen({
    super.key,
    required this.serverId,
    required this.channelId,
  });

  @override
  ConsumerState<WatchTogetherScreen> createState() => _WatchTogetherScreenState();
}

class _WatchTogetherScreenState extends ConsumerState<WatchTogetherScreen> {
  VideoPlayerController? _playerController;
  bool _isPlayerInitialized = false;
  bool _showControls = true;
  Timer? _hideControlsTimer;
  bool _isSeeking = false;

  String? _currentUrl;

  @override
  void initState() {
    super.initState();
    // Bind sync handler from controller
    ref.read(watchTogetherControllerProvider.notifier).onSyncReceived = _handleRemoteSync;
    
    // Initialize player with current stream url if already resolved
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = ref.read(watchTogetherControllerProvider);
      if (state.resolvedStreamUrl != null) {
        _initializePlayer(state.resolvedStreamUrl!);
      }
    });
  }

  @override
  void dispose() {
    _hideControlsTimer?.cancel();
    _playerController?.dispose();
    super.dispose();
  }

  void _handleRemoteSync(int positionMs, bool playing) {
    if (_playerController == null || !_isPlayerInitialized) return;

    final targetPos = Duration(milliseconds: positionMs);
    final currentPos = _playerController!.value.position;
    final drift = (currentPos.inMilliseconds - positionMs).abs();

    // Auto-drift correction: If current playback position deviates by > 2 seconds, force seek
    if (drift > 2000) {
      _playerController!.seekTo(targetPos);
    }

    if (playing && !_playerController!.value.isPlaying) {
      _playerController!.play();
    } else if (!playing && _playerController!.value.isPlaying) {
      _playerController!.pause();
    }
  }

  Future<void> _initializePlayer(String url) async {
    if (_currentUrl == url) return;

    _currentUrl = url;
    if (!mounted) return;
    setState(() {
      _isPlayerInitialized = false;
    });

    if (_playerController != null) {
      _playerController!.removeListener(_onPlayerStateChanged);
      await _playerController!.dispose();
      _playerController = null;
    }

    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    _playerController = controller;

    try {
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _isPlayerInitialized = true;
      });

      // Synchronize listener
      controller.addListener(_onPlayerStateChanged);
      
      // If viewer, sync with current session anchor position immediately
      final state = ref.read(watchTogetherControllerProvider);
      if (state.session != null) {
        final initialPos = Duration(milliseconds: state.session!.anchorPositionMs);
        await controller.seekTo(initialPos);
        if (state.session!.anchorPlaying) {
          await controller.play();
        }
      }
    } catch (e) {
      debugPrint('Failed to initialize video player: $e');
    }
  }

  void _onPlayerStateChanged() {
    if (!mounted || _playerController == null) return;

    setState(() {});

    if (_isSeeking) return;

    final positionMs = _playerController!.value.position.inMilliseconds;
    final playing = _playerController!.value.isPlaying;

    // Report local state update to synchronization room
    ref.read(watchTogetherControllerProvider.notifier).updateSyncState(
          positionMs,
          playing,
        );
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
    });
    if (_showControls) {
      _startHideControlsTimer();
    }
  }

  void _startHideControlsTimer() {
    _hideControlsTimer?.cancel();
    _hideControlsTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  Future<void> _playPause() async {
    if (_playerController == null) return;

    final state = ref.read(watchTogetherControllerProvider);
    final canControl = state.isHost || (state.session?.settings.allowSeekByViewer ?? true);
    if (!canControl) return;

    if (_playerController!.value.isPlaying) {
      await _playerController!.pause();
    } else {
      await _playerController!.play();
    }
    _onPlayerStateChanged();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(watchTogetherControllerProvider);

    ref.listen<WatchTogetherState>(watchTogetherControllerProvider, (previous, next) {
      if (next.resolvedStreamUrl != null && next.resolvedStreamUrl != previous?.resolvedStreamUrl) {
        _initializePlayer(next.resolvedStreamUrl!);
      }
    });

    if (state.isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
        ),
      );
    }

    final hasVideo = _playerController != null && _isPlayerInitialized;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Video stage
          if (hasVideo)
            GestureDetector(
              onTap: _toggleControls,
              child: Center(
                child: AspectRatio(
                  aspectRatio: _playerController!.value.aspectRatio,
                  child: VideoPlayer(_playerController!),
                ),
              ),
            )
          else
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'Loading media stream...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),

          // Custom glass controls overlay
          if (_showControls) ...[
            _buildHeader(state),
            _buildFooter(state),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(WatchTogetherState state) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: Colors.black.withValues(alpha: 0.4),
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              bottom: 16,
              left: 16,
              right: 16,
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    ref.read(watchTogetherControllerProvider.notifier).leaveSession();
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.session?.mediaTitle ?? 'Watch Together',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        state.isHost ? 'Hosting Session' : 'Watching Live Stream',
                        style: GoogleFonts.inter(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.hd_outlined, color: Color(FlickoColors.brandLime), size: 22),
                  tooltip: 'Video Quality (${state.selectedQuality})',
                  onPressed: () => _showQualitySelectorSheet(context, state),
                ),
                const SizedBox(width: 4),
                if (state.isHost) ...[
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Color(FlickoColors.brandLime), size: 20),
                    tooltip: 'Change Video URL',
                    onPressed: () => _showChangeVideoSheet(context),
                  ),
                  const SizedBox(width: 8),
                ],
                if (state.isHost)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      ref.read(watchTogetherControllerProvider.notifier).endSession();
                      Navigator.pop(context);
                    },
                    child: const Text('End Session'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showQualitySelectorSheet(BuildContext context, WatchTogetherState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.hd_outlined, color: Color(FlickoColors.brandLime), size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Select Stream Quality',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (state.availableQualities.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Auto Quality Only',
                    style: GoogleFonts.inter(color: Colors.white70),
                  ),
                )
              else
                ...state.availableQualities.keys.map((quality) {
                  final isSelected = state.selectedQuality == quality;
                  return ListTile(
                    title: Text(
                      quality,
                      style: GoogleFonts.inter(
                        color: isSelected ? const Color(FlickoColors.brandLime) : Colors.white,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Color(FlickoColors.brandLime))
                        : null,
                    onTap: () {
                      Navigator.pop(context);
                      ref.read(watchTogetherControllerProvider.notifier).selectQuality(quality);
                    },
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  void _showChangeVideoSheet(BuildContext context) {
    final controller = TextEditingController(text: ref.read(watchTogetherControllerProvider).session?.mediaUrl);
    String selectedKind = ref.read(watchTogetherControllerProvider).session?.mediaKind ?? 'youtube';

    final List<Map<String, String>> presets = const [
      {
        'title': 'Big Buck Bunny (MP4)',
        'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        'kind': 'mp4'
      },
      {
        'title': 'Sintel Trailer (HLS)',
        'url': 'https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8',
        'kind': 'hls'
      },
      {
        'title': 'Elephants Dream (MP4)',
        'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        'kind': 'mp4'
      },
      {
        'title': 'Flicko Promo (YT)',
        'url': 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
        'kind': 'youtube'
      }
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.bgSecondary).withValues(alpha: 0.9),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Change Stream Media',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Update the video URL for all viewers in this room.',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textSecondary),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      initialValue: selectedKind,
                      dropdownColor: const Color(FlickoColors.bgSecondary),
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                      decoration: const InputDecoration(
                        labelText: 'Media Stream Type',
                        labelStyle: TextStyle(color: Colors.white54),
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'youtube', child: Text('YouTube Video')),
                        DropdownMenuItem(value: 'vimeo', child: Text('Vimeo Stream')),
                        DropdownMenuItem(value: 'mp4', child: Text('Direct MP4 Link')),
                        DropdownMenuItem(value: 'hls', child: Text('HLS Stream (m3u8)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() => selectedKind = val);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      style: GoogleFonts.inter(color: Colors.white),
                      decoration: const InputDecoration(
                        labelText: 'Media URL',
                        labelStyle: TextStyle(color: Colors.white54),
                        hintText: 'https://...',
                        filled: true,
                        fillColor: Colors.black26,
                        border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'QUICK PRESETS',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presets.map((preset) {
                        return ActionChip(
                          backgroundColor: const Color(FlickoColors.bgTertiary),
                          side: const BorderSide(color: Color(0xFF222222)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          label: Text(
                            preset['title']!,
                            style: GoogleFonts.inter(
                              color: const Color(FlickoColors.brandLime),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () {
                            setModalState(() {
                              selectedKind = preset['kind']!;
                              controller.text = preset['url']!;
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(FlickoColors.brandLime),
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () {
                          final url = controller.text.trim();
                          if (url.isEmpty) return;

                          String title = 'Watch Together Video';
                          final matchingPreset = presets.firstWhere(
                            (p) => p['url'] == url,
                            orElse: () => {},
                          );
                          if (matchingPreset.isNotEmpty) {
                            title = matchingPreset['title']!;
                          } else if (url.contains('youtube.com') || url.contains('youtu.be')) {
                            title = 'YouTube Stream';
                          }

                          ref.read(watchTogetherControllerProvider.notifier).changeMedia(
                                url,
                                title,
                                selectedKind,
                              );
                          Navigator.pop(context);
                        },
                        child: Text(
                          'Update Stream',
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFooter(WatchTogetherState state) {
    final position = _playerController?.value.position ?? Duration.zero;
    final duration = _playerController?.value.duration ?? Duration.zero;

    final canControl = state.isHost || (state.session?.settings.allowSeekByViewer ?? true);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            color: Colors.black.withValues(alpha: 0.4),
            padding: EdgeInsets.only(
              top: 16,
              bottom: MediaQuery.of(context).padding.bottom + 16,
              left: 16,
              right: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Slider timeline progress bar
                if (_playerController != null)
                  Row(
                    children: [
                      Text(
                        _formatDuration(position),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      Expanded(
                        child: Slider(
                          value: position.inMilliseconds.toDouble().clamp(
                                0.0,
                                duration.inMilliseconds.toDouble(),
                              ),
                          max: duration.inMilliseconds.toDouble(),
                          activeColor: const Color(FlickoColors.blurple),
                          inactiveColor: Colors.white24,
                          onChanged: canControl
                              ? (value) {
                                  setState(() {
                                    _isSeeking = true;
                                  });
                                }
                              : null,
                          onChangeEnd: (value) async {
                            if (_playerController != null) {
                              await _playerController!
                                  .seekTo(Duration(milliseconds: value.toInt()));
                              setState(() {
                                _isSeeking = false;
                              });
                              _onPlayerStateChanged();
                            }
                          },
                        ),
                      ),
                      Text(
                        _formatDuration(duration),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ],
                  ),

                const SizedBox(height: 12),

                // Controls row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 32,
                      icon: const Icon(Icons.replay_10, color: Colors.white),
                      onPressed: canControl && _playerController != null
                          ? () async {
                              if (_playerController == null) return;
                              final newPos = position - const Duration(seconds: 10);
                              await _playerController!.seekTo(
                                newPos < Duration.zero ? Duration.zero : newPos,
                              );
                              _onPlayerStateChanged();
                            }
                          : null,
                    ),
                    const SizedBox(width: 16),
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: canControl && _playerController != null
                          ? const Color(FlickoColors.blurple)
                          : Colors.grey.withValues(alpha: 0.3),
                      child: IconButton(
                        iconSize: 32,
                        icon: Icon(
                          _playerController?.value.isPlaying == true
                              ? Icons.pause
                              : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        onPressed: canControl && _playerController != null ? _playPause : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      iconSize: 32,
                      icon: const Icon(Icons.forward_10, color: Colors.white),
                      onPressed: canControl && _playerController != null
                          ? () async {
                              if (_playerController == null) return;
                              final newPos = position + const Duration(seconds: 10);
                              await _playerController!.seekTo(
                                newPos > duration ? duration : newPos,
                              );
                              _onPlayerStateChanged();
                            }
                          : null,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
