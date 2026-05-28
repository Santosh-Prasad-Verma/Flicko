import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/core/services/flicko_haptics.dart';
import 'package:mobile/data/models/soundboard_model.dart';
import 'package:mobile/data/services/soundboard_service.dart';
import 'package:mobile/features/store/data/custom_recording_service.dart';

class MyInstantsExplorerScreen extends ConsumerStatefulWidget {
  const MyInstantsExplorerScreen({super.key});

  @override
  ConsumerState<MyInstantsExplorerScreen> createState() => _MyInstantsExplorerScreenState();
}

class _MyInstantsExplorerScreenState extends ConsumerState<MyInstantsExplorerScreen> {
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<SoundboardSound> _sounds = [];
  Set<String> _downloadedSoundIds = {};
  Set<String> _downloadingIds = {};
  
  bool _isLoading = true;
  String? _playingId;
  String _searchQuery = '';

  static const Color _neonGreen = Color(FlickoColors.accentPrimary);
  static const Color _neonPink = Color(FlickoColors.pink);
  static const Color _bg = Color(FlickoColors.bgPrimary);
  static const Color _cardBg = Color(FlickoColors.bgSecondary);
  static const Color _muted = Color(FlickoColors.textMuted);

  @override
  void initState() {
    super.initState();
    _loadData();
    _audioPlayer.playerStateStream.listen((playerState) {
      if (playerState.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() {
            _playingId = null;
          });
        }
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadDownloadedSounds();
    await _fetchSounds();
  }

  Future<void> _loadDownloadedSounds() async {
    try {
      final custom = await ref.read(customRecordingServiceProvider).getCustomRecordings();
      if (mounted) {
        setState(() {
          _downloadedSoundIds = custom.map((r) => r.id).toSet();
        });
      }
    } catch (e) {
      debugPrint('Error loading downloaded sounds: $e');
    }
  }

  Future<void> _fetchSounds() async {
    try {
      List<SoundboardSound> fetched;
      if (_searchQuery.trim().isEmpty) {
        fetched = await ref.read(soundboardServiceProvider).getTrendingSounds();
      } else {
        fetched = await ref.read(soundboardServiceProvider).searchSounds(_searchQuery);
      }
      if (mounted) {
        setState(() {
          _sounds = fetched;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching sounds: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearch(String query) {
    setState(() {
      _searchQuery = query;
      _isLoading = true;
    });
    _fetchSounds();
  }

  Future<void> _previewSound(SoundboardSound sound) async {
    FlickoHaptics.light();
    if (_playingId == sound.id) {
      await _audioPlayer.stop();
      setState(() {
        _playingId = null;
      });
      return;
    }

    setState(() {
      _playingId = sound.id;
    });

    try {
      await _audioPlayer.stop();
      await _audioPlayer.setUrl(sound.url);
      await _audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing preview: $e');
      if (mounted) {
        setState(() {
          _playingId = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to play preview'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadSound(SoundboardSound sound) async {
    if (_downloadedSoundIds.contains(sound.id)) return;
    
    FlickoHaptics.medium();
    setState(() {
      _downloadingIds.add(sound.id);
    });

    try {
      final response = await http.get(Uri.parse(sound.url)).timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'sound_${sound.id.replaceAll('myinstants_', '')}.mp3';
        final file = File('${appDir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        final record = CustomSoundRecord(
          id: sound.id,
          name: sound.name,
          emoji: sound.emoji,
          waveformPoints: List.generate(20, (index) => 0.2 + (index % 4) * 0.2),
          duration: sound.duration.toDouble(),
          createdAt: DateTime.now(),
          url: file.path,
        );

        await ref.read(customRecordingServiceProvider).saveRecording(record);
        await _loadDownloadedSounds();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: Colors.black,
              content: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: _neonGreen, width: 2),
                  color: Colors.black,
                ),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                child: Row(
                  children: [
                    Text(sound.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ADDED "${sound.name.toUpperCase()}" TO SOUNDBOARD!',
                        style: GoogleFonts.inter(
                          color: _neonGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              behavior: SnackBarBehavior.floating,
              elevation: 0,
            ),
          );
        }
      } else {
        throw Exception('Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error downloading sound: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download sound: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _downloadingIds.remove(sound.id);
        });
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'SOUNDBOARD_EXPLORER',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 2,
            fontSize: 18,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Input with Neo-Brutalist styling
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: _neonGreen, width: 2),
                boxShadow:  [
                  BoxShadow(color: _neonGreen.withValues(alpha: 0.25),
                    blurRadius: 14, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(color: Colors.white),
                onChanged: (val) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'SEARCH MYINSTANTS CLIPS...',
                  hintStyle: GoogleFonts.inter(color: _muted, fontSize: 13),
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.search, color: _neonGreen),
                    onPressed: () => _onSearch(_searchController.text),
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white),
                          onPressed: () {
                            _searchController.clear();
                            _onSearch('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onSubmitted: _onSearch,
              ),
            ),
          ),
          
          const SizedBox(height: 12),

          // Sub-heading
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  color: _neonPink,
                ),
                const SizedBox(width: 8),
                Text(
                  _searchQuery.isEmpty ? 'TRENDING SOUNDS' : 'SEARCH RESULTS FOR "${_searchQuery.toUpperCase()}"',
                  style: GoogleFonts.inter(
                    color: _neonPink,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Main Sound Grid
          Expanded(
            child: _isLoading
                ? _buildLoadingGrid()
                : _sounds.isEmpty
                    ? _buildEmptyState()
                    : _buildSoundGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: _cardBg,
            border: Border.all(color: _muted.withOpacity(0.3), width: 1.5),
          ),
        ).animate(onPlay: (controller) => controller.repeat(reverse: true))
         .shimmer(duration: 1.seconds, color: Colors.white10);
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.music_off_outlined, size: 48, color: _muted),
          const SizedBox(height: 16),
          Text(
            'NO SOUNDS FOUND',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'TRY SEARCHING FOR SOMETHING ELSE',
            style: GoogleFonts.inter(color: _muted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3,
      ),
      itemCount: _sounds.length,
      itemBuilder: (context, index) {
        final sound = _sounds[index];
        final isPlaying = _playingId == sound.id;
        final isDownloaded = _downloadedSoundIds.contains(sound.id);
        final isDownloading = _downloadingIds.contains(sound.id);

        final borderColor = isPlaying ? _neonPink : Colors.white24;

        return GestureDetector(
          onTap: () => _previewSound(sound),
          child: Container(
            decoration: BoxDecoration(
              color: _cardBg,
              border: Border.all(
                color: borderColor,
                width: isPlaying ? 2.5 : 1.5,
              ),
              boxShadow: isPlaying
                  ? [
                      BoxShadow(color: _neonPink.withValues(alpha: 0.25),
                        blurRadius: 14, offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                // Active playing overlay animation
                if (isPlaying)
                  Positioned.fill(
                    child: Container(
                      color: _neonPink.withOpacity(0.05),
                    ).animate(onPlay: (c) => c.repeat(reverse: true))
                     .fadeIn(duration: 300.ms),
                  ),

                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Emoji & Title row
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: isPlaying ? _neonPink.withOpacity(0.2) : Colors.black,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              sound.emoji,
                              style: const TextStyle(fontSize: 20),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              sound.name.toUpperCase(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),

                      // Player status indicator or info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Play/Pause icon indicator
                          Icon(
                            isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
                            color: isPlaying ? _neonPink : Colors.white70,
                            size: 20,
                          ),

                          // Download / Status Button
                          GestureDetector(
                            onTap: () => _downloadSound(sound),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: isDownloaded
                                    ? _neonGreen.withOpacity(0.15)
                                    : Colors.black,
                                border: Border.all(
                                  color: isDownloaded ? _neonGreen : Colors.white24,
                                  width: 1,
                                ),
                              ),
                              child: isDownloading
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(_neonGreen),
                                      ),
                                    )
                                  : Icon(
                                      isDownloaded ? Icons.check : Icons.download_rounded,
                                      color: isDownloaded ? _neonGreen : Colors.white,
                                      size: 14,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
