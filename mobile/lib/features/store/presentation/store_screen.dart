import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/wishlist_service.dart';
import 'package:mobile/features/store/data/equipment_service.dart';
import 'package:mobile/core/services/flicko_haptics.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/features/store/presentation/widgets/discord_profile_preview_card.dart';

/// Discord-Style Mobile Shop Screen
class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _selectedCategory = 0;
  final _searchController = TextEditingController();

  // Colors matching Discord Mobile Shop Dark Theme
  static const _bgDark = Color(0xFF111214);
  static const _cardBg = Color(0xFF1E1F22);
  static const _cardBgLight = Color(0xFF2B2D31);
  static const _blurple = Color(0xFF5865F2);
  static const _greenDiscount = Color(0xFF23A55A);
  static const _purpleBannerGrad1 = Color(0xFF381F68);
  static const _purpleBannerGrad2 = Color(0xFF1D1137);

  final _categories = ['ALL', 'DECORATIONS', 'BANNERS', 'EFFECTS', 'THEMES', 'NAMEPLATES', 'BADGES', 'VOICE_SKINS', 'STICKERS'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final wishlist = ref.watch(wishlistProvider);

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: _buildDiscordAppBar(cart, wishlist),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDiscoverShopTab(wishlist),
          _buildMyItemsCollectionTab(),
        ],
      ),
    );
  }

  /// Top App Bar matching Discord Shop UI (Screenshot 1 & 2)
  PreferredSizeWidget _buildDiscordAppBar(List<CartItem> cart, List<String> wishlist) {
    return AppBar(
      backgroundColor: _bgDark,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Stack(
        alignment: Alignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
            onPressed: () => context.pop(),
          ),
          // Red Badge Notification (99)
          Positioned(
            right: 6,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFDA373C),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '99',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Text(
            'Shop',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
        ],
      ),
      actions: [
        // Orbs Currency Counter Pill (❖ 0)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, color: Colors.white70, size: 14),
              const SizedBox(width: 4),
              Text(
                '0',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // Wishlist Heart Action
        GestureDetector(
          onTap: () => _showWishlistSheet(),
          child: Stack(
            alignment: Alignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 22),
                onPressed: () => _showWishlistSheet(),
              ),
              if (wishlist.isNotEmpty)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFDA373C),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Hamburger Menu Action
        IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white, size: 24),
          onPressed: () {
            _showCategoryPickerSheet();
          },
        ),
        const SizedBox(width: 4),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(42),
        child: TabBar(
          controller: _tabController,
          indicatorColor: _blurple,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.tab,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white54,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Shop Discover'),
            Tab(text: 'My Inventory'),
          ],
        ),
      ),
    );
  }

  /// Main Discover Tab Layout
  Widget _buildDiscoverShopTab(List<String> wishlist) {
    final type = _categories[_selectedCategory];
    final productsAsync = ref.watch(storeProductsProvider((type: type, search: null)));

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Featured Hero Banner ("FIN." / Shark Theme) (Screenshot 1)
          _buildHeroFeatureCarousel(),

          const SizedBox(height: 16),

          // 2. Purple Announcement Section ("Frames are new in the Shop...") (Screenshot 1)
          _buildPurpleFrameAnnouncementSection(wishlist),

          const SizedBox(height: 24),

          // 3. Featured Collection Wide Banner ("NIGHT TERRORS") (Screenshot 2)
          _buildNightTerrorsBanner(),

          const SizedBox(height: 24),

          // 4. "Summer Bliss" Section Header + Items (Screenshot 2)
          _buildSectionHeader('Summer Bliss', onShopAll: () {}),
          const SizedBox(height: 12),
          _buildHorizontalBundlesRow(wishlist),

          const SizedBox(height: 28),

          // 5. "Find your style" Section Header + Main Grid (Screenshot 2, 3, 4)
          _buildSectionHeader('Find your style', onShopAll: () {}),
          const SizedBox(height: 12),

          // Main Product Grid
          productsAsync.when(
            data: (products) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    return _buildDiscordProductCard(products[index], wishlist);
                  },
                ),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: _blurple)),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text('Failed to load shop items: $e', style: const TextStyle(color: Colors.red)),
              ),
            ),
          ),

          const SizedBox(height: 100),
        ],
      ),
    );
  }

  /// Hero Carousel Banner ("FIN.") (Screenshot 1)
  Widget _buildHeroFeatureCarousel() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      height: 200,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F2027),
            Color(0xFF203A43),
            Color(0xFF2C5364),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black45,
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Dark Overlay Shark Graphic simulation
            Positioned(
              right: -20,
              top: -10,
              bottom: -10,
              child: Opacity(
                opacity: 0.85,
                child: Icon(
                  Icons.phishing_rounded,
                  size: 220,
                  color: Colors.cyan.withValues(alpha: 0.3),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'FIN.',
                    style: GoogleFonts.permanentMarker(
                      color: const Color(0xFFED4245),
                      fontSize: 52,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Submerge into the dark depths.',
                    style: GoogleFonts.inter(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Carousel Next Arrow Button
            Positioned(
              right: 16,
              top: 80,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: const BoxDecoration(
                  color: Colors.black54,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 24),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Purple Gradient Announcement Banner Section (Screenshot 1)
  Widget _buildPurpleFrameAnnouncementSection(List<String> wishlist) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_purpleBannerGrad1, _purpleBannerGrad2],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Frames are new in the Shop. Your profile called, it wants one.',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Horizontal Frames Row
          SizedBox(
            height: 200,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFrameCard('Miaow Miaow Cat', '₹255.00', ['cat_ears'], wishlist, colorDots: [Colors.pinkAccent, Colors.white, Colors.orangeAccent]),
                const SizedBox(width: 12),
                _buildFrameCard('Mariposa', '₹255.00', ['butterfly_wings'], wishlist, colorDots: [Colors.purpleAccent, Colors.lightBlueAccent, Colors.white]),
                const SizedBox(width: 12),
                _buildFrameCard('Solar Flare', '₹255.00', ['solar_ring'], wishlist, colorDots: [Colors.amber, Colors.orange]),
                const SizedBox(width: 12),
                _buildFrameCard('Fallen Angel', '₹255.00', ['angel_wings'], wishlist, colorDots: [Colors.deepPurpleAccent, Colors.blueAccent]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Featured Collection Wide Banner ("NIGHT TERRORS") (Screenshot 2)
  Widget _buildNightTerrorsBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 160,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: const Color(0xFF18191C),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        image: const DecorationImage(
          image: NetworkImage('https://images.unsplash.com/photo-1509198397868-475647b2a1e5?w=800&auto=format&fit=crop&q=60'),
          fit: BoxFit.cover,
          opacity: 0.35,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'NIGHT TERRORS',
                  style: GoogleFonts.creepster(
                    color: Colors.white,
                    fontSize: 34,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Exclusive Collection',
                    style: GoogleFonts.inter(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Section Header Row (Title + Shop All pill)
  Widget _buildSectionHeader(String title, {required VoidCallback onShopAll}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          GestureDetector(
            onTap: onShopAll,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: _blurple,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                'Shop All',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Horizontal Row of Bundles ("Summer Bliss") (Screenshot 2)
  Widget _buildHorizontalBundlesRow(List<String> wishlist) {
    return SizedBox(
      height: 210,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _buildBundleCard('the duck bundle', '₹445.00', '-13%', Icons.cruelty_free_rounded, wishlist),
          const SizedBox(width: 12),
          _buildBundleCard('Bubble Bundle', '₹445.00', '-13%', Icons.bubble_chart_rounded, wishlist),
          const SizedBox(width: 12),
          _buildBundleCard('Stalkers Bundle', '₹569.00', '-26%', Icons.visibility_rounded, wishlist),
          const SizedBox(width: 12),
          _buildBundleCard('Spider-Man Bundle', '₹879.00', '-24%', Icons.hub_rounded, wishlist),
        ],
      ),
    );
  }

  /// Discord Product Card (Matching Screenshot 1, 2, 3, 4)
  Widget _buildDiscordProductCard(StoreProduct product, List<String> wishlist) {
    final inWishlist = wishlist.contains(product.id);

    return GestureDetector(
      onTap: () => _showDiscordProductDetailSheet(product),
      child: Container(
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Card Preview Area
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _cardBgLight,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Center(
                      child: product.type.toUpperCase() == 'AVATAR_DECORATION'
                          ? UserAvatar(
                              size: 56,
                              decoration: product.id,
                              name: product.name,
                              showStatus: false,
                              showBadge: false,
                            )
                          : Icon(
                              _iconForType(product.type),
                              color: Colors.white70,
                              size: 44,
                            ),
                    ),
                  ),
                ),
                // Card Details Footer
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        product.price == 0 ? 'FREE' : '₹${product.price.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Wishlist Heart Icon (Top Right)
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () async {
                  FlickoHaptics.light();
                  await ref.read(wishlistProvider.notifier).toggle(product.id);
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    inWishlist ? Icons.favorite : Icons.favorite_border_rounded,
                    color: inWishlist ? const Color(0xFFED4245) : Colors.white70,
                    size: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Special Avatar Frame Card (Matching Screenshot 1 & 3)
  Widget _buildFrameCard(String title, String price, List<String> tags, List<String> wishlist, {List<Color>? colorDots}) {
    return GestureDetector(
      onTap: () {
        _showDiscordProductDetailSheet(StoreProduct(
          id: title.toLowerCase().replaceAll(' ', '_'),
          slug: title.toLowerCase().replaceAll(' ', '_'),
          name: title,
          description: 'Give your avatar a new look with this exclusive frame.',
          price: 255.00,
          rarity: 'Legendary',
          type: 'AVATAR_DECORATION',
        ));
      },
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _cardBgLight,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    child: Center(
                      child: UserAvatar(
                        size: 58,
                        name: title,
                        showStatus: false,
                        showBadge: false,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            price,
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                          if (colorDots != null)
                            Row(
                              children: colorDots.map((c) => Container(
                                margin: const EdgeInsets.only(left: 2),
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(color: c, shape: BoxShape.circle),
                              )).toList(),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            // Top Right Heart
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                child: const Icon(Icons.favorite_border_rounded, color: Colors.white70, size: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Bundle Card (Matching Screenshot 2 & 4)
  Widget _buildBundleCard(String title, String price, String discount, IconData icon, List<String> wishlist) {
    return Container(
      width: 155,
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _cardBgLight,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Center(
                    child: Icon(icon, color: Colors.cyanAccent, size: 48),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          price,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          discount,
                          style: GoogleFonts.inter(
                            color: _greenDiscount,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Top Right Heart
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
              child: const Icon(Icons.favorite_border_rounded, color: Colors.white70, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  /// DISCORD PRODUCT DETAIL MODAL BOTTOM SHEET (Screenshot 1, 2, 5)
  void _showDiscordProductDetailSheet(StoreProduct product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        int selectedTab = 0; // 0: Profile, 1: Decoration, 2: Nameplate

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Top Drag Handle Indicator & Header Icons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 40),
                      Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white24,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white10,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.remove_red_eye_outlined, color: Colors.white, size: 18),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white10,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.favorite_border_rounded, color: Colors.white, size: 18),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Large Interactive Preview Box (Profile / Decoration / Nameplate)
                  DiscordProfilePreviewCard(
                    previewProduct: product,
                    showLiveLabel: true,
                  ),
                  const SizedBox(height: 18),

                  // Title & Subtitle
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      product.name,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      product.description ?? 'Give your avatar and profile a new look.',
                      style: GoogleFonts.inter(
                        color: Colors.white60,
                        fontSize: 13,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Pricing Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        product.price == 0 ? 'FREE' : '₹${product.price.toStringAsFixed(2)}',
                        style: GoogleFonts.inter(
                          color: product.price == 0 ? _greenDiscount : Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                  Row(
                    children: [
                      const Icon(Icons.auto_awesome_rounded, color: Colors.white70, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '4100',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Flicko Nitro Discount Subscribing Row
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.white, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '₹210.00 with Nitro ',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {},
                    child: Text(
                      'subscribe now',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 13,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Main CTA Button: Buy Decoration + Gift Icon Button
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        ref.read(cartProvider.notifier).add(product);
                        Navigator.pop(context);
                        context.push('/store/cart');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blurple,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        'Buy Decoration',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _blurple,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Secondary CTA Button: Redeem ❖ 4100
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: null, // Disabled or active orb redemption
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: const BorderSide(color: Colors.white12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Redeem ',
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const Icon(Icons.auto_awesome_rounded, color: Colors.white54, size: 14),
                      Text(
                        ' 4100',
                        style: GoogleFonts.inter(color: Colors.white54, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Disclaimer Text
              Text(
                'By clicking \'Buy Decoration\', you agree to the Paid Service Terms. Buying an item from the Shop means you\'re buying a limited licence to use this item on Flicko.',
                style: GoogleFonts.inter(
                  color: Colors.white38,
                  fontSize: 10,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  },
);
}

  /// Category Picker Bottom Sheet
  void _showCategoryPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
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
                'Browse Categories',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            ..._categories.asMap().entries.map((entry) => ListTile(
              title: Text(
                entry.value.replaceAll('_', ' '),
                style: GoogleFonts.inter(
                  color: _selectedCategory == entry.key ? _blurple : Colors.white,
                  fontWeight: _selectedCategory == entry.key ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: _selectedCategory == entry.key ? const Icon(Icons.check_rounded, color: _blurple) : null,
              onTap: () {
                setState(() => _selectedCategory = entry.key);
                Navigator.pop(ctx);
              },
            )),
          ],
        ),
      ),
    );
  }

  /// Wishlist Sheet
  void _showWishlistSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final wishlistProducts = ref.watch(wishlistProductsProvider);
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'My Wishlist',
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 16),
                wishlistProducts.when(
                  data: (products) {
                    if (products.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(30),
                        child: Text('Your wishlist is empty.', style: TextStyle(color: Colors.white54)),
                      );
                    }
                    return Column(
                      children: products.map((p) => ListTile(
                        title: Text(p.name, style: const TextStyle(color: Colors.white)),
                        subtitle: Text('₹${p.price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white70)),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => ref.read(wishlistProvider.notifier).remove(p.id),
                        ),
                      )).toList(),
                    );
                  },
                  loading: () => const CircularProgressIndicator(color: _blurple),
                  error: (e, _) => Text('Error: $e', style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  /// My Items Collection Tab
  Widget _buildMyItemsCollectionTab() {
    final purchasesAsync = ref.watch(userPurchasesProvider);
    final equippedAsync = ref.watch(equippedItemsProvider);

    return purchasesAsync.when(
      data: (purchases) {
        if (purchases.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.inventory_2_outlined, color: Colors.white38, size: 64),
                const SizedBox(height: 16),
                Text(
                  'No Purchased Items',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: purchases.length,
          itemBuilder: (context, index) {
            final p = purchases[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _cardBg,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(_iconForType(p.productType), color: Colors.white70),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      p.productName,
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: _blurple)),
      error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toUpperCase()) {
      case 'AVATAR_DECORATION':
      case 'DECORATIONS':
        return Icons.face_retouching_natural_rounded;
      case 'THEME':
      case 'THEMES':
        return Icons.palette_rounded;
      case 'NAMEPLATE':
      case 'NAMEPLATES':
        return Icons.badge_rounded;
      case 'VOICE_SKIN':
      case 'VOICE_SKINS':
        return Icons.graphic_eq_rounded;
      case 'STICKERS':
        return Icons.sticky_note_2_rounded;
      default:
        return Icons.auto_awesome_rounded;
    }
  }
}
