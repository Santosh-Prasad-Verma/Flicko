import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/core/services/flicko_haptics.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';
import 'package:mobile/data/models/soundboard_model.dart';
import 'package:mobile/data/services/soundboard_service.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/custom_recording_service.dart';
import 'package:mobile/features/store/data/badge_alchemy_service.dart';

class SoundboardSheet extends ConsumerStatefulWidget {
  final String serverId;
  const SoundboardSheet({super.key, required this.serverId});

  @override
  ConsumerState<SoundboardSheet> createState() => _SoundboardSheetState();
}

class _SoundboardSheetState extends ConsumerState<SoundboardSheet> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  double _volume = 0.5;
  String? _playingId;
  Timer? _searchDebounce;

  List<SoundboardSound> _trendingSounds = [];
  List<SoundboardSound> _searchResults = [];
  bool _isLoadingTrending = true;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadTrendingSounds();
  }

  Future<void> _loadTrendingSounds() async {
    setState(() => _isLoadingTrending = true);
    try {
      final sounds = await ref.read(soundboardServiceProvider).getTrendingSounds();
      if (mounted) {
        setState(() {
          _trendingSounds = sounds;
          _isLoadingTrending = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading trending sounds: $e');
      if (mounted) setState(() => _isLoadingTrending = false);
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
        final results = await ref.read(soundboardServiceProvider).searchSounds(query);
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

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _playSound(SoundboardSound sound) async {
    setState(() => _playingId = sound.id);
    FlickoHaptics.light();

    // Play and broadcast via VoiceController
    await ref.read(voiceControllerProvider.notifier).sendSoundboardSound(sound);

    // Track play count in backend
    final activeChannelId = ref.read(voiceControllerProvider).activeChannelId ?? '';
    await ref.read(soundboardServiceProvider).playSound(sound.id, serverId: widget.serverId, channelId: activeChannelId);

    // Increment alchemy stat
    ref.read(badgeAlchemyProvider.notifier).incrementSoundsPlayed();

    // Simulate playback duration for UI feedback
    Future.delayed(Duration(seconds: sound.duration), () {
      if (mounted) {
        setState(() => _playingId = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgPrimary),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(FlickoRadius.lg)),
      ),
      child: Column(
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.textMuted).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FlickoSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Soundboard',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(FlickoColors.textPrimary),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Color(FlickoColors.textMuted)),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.all(FlickoSpacing.md),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: Color(FlickoColors.textPrimary)),
              decoration: InputDecoration(
                hintText: 'Search MyInstants sounds...',
                hintStyle: const TextStyle(color: Color(FlickoColors.textMuted)),
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
                fillColor: const Color(FlickoColors.bgSecondary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FlickoRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          // Tabs (hidden during search)
          if (_searchController.text.isEmpty)
            TabBar(
              controller: _tabController,
              labelColor: const Color(FlickoColors.accentPrimary),
              unselectedLabelColor: const Color(FlickoColors.textMuted),
              indicatorColor: const Color(FlickoColors.accentPrimary),
              labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(text: 'Favorites', icon: Icon(Icons.star, size: 20)),
                Tab(text: 'Server', icon: Icon(Icons.music_note, size: 20)),
                Tab(text: 'Trending', icon: Icon(Icons.trending_up, size: 20)),
                Tab(text: 'Purchased', icon: Icon(Icons.shopping_bag, size: 20)),
              ],
            ),

          // Volume
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FlickoSpacing.md, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _volume == 0 ? Icons.volume_mute : Icons.volume_down,
                  color: const Color(FlickoColors.textMuted),
                  size: 18,
                ),
                Expanded(
                  child: Slider(
                    value: _volume,
                    onChanged: (v) => setState(() => _volume = v),
                    activeColor: const Color(FlickoColors.accentPrimary),
                    inactiveColor: const Color(FlickoColors.bgTertiary),
                  ),
                ),
                Text(
                  '${(_volume * 100).toInt()}%',
                  style: const TextStyle(color: Color(FlickoColors.textMuted), fontSize: 12),
                ),
              ],
            ),
          ),

          // Grid
          Expanded(
            child: _searchController.text.isNotEmpty
                ? _buildSearchResultsGrid()
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSoundGrid(isFavorite: true),
                      _buildSoundGrid(serverId: widget.serverId),
                      _buildTrendingGrid(),
                      _buildPurchasedSoundsGrid(),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsGrid() {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.music_off, size: 48, color: const Color(FlickoColors.textMuted).withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            Text(
              'No sounds found for "${_searchController.text}"',
              style: const TextStyle(color: Color(FlickoColors.textMuted)),
            ),
          ],
        ),
      );
    }
    return _buildSoundGridFromList(_searchResults);
  }

  Widget _buildTrendingGrid() {
    if (_isLoadingTrending) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_trendingSounds.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.trending_up, size: 48, color: const Color(FlickoColors.textMuted).withValues(alpha: 0.2)),
            const SizedBox(height: 16),
            const Text(
              'No trending sounds available',
              style: TextStyle(color: Color(FlickoColors.textMuted)),
            ),
          ],
        ),
      );
    }
    return _buildSoundGridFromList(_trendingSounds);
  }

  Widget _buildSoundGrid({String? serverId, bool isFavorite = false}) {
    return FutureBuilder<List<SoundboardSound>>(
      future: isFavorite
          ? ref.read(soundboardServiceProvider).getFavoriteSounds()
          : ref.read(soundboardServiceProvider).getServerSounds(serverId ?? widget.serverId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final sounds = snapshot.data ?? [];

        if (sounds.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.music_off, size: 48, color: const Color(FlickoColors.textMuted).withValues(alpha: 0.2)),
                const SizedBox(height: 16),
                Text(
                  isFavorite ? 'No favorites yet' : 'No sounds found',
                  style: const TextStyle(color: Color(FlickoColors.textMuted)),
                ),
              ],
            ),
          );
        }

        return _buildSoundGridFromList(sounds);
      },
    );
  }

  Widget _buildSoundGridFromList(List<SoundboardSound> sounds) {
    return GridView.builder(
      padding: const EdgeInsets.all(FlickoSpacing.md),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.2,
      ),
      itemCount: sounds.length,
      itemBuilder: (context, index) {
        final sound = sounds[index];
        final isPlaying = _playingId == sound.id;

        return InkWell(
          onTap: () => _playSound(sound),
          onLongPress: () {
            ref.read(soundboardServiceProvider).toggleFavorite(sound.id);
            FlickoHaptics.medium();
            setState(() {}); // Refresh list
          },
          borderRadius: BorderRadius.circular(FlickoRadius.md),
          child: Container(
            decoration: BoxDecoration(
              color: isPlaying ? const Color(FlickoColors.accentPrimary) : const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(FlickoRadius.md),
              border: Border.all(
                color: isPlaying ? const Color(FlickoColors.accentPrimary) : const Color(FlickoColors.border).withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(sound.emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 4),
                Text(
                  sound.name,
                  style: TextStyle(
                    color: isPlaying ? Colors.white : const Color(FlickoColors.textPrimary),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPurchasedSoundsGrid() {
    final purchasesAsync = ref.watch(userPurchasesProvider);

    return purchasesAsync.when(
      data: (purchases) {
        final soundPurchases = purchases.where((p) => p.productType.toUpperCase() == 'SOUNDS').toList();
        final List<SoundboardSound> purchasedSounds = [];
        for (final p in soundPurchases) {
          purchasedSounds.addAll(_getSoundsForPurchasedItem(p.productId));
        }

        return FutureBuilder<List<CustomSoundRecord>>(
          future: ref.read(customRecordingServiceProvider).getCustomRecordings(),
          builder: (context, snapshot) {
            final customSounds = snapshot.data ?? [];
            final mappedCustom = customSounds.map((c) => SoundboardSound(
              id: c.id,
              serverId: 'custom',
              name: c.name.toUpperCase(),
              emoji: c.emoji,
              url: c.url ?? 'https://www.myinstants.com/media/sounds/vine-boom.mp3',
              duration: c.duration.toInt(),
              creatorId: 'user',
              createdAt: c.createdAt,
            )).toList();

            final allSounds = [...purchasedSounds, ...mappedCustom];

            if (allSounds.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shopping_bag_outlined, size: 48, color: const Color(FlickoColors.textMuted).withValues(alpha: 0.2)),
                    const SizedBox(height: 16),
                    const Text(
                      'No purchased store sounds yet',
                      style: TextStyle(color: Color(FlickoColors.textMuted)),
                    ),
                  ],
                ),
              );
            }

            return _buildSoundGridFromList(allSounds);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.red))),
    );
  }

  List<SoundboardSound> _getSoundsForPurchasedItem(String productId) {
    final now = DateTime.now();
    if (productId == 'myinstants-trending') {
      return [
        SoundboardSound(id: 'trending_1', serverId: 'store', name: 'Vine Boom', emoji: '💥', url: 'https://www.myinstants.com/media/sounds/vine-boom.mp3', duration: 2, creatorId: 'store', createdAt: now),
        SoundboardSound(id: 'trending_2', serverId: 'store', name: 'Bruh Moment', emoji: '🤦', url: 'https://www.myinstants.com/media/sounds/bruh-sound-effect-2.mp3', duration: 2, creatorId: 'store', createdAt: now),
        SoundboardSound(id: 'trending_3', serverId: 'store', name: 'Sad Violin', emoji: '🎻', url: 'https://www.myinstants.com/media/sounds/sad-violin.mp3', duration: 4, creatorId: 'store', createdAt: now),
      ];
    } else if (productId == 'classic-memes') {
      return [
        SoundboardSound(id: 'classic_1', serverId: 'store', name: 'OOF Death', emoji: '💀', url: 'https://www.myinstants.com/media/sounds/roblox-death-sound_1.mp3', duration: 1, creatorId: 'store', createdAt: now),
        SoundboardSound(id: 'classic_2', serverId: 'store', name: 'Meme Airhorn', emoji: '📢', url: 'https://www.myinstants.com/media/sounds/mlg-airhorn.mp3', duration: 2, creatorId: 'store', createdAt: now),
        SoundboardSound(id: 'classic_3', serverId: 'store', name: 'Anime Wow', emoji: '✨', url: 'https://www.myinstants.com/media/sounds/anime-wow.mp3', duration: 2, creatorId: 'store', createdAt: now),
      ];
    } else if (productId == 'retro-beeps') {
      return [
        SoundboardSound(id: 'retro_1', serverId: 'store', name: 'Super Mario Jump', emoji: '🍄', url: 'https://www.myinstants.com/media/sounds/super-mario-jump.mp3', duration: 1, creatorId: 'store', createdAt: now),
        SoundboardSound(id: 'retro_2', serverId: 'store', name: 'Pacman Death', emoji: '👾', url: 'https://www.myinstants.com/media/sounds/pacman-death.mp3', duration: 2, creatorId: 'store', createdAt: now),
      ];
    } else if (productId == 'chill-beats') {
      return [
        SoundboardSound(id: 'chill_1', serverId: 'store', name: 'Lofi Chime', emoji: '🍃', url: 'https://www.myinstants.com/media/sounds/lofi-chime.mp3', duration: 3, creatorId: 'store', createdAt: now),
        SoundboardSound(id: 'chill_2', serverId: 'store', name: 'Rain Loop', emoji: '🌧️', url: 'https://www.myinstants.com/media/sounds/rain-sound.mp3', duration: 5, creatorId: 'store', createdAt: now),
      ];
    }
    return [];
  }
}
