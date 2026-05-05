import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/services/flicko_haptics.dart';
import 'package:mobile/data/models/soundboard_model.dart';
import 'package:mobile/data/services/soundboard_service.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class SoundboardScreen extends ConsumerStatefulWidget {
  final String serverId;
  const SoundboardScreen({super.key, required this.serverId});

  @override
  ConsumerState<SoundboardScreen> createState() => _SoundboardScreenState();
}

class _SoundboardScreenState extends ConsumerState<SoundboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  double _volume = 0.5;
  String? _playingId;

  static const Color lime = Color(0xFFCBEF17);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF1A1A1A);
  static const Color darkGrey = Color(0xFF0A0A0A);

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
    await ref.read(voiceControllerProvider.notifier).sendSoundboardSound(sound);
    await ref.read(soundboardServiceProvider).playSound(sound.id);
    Future.delayed(Duration(seconds: sound.duration), () {
      if (mounted) setState(() => _playingId = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: black,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: Column(
                children: [
                  _buildVolumeControl(),
                  _buildSearchBar(),
                  _buildTabs(),
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
            ),
            _buildFooterInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: const BoxDecoration(
        color: black,
        border: Border(bottom: BorderSide(color: lime, width: 4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _brutalistIconButton(Icons.arrow_back_ios_new, () => context.pop()),
          Column(
            children: [
              Text(
                'SOUNDBOARD',
                style: GoogleFonts.spaceGrotesk(
                  color: white,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  letterSpacing: -1,
                  height: 1,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(color: lime, shape: BoxShape.rectangle),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AUDIO_INTERCEPT_READY',
                    style: GoogleFonts.robotoMono(
                      color: lime,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          _brutalistIconButton(Icons.tune, () {}),
        ],
      ),
    );
  }

  Widget _brutalistIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: black,
          border: Border.all(color: lime, width: 2.5),
          boxShadow: const [
            BoxShadow(color: lime, offset: Offset(4, 4)),
          ],
        ),
        child: Icon(icon, size: 20, color: lime),
      ),
    );
  }

  Widget _buildVolumeControl() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: grey,
        border: Border.all(color: white, width: 2.5),
        boxShadow: const [
          BoxShadow(color: lime, offset: Offset(4, 4)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.volume_up_rounded, color: lime, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: SliderTheme(
              data: SliderThemeData(
                activeTrackColor: lime,
                inactiveTrackColor: black,
                thumbColor: white,
                overlayColor: lime.withValues(alpha: 0.2),
                trackHeight: 12,
                thumbShape: const RoundSliderThumbShape(
                  enabledThumbRadius: 10,
                  elevation: 0,
                  pressedElevation: 0,
                ),
                trackShape: const RectangularSliderTrackShape(),
              ),
              child: Slider(
                value: _volume,
                onChanged: (v) => setState(() => _volume = v),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Container(
            width: 50,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: black,
              border: Border.all(color: lime, width: 1.5),
            ),
            child: Center(
              child: Text(
                '${(_volume * 100).toInt()}%',
                style: GoogleFonts.robotoMono(
                  color: lime,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: black,
          border: Border.all(color: white, width: 2.5),
          boxShadow: const [
            BoxShadow(color: white, offset: Offset(4, 4)),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: GoogleFonts.robotoMono(
            color: white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'SEARCH_SOUNDS_DATABASE...',
            hintStyle: GoogleFonts.robotoMono(
              color: white.withValues(alpha: 0.3),
              fontSize: 14,
            ),
            prefixIcon: const Icon(Icons.search, color: lime, size: 24),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          color: lime,
          border: Border.all(color: black, width: 2),
        ),
        labelColor: black,
        unselectedLabelColor: white.withValues(alpha: 0.5),
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        labelStyle: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w900,
          fontSize: 12,
          letterSpacing: 1,
        ),
        unselectedLabelStyle: GoogleFonts.spaceGrotesk(
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 1,
        ),
        tabs: const [
          Tab(text: 'SAVED'),
          Tab(text: 'SERVER'),
          Tab(text: 'TRENDING'),
        ],
      ),
    );
  }

  Widget _buildSoundGrid({String? serverId, bool isFavorite = false, bool isTrending = false}) {
    return FutureBuilder<List<SoundboardSound>>(
      future: isFavorite 
          ? ref.read(soundboardServiceProvider).getFavoriteSounds()
          : ref.read(soundboardServiceProvider).getServerSounds(serverId ?? widget.serverId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: lime));
        }
        
        final sounds = snapshot.data ?? [];
        final filteredSounds = sounds.where((s) => s.name.toLowerCase().contains(_searchController.text.toLowerCase())).toList();

        if (filteredSounds.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '404_SOUND_NOT_FOUND',
                  style: GoogleFonts.robotoMono(
                    color: white.withValues(alpha: 0.1),
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.1,
          ),
          itemCount: filteredSounds.length,
          itemBuilder: (context, index) {
            final sound = filteredSounds[index];
            final isPlaying = _playingId == sound.id;

            return GestureDetector(
              onTap: () => _playSound(sound),
              child: AnimatedScale(
                scale: isPlaying ? 0.95 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Container(
                  decoration: BoxDecoration(
                    color: isPlaying ? lime : black,
                    border: Border.all(color: isPlaying ? white : lime, width: 3),
                    boxShadow: [
                      if (!isPlaying)
                        const BoxShadow(
                          color: lime,
                          offset: Offset(6, 6),
                        ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Text(
                          '#${index + 1}',
                          style: GoogleFonts.robotoMono(
                            color: isPlaying ? black.withValues(alpha: 0.3) : lime.withValues(alpha: 0.3),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              sound.emoji, 
                              style: TextStyle(
                                fontSize: 42,
                                shadows: isPlaying ? [] : [
                                  Shadow(color: lime.withValues(alpha: 0.5), offset: const Offset(2, 2)),
                                ],
                              )
                            ),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                sound.name.toUpperCase(),
                                style: GoogleFonts.spaceGrotesk(
                                  color: isPlaying ? black : white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  height: 1,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isPlaying)
                        Positioned(
                          bottom: 0,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 4,
                            color: black,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFooterInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: darkGrey,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'SYSTEM_READY',
            style: GoogleFonts.robotoMono(color: lime, fontSize: 10, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          Text(
            'BUFF_STATUS: OPTIMAL',
            style: GoogleFonts.robotoMono(color: white.withValues(alpha: 0.4), fontSize: 10),
          ),
        ],
      ),
    );
  }
}
