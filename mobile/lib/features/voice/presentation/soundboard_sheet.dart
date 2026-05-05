import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/theme/flicko_colors.dart';
import 'package:mobile/core/theme/flicko_radius.dart';
import 'package:mobile/core/theme/flicko_spacing.dart';
import 'package:mobile/core/services/flicko_haptics.dart';
import 'package:mobile/features/voice/application/music_notifier.dart'; // Reusing volume from music logic if possible
import 'package:mobile/data/models/soundboard_model.dart';
import 'package:mobile/data/services/soundboard_service.dart';
import 'package:google_fonts/google_fonts.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _playSound(SoundboardSound sound) async {
    setState(() => _playingId = sound.id);
    FlickoHaptics.light();
    
    // Play and broadcast via VoiceController
    await ref.read(voiceControllerProvider.notifier).sendSoundboardSound(sound);
    
    // Track play count in Supabase
    await ref.read(soundboardServiceProvider).playSound(sound.id);
    
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
      decoration: const BoxDecoration(
        color: FlickoColors.bgPrimary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(FlickoRadius.lg)),
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
                color: FlickoColors.textMuted.withOpacity(0.3),
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
                    color: FlickoColors.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: FlickoColors.textMuted),
                ),
              ],
            ),
          ),

          // Search
          Padding(
            padding: const EdgeInsets.all(FlickoSpacing.md),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: const TextStyle(color: FlickoColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search sounds...',
                hintStyle: const TextStyle(color: FlickoColors.textMuted),
                prefixIcon: const Icon(Icons.search, color: FlickoColors.textMuted),
                filled: true,
                fillColor: FlickoColors.bgSecondary,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(FlickoRadius.md),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),

          // Tabs
          TabBar(
            controller: _tabController,
            labelColor: FlickoColors.accentPrimary,
            unselectedLabelColor: FlickoColors.textMuted,
            indicatorColor: FlickoColors.accentPrimary,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: const [
              Tab(text: 'Favorites', icon: Icon(Icons.star, size: 20)),
              Tab(text: 'Server', icon: Icon(Icons.musical_notes, size: 20)),
              Tab(text: 'Trending', icon: Icon(Icons.trending_up, size: 20)),
            ],
          ),

          // Volume
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: FlickoSpacing.md, vertical: 8),
            child: Row(
              children: [
                Icon(
                  _volume == 0 ? Icons.volume_mute : Icons.volume_down,
                  color: FlickoColors.textMuted,
                  size: 18,
                ),
                Expanded(
                  child: Slider(
                    value: _volume,
                    onChanged: (v) => setState(() => _volume = v),
                    activeColor: FlickoColors.accentPrimary,
                    inactiveColor: FlickoColors.bgTertiary,
                  ),
                ),
                Text(
                  '${(_volume * 100).toInt()}%',
                  style: const TextStyle(color: FlickoColors.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),

          // Grid
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSoundGrid(isFavorite: true),
                _buildSoundGrid(serverId: widget.serverId),
                _buildSoundGrid(isTrending: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSoundGrid({String? serverId, bool isFavorite = false, bool isTrending = false}) {
    // In a real app, this would use a FutureBuilder or StreamProvider
    return FutureBuilder<List<SoundboardSound>>(
      future: isFavorite 
          ? ref.read(soundboardServiceProvider).getFavoriteSounds()
          : ref.read(soundboardServiceProvider).getServerSounds(serverId ?? widget.serverId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final sounds = snapshot.data ?? [];
        final filteredSounds = sounds.where((s) => s.name.toLowerCase().contains(_searchController.text.toLowerCase())).toList();

        if (filteredSounds.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.music_off, size: 48, color: FlickoColors.textMuted.withOpacity(0.2)),
                const SizedBox(height: 16),
                Text(
                  isFavorite ? 'No favorites yet' : 'No sounds found',
                  style: const TextStyle(color: FlickoColors.textMuted),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(FlickoSpacing.md),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.2,
          ),
          itemCount: filteredSounds.length,
          itemBuilder: (context, index) {
            final sound = filteredSounds[index];
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
                  color: isPlaying ? FlickoColors.accentPrimary : FlickoColors.bgSecondary,
                  borderRadius: BorderRadius.circular(FlickoRadius.md),
                  border: Border.all(
                    color: isPlaying ? FlickoColors.accentPrimary : FlickoColors.border.withOpacity(0.2),
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
                        color: isPlaying ? Colors.white : FlickoColors.textPrimary,
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
      },
    );
  }
}
