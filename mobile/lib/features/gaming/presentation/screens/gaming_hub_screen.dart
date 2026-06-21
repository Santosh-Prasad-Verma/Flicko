import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class GamingHubScreen extends StatefulWidget {
  const GamingHubScreen({super.key});

  @override
  State<GamingHubScreen> createState() => _GamingHubScreenState();
}

class _GamingHubScreenState extends State<GamingHubScreen> {
  // ── Palette ──────────────────────────────────────────────────────────
  static const Color _bgDeep = Color(0xFF050505);
  static const Color _accentLime = Color(0xFF52B788);
  static const Color _accentGreen = Color(0xFF10B981);
  static const Color _accentPurple = Color(0xFF8B5CF6);
  static const Color _white = Color(0xFFF5F5F5);
  static const Color _glass = Color(0xFF121212);
  static const Color _dangerRed = Color(0xFFED4245);

  // ── State variables ──────────────────────────────────────────────────
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  int _currentBannerIndex = 0;
  late final PageController _pageController;
  Timer? _carouselTimer;

  // ── Notification State ───────────────────────────────────────────────
  int _unreadNotifications = 2;

  // ── Banner Data ──────────────────────────────────────────────────────
  final List<_BannerData> _banners = [
    const _BannerData(
      title: 'LUDO ROYALE',
      subtitle: 'Play online with 4 players now!',
      tag: 'LIVE LOBBIES',
      image: 'assets/ludo/images/card-logo.png',
      route: '/ludo',
      color: _accentPurple,
    ),
    const _BannerData(
      title: 'CYBER SEASON',
      subtitle: 'Unlock exclusive Neon cosmetics',
      tag: 'NEW REWARDS',
      image: 'assets/images/gaming/cyber_ninja.png',
      route: '/ludo',
      color: _accentLime,
    ),
  ];

  // ── Games Data ───────────────────────────────────────────────────────
  final List<_GameData> _allGames = [
    const _GameData(
      title: 'Ludo Royale',
      genre: 'Board',
      genreColor: _accentPurple,
      image: 'assets/ludo/images/card-logo.png',
      route: '/ludo',
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
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        );
      });
    });
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _pageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDeep,
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F1A).withOpacity(0.95),
            border: const Border(
              right: BorderSide(color: Colors.white10, width: 1.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DrawerHeader(
                decoration: const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.white10),
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Explore is under development'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.sports_esports_rounded, color: Colors.white70),
                title: Text(
                  'Play',
                  style: GoogleFonts.inter(color: Colors.white70),
                ),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/gaming/launch');
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
                  context.push('/profile');
                },
              ),
            ],
          ),
        ),
      ),
      body: Stack(
        children: [
          // ── Dramatic ambient lighting ──
          Positioned(
            top: -80,
            left: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accentLime.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 120,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accentGreen.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 100,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _accentLime.withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Main scrollable content ──
          SafeArea(
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              children: [
                _buildTopBar(context),
                const SizedBox(height: 20),
                _buildBannerCarousel(),
                const SizedBox(height: 24),
                _buildSectionHeader('New Games', onSeeAll: () => _showAllGamesLibrary(context)),
                const SizedBox(height: 16),
                _buildNewGamesRow(context),
                const SizedBox(height: 32),
                _buildFeaturedGame(context),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // TOP BAR
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildTopBar(BuildContext context) {
    if (_isSearching) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: _glass.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(Icons.search_rounded, color: _white.withValues(alpha: 0.4), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  style: GoogleFonts.inter(color: _white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search games...',
                    hintStyle: GoogleFonts.inter(
                      color: _white.withValues(alpha: 0.35),
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: _white.withValues(alpha: 0.5), size: 20),
                onPressed: () {
                  setState(() {
                    _isSearching = false;
                    _searchQuery = '';
                    _searchController.clear();
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Row(
        children: [
          Builder(
            builder: (innerContext) {
              return _glassIconButton(
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
          const Spacer(),
          // Search icon
          _glassIconButton(Icons.search_rounded, onTap: () {
            setState(() {
              _isSearching = true;
            });
          }),
          const SizedBox(width: 12),
          // Notification bell with red badge
          Stack(
            children: [
              _glassIconButton(Icons.notifications_outlined, onTap: () => _showNotifications(context)),
              if (_unreadNotifications > 0)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _dangerRed,
                      shape: BoxShape.circle,
                      border: Border.all(color: _bgDeep, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: _dangerRed.withValues(alpha: 0.6),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _glassIconButton(IconData icon, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: _glass.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _white.withValues(alpha: 0.08),
              ),
            ),
            child: Icon(icon, color: _white.withValues(alpha: 0.8), size: 20),
          ),
        ),
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
              return AnimatedBuilder(
                animation: _pageController,
                builder: (context, child) {
                  double value = 1.0;
                  if (_pageController.position.haveDimensions) {
                    value = _pageController.page! - index;
                    value = (1 - (value.abs() * 0.15)).clamp(0.0, 1.0);
                  }
                  return Transform.scale(
                    scale: CurveTween(curve: Curves.easeOut).transform(value),
                    child: Opacity(
                      opacity: value.clamp(0.5, 1.0),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: GestureDetector(
                    onTap: () => context.push(banner.route),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        decoration: BoxDecoration(
                          color: _glass.withValues(alpha: 0.8),
                          border: Border.all(
                            color: banner.color.withValues(alpha: 0.15),
                            width: 1.5,
                          ),
                        ),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Glowing nebula light in the background
                            Positioned(
                              right: -40,
                              top: -40,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: [
                                      banner.color.withValues(alpha: 0.3),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            // Text contents on the left
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
                                      color: banner.color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: banner.color.withValues(alpha: 0.35),
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
                                      color: _white.withValues(alpha: 0.6),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            // Character image floating on the right
                            Positioned(
                              right: 12,
                              bottom: 0,
                              top: 8,
                              child: Image.asset(
                                banner.image,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => const SizedBox(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        // Indicators
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
                color: isActive ? _accentLime : _white.withValues(alpha: 0.2),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: _accentLime.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ]
                    : null,
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
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _white,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward_rounded, color: _accentLime, size: 20),
          const Spacer(),
          GestureDetector(
            onTap: onSeeAll,
            child: Text(
              'See All',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _accentLime.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // NEW GAMES HORIZONTAL ROW
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildNewGamesRow(BuildContext context) {
    final filteredGames = _allGames.where((g) {
      return g.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    if (filteredGames.isEmpty) {
      return SizedBox(
        height: 210,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search_off_rounded, color: _white.withValues(alpha: 0.2), size: 48),
              const SizedBox(height: 12),
              Text(
                'No games match your search',
                style: GoogleFonts.inter(
                  color: _white.withValues(alpha: 0.4),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutBack,
      builder: (context, animValue, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - animValue)),
          child: Opacity(
            opacity: animValue.clamp(0.0, 1.0),
            child: child,
          ),
        );
      },
      child: SizedBox(
        height: 210,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          physics: const BouncingScrollPhysics(),
          itemCount: filteredGames.length,
          separatorBuilder: (_, __) => const SizedBox(width: 16),
          itemBuilder: (ctx, i) => _buildGameCard(context, filteredGames[i]),
        ),
      ),
    );
  }

  Widget _buildGameCard(BuildContext context, _GameData game) {
    return GestureDetector(
      onTap: () => context.push(game.route),
      child: SizedBox(
        width: 140,
        height: 210,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Glassmorphic card body
            Positioned(
              top: 30,
              left: 0,
              right: 0,
              bottom: 0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _glass.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _white.withValues(alpha: 0.08),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 80, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            game.title,
                            style: GoogleFonts.epilogue(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: _white,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: game.genreColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: game.genreColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Text(
                              game.genre,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: game.genreColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Character art – bleeds out of card top
            Positioned(
              top: -20,
              left: 10,
              right: 10,
              child: SizedBox(
                height: 120,
                child: Image(
                  image: AssetImage(game.image),
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: RadialGradient(
                        colors: [
                          game.genreColor.withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.sports_esports_rounded,
                      color: game.genreColor.withValues(alpha: 0.7),
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // FEATURED GAME CARD
  // ═══════════════════════════════════════════════════════════════════════
  Widget _buildFeaturedGame(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeOutCubic,
      builder: (context, animValue, child) {
        return Transform.translate(
          offset: Offset(0, 35 * (1 - animValue)),
          child: Opacity(
            opacity: animValue,
            child: child,
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: GestureDetector(
          onTap: () => context.push('/ludo'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 220,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Background image
                  Image(
                    image: const AssetImage(
                        'assets/ludo/images/card-logo.png'),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1A1A2E),
                            Color(0xFF16213E),
                            Color(0xFF0F3460),
                          ],
                        ),
                      ),
                      child: const Center(
                        child: Icon(Icons.rocket_launch_rounded,
                            color: Colors.white24, size: 64),
                      ),
                    ),
                  ),

                  // Cinematic gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          _bgDeep.withValues(alpha: 0.3),
                          _bgDeep.withValues(alpha: 0.85),
                          _bgDeep.withValues(alpha: 0.95),
                        ],
                        stops: const [0.0, 0.35, 0.7, 1.0],
                      ),
                    ),
                  ),

                  // Glassmorphic bottom sheet
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: ClipRRect(
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          color: _glass.withValues(alpha: 0.3),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Popular badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: _accentLime.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color:
                                            _accentLime.withValues(alpha: 0.5),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.local_fire_department_rounded,
                                            color: _accentLime, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Popular',
                                          style: GoogleFonts.inter(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: _accentLime,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  // Play button
                                  GestureDetector(
                                    onTap: () =>
                                        context.push('/ludo'),
                                    child: Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: const LinearGradient(
                                          colors: [_accentLime, _accentGreen],
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: _accentLime
                                                .withValues(alpha: 0.5),
                                            blurRadius: 12,
                                          ),
                                        ],
                                      ),
                                      child: const Icon(Icons.sports_esports_rounded,
                                          color: Colors.white, size: 24),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  // Wishlist heart
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: _white.withValues(alpha: 0.08),
                                      border: Border.all(
                                        color: _white.withValues(alpha: 0.12),
                                      ),
                                    ),
                                    child: Icon(Icons.favorite_border_rounded,
                                        color: _white.withValues(alpha: 0.7),
                                        size: 20),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'LUDO ROYALE',
                                style: GoogleFonts.epilogue(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: _white,
                                  letterSpacing: 1.5,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Play the classic board game Ludo with your friends online or offline. Play Ludo Royale now on Flicko Gaming Hub.',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  color: _white.withValues(alpha: 0.55),
                                  height: 1.5,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // WORKING NOTIFICATIONS SHEET OVERLAY
  // ═══════════════════════════════════════════════════════════════════════
  void _showNotifications(BuildContext context) {
    setState(() {
      _unreadNotifications = 0;
    });
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.52,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F).withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: _accentLime.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Drag handle
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: _white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Text(
                          'Notifications',
                          style: GoogleFonts.epilogue(
                            color: _white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        _glassIconButton(Icons.done_all_rounded, onTap: () {
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
                        _buildNotificationItem(
                          title: 'Ludo Challenge Invite',
                          description: 'Valkyrie has invited you to a live Ludo match.',
                          time: 'Just now',
                          icon: Icons.casino_rounded,
                          color: _accentPurple,
                          actionLabel: 'JOIN MATCH',
                          onAction: () {
                            Navigator.pop(context);
                            context.push('/ludo');
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildNotificationItem(
                          title: 'Ludo Lobby Full',
                          description: 'Your Ludo Royale quick match lobby is ready.',
                          time: '5m ago',
                          icon: Icons.casino_rounded,
                          color: _accentPurple,
                          actionLabel: 'PLAY NOW',
                          onAction: () {
                            Navigator.pop(context);
                            context.push('/ludo');
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationItem({
    required String title,
    required String description,
    required String time,
    required IconData icon,
    required Color color,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _white.withValues(alpha: 0.06)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.epilogue(
                        color: _white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      time,
                      style: GoogleFonts.inter(
                        color: _white.withValues(alpha: 0.35),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    color: _white.withValues(alpha: 0.55),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onAction,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.7)],
                      ),
                    ),
                    child: Text(
                      actionLabel,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  // "SEE ALL" GAME LIBRARY DRAWER
  // ═══════════════════════════════════════════════════════════════════════
  void _showAllGamesLibrary(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.75),
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F).withValues(alpha: 0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                  top: BorderSide(
                    color: _accentLime.withValues(alpha: 0.25),
                    width: 2,
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
                      color: _white.withValues(alpha: 0.15),
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
                        _glassIconButton(Icons.close_rounded, onTap: () {
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
                      ],
                    ),
                  ),
                ],
              ),
            ),
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
        color: _white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _white.withValues(alpha: 0.08)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            _white.withValues(alpha: 0.02),
            color.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Row(
        children: [
          // Game Icon/Avatar
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: _white.withValues(alpha: 0.02),
              border: Border.all(color: _white.withValues(alpha: 0.05)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(image, fit: BoxFit.contain),
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
                    fontSize: 18,
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
                        color: _white.withValues(alpha: 0.4),
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
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Simple data classes
// ═══════════════════════════════════════════════════════════════════════════
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

  const _BannerData({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.image,
    required this.route,
    required this.color,
  });
}
