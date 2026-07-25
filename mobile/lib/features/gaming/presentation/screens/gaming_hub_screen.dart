import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/features/auth/application/auth_notifier.dart';

class GamingHubScreen extends ConsumerStatefulWidget {
  const GamingHubScreen({super.key});

  @override
  ConsumerState<GamingHubScreen> createState() => _GamingHubScreenState();
}

class _GamingHubScreenState extends ConsumerState<GamingHubScreen> {
  // ── Color Palette (Flat Minimalist Theme) ─────────────────────────────
  static const Color _bgDeep = Color(0xFF0C0C0F);
  static const Color _bgCard = Color(0xFF17171C);
  static const Color _border = Color(0xFF25252E);
  static const Color _accentLime = Color(0xFF52B788);
  static const Color _accentGreen = Color(0xFF10B981);
  static const Color _accentPurple = Color(0xFF8B5CF6);
  static const Color _white = Color(0xFFF3F4F6);
  static const Color _textMuted = Color(0xFF9CA3AF);
  static const Color _dangerRed = Color(0xFFED4245);

  // ── State Variables ──────────────────────────────────────────────────
  int _currentBannerIndex = 0;
  late final PageController _pageController;
  Timer? _carouselTimer;

  // ── Banner Data ──────────────────────────────────────────────────────
  final List<_BannerData> _banners = [
    const _BannerData(
      title: 'SOMISOMI ARCADE',
      subtitle: 'Play the cutest retro arcade matches!',
      tag: 'FEATURED',
      image: 'assets/images/gaming/somisomi_banner.jpg',
      route: '/ludo',
      color: _accentLime,
      isFullBackground: true,
    ),
    const _BannerData(
      title: 'LUDO CHAMPIONSHIP',
      subtitle: 'Play & climb the leaderboard!',
      tag: 'TOURNAMENT',
      image: 'assets/images/gaming/ludo-banner.jpg',
      route: '/ludo',
      color: _accentPurple,
      isFullBackground: true,
    ),
    const _BannerData(
      title: 'LUDO CHALLENGE',
      subtitle: 'Roll the dice and beat your friends!',
      tag: 'PLAY NOW',
      image: 'assets/images/gaming/ludo-banner2.jpg',
      route: '/ludo',
      color: _accentGreen,
      isFullBackground: true,
    ),
  ];

  // ── Games Data ───────────────────────────────────────────────────────
  final List<_GameData> _allGames = [
    const _GameData(
      title: 'Ludo Royale',
      genre: 'Board Game',
      genreColor: _accentPurple,
      image: 'assets/ludo/images/card-logo.png',
      route: '/ludo',
    ),
    const _GameData(
      title: 'Create Watch Room',
      genre: 'Co-Watching',
      genreColor: _accentLime,
      image: '',
      route: '/watch-together/standalone',
    ),
    const _GameData(
      title: 'Public Lobbies',
      genre: 'Co-Watching',
      genreColor: _accentGreen,
      image: '',
      route: '/watch-together/lobbies',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
    _startBannerTimer();
  }

  void _startBannerTimer() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      setState(() {
        _currentBannerIndex = (_currentBannerIndex + 1) % _banners.length;
        _pageController.animateToPage(
          _currentBannerIndex,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
        );
      });
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      drawer: Drawer(
        backgroundColor: _bgCard,
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
              right: BorderSide(color: _border, width: 1.0),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: _border),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      'Gaming Hub',
                      style: GoogleFonts.epilogue(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ultimate Arcade',
                      style: GoogleFonts.inter(
                        color: _accentLime,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.home_rounded, color: _accentLime),
                title: Text(
                  'Home',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.explore_outlined, color: Colors.white70),
                title: Text(
                  'Explore',
                  style: GoogleFonts.inter(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/discover');
                },
              ),
              ListTile(
                leading: const Icon(Icons.leaderboard_outlined, color: Colors.white70),
                title: Text(
                  'Stats',
                  style: GoogleFonts.inter(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/gaming/stats');
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded, color: Colors.white70),
                title: Text(
                  'Profile',
                  style: GoogleFonts.inter(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.pop(context);
                  final userId = ref.read(currentUserIdProvider);
                  if (userId != null) {
                    context.push('/profile/$userId');
                  }
                },
              ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const BouncingScrollPhysics(),
          children: [
            _buildTopBar(context),
            const SizedBox(height: 20),
            _buildBannerCarousel(),
            const SizedBox(height: 24),
            _buildSectionHeader('All Games', onSeeAll: () => _showAllGamesLibrary(context)),
            const SizedBox(height: 16),
            _buildNewGamesRow(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TOP BAR
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildTopBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Builder(
            builder: (innerContext) {
              return _flatIconButton(
                Icons.menu_rounded,
                onTap: () => Scaffold.of(innerContext).openDrawer(),
              );
            },
          ),
          const SizedBox(width: 16),
          Text(
            'Gaming Hub',
            style: GoogleFonts.epilogue(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _white,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _flatIconButton(IconData icon, {required VoidCallback onTap, Color? iconColor}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border),
        ),
        child: Icon(icon, color: iconColor ?? _white.withValues(alpha: 0.8), size: 20),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // BANNER CAROUSEL
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildBannerCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 160,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentBannerIndex = index;
              });
            },
            itemCount: _banners.length,
            itemBuilder: (context, index) {
              final banner = _banners[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => context.push(banner.route),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: _bgCard,
                        border: Border.all(
                          color: _border,
                          width: 1.0,
                        ),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (banner.isFullBackground) ...[
                            Positioned.fill(
                              child: Image.asset(
                                banner.image,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const SizedBox(),
                              ),
                            ),
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.centerLeft,
                                    end: Alignment.centerRight,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.8),
                                      Colors.black.withValues(alpha: 0.1),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: banner.color.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: banner.color.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    banner.tag,
                                    style: GoogleFonts.inter(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: banner.color,
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  banner.title,
                                  style: GoogleFonts.epilogue(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: _white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  banner.subtitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: _textMuted,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
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
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (index) {
            final isActive = _currentBannerIndex == index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 16 : 6,
              height: 6,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(3),
                color: isActive ? _accentLime : _border,
              ),
            );
          }),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SECTION HEADER
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildSectionHeader(String title, {required VoidCallback onSeeAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.epilogue(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_rounded, color: _accentLime, size: 18),
          const Spacer(),
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              'See All',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _accentLime,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // GAMES GRID / LIST VIEW
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildNewGamesRow(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _allGames.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (ctx, i) => _buildGameCard(context, _allGames[i]),
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, _GameData game) {
    return GestureDetector(
      onTap: () => context.push(game.route),
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _border),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: _bgDeep,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: game.image.isEmpty
                      ? Icon(
                          game.genre == 'Board Game' ? Icons.casino_rounded : Icons.live_tv_rounded,
                          color: game.genreColor,
                          size: 40,
                        )
                      : Image.asset(
                          game.image,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.sports_esports_rounded,
                            color: game.genreColor,
                            size: 40,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              game.title,
              style: GoogleFonts.epilogue(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _white,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: game.genreColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: game.genreColor.withValues(alpha: 0.25),
                ),
              ),
              child: Text(
                game.genre,
                style: GoogleFonts.inter(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: game.genreColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  // ═══════════════════════════════════════════════════════════════════════
  // "SEE ALL" GAME LIBRARY DRAWER (Flat Style)
  // ═══════════════════════════════════════════════════════════════════════
  void _showAllGamesLibrary(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      isScrollControlled: true,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.65,
          decoration: const BoxDecoration(
            color: _bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(
                color: _border,
                width: 1,
              ),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: _border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Text(
                      'Game Library',
                      style: GoogleFonts.epilogue(
                        color: _white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const Spacer(),
                    _flatIconButton(Icons.close_rounded, onTap: () {
                      Navigator.pop(context);
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  physics: const BouncingScrollPhysics(),
                  children: [
                    _buildLibraryItem(
                      context,
                      title: 'Ludo Royale',
                      genre: 'BOARD GAME',
                      rating: '4.8 ⭐',
                      activePlayers: '1,240 online',
                      image: 'assets/ludo/images/card-logo.png',
                      color: _accentPurple,
                      route: '/ludo',
                    ),
                    const SizedBox(height: 12),
                    _buildLibraryItem(
                      context,
                      title: 'Create Watch Room',
                      genre: 'CO-WATCHING',
                      rating: '5.0 ⭐',
                      activePlayers: 'Private rooms',
                      image: '',
                      color: _accentLime,
                      route: '/watch-together/standalone',
                    ),
                    const SizedBox(height: 12),
                    _buildLibraryItem(
                      context,
                      title: 'Public Lobbies',
                      genre: 'CO-WATCHING',
                      rating: '4.7 ⭐',
                      activePlayers: 'Browse rooms',
                      image: '',
                      color: _accentGreen,
                      route: '/watch-together/lobbies',
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLibraryItem(
    BuildContext context, {
    required String title,
    required String genre,
    required String rating,
    required String activePlayers,
    required String image,
    required Color color,
    required String route,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgDeep,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _bgCard,
              border: Border.all(color: _border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: image.isEmpty
                  ? Icon(Icons.live_tv_rounded, color: color, size: 36)
                  : Image.asset(image, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  genre,
                  style: GoogleFonts.inter(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.epilogue(
                    color: _white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      rating,
                      style: GoogleFonts.inter(color: Colors.amber, fontSize: 12),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      activePlayers,
                      style: GoogleFonts.inter(
                        color: _textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              Navigator.pop(context);
              context.push(route);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [color, color.withValues(alpha: 0.7)],
                ),
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameData {
  final String title;
  final String genre;
  final Color genreColor;
  final String image;
  final String route;

  const _GameData({
    required this.title,
    required this.genre,
    required this.genreColor,
    required this.image,
    required this.route,
  });
}

class _BannerData {
  final String title;
  final String subtitle;
  final String tag;
  final String image;
  final String route;
  final Color color;
  final bool isFullBackground;

  const _BannerData({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.image,
    required this.route,
    required this.color,
    this.isFullBackground = false,
  });
}
