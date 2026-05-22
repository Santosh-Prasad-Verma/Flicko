import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/equipment_service.dart';
import 'package:mobile/features/store/data/wishlist_service.dart';

class StoreScreen extends ConsumerStatefulWidget {
  const StoreScreen({super.key});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends ConsumerState<StoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedCategory = 0;
  String _searchQuery = '';
  bool _showSearch = false;
  bool _showFilters = false;
  String _sortBy = 'newest'; // newest, price_low, price_high, popular
  final _searchController = TextEditingController();

  static const _bg = Color(0xFF050505);
  static const _surface = Color(0xFF0C0C0E);
  static const _neon = Color(0xFF9B84EE);
  static const _white = Color(0xFFFFFFFF);
  static const _muted = Color(0xFF71717A);
  static const _lime = Color(0xFF52B788);
  static const _gold = Color(0xFFFFD700);

  final _categories = ['ALL', 'THEMES', 'STICKERS', 'SOUNDS', 'BADGES'];

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
    
    return Scaffold(
      backgroundColor: _bg,
      appBar: _buildAppBar(cart),
      body: TabBarView(
        controller: _tabController,
        children: [_buildDiscoverTab(), _buildMyItemsTab()],
      ),
      floatingActionButton: cart.isNotEmpty
          ? _buildCartFAB(cart)
          : null,
    );
  }

  PreferredSizeWidget _buildAppBar(List<CartItem> cart) {
    return AppBar(
      backgroundColor: _surface,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: _white),
        onPressed: () => context.pop(),
      ),
      title: _showSearch
          ? _buildSearchField()
          : Text(
              'Store',
              style: GoogleFonts.epilogue(
                color: _white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                fontStyle: FontStyle.italic,
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
                    color: _neon,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '${cart.length}',
                    style: GoogleFonts.spaceGrotesk(
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
      bottom: TabBar(
        controller: _tabController,
        indicatorColor: _neon,
        indicatorWeight: 2,
        labelColor: _white,
        unselectedLabelColor: _muted,
        labelStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 13),
        tabs: const [Tab(text: 'DISCOVER'), Tab(text: 'MY ITEMS')],
      ),
    );
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      style: GoogleFonts.spaceGrotesk(color: _white),
      decoration: InputDecoration(
        hintText: 'Search products...',
        hintStyle: GoogleFonts.spaceGrotesk(color: _muted),
        filled: true,
        fillColor: _bg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      onChanged: (v) => setState(() => _searchQuery = v),
    );
  }

  Widget _buildDiscoverTab() {
    final type = _categories[_selectedCategory];
    final productsAsync = ref.watch(storeProductsProvider((type: type, search: _searchQuery.isNotEmpty ? _searchQuery : null)));
    final wishlist = ref.watch(wishlistProvider);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _buildFeaturedBanner()),
        SliverToBoxAdapter(child: _buildCategoryChips()),
        SliverToBoxAdapter(child: _buildSortFilter()),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
        productsAsync.when(
          data: (products) {
            // Sort products
            final sorted = List<StoreProduct>.from(products);
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
                          style: GoogleFonts.spaceGrotesk(color: _white, fontWeight: FontWeight.w700),
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
                  childAspectRatio: 0.75,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildProductCard(sorted[index], wishlist),
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
                      style: GoogleFonts.spaceGrotesk(color: _white, fontSize: 12),
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
                    style: GoogleFonts.spaceGrotesk(color: _white, fontSize: 12),
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
                style: GoogleFonts.spaceGrotesk(color: _white, fontWeight: FontWeight.w700, fontSize: 16),
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
              title: Text(item.$2, style: GoogleFonts.spaceGrotesk(color: _white)),
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
    final wishlistProducts = ref.watch(wishlistProductsProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'My Wishlist',
                    style: GoogleFonts.spaceGrotesk(color: _white, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${ref.watch(wishlistProvider).length}',
                      style: GoogleFonts.spaceGrotesk(color: Colors.red, fontWeight: FontWeight.w700),
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
                          Text('Your wishlist is empty', style: GoogleFonts.spaceGrotesk(color: _muted)),
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
      ),
    );
  }

  Widget _buildWishlistItem(StoreProduct product) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _getRarityColor(product.rarity).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_iconForType(product.type), color: _getRarityColor(product.rarity), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: GoogleFonts.spaceGrotesk(color: _white, fontWeight: FontWeight.w600)),
                Text(
                  product.price == 0 ? 'FREE' : '\$${product.price.toStringAsFixed(2)}',
                  style: GoogleFonts.spaceGrotesk(color: _lime, fontWeight: FontWeight.w700),
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
        gradient: const LinearGradient(
          colors: [_neon, Color(0xFF00E5FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _white.withValues(alpha: 0.1)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _white.withValues(alpha: 0.05),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  color: Colors.black54,
                  child: Text(
                    'FEATURED DROP',
                    style: GoogleFonts.spaceMono(
                      color: Colors.white70,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Neon Pulse Theme',
                  style: GoogleFonts.epilogue(
                    color: Colors.black,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      color: Colors.black,
                      child: Text(
                        '\$4.99',
                        style: GoogleFonts.spaceGrotesk(
                          color: _white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.arrow_forward, color: Colors.black),
                  ],
                ),
              ],
            ),
          ),
        ],
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
            onTap: () => setState(() => _selectedCategory = index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? _neon : _surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? _neon : _white.withValues(alpha: 0.1),
                ),
              ),
              child: Text(
                _categories[index],
                style: GoogleFonts.spaceGrotesk(
                  color: selected ? Colors.black : _muted,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildProductCard(StoreProduct product, List<String> wishlist) {
    final rarityColor = _getRarityColor(product.rarity);
    final isFree = product.price == 0;
    final cart = ref.watch(cartProvider);
    final inCart = cart.any((item) => item.product.id == product.id);
    final inWishlist = wishlist.contains(product.id);

    return GestureDetector(
      onTap: () => context.push('/store/product/${product.id}'),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: rarityColor.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          rarityColor.withValues(alpha: 0.3),
                          rarityColor.withValues(alpha: 0.05),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    ),
                    child: Center(
                      child: Icon(
                        _iconForType(product.type),
                        color: rarityColor,
                        size: 48,
                      ),
                    ),
                  ),
                  if (product.isHot)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'HOT',
                          style: GoogleFonts.spaceMono(
                            color: _white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  // Wishlist button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => ref.read(wishlistProvider.notifier).toggle(product.id),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          inWishlist ? Icons.favorite : Icons.favorite_border,
                          color: inWishlist ? Colors.red : _white,
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: rarityColor.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        product.rarity.toUpperCase(),
                        style: GoogleFonts.spaceMono(
                          color: Colors.black,
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: GoogleFonts.spaceGrotesk(
                      color: _white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    product.type.toUpperCase(),
                    style: GoogleFonts.spaceMono(
                      color: _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isFree ? 'FREE' : '\$${product.price.toStringAsFixed(2)}',
                        style: GoogleFonts.epilogue(
                          color: isFree ? _lime : _white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          ref.read(cartProvider.notifier).add(product);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${product.name} added to cart'),
                              backgroundColor: _lime,
                              action: SnackBarAction(
                                label: 'VIEW',
                                textColor: Colors.black,
                                onPressed: () => context.push('/store/cart'),
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: inCart ? _lime : _neon,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            inCart ? Icons.check : Icons.add_shopping_cart,
                            color: Colors.black,
                            size: 16,
                          ),
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
          data: (equipped) => Column(
            children: [
              // Quick access header
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${purchases.length} item${purchases.length == 1 ? '' : 's'} owned',
                      style: GoogleFonts.spaceGrotesk(color: _muted, fontSize: 12),
                    ),
                    GestureDetector(
                      onTap: () => context.push('/store/inventory'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _neon,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.inventory_2, color: Colors.black, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              'MANAGE',
                              style: GoogleFonts.spaceGrotesk(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Items list
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: purchases.length,
                  itemBuilder: (context, index) => _buildPurchaseItem(purchases[index], equipped),
                ),
              ),
            ],
          ),
          loading: () => const Center(child: CircularProgressIndicator(color: _neon)),
          error: (_, __) => const Center(child: Text('Error loading equipped items', style: TextStyle(color: Colors.red))),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: _neon)),
      error: (e, _) => Center(child: Text('Error: $e', style: TextStyle(color: Colors.red))),
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
            'NO ITEMS YET',
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
                'BROWSE STORE',
                style: GoogleFonts.spaceGrotesk(
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
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isEquipped ? _lime : _white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _neon.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _iconForType(purchase.productType),
              color: _neon,
              size: 24,
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
                        purchase.productName,
                        style: GoogleFonts.spaceGrotesk(
                          color: _white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (isEquipped)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: _lime,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'EQUIPPED',
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 9,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  purchase.productType.toUpperCase(),
                  style: GoogleFonts.spaceMono(
                    color: _muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: _muted, size: 18),
            onPressed: () => context.push('/store/inventory'),
          ),
        ],
      ),
    );
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
              '${cart.length} item${cart.length == 1 ? '' : 's'} • \$${ref.read(cartProvider.notifier).total.toStringAsFixed(2)}',
              style: GoogleFonts.spaceGrotesk(
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
      default:
        return Icons.store_rounded;
    }
  }
}
