import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/services/soundboard_service.dart';
import 'package:mobile/data/models/soundboard_model.dart';
import 'package:mobile/data/clients/dio_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Soundboard Widget
///
/// Discord-style soundboard for playing sound effects in voice channels.
/// Loads trending sounds from MyInstants and supports live search.
class Soundboard extends ConsumerStatefulWidget {
  final String serverId;
  final String channelId;

  const Soundboard({
    super.key,
    required this.serverId,
    required this.channelId,
  });

  @override
  ConsumerState<Soundboard> createState() => _SoundboardState();
}

class _SoundboardState extends ConsumerState<Soundboard> {
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  late final SoundboardService _soundboardService;

  String _activeTab = 'trending';
  bool _isLoading = true;
  String? _currentlyPlayingId;
  double _volume = 0.8;
  Timer? _searchDebounce;

  List<SoundboardSound> _trendingSounds = [];
  List<SoundboardSound> _searchResults = [];
  List<SoundboardSound> _serverSounds = [];
  List<SoundboardSound> _favoriteSounds = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _soundboardService = SoundboardService(
      Supabase.instance.client,
      ref.read(dioProvider),
    );
    _loadSounds();
  }

  Future<void> _loadSounds() async {
    setState(() => _isLoading = true);
    try {
      final trending = await _soundboardService.getTrendingSounds();
      final server = await _soundboardService.getServerSounds(widget.serverId);
      final favorites = await _soundboardService.getFavoriteSounds();
      if (mounted) {
        setState(() {
          _trendingSounds = trending;
          _serverSounds = server;
          _favoriteSounds = favorites;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading sounds: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSearchChanged(String query) {
    _searchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _isSearching = false;
        _searchResults = [];
      });
      return;
    }
    setState(() => _isSearching = true);
    _searchDebounce = Timer(const Duration(milliseconds: 500), () async {
      try {
        final results = await _soundboardService.searchSounds(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        debugPrint('Error searching sounds: $e');
        if (mounted) setState(() => _isSearching = false);
      }
    });
  }

  List<SoundboardSound> get _currentSounds {
    if (_searchController.text.isNotEmpty) {
      return _searchResults;
    }

    switch (_activeTab) {
      case 'favorites':
        return _favoriteSounds;
      case 'server':
        return _serverSounds;
      case 'trending':
        return _trendingSounds;
      default:
        return [];
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _audioPlayer.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _playSound(SoundboardSound sound) async {
    try {
      setState(() => _currentlyPlayingId = sound.id);

      await _audioPlayer.setUrl(sound.url);
      await _audioPlayer.setVolume(_volume);
      await _audioPlayer.play();

      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) {
            setState(() => _currentlyPlayingId = null);
          }
        }
      });
    } catch (e) {
      debugPrint('Error playing sound: $e');
      setState(() => _currentlyPlayingId = null);
    }
  }

  void _stopSound() {
    _audioPlayer.stop();
    setState(() => _currentlyPlayingId = null);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(FlickoColors.textMuted),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Soundboard',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                _buildVolumeControl(),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(FlickoColors.textMuted)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
              decoration: InputDecoration(
                hintText: 'Search MyInstants sounds...',
                hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                prefixIcon: const Icon(Icons.search, color: Color(FlickoColors.textMuted)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(FlickoColors.textMuted)),
                        onPressed: () {
                          _searchController.clear();
                          _onSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(FlickoColors.bgTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_searchController.text.isEmpty) _buildTabBar(),
          const Divider(color: Color(FlickoColors.bgTertiary), height: 1),
          Expanded(
            child: _isLoading || _isSearching
                ? const Center(child: CircularProgressIndicator())
                : _buildSoundGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeControl() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgTertiary),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              _volume == 0 ? Icons.volume_off :
              _volume < 0.5 ? Icons.volume_down : Icons.volume_up,
              color: const Color(FlickoColors.textSecondary),
              size: 18,
            ),
            onPressed: () {
              setState(() => _volume = _volume == 0 ? 0.8 : 0);
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          ),
          SizedBox(
            width: 80,
            child: Slider(
              value: _volume,
              onChanged: (v) => setState(() => _volume = v),
              activeColor: const Color(FlickoColors.blurple),
              inactiveColor: const Color(FlickoColors.bgPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final tabs = [
      _TabData(key: 'trending', label: 'Trending', icon: Icons.trending_up),
      _TabData(key: 'server', label: 'Server', icon: Icons.music_note),
      _TabData(key: 'favorites', label: 'Favorites', icon: Icons.star),
    ];

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: tabs.map((tab) {
          final isActive = _activeTab == tab.key;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _activeTab = tab.key),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isActive
                          ? const Color(FlickoColors.blurple)
                          : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tab.icon,
                      size: 16,
                      color: isActive
                          ? const Color(FlickoColors.blurple)
                          : const Color(FlickoColors.textMuted),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tab.label,
                      style: GoogleFonts.inter(
                        color: isActive
                            ? const Color(FlickoColors.blurple)
                            : const Color(FlickoColors.textMuted),
                        fontSize: 13,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSoundGrid() {
    final sounds = _currentSounds;

    if (sounds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.music_off,
              size: 48,
              color: Color(FlickoColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isNotEmpty
                  ? 'No sounds found for "${_searchController.text}"'
                  : 'No sounds found',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: sounds.length,
      itemBuilder: (context, index) {
        final sound = sounds[index];
        final isPlaying = _currentlyPlayingId == sound.id;

        return GestureDetector(
          onTap: () => isPlaying ? _stopSound() : _playSound(sound),
          child: Container(
            decoration: BoxDecoration(
              color: isPlaying
                  ? const Color(FlickoColors.blurple)
                  : const Color(FlickoColors.bgTertiary),
              borderRadius: BorderRadius.circular(12),
              boxShadow: isPlaying
                  ? [
                      BoxShadow(
                        color: const Color(FlickoColors.blurple).withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isPlaying
                        ? Colors.white.withValues(alpha: 0.2)
                        : const Color(FlickoColors.bgSecondary),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: isPlaying
                        ? const Icon(Icons.stop, color: Colors.white, size: 24)
                        : Text(sound.emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    sound.name,
                    style: GoogleFonts.inter(
                      color: isPlaying ? Colors.white : const Color(FlickoColors.textPrimary),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isPlaying)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Container(
                      width: 20,
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
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

/// Data class for tab configuration
class _TabData {
  final String key;
  final String label;
  final IconData icon;

  _TabData({required this.key, required this.label, required this.icon});
}

/// Extension to show Soundboard
extension SoundboardExtension on BuildContext {
  void showSoundboard({
    required String serverId,
    required String channelId,
  }) {
    showModalBottomSheet(
      context: this,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Soundboard(
        serverId: serverId,
        channelId: channelId,
      ),
    );
  }
}
