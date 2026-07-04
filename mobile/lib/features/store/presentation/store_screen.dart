import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/equipment_service.dart';
import 'package:mobile/features/store/data/wishlist_service.dart';
import 'package:mobile/features/store/data/store_theme_service.dart';
import 'package:mobile/core/services/flicko_haptics.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/features/shared/presentation/widgets/kinetic_nameplate_text.dart';
import 'package:mobile/features/voice/data/voice_filter_service.dart';
import 'package:mobile/features/voice/presentation/widgets/voice_synth_board_sheet.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _visualizerController;
  int _selectedCategory = 0;
  String _searchQuery = '';
  bool _showSearch = false;
  String _sortBy = 'newest'; // newest, price_low, price_high, popular
  final _searchController = TextEditingController();

  static const _bg = Color(0xFF000000); // Pure Black
  static const _surface = Color(0xFF0C0C0E); // Deep Black-Gray
  static const _neon = Color(0xFF52B788); // Sonic Drip Lime Green
  static const _white = Color(0xFFFFFFFF);
  static const _muted = Color(0xFF71717A);
  static const _lime = Color(0xFF52B788); // Lime Green
  static const _gold = Color(0xFFFFD700);

  final _categories = ['ALL', 'THEMES', 'DECORATIONS', 'NAMEPLATES', 'VOICE_SKINS', 'WARP_DRIPS', 'STICKERS', 'SOUNDS', 'BADGES'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _visualizerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _visualizerController.dispose();
    super.dispose();
  }

  Widget _buildLiquidGlassBackground({required Widget child}) {
    return Stack(
      children: [
        // Pure black base
        Container(color: const Color(0xFF000000)),
        // Ambient glow 1 (Emerald Green)
        Positioned(
          top: -100,
          left: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withValues(alpha: 0.18),
            ),
          ),
        ),
        // Ambient glow 2 (Deep Purple)
        Positioned(
          bottom: 200,
          right: -100,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF9B84EE).withValues(alpha: 0.15),
            ),
          ),
        ),
        // Ambient glow 3 (Cyan/Teal)
        Positioned(
          top: 300,
          right: -50,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
            ),
          ),
        ),
        // Backdrop blur overlay to smear the glow into a liquid backdrop
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
            child: Container(color: Colors.transparent),
          ),
        ),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(cart),
      body: _buildLiquidGlassBackground(
        child: SafeArea(
          bottom: false,
          child: TabBarView(
            controller: _tabController,
            children: [_buildDiscoverTab(), _buildMyItemsTab()],
          ),
        ),
      ),
      floatingActionButton: cart.isNotEmpty
          ? _buildCartFAB(cart)
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(List<CartItem> cart) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            color: Colors.black.withValues(alpha: 0.25),
          ),
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _white),
        onPressed: () => context.pop(),
      ),
      title: _showSearch
          ? _buildSearchField()
          : Text(
              'Flicko Store',
              style: GoogleFonts.inter(
                color: _white,
                fontWeight: FontWeight.w900,
                fontSize: 22,
                letterSpacing: 2,
              ),
            ),
      actions: [
        IconButton(
          icon: Icon(_showSearch ? Icons.close : Icons.search, color: _white),
          onPressed: () => setState(() {
            _showSearch = !_showSearch;
            if (!_showSearch) {
              _searchQuery = '';
              _searchController.clear();
            }
          }),
        ),
        Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.shopping_bag_outlined, color: _white),
              onPressed: () => context.push('/store/cart'),
            ),
            if (cart.isNotEmpty)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: _lime,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${cart.length}',
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(48),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            indicatorColor: _neon,
            indicatorWeight: 2,
            indicatorSize: TabBarIndicatorSize.label,
            labelColor: _neon,
            unselectedLabelColor: _muted,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13, letterSpacing: 1.0),
            tabs: const [
              Tab(text: 'Discover'),
              Tab(text: 'My Collection'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      style: GoogleFonts.inter(color: _white),
      decoration: InputDecoration(
        hintText: 'Search products...',
        hintStyle: GoogleFonts.inter(color: _muted),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _white.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: _white.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF52B788), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      onChanged: (v) => setState(() => _searchQuery = v),
    );
  }

  Widget _buildCollectorXPBar() {
    final purchasesAsync = ref.watch(userPurchasesProvider);
    return purchasesAsync.maybeWhen(
      data: (purchases) {
        final ownedCount = purchases.length;
        final xp = ownedCount * 250;
        final level = (xp / 500).floor() + 1;
        final currentLevelXp = xp % 500;
        final double progress = currentLevelXp / 500.0;

        String rank = 'NOVICE DRIPPER';
        if (level == 2) {
          rank = 'VINYL SCRATCHER';
        } else if (level == 3) {
          rank = 'BADGE COLLECTOR';
        } else if (level == 4) {
          rank = 'COSMIC COLLECTOR';
        } else if (level >= 5) {
          rank = 'LEGENDARY COSMIC DJ';
        }

        return Padding(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.0),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withValues(alpha: 0.04),
                      Colors.white.withValues(alpha: 0.01),
                    ],
                  ),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: _neon.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.stars_rounded, color: _neon, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Collector Level $level',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _gold.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _gold.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Text(
                      rank,
                      style: GoogleFonts.inter(
                        color: _gold,
                        fontSize: 8,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TweenAnimationBuilder<double>(
                key: ValueKey('xp_progress_${level}_$progress'),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                tween: Tween<double>(begin: 0.0, end: progress),
                builder: (context, animatedProgress, child) {
                  return Container(
                    height: 8,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Stack(
                      children: [
                        FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: animatedProgress.clamp(0.01, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [_neon, _neon.withValues(alpha: 0.7)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color: _neon.withValues(alpha: 0.3),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$currentLevelXp / 500 XP',
                    style: GoogleFonts.inter(color: _muted, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '$ownedCount Items Collected',
                    style: GoogleFonts.inter(color: _muted, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  Widget _buildDiscoverTab() {
    final type = _categories[_selectedCategory];
    final productsAsync = ref.watch(storeProductsProvider((type: type, search: null)));
    final wishlist = ref.watch(wishlistProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildCollectorXPBar()),
        SliverToBoxAdapter(child: _buildFeaturedBanner()),
        SliverToBoxAdapter(child: _buildCategoryChips()),
        SliverToBoxAdapter(child: _buildSortFilter()),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        productsAsync.when(
          data: (products) {
            // Sort and filter products locally by search query
            var sorted = List<StoreProduct>.from(products);
            if (_searchQuery.isNotEmpty) {
              final query = _searchQuery.toLowerCase();
              sorted = sorted.where((p) => 
                p.name.toLowerCase().contains(query) || 
                p.type.toLowerCase().contains(query) ||
                p.rarity.toLowerCase().contains(query)
              ).toList();
            }

            switch (_sortBy) {
              case 'price_low':
                sorted.sort((a, b) => a.price.compareTo(b.price));
                break;
              case 'price_high':
                sorted.sort((a, b) => b.price.compareTo(a.price));
                break;
              case 'popular':
                sorted.sort((a, b) {
                  if (a.isHot && !b.isHot) return -1;
                  if (!a.isHot && b.isHot) return 1;
                  return 0;
                });
                break;
              default:
                // newest - already sorted by created_at from service
                break;
            }

            if (sorted.isEmpty) {
              return SliverToBoxAdapter(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: Column(
                      children: [
                        Icon(Icons.search_off, color: _muted, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'No products found',
                          style: GoogleFonts.inter(color: _white, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            return SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildProductCard(sorted[index], wishlist, index, sorted.length),
                  childCount: sorted.length,
                ),
              ),
            );
          },
          loading: () => const SliverToBoxAdapter(
            child: Center(child: CircularProgressIndicator(color: _neon)),
          ),
          error: (e, _) => SliverToBoxAdapter(
            child: Center(child: Text('Error: $e', style: TextStyle(color: Colors.red))),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildSortFilter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Sort dropdown
          Expanded(
            child: GestureDetector(
              onTap: () => _showSortSheet(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _white.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sort, color: _muted, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Sort: ${_getSortLabel()}',
                      style: GoogleFonts.inter(color: _white, fontSize: 12),
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_drop_down, color: _muted, size: 16),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Wishlist button
          GestureDetector(
            onTap: () => _showWishlistSheet(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _white.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite_border, color: Colors.red, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    '${ref.watch(wishlistProvider).length}',
                    style: GoogleFonts.inter(color: _white, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getSortLabel() {
    switch (_sortBy) {
      case 'price_low':
        return 'Price: Low';
      case 'price_high':
        return 'Price: High';
      case 'popular':
        return 'Popular';
      default:
        return 'Newest';
    }
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Sort Products',
                style: GoogleFonts.inter(color: _white, fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
            ...[
              ('newest', 'Newest First'),
              ('popular', 'Most Popular'),
              ('price_low', 'Price: Low to High'),
              ('price_high', 'Price: High to Low'),
            ].map((item) => ListTile(
              leading: Icon(
                _sortBy == item.$1 ? Icons.radio_button_checked : Icons.radio_button_off,
                color: _sortBy == item.$1 ? _neon : _muted,
              ),
              title: Text(item.$2, style: GoogleFonts.inter(color: _white)),
              onTap: () {
                setState(() => _sortBy = item.$1);
                Navigator.pop(ctx);
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showWishlistSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (ctx, scrollController) => Consumer(
              builder: (context, ref, child) {
                final wishlistProducts = ref.watch(wishlistProductsProvider);
                final wishlist = ref.watch(wishlistProvider);

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(
                      top: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 10),
                        height: 4,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'My wishlist',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 20,
                                letterSpacing: 0,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.redAccent.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '${wishlist.length}',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: wishlistProducts.when(
                      data: (products) {
                        if (products.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.favorite_border, color: _muted, size: 48),
                                const SizedBox(height: 12),
                                Text(
                                  'YOUR_WISHLIST_IS_EMPTY',
                                  style: GoogleFonts.inter(
                                    color: _muted,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: products.length,
                          itemBuilder: (ctx, index) => _buildWishlistItem(products[index]),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator(color: _neon)),
                      error: (_, __) => const Center(child: Text('Error loading wishlist', style: TextStyle(color: Colors.red))),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
        ),
      ),
    );
  }

  Widget _buildWishlistItem(StoreProduct product) {
    final rarityColor = _getRarityColor(product.rarity);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: rarityColor, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: rarityColor.withValues(alpha: 0.15),
              border: Border.all(color: rarityColor, width: 1.5),
            ),
            child: Icon(_iconForType(product.type), color: rarityColor, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.price == 0 ? 'FREE' : '₹${product.price.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(color: _lime, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
            onPressed: () => ref.read(wishlistProvider.notifier).remove(product.id),
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedBanner() {
    return Container(
      margin: const EdgeInsets.all(16),
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1B4D3E), // Sleek deep emerald
            Color(0xFF0F1E1A), // Sleek obsidian
          ],
        ),
        border: Border.all(color: _neon.withValues(alpha: 0.25), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: _neon.withValues(alpha: 0.12),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Abstract decorative ambient glow circle in the corner
            Positioned(
              right: -30,
              top: -30,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _neon.withValues(alpha: 0.12),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _neon.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'FEATURED DROP',
                      style: GoogleFonts.inter(
                        color: _neon,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sonic Drip Theme',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '₹399',
                          style: GoogleFonts.inter(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.arrow_forward, color: _lime, size: 20),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = _selectedCategory == index;
          return GestureDetector(
            onTap: () {
              FlickoHaptics.selection();
              setState(() => _selectedCategory = index);
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: AnimatedContainer(
                  key: ValueKey('store_category_chip_${_categories[index]}'),
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? _lime : Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected ? _lime : Colors.white.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
              child: AnimatedScale(
                duration: const Duration(milliseconds: 250),
                scale: selected ? 1.05 : 1.0,
                child: Text(
                  _categories[index]
                      .replaceAll('_', ' ')
                      .toLowerCase()
                      .split(' ')
                      .map((s) => s.isNotEmpty ? s[0].toUpperCase() + s.substring(1) : '')
                      .join(' '),
                  style: GoogleFonts.inter(
                    color: selected ? Colors.black : Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
        },
      ),
    );
  }

  Widget _buildProductCard(StoreProduct product, List<String> wishlist, int index, int totalCount) {
    final isCrate = product.id == 'mystery-crate';
    final rarityColor = isCrate ? const Color(0xFFFF007F) : _getRarityColor(product.rarity);
    final isFree = product.price == 0;
    final cart = ref.watch(cartProvider);
    final inCart = cart.any((item) => item.product.id == product.id);
    final inWishlist = wishlist.contains(product.id);

    final cardWidget = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: rarityColor.withValues(alpha: 0.25),
              width: 1.2,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withValues(alpha: 0.04),
                Colors.white.withValues(alpha: 0.01),
              ],
            ),
          ),
      child: Stack(
        children: [
          // 1. Clickable Card Body
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                if (product.id == 'myinstants-trending') {
                  context.push('/store/myinstants');
                } else if (product.type.toUpperCase() == 'AVATAR_DECORATION') {
                  context.push('/store/decorations');
                } else if (product.type.toUpperCase() == 'NAMEPLATE') {
                  context.push('/store/nameplates');
                } else if (product.type.toUpperCase() == 'VOICE_SKIN') {
                  context.push('/store/voice-skins');
                } else if (product.type.toUpperCase() == 'ENTRANCE_WARP' || product.type.toUpperCase() == 'DRIP_CARD') {
                  context.push('/store/warp-drips');
                } else if (product.type.toUpperCase() == 'BADGE') {
                  context.push('/store/badge-alchemy');
                } else {
                  context.push('/store/product/${product.id}');
                }
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image Area
                    Expanded(
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: rarityColor.withValues(alpha: 0.05),
                          border: Border(
                            bottom: BorderSide(
                              color: rarityColor.withValues(alpha: 0.15),
                              width: 1,
                            ),
                          ),
                        ),
                        child: Center(
                          child: product.type.toUpperCase() == 'AVATAR_DECORATION'
                              ? UserAvatar(size: 56, decoration: product.id, name: 'PREVIEW', showStatus: false, showBadge: false)
                              : product.type.toUpperCase() == 'NAMEPLATE'
                                  ? Center(
                                      child: KineticNameplateText(
                                        text: 'DRIP_TAG',
                                        decorationId: product.id,
                                        style: GoogleFonts.inter(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 16,
                                        ),
                                      ),
                                    )
                                  : product.type.toUpperCase() == 'VOICE_SKIN'
                                      ? Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 12),
                                          child: AnimatedBuilder(
                                            animation: _visualizerController,
                                            builder: (context, _) {
                                              return CustomPaint(
                                                size: const Size(double.infinity, 40),
                                                painter: SynthesizerWavePainter(
                                                  animationValue: _visualizerController.value,
                                                  preset: product.id,
                                                  pitch: 0.0,
                                                  reverb: 0.0,
                                                  bitcrush: 0.0,
                                                  isEnabled: true,
                                                  neonColor: _neon,
                                                  goldColor: _gold,
                                                  skinId: product.id,
                                                ),
                                              );
                                            },
                                          ),
                                        )
                                      : Icon(
                                          _iconForType(product.type),
                                          color: rarityColor,
                                          size: 40,
                                        ),
                        ),
                      ),
                    ),
                    // Text Details Area
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.name.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              letterSpacing: 0.5,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            product.type.toUpperCase().replaceAll('_', ' '),
                            style: GoogleFonts.inter(
                              color: _muted,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Text(
                                isFree ? 'FREE' : '₹${product.price.toStringAsFixed(0)}',
                                style: GoogleFonts.robotoMono(
                                  color: isFree ? _lime : Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
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
            ),
          ),
          
          // 2. Hot Tag (top left)
          if (product.isHot)
            Positioned(
              top: 10,
              left: 10,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'HOT',
                  style: GoogleFonts.inter(
                    color: _white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

          // 3. Rarity Tag
          Positioned(
            top: 10,
            left: product.isHot ? 48 : 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: rarityColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: rarityColor.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Text(
                product.rarity.toUpperCase(),
                style: GoogleFonts.inter(
                  color: rarityColor,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),

          // 4. Wishlist heart button (top right overlay)
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () async {
                FlickoHaptics.light();
                await ref.read(wishlistProvider.notifier).toggle(product.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(inWishlist ? 'Removed from wishlist' : 'Added to wishlist'),
                      backgroundColor: inWishlist ? Colors.red : _lime,
                      duration: const Duration(milliseconds: 800),
                    ),
                  );
                }
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: inWishlist ? Colors.red.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                ),
                child: Icon(
                  inWishlist ? Icons.favorite : Icons.favorite_border,
                  color: inWishlist ? Colors.red : Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),

          // 5. Add to Cart / Spin button (bottom right overlay)
          Positioned(
            bottom: 12,
            right: 12,
            child: GestureDetector(
              onTap: () {
                if (product.id == 'mystery-crate') {
                  _showCrateSpinDialog(product);
                  return;
                }
                ref.read(cartProvider.notifier).add(product);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${product.name} added to cart'),
                    backgroundColor: _lime,
                    duration: const Duration(seconds: 1),
                    action: SnackBarAction(
                      label: 'VIEW',
                      textColor: Colors.black,
                      onPressed: () => context.push('/store/cart'),
                    ),
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (product.id == 'mystery-crate' || inCart) ? _lime : Colors.black.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: (product.id == 'mystery-crate' || inCart) ? _lime : Colors.white.withValues(alpha: 0.2),
                    width: 1,
                  ),
                  boxShadow: (product.id == 'mystery-crate' || inCart)
                      ? [
                          BoxShadow(
                            color: _lime.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : [],
                ),
                child: Icon(
                  product.id == 'mystery-crate'
                      ? Icons.play_arrow_rounded
                      : (inCart ? Icons.check : Icons.add_shopping_cart),
                  color: (product.id == 'mystery-crate' || inCart) ? Colors.black : Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  ),
);

    // Apply cascading entrance transition
    return TweenAnimationBuilder<double>(
      key: ValueKey('store_card_anim_${product.id}'),
      duration: Duration(milliseconds: 400 + (index * 60).clamp(0, 450)),
      curve: Curves.easeOutCubic,
      tween: Tween<double>(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 30 * (1.0 - value)),
          child: Opacity(
            opacity: value,
            child: child,
          ),
        );
      },
      child: cardWidget,
    );
  }

  Widget _buildMyItemsTab() {
    final purchasesAsync = ref.watch(userPurchasesProvider);
    final equippedAsync = ref.watch(equippedItemsProvider);

    return purchasesAsync.when(
      data: (purchases) {
        if (purchases.isEmpty) {
          return _buildEmptyState();
        }

        return equippedAsync.when(
          data: (equipped) {
            final themes = purchases.where((p) {
              final type = p.productType.toUpperCase();
              return type.contains('THEME') && !type.contains('DECORATION');
            }).toList();

            final decorations = purchases.where((p) {
              final type = p.productType.toUpperCase();
              return type.contains('DECORATION');
            }).toList();

            final stickers = purchases.where((p) {
              final type = p.productType.toUpperCase();
              return type == 'STICKERS';
            }).toList();

            final sounds = purchases.where((p) {
              final type = p.productType.toUpperCase();
              return type == 'SOUNDS';
            }).toList();

            final badges = purchases.where((p) {
              final type = p.productType.toUpperCase();
              return type.contains('BADGE') && !type.contains('NAMEPLATE');
            }).toList();

            final nameplates = purchases.where((p) {
              final type = p.productType.toUpperCase();
              return type == 'NAMEPLATE';
            }).toList();

            final voiceSkins = purchases.where((p) {
              final type = p.productType.toUpperCase();
              return type == 'VOICE_SKIN';
            }).toList();

            final warpDrips = purchases.where((p) {
              final type = p.productType.toUpperCase();
              return type == 'ENTRANCE_WARP' || type == 'DRIP_CARD';
            }).toList();

            final crates = purchases.where((p) {
              final type = p.productType.toUpperCase();
              return p.productId == 'mystery-crate' || type == 'CRATE';
            }).toList();

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFusionBanner(),
                  const SizedBox(height: 12),
                  _buildGachaBanner(crates.length),
                  const SizedBox(height: 12),
                  _buildBadgeAlchemyBanner(),
                  const SizedBox(height: 24),
                  if (crates.isNotEmpty) ...[
                    _buildMyItemsSection('MYSTERY_CRATES', crates, equipped, 0),
                    const SizedBox(height: 24),
                  ],
                  _buildMyItemsSection('THEMES', themes, equipped, 1),
                  const SizedBox(height: 24),
                  _buildMyItemsSection('AVATAR_DECORATIONS', decorations, equipped, 2),
                  const SizedBox(height: 24),
                  _buildMyItemsSection('NAMEPLATES', nameplates, equipped, 3),
                  const SizedBox(height: 24),
                  _buildMyItemsSection('VOICE_SKINS', voiceSkins, equipped, 4),
                  const SizedBox(height: 24),
                  _buildMyItemsSection('WARP_DRIPS', warpDrips, equipped, 5),
                  const SizedBox(height: 24),
                  _buildMyItemsSection('STICKER_PACKS', stickers, equipped, 6),
                  const SizedBox(height: 24),
                  _buildMyItemsSection('SOUNDBOARDS', sounds, equipped, 7),
                  const SizedBox(height: 24),
                  _buildMyItemsSection('BADGES', badges, equipped, 8),
                  const SizedBox(height: 80),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator(color: _neon)),
          error: (_, __) => const Center(child: Text('Error loading equipped items', style: TextStyle(color: Colors.red))),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: _neon)),
      error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: Colors.red))),
    );
  }

  Widget _buildFusionBanner() {
    return GestureDetector(
      onTap: () {
        FlickoHaptics.medium();
        context.push('/store/fusion');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _neon.withValues(alpha: 0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _neon.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.science_outlined, color: _neon, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Cosmic Fusion Chamber',
                          style: GoogleFonts.inter(
                            color: _white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fuse duplicate or unwanted items to synthesize high-rarity premium cosmetics!',
                    style: GoogleFonts.inter(
                      color: _muted,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _neon.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.bolt, color: _neon, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGachaBanner(int ownedCount) {
    const Color magenta = Color(0xFFFF007F);
    return GestureDetector(
      onTap: () {
        FlickoHaptics.medium();
        context.push('/store/gacha');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: magenta.withValues(alpha: 0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: magenta.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.casino_outlined, color: magenta, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Mystery Vinyl Deck',
                          style: GoogleFonts.inter(
                            color: _white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: magenta.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '$ownedCount Unopened',
                          style: GoogleFonts.inter(
                            color: magenta,
                            fontWeight: FontWeight.bold,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Spin the vinyl record for a chance to unlock legendary cosmetics!',
                    style: GoogleFonts.inter(
                      color: _muted,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: magenta.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: magenta, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgeAlchemyBanner() {
    const Color gold = Color(0xFFFFD700);
    return GestureDetector(
      onTap: () {
        FlickoHaptics.medium();
        context.push('/store/badge-alchemy');
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: gold.withValues(alpha: 0.2), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: gold.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome, color: gold, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Alchemical Crucible',
                          style: GoogleFonts.inter(
                            color: _white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 0.5,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: gold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Active',
                          style: GoogleFonts.inter(
                            color: gold,
                            fontWeight: FontWeight.bold,
                            fontSize: 8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fuse lower-tier badges to claim high-tier badge rewards!',
                    style: GoogleFonts.inter(
                      color: _muted,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: gold.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.flash_on, color: gold, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMyItemsSection(String title, List<UserPurchase> items, Map<String, EquippedItem> equipped, int categoryIndex) {
    // Format technical titles to beautiful, clean text
    final formattedTitle = title
        .replaceAll('_', ' ')
        .split(' ')
        .map((str) => str.isNotEmpty ? str[0].toUpperCase() + str.substring(1).toLowerCase() : '')
        .join(' ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                formattedTitle,
                style: GoogleFonts.inter(
                  color: _lime,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${items.length} Owned',
              style: GoogleFonts.inter(
                color: _muted,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              children: [
                Text(
                  'No items owned in this category',
                  style: GoogleFonts.inter(color: _muted, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    _tabController.animateTo(0);
                    setState(() => _selectedCategory = categoryIndex);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _lime.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _lime, width: 1.2),
                    ),
                    child: Text(
                      'Browse Store',
                      style: GoogleFonts.inter(
                        color: _lime,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: items.map((purchase) => _buildPurchaseItem(purchase, equipped)).toList(),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shopping_bag_outlined, color: _muted, size: 64),
          const SizedBox(height: 16),
          Text(
            'No Items Yet',
            style: GoogleFonts.epilogue(
              color: _white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Items you purchase will appear here.',
            style: GoogleFonts.inter(color: _muted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _tabController.animateTo(0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: _neon,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Browse Store',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseItem(UserPurchase purchase, Map<String, EquippedItem> equipped) {
    final typeKey = purchase.productType.toLowerCase();
    final isEquipped = equipped[typeKey]?.productId == purchase.productId;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isEquipped ? _lime : Colors.white.withValues(alpha: 0.08),
          width: isEquipped ? 2.0 : 1.0,
        ),
        boxShadow: isEquipped
            ? [
                BoxShadow(
                  color: _lime.withValues(alpha: 0.15),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: isEquipped ? _lime.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isEquipped ? _lime.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: Icon(
              _iconForType(purchase.productType),
              color: isEquipped ? _lime : _white.withValues(alpha: 0.6),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        purchase.productName.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: _white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          letterSpacing: 0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isEquipped) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _lime.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _lime.withValues(alpha: 0.4), width: 1),
                        ),
                        child: Text(
                          'Equipped',
                          style: GoogleFonts.inter(
                            color: _lime,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  purchase.productType.toUpperCase(),
                  style: GoogleFonts.inter(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (purchase.productType.toUpperCase() == 'CRATE')
            GestureDetector(
              onTap: () {
                FlickoHaptics.medium();
                context.push('/store/gacha');
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF007F), // Magenta
                  border: Border.all(color: Colors.black, width: 1.5),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFFFF007F),
                      blurRadius: 14, offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Text(
                  'Open Crate',
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 9,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: Icon(Icons.more_vert, color: isEquipped ? _lime : _muted, size: 18),
              onPressed: () => _showDirectItemOptions(purchase, isEquipped),
            ),
        ],
      ),
    );
  }

  void _showDirectItemOptions(UserPurchase item, bool isEquipped) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.1),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 20),
              Text(
                item.productName.toUpperCase(),
                style: GoogleFonts.inter(
                  color: _white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              if (!isEquipped)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    color: _lime.withValues(alpha: 0.2),
                    child: const Icon(Icons.check_circle, color: _lime),
                  ),
                  title: Text(
                    'Equip Item',
                    style: GoogleFonts.inter(color: _white, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                  subtitle: Text(
                    'Activate this ${item.productType.toLowerCase()}',
                    style: GoogleFonts.inter(color: _muted),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _equipItemDirect(item);
                  },
                ),
              if (isEquipped)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    color: Colors.red.withValues(alpha: 0.2),
                    child: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  ),
                  title: Text(
                    'Unequip Item',
                    style: GoogleFonts.inter(color: Colors.red, fontWeight: FontWeight.w900, letterSpacing: 1),
                  ),
                  subtitle: Text(
                    'Stop using this ${item.productType.toLowerCase()}',
                    style: GoogleFonts.inter(color: _muted),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _unequipItemDirect(item);
                  },
                ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  color: _white.withValues(alpha: 0.1),
                  child: const Icon(Icons.card_giftcard, color: Colors.white),
                ),
                title: Text(
                  'Gift to a Friend',
                  style: GoogleFonts.inter(color: _white, fontWeight: FontWeight.w900, letterSpacing: 1),
                ),
                subtitle: Text('Send to another user', style: GoogleFonts.inter(color: _muted)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gifting coming soon!'), backgroundColor: _lime),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
            ),
          ),
        ),
    );
  }

  Future<void> _equipItemDirect(UserPurchase item) async {
    final service = ref.read(equipmentServiceProvider);
    final success = await service.equipItem(item.productId, item.productType);
    
    if (success) {
      ref.invalidate(equippedItemsProvider);
      ref.invalidate(userPurchasesProvider);
      ref.invalidate(activeStoreThemeProvider);
      if (item.productType.toUpperCase() == 'VOICE_SKIN') {
        ref.invalidate(equippedVoiceSkinProvider);
        ref.invalidate(voiceFilterProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.productName} equipped successfully!'),
            backgroundColor: _lime,
          ),
        );
      }
    }
  }

  Future<void> _unequipItemDirect(UserPurchase item) async {
    final service = ref.read(equipmentServiceProvider);
    final success = await service.unequipItem(item.productId);
    
    if (success) {
      ref.invalidate(equippedItemsProvider);
      ref.invalidate(userPurchasesProvider);
      ref.invalidate(activeStoreThemeProvider);
      if (item.productType.toUpperCase() == 'VOICE_SKIN') {
        ref.invalidate(equippedVoiceSkinProvider);
        ref.invalidate(voiceFilterProvider);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.productName} unequipped'),
            backgroundColor: _lime,
          ),
        );
      }
    }
  }

  void _showCrateSpinDialog(StoreProduct product) async {
    FlickoHaptics.medium();
    // Instantly purchase the crate locally
    final success = await ref.read(storeServiceProvider).purchaseProduct(product);
    if (success && mounted) {
      ref.invalidate(userPurchasesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('MYSTERY CRATE PURCHASED! ENTERING UNBOXING DECK...'),
          backgroundColor: Color(0xFFFF007F),
          duration: Duration(milliseconds: 1500),
        ),
      );
      // Wait a moment and navigate to unboxing arena
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        context.push('/store/gacha');
      }
    }
  }

  Widget _buildCartFAB(List<CartItem> cart) {
    return GestureDetector(
      onTap: () => context.push('/store/cart'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: _neon,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: _neon.withValues(alpha: 0.4),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shopping_bag, color: Colors.black),
            const SizedBox(width: 8),
            Text(
              '${cart.length} item${cart.length == 1 ? '' : 's'} • ₹${ref.read(cartProvider.notifier).total.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                color: Colors.black,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return _gold;
      case 'epic':
        return _neon;
      case 'rare':
        return const Color(0xFF00E5FF);
      default:
        return _muted;
    }
  }

  IconData _iconForType(String type) {
    switch (type.toUpperCase()) {
      case 'THEME':
        return Icons.palette_rounded;
      case 'STICKERS':
        return Icons.emoji_emotions_rounded;
      case 'SOUNDS':
        return Icons.music_note_rounded;
      case 'BADGE':
        return Icons.verified_rounded;
      case 'NAMEPLATE':
        return Icons.badge_rounded;
      case 'VOICE_SKIN':
      case 'VOICESKIN':
        return Icons.graphic_eq_rounded;
      case 'ENTRANCE_WARP':
        return Icons.blur_on;
      case 'DRIP_CARD':
        return Icons.crop_portrait;
      case 'BUNDLE':
        return Icons.inventory_2_rounded;
      case 'CRATE':
        return Icons.album_rounded;
      default:
        return Icons.store_rounded;
    }
  }
}

// ==========================================
// GACHA CRATE TURNTABLE SPIN DIALOG & WIDGETS
// ==========================================

class ConfettiParticle {
  double x;
  double y;
  double vx;
  double vy;
  Color color;
  double size;
  double gravity;

  ConfettiParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.color,
    required this.size,
    this.gravity = 0.2,
  });

  void update() {
    vy += gravity;
    x += vx;
    y += vy;
  }
}

class GachaSpinDialog extends StatefulWidget {
  final StoreProduct crateProduct;
  final StoreService storeService;
  final VoidCallback onUnlocked;

  const GachaSpinDialog({
    super.key,
    required this.crateProduct,
    required this.storeService,
    required this.onUnlocked,
  });

  @override
  State<GachaSpinDialog> createState() => _GachaSpinDialogState();
}

class _GachaSpinDialogState extends State<GachaSpinDialog> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _needleController;
  late AnimationController _confettiController;
  
  bool _isSpinning = false;
  StoreProduct? _reward;
  final List<ConfettiParticle> _particles = [];
  final math.Random _random = math.Random();
  bool _isEquipped = false;

  static const Color _bg = Color(0xFF000000);
  static const Color _neon = Color(0xFF52B788);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xFF71717A);
  static const Color _gold = Color(0xFFFFD700);

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return _gold;
      case 'epic':
        return _neon;
      case 'rare':
        return const Color(0xFF00E5FF);
      default:
        return _muted;
    }
  }

  IconData _iconForType(String type) {
    switch (type.toUpperCase()) {
      case 'THEME':
        return Icons.palette_rounded;
      case 'STICKERS':
        return Icons.emoji_emotions_rounded;
      case 'SOUNDS':
        return Icons.music_note_rounded;
      case 'BADGE':
        return Icons.verified_rounded;
      case 'NAMEPLATE':
        return Icons.badge_rounded;
      case 'VOICE_SKIN':
      case 'VOICESKIN':
        return Icons.graphic_eq_rounded;
      case 'ENTRANCE_WARP':
        return Icons.blur_on;
      case 'DRIP_CARD':
        return Icons.crop_portrait;
      case 'BUNDLE':
        return Icons.inventory_2_rounded;
      case 'CRATE':
        return Icons.album_rounded;
      default:
        return Icons.store_rounded;
    }
  }

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _confettiController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..addListener(() {
        _updateConfetti();
      });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _needleController.dispose();
    _confettiController.dispose();
    super.dispose();
  }

  void _spawnConfetti() {
    final colors = [
      _neon,
      _gold,
      const Color(0xFF00E5FF),
      Colors.pinkAccent,
      Colors.orangeAccent,
    ];
    _particles.clear();
    for (int i = 0; i < 80; i++) {
      _particles.add(
        ConfettiParticle(
          x: 150 + _random.nextDouble() * 100,
          y: 400,
          vx: (_random.nextDouble() - 0.5) * 12,
          vy: -(_random.nextDouble() * 10 + 5),
          color: colors[_random.nextInt(colors.length)],
          size: _random.nextDouble() * 6 + 4,
        ),
      );
    }
  }

  void _updateConfetti() {
    if (!mounted) return;
    setState(() {
      for (final p in _particles) {
        p.update();
      }
    });
  }

  void _startUnboxing() async {
    if (_isSpinning) return;
    setState(() {
      _isSpinning = true;
      _reward = null;
      _isEquipped = false;
    });

    // 1. Drop the needle arm onto the record
    await _needleController.forward();
    setState(() {
      _isNeedleDropped = true;
    });

    // 2. Start rapid spinning
    _rotationController.repeat();
    
    // Roll reward from service
    final reward = widget.storeService.getRandomGachaReward();

    // 3. Spin for 2 seconds
    await Future.delayed(const Duration(milliseconds: 2000));
    
    // Decelerate turntable rotation
    await _rotationController.animateTo(
      _rotationController.value + 1.8,
      duration: const Duration(milliseconds: 1500),
      curve: Curves.decelerate,
    );
    _rotationController.stop();

    // Add purchase to local SharedPreferences database
    await widget.storeService.purchaseProduct(reward);
    widget.onUnlocked();

    // 4. Reveal reward & launch confetti shower
    setState(() {
      _reward = reward;
      _isSpinning = false;
      _spawnConfetti();
    });
    _confettiController.repeat();
  }

  Future<void> _equipRewardDirect(WidgetRef ref, StoreProduct reward) async {
    final service = ref.read(equipmentServiceProvider);
    final success = await service.equipItem(reward.id, reward.type);
    if (success) {
      ref.invalidate(equippedItemsProvider);
      ref.invalidate(userPurchasesProvider);
      ref.invalidate(activeStoreThemeProvider);
      setState(() {
        _isEquipped = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: _bg.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1),
              boxShadow: [
                BoxShadow(
                  color: _neon.withValues(alpha: 0.18),
                  blurRadius: 32,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        'Turntable Gacha',
                        style: GoogleFonts.inter(
                          color: _white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Spin the platter to drop a reward.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          color: _muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  const SizedBox(height: 24),

                  // The Turntable Deck Area
                  if (_reward == null)
                    AnimatedBuilder(
                      animation: Listenable.merge([_rotationController, _needleController]),
                      builder: (context, child) {
                        return Container(
                          width: 280,
                          height: 280,
                          decoration: BoxDecoration(
                            border: Border.all(color: _neon, width: 2),
                          ),
                          child: CustomPaint(
                            painter: TurntablePainter(
                              rotationAngle: _rotationController.value,
                              needleProgress: _needleController.value,
                              neonColor: _neon,
                            ),
                          ),
                        );
                      },
                    )
                  else
                    // Reward Reveal Card
                    _buildRewardCard(_reward!),

                  const SizedBox(height: 24),

                  // Actions
                  if (_reward == null)
                    GestureDetector(
                      onTap: _isSpinning ? null : _startUnboxing,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _isSpinning ? const Color(0xFF1A1A1A) : _neon,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: _isSpinning
                              ? null
                              : [
                                  BoxShadow(
                                    color: _neon.withValues(alpha: 0.35),
                                    blurRadius: 18,
                                    spreadRadius: 1,
                                  ),
                                ],
                        ),
                        child: Center(
                          child: Text(
                            _isSpinning ? 'Spinning record…' : 'Drop needle to spin',
                            style: GoogleFonts.inter(
                              color: _isSpinning ? _muted : Colors.black,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ),
                    )
                  else
                    Consumer(
                      builder: (context, ref, _) {
                        return Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: _isEquipped ? null : () => _equipRewardDirect(ref, _reward!),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: _isEquipped ? const Color(0xFF1A1A1A) : _neon,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _isEquipped ? 'Equipped' : 'Equip now',
                                      style: GoogleFonts.inter(
                                        color: _isEquipped ? _neon : Colors.black,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => Navigator.pop(context),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: _white.withValues(alpha: 0.2), width: 1),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Close',
                                      style: GoogleFonts.inter(
                                        color: _white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                ],
              ),
            ),
            
            // Confetti canvas overlays
            if (_reward != null)
              IgnorePointer(
                child: SizedBox(
                  width: double.infinity,
                  height: size.height * 0.6,
                  child: CustomPaint(
                    painter: ConfettiPainter(particles: _particles),
                  ),
                ),
              ),
          ],
        ),
          ),
        ),
      ),
    );
  }

  Widget _buildRewardCard(StoreProduct reward) {
    final rarityColor = _getRarityColor(reward.rarity);
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: rarityColor.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: rarityColor.withValues(alpha: 0.25),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: rarityColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: rarityColor.withValues(alpha: 0.5), width: 1),
            ),
            child: Text(
              _capitalize(reward.rarity),
              style: GoogleFonts.inter(
                color: rarityColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Icon(
            _iconForType(reward.type),
            color: rarityColor,
            size: 64,
          ),
          const SizedBox(height: 20),
          Text(
            reward.name,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _capitalize(reward.type.replaceAll('_', ' ')),
            style: GoogleFonts.inter(
              color: _muted,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            reward.description ?? 'A high-fidelity cosmetic unlocked via Gacha Spin.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _white.withValues(alpha: 0.7),
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1).toLowerCase();
}

class TurntablePainter extends CustomPainter {
  final double rotationAngle;
  final double needleProgress;
  final Color neonColor;

  TurntablePainter({
    required this.rotationAngle,
    required this.needleProgress,
    required this.neonColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    // 1. Draw Turntable Deck (Brutalist box outline)
    final deckPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = neonColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), deckPaint);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), borderPaint);

    // 2. Draw Vinyl record body (rotating)
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle * 2 * math.pi);

    final recordPaint = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, radius, recordPaint);

    // Draw grooves
    final groovePaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    for (double r = radius - 15; r > 10; r -= 15) {
      canvas.drawCircle(Offset.zero, r, groovePaint);
    }

    // Draw custom neon center label
    final labelPaint = Paint()
      ..color = neonColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 18, labelPaint);

    final innerCirclePaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset.zero, 5, innerCirclePaint);

    canvas.restore();

    // 3. Draw Turntable Tonearm (Needle arm)
    final pivot = Offset(size.width - 25, 25);
    final tonearmPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final swivelAngle = 0.05 + (0.35 * needleProgress);
    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(swivelAngle);

    // Draw tonearm segments
    canvas.drawLine(Offset.zero, const Offset(-10, 80), tonearmPaint);
    canvas.drawLine(const Offset(-10, 80), const Offset(-30, 140), tonearmPaint);
    
    // Draw needle head cartridge
    final headPaint = Paint()
      ..color = neonColor
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(center: const Offset(-30, 140), width: 12, height: 18),
      headPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant TurntablePainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle ||
        oldDelegate.needleProgress != needleProgress ||
        oldDelegate.neonColor != neonColor;
  }
}

class ConfettiPainter extends CustomPainter {
  final List<ConfettiParticle> particles;

  ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final paint = Paint()
        ..color = p.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(p.x, p.y), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

