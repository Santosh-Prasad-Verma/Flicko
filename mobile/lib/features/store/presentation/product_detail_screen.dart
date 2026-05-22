import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/wishlist_service.dart';
import 'package:mobile/features/store/presentation/widgets/product_preview_widget.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  static const Color _bg = Color(0xFF050505);
  static const Color _surface = Color(0xFF0C0C0E);
  static const Color _neon = Color(0xFF9B84EE);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xFF71717A);
  static const Color _lime = Color(0xFF52B788);
  static const Color _gold = Color(0xFFFFD700);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productProvider(productId));

    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _surface.withValues(alpha: 0.8),
            shape: BoxShape.circle,
          ),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: _white),
            onPressed: () => context.pop(),
          ),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _surface.withValues(alpha: 0.8),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.share, color: _white),
              onPressed: () {
                // Share functionality
              },
            ),
          ),
        ],
      ),
      body: productAsync.when(
        data: (product) {
          if (product == null) {
            return _buildNotFound();
          }
          return _buildProductDetail(context, ref, product);
        },
        loading: () => const Center(child: CircularProgressIndicator(color: _neon)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildNotFound() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: _muted, size: 64),
          const SizedBox(height: 16),
          Text(
            'Product not found',
            style: GoogleFonts.epilogue(color: _white, fontSize: 20, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _buildProductDetail(BuildContext context, WidgetRef ref, StoreProduct product) {
    final rarityColor = _getRarityColor(product.rarity);
    final isFree = product.price == 0;
    final cart = ref.watch(cartProvider);
    final inCart = cart.any((item) => item.product.id == product.id);

    return Stack(
      children: [
        // Background gradient
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 400,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  rarityColor.withValues(alpha: 0.3),
                  _bg,
                ],
              ),
            ),
          ),
        ),
        // Content
        SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 100),
              // Product preview
              _buildProductPreview(product, rarityColor),
              const SizedBox(height: 24),
              // Product info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: rarityColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            product.rarity.toUpperCase(),
                            style: GoogleFonts.spaceMono(
                              color: Colors.black,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (product.isHot)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_fire_department, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'HOT',
                                  style: GoogleFonts.spaceMono(
                                    color: _white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      product.name,
                      style: GoogleFonts.epilogue(
                        color: _white,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(_iconForType(product.type), color: _muted, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          product.type.toUpperCase(),
                          style: GoogleFonts.spaceGrotesk(
                            color: _muted,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Description
                    if (product.description != null) ...[
                      Text(
                        'DESCRIPTION',
                        style: GoogleFonts.spaceGrotesk(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.description!,
                        style: GoogleFonts.spaceGrotesk(
                          color: _white.withValues(alpha: 0.8),
                          fontSize: 14,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                    // Features
                    _buildFeaturesSection(product),
                    const SizedBox(height: 24),
                    // Reviews
                    _buildReviewsSection(),
                  ],
                ),
              ),
            ],
          ),
        ),
        // Bottom bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: _buildBottomBar(context, ref, product, isFree, inCart),
        ),
      ],
    );
  }

  Widget _buildProductPreview(StoreProduct product, Color rarityColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ProductPreviewWidget(
        productType: product.type,
        productName: product.name,
        primaryColor: rarityColor,
        secondaryColor: Colors.black,
        height: 280,
      ),
    );
  }

  Widget _buildFeaturesSection(StoreProduct product) {
    final features = _getFeaturesForType(product.type);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'INCLUDES',
          style: GoogleFonts.spaceGrotesk(
            color: _muted,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        ...features.map((feature) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: _lime, size: 18),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  feature,
                  style: GoogleFonts.spaceGrotesk(
                    color: _white.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'REVIEWS',
              style: GoogleFonts.spaceGrotesk(
                color: _muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            Row(
              children: [
                ...List.generate(5, (i) => const Icon(Icons.star, color: _gold, size: 16)),
                const SizedBox(width: 8),
                Text(
                  '4.9 (128 reviews)',
                  style: GoogleFonts.spaceGrotesk(
                    color: _white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _neon.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: _neon, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alex_Gamer',
                        style: GoogleFonts.spaceGrotesk(
                          color: _white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Row(
                        children: List.generate(5, (i) => const Icon(Icons.star, color: _gold, size: 12)),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Amazing product! The quality is fantastic and it looks even better in person.',
                style: GoogleFonts.spaceGrotesk(
                  color: _white.withValues(alpha: 0.7),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context, WidgetRef ref, StoreProduct product, bool isFree, bool inCart) {
    final wishlist = ref.watch(wishlistProvider);
    final isInWishlist = wishlist.contains(product.id);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surface,
        border: Border(top: BorderSide(color: _white.withValues(alpha: 0.1))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Wishlist button
            GestureDetector(
              onTap: () async {
                await ref.read(wishlistProvider.notifier).toggle(product.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isInWishlist ? 'Removed from wishlist' : 'Added to wishlist'),
                      backgroundColor: isInWishlist ? Colors.red : _lime,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
              },
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isInWishlist ? Colors.red : _white.withValues(alpha: 0.2),
                  ),
                ),
                child: Icon(
                  isInWishlist ? Icons.favorite : Icons.favorite_border,
                  color: isInWishlist ? Colors.red : _white.withValues(alpha: 0.7),
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'PRICE',
                    style: GoogleFonts.spaceGrotesk(
                      color: _muted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    isFree ? 'FREE' : '\$${product.price.toStringAsFixed(2)}',
                    style: GoogleFonts.epilogue(
                      color: isFree ? _lime : _white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: () {
                  if (inCart) {
                    context.push('/store/cart');
                    return;
                  }

                  ref.read(cartProvider.notifier).add(product);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.name} added to cart'),
                      backgroundColor: _lime,
                      action: SnackBarAction(
                        label: 'VIEW CART',
                        textColor: Colors.black,
                        onPressed: () => context.push('/store/cart'),
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: inCart
                          ? [_lime, _lime]
                          : [_neon, const Color(0xFF00E5FF)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          inCart ? Icons.shopping_bag : Icons.add_shopping_cart,
                          color: Colors.black,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          inCart ? 'IN CART' : (isFree ? 'GET FREE' : 'ADD'),
                          style: GoogleFonts.spaceGrotesk(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
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
    );
  }

  List<String> _getFeaturesForType(String type) {
    switch (type.toUpperCase()) {
      case 'THEME':
        return [
          'Custom color palette',
          'Dark mode optimized',
          'Animated backgrounds',
          'Icon pack included',
        ];
      case 'STICKERS':
        return [
          '50+ unique stickers',
          'HD quality',
          'Regular updates',
          'Exclusive designs',
        ];
      case 'SOUNDS':
        return [
          '20+ notification sounds',
          'Custom message tones',
          'High-quality audio',
          'Mix and match options',
        ];
      case 'BADGE':
        return [
          'Profile badge display',
          'Animated effects',
          'Priority status',
          'Exclusive design',
        ];
      default:
        return ['Premium quality', 'Exclusive content', 'Regular updates'];
    }
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
