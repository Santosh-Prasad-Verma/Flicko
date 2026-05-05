import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/voice/application/music_notifier.dart';
import 'music_search_sheet.dart';

class SonicDripScreen extends ConsumerWidget {
  const SonicDripScreen({super.key});

  static const Color lime = Color(0xFFCBEF17);
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF1A1A1A);
  static const Color darkGrey = Color(0xFF0A0A0A);

  void _showSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const MusicSearchSheet(),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicNotifierProvider);
    final nowPlaying = state.nowPlaying;

    return Scaffold(
      backgroundColor: black,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    _buildNowPlayingCard(nowPlaying),
                    const SizedBox(height: 40),
                    if (nowPlaying != null) ...[
                      _buildProgressBar(),
                      const SizedBox(height: 40),
                      _buildPlaybackControls(ref, state),
                      const SizedBox(height: 32),
                    ],
                    _buildActionButtons(context),
                    const SizedBox(height: 48),
                    _buildUpcomingQueue(state),
                  ],
                ),
              ),
            ),
            _buildSystemStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
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
                'SONIC_DROP',
                style: GoogleFonts.spaceGrotesk(
                  color: white,
                  fontWeight: FontWeight.w900,
                  fontSize: 28,
                  letterSpacing: 2,
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
                    'VIRTUAL_TURNTABLE_V2.0',
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
          _brutalistIconButton(Icons.more_vert, () {}),
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

  Widget _buildNowPlayingCard(dynamic nowPlaying) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: black,
        border: Border.all(color: white, width: 4),
        boxShadow: const [
          BoxShadow(color: lime, offset: Offset(10, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: grey,
                image: nowPlaying?.imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(nowPlaying!.imageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                border: const Border(bottom: BorderSide(color: white, width: 4)),
              ),
              child: nowPlaying?.imageUrl == null
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.waves_rounded, color: lime.withValues(alpha: 0.3), size: 140),
                          const SizedBox(height: 24),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: lime, width: 1.5),
                            ),
                            child: Text(
                              'NO_SIGNAL_DETECTED',
                              style: GoogleFonts.robotoMono(
                                color: lime,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : null,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: const BoxDecoration(color: lime),
                      child: Text(
                        'AUDIO_OUT',
                        style: GoogleFonts.robotoMono(
                          color: black,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      'MASTER_QUALITY_FIX',
                      style: GoogleFonts.robotoMono(
                        color: white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  (nowPlaying?.name ?? 'IDLE_STATE').toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: white,
                    height: 0.9,
                    letterSpacing: -1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  (nowPlaying?.artistName ?? 'SYSTEM_WAITING...').toUpperCase(),
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    color: lime,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls(WidgetRef ref, dynamic state) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
          decoration: BoxDecoration(
            color: black,
            border: Border.all(color: white, width: 2.5),
            boxShadow: const [
              BoxShadow(color: white, offset: Offset(6, 6)),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _controlButton(Icons.shuffle, () {}, size: 50, isSecondary: true),
              _controlButton(Icons.skip_previous, () {}, size: 60),
              _controlButton(
                state.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                () => ref.read(musicNotifierProvider.notifier).togglePlayPause(),
                size: 85,
                isPrimary: true,
              ),
              _controlButton(
                Icons.skip_next,
                () => ref.read(musicNotifierProvider.notifier).skipForward(),
                size: 60,
              ),
              _controlButton(
                Icons.stop_rounded,
                () => ref.read(musicNotifierProvider.notifier).stop(),
                size: 50,
                isDanger: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _controlButton(IconData icon, VoidCallback onTap, {
    required double size,
    bool isPrimary = false,
    bool isSecondary = false,
    bool isDanger = false,
  }) {
    final bgColor = isPrimary ? lime : (isDanger ? const Color(0xFFFF3333) : black);
    final iconColor = isPrimary ? black : white;
    final borderColor = isPrimary ? black : (isDanger ? black : white);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: borderColor, width: 3),
          boxShadow: [
            BoxShadow(color: borderColor, offset: const Offset(4, 4)),
          ],
        ),
        child: Icon(icon, size: size * 0.45, color: iconColor),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('01:24', style: GoogleFonts.robotoMono(color: lime, fontSize: 13, fontWeight: FontWeight.w900)),
            Text('03:45', style: GoogleFonts.robotoMono(color: white.withValues(alpha: 0.5), fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 24,
          width: double.infinity,
          decoration: BoxDecoration(
            color: grey,
            border: Border.all(color: white, width: 2.5),
          ),
          child: Stack(
            children: [
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: 0.4,
                child: Container(
                  color: lime,
                  child: Center(
                    child: Container(
                      width: 2,
                      height: 12,
                      color: black.withValues(alpha: 0.3),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(15, (i) => Container(width: 1, height: 24, color: white.withValues(alpha: 0.1))),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _brutalistButton(
            'ADD_TO_DRIP',
            () => _showSearch(context),
            bgColor: lime,
            textColor: black,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _brutalistButton(
            'LYRIC_SHEET',
            () {},
            bgColor: black,
            textColor: white,
          ),
        ),
      ],
    );
  }

  Widget _brutalistButton(String text, VoidCallback onTap, {required Color bgColor, required Color textColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: textColor == black ? black : white, width: 3),
          boxShadow: [
            BoxShadow(color: textColor == black ? black : white, offset: const Offset(5, 5)),
          ],
        ),
        child: Center(
          child: Text(
            text,
            style: GoogleFonts.spaceGrotesk(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUpcomingQueue(dynamic state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(color: lime),
              child: Text(
                'QUEUE_MANIFEST',
                style: GoogleFonts.spaceGrotesk(
                  color: black,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Divider(color: white.withValues(alpha: 0.2), thickness: 2)),
          ],
        ),
        const SizedBox(height: 24),
        if (state.queue.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(48),
            decoration: BoxDecoration(
              border: Border.all(color: white.withValues(alpha: 0.1), width: 2, style: BorderStyle.solid),
            ),
            child: Column(
              children: [
                Icon(Icons.inventory_2_outlined, color: white.withValues(alpha: 0.1), size: 40),
                const SizedBox(height: 16),
                Text(
                  'QUEUE_BUFFER_EMPTY',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.robotoMono(color: white.withValues(alpha: 0.1), fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          )
        else
          ...List.generate(state.queue.length, (index) {
            final track = state.queue[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: black,
                border: Border.all(color: white, width: 2),
                boxShadow: const [
                  BoxShadow(color: white, offset: Offset(4, 4)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      border: Border.all(color: lime, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.robotoMono(color: lime, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.name.toUpperCase(),
                          style: GoogleFonts.spaceGrotesk(color: white, fontWeight: FontWeight.w900, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          track.artistName.toUpperCase(),
                          style: GoogleFonts.robotoMono(color: lime, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.reorder_rounded, color: white.withValues(alpha: 0.3)),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildSystemStatus() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: darkGrey,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            'CONNECTION: SECURE',
            style: GoogleFonts.robotoMono(color: white.withValues(alpha: 0.4), fontSize: 9, fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 24),
          Text(
            'BUFFER: 100%',
            style: GoogleFonts.robotoMono(color: white.withValues(alpha: 0.4), fontSize: 9, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
