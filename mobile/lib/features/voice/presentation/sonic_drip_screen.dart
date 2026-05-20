import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../application/sonic_drip_notifier.dart';
import '../domain/music_models.dart';
import 'widgets/now_playing_card.dart';
import 'widgets/playback_controls.dart';
import 'widgets/queue_list.dart';
import 'widgets/search_sheet.dart';
import 'widgets/drip_bash_sheet.dart';
import 'spotify_connect_screen.dart';

class SonicDripScreen extends ConsumerWidget {
  const SonicDripScreen({super.key});

  static const _lime = Color(0xFF52B788);
  static const _black = Color(0xFF000000);
  static const _white = Color(0xFFFFFFFF);
  static const _surface = Color(0xFF0A0A0A);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(sonicDripProvider);

    return Scaffold(
      backgroundColor: _black,
      body: SafeArea(
        child: Column(
          children: [
            _AppBar(onSearch: () => _openSearch(context)),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Column(
                  children: [
                    NowPlayingCard(
                      track: state.playback.currentTrack,
                      status: state.playback.status,
                    ),
                    const SizedBox(height: 32),
                    if (state.playback.currentTrack != null) ...[
                      _ProgressSection(state: state),
                      const SizedBox(height: 32),
                    ],
                    PlaybackControls(state: state),
                    const SizedBox(height: 32),
                    _ActionRow(
                      onSearch: () => _openSearch(context),
                      onDripBash: () => _openDripBash(context),
                    ),
                    const SizedBox(height: 40),
                    QueueList(queue: state.queue),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _StatusBar(state: state),
          ],
        ),
      ),
    );
  }

  void _openSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SearchSheet(),
    );
  }

  void _openDripBash(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DripBashSheet(),
    );
  }
}

// ─── App Bar ──────────────────────────────────────────────────────────────────

class _AppBar extends StatelessWidget {
  final VoidCallback onSearch;
  const _AppBar({required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFF000000),
        border: Border(bottom: BorderSide(color: Color(0xFF52B788), width: 3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _IconBtn(Icons.arrow_back_ios_new, () => context.pop()),
          Column(
            children: [
              Text(
                'SONIC_DRIP',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
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
                    color: const Color(0xFF52B788),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'VIRTUAL_TURNTABLE_V2',
                    style: GoogleFonts.robotoMono(
                      color: const Color(0xFF52B788),
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
          _IconBtn(Icons.search, onSearch),
        ],
      ),
    );
  }
}

// ─── Progress Section ─────────────────────────────────────────────────────────

class _ProgressSection extends ConsumerWidget {
  final SonicDripState state;
  const _ProgressSection({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              state.playback.positionFormatted,
              style: GoogleFonts.robotoMono(
                color: const Color(0xFF52B788),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              state.playback.durationFormatted,
              style: GoogleFonts.robotoMono(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 13,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTapDown: (details) {
            final box = context.findRenderObject() as RenderBox;
            final progress = details.localPosition.dx / box.size.width;
            ref.read(sonicDripProvider.notifier).seekTo(progress);
          },
          child: Container(
            height: 20,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A1A),
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: state.playback.progress,
              child: Container(color: const Color(0xFF52B788)),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Action Row ───────────────────────────────────────────────────────────────

class _ActionRow extends StatelessWidget {
  final VoidCallback onSearch;
  final VoidCallback onDripBash;
  const _ActionRow({required this.onSearch, required this.onDripBash});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _BrutalistButton(
                label: 'DRIP_BASH',
                onTap: onDripBash,
                bgColor: const Color(0xFF52B788),
                textColor: Colors.black,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _BrutalistButton(
                label: 'ADD_TO_DRIP',
                onTap: onSearch,
                bgColor: Colors.black,
                textColor: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _BrutalistButton(
                label: 'SPOTIFY',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SpotifyConnectScreen(),
                  ),
                ),
                bgColor: Colors.black,
                textColor: const Color(0xFF1DB954),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Status Bar ───────────────────────────────────────────────────────────────

class _StatusBar extends StatelessWidget {
  final SonicDripState state;
  const _StatusBar({required this.state});

  @override
  Widget build(BuildContext context) {
    final isConnected = state.hasSession;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: const Color(0xFF0A0A0A),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: isConnected ? Colors.green : Colors.grey,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isConnected
                ? 'SPOTIFY: ${state.session!.displayName.toUpperCase()}'
                : 'ITUNES_SEARCH_MODE',
            style: GoogleFonts.robotoMono(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 20),
          Text(
            'QUEUE: ${state.queue.length}',
            style: GoogleFonts.robotoMono(
              color: Colors.white.withValues(alpha: 0.35),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Shared Widgets ───────────────────────────────────────────────────────────

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _IconBtn(this.icon, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: const Color(0xFF52B788), width: 2),
          boxShadow: const [BoxShadow(color: Color(0xFF52B788), offset: Offset(3, 3))],
        ),
        child: Icon(icon, size: 18, color: const Color(0xFF52B788)),
      ),
    );
  }
}

class _BrutalistButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Color bgColor;
  final Color textColor;

  const _BrutalistButton({
    required this.label,
    required this.onTap,
    required this.bgColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: bgColor,
          border: Border.all(color: textColor == Colors.black ? Colors.black : Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: textColor == Colors.black ? Colors.black : Colors.white,
              offset: const Offset(4, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.spaceGrotesk(
              color: textColor,
              fontWeight: FontWeight.w900,
              fontSize: 13,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}
