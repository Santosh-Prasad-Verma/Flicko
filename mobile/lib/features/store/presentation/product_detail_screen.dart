import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/wishlist_service.dart';
import 'package:mobile/features/store/data/store_audio_preview_service.dart';
import 'package:mobile/features/store/data/store_theme_service.dart';

class ProductDetailScreen extends ConsumerWidget {
  final String productId;

  const ProductDetailScreen({super.key, required this.productId});

  static const Color _bg = Color(0xFF000000);
  static const Color _surface = Color(0xFF000000);
  static const Color _neon = Color(0xFF52B788);
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
            color: Colors.black,
            border: Border.all(color: _neon, width: 1.5),
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
            color: Colors.black,
            border: Border.all(color: _neon, width: 1.5),
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

  Widget _buildLiquidGlassBackground({required Widget child, required Color rarityColor}) {
    return Stack(
      children: [
        Container(color: const Color(0xFF000000)),
        // Rarity ambient glow
        Positioned(
          top: -80,
          left: -80,
          child: Container(
            width: 360,
            height: 360,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: rarityColor.withValues(alpha: 0.22),
            ),
          ),
        ),
        // Secondary ambient glow
        Positioned(
          bottom: 120,
          right: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF9B84EE).withValues(alpha: 0.12),
            ),
          ),
        ),
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 75, sigmaY: 75),
            child: Container(color: Colors.transparent),
          ),
        ),
        child,
      ],
    );
  }

  Widget _buildProductDetail(BuildContext context, WidgetRef ref, StoreProduct product) {
    final rarityColor = _getRarityColor(product.rarity);
    final isFree = product.price == 0;
    final cart = ref.watch(cartProvider);
    final inCart = cart.any((item) => item.product.id == product.id);

    return _buildLiquidGlassBackground(
      rarityColor: rarityColor,
      child: Stack(
        children: [
          // Content
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 120),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 100),
              // Product preview
              _buildProductPreview(context, ref, product, rarityColor),
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
                            color: Colors.black,
                            border: Border.all(color: rarityColor, width: 1.5),
                          ),
                          child: Text(
                            product.rarity.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: rarityColor,
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
                              color: Colors.black,
                              border: Border.all(color: Colors.red, width: 1.5),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.local_fire_department, color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  'HOT',
                                  style: GoogleFonts.inter(
                                    color: Colors.red,
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
                          style: GoogleFonts.inter(
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
                        style: GoogleFonts.inter(
                          color: _muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        product.description!,
                        style: GoogleFonts.inter(
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
    ));
  }

  Widget _buildProductPreview(BuildContext context, WidgetRef ref, StoreProduct product, Color rarityColor) {
    if (product.type.toUpperCase() == 'THEME') {
      final theme = BuiltInThemes.getById(product.id) ?? BuiltInThemes.sonicDrip;
      return _buildThemeMockSimulator(theme);
    }

    final previewStatus = ref.watch(storeAudioPreviewProvider);
    final isPlaying = previewStatus.productId == product.id && previewStatus.state == AudioPreviewState.playing;
    final isLoading = previewStatus.productId == product.id && previewStatus.state == AudioPreviewState.loading;

    return _buildVinylRecordPreview(ref, product, rarityColor, isPlaying, isLoading);
  }

  Widget _buildThemeMockSimulator(StoreTheme theme) {
    return Container(
      height: 280,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: theme.backgroundColor,
        border: Border.all(color: theme.primaryColor, width: 1),
        boxShadow: [
          BoxShadow(color: theme.primaryColor,
            blurRadius: 14, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Simulated App Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: theme.surfaceColor,
              border: Border(bottom: BorderSide(color: theme.primaryColor.withValues(alpha: 0.3), width: 1.5)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: theme.primaryColor,
                  child: const Icon(Icons.tag, color: Colors.black, size: 12),
                ),
                const SizedBox(width: 8),
                Text(
                  'general-chat',
                  style: GoogleFonts.inter(
                    color: theme.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Icon(Icons.headset, color: theme.primaryColor, size: 14),
              ],
            ),
          ),
          // Chat messages
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildSimulatedMessage(
                  theme: theme,
                  sender: 'Alice',
                  message: 'This theme looks absolutely dope! 🔥',
                  avatarColor: theme.primaryColor,
                ),
                const SizedBox(height: 8),
                _buildSimulatedMessage(
                  theme: theme,
                  sender: 'Bob',
                  message: 'Clean brutalist aesthetic. Drop the needle!',
                  avatarColor: theme.secondaryColor,
                  isMe: true,
                ),
              ],
            ),
          ),
          // Mock Message Input
          Container(
            padding: const EdgeInsets.all(8),
            color: theme.surfaceColor,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.backgroundColor,
                      border: Border.all(color: theme.primaryColor.withValues(alpha: 0.5)),
                    ),
                    child: Text(
                      'Message #general-chat',
                      style: GoogleFonts.inter(color: theme.textSecondary, fontSize: 11),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.emoji_emotions, color: theme.primaryColor, size: 18),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSimulatedMessage({
    required StoreTheme theme,
    required String sender,
    required String message,
    required Color avatarColor,
    bool isMe = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: avatarColor,
          child: Text(sender[0], style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sender,
                style: GoogleFonts.inter(
                  color: avatarColor,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isMe ? theme.surfaceColor : Colors.black,
                  border: Border.all(color: isMe ? theme.primaryColor : theme.textSecondary.withValues(alpha: 0.2)),
                ),
                child: Text(
                  message,
                  style: GoogleFonts.inter(color: theme.textPrimary, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVinylRecordPreview(WidgetRef ref, StoreProduct product, Color rarityColor, bool isPlaying, bool isLoading) {
    return Container(
      height: 280,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: rarityColor, width: 1),
        boxShadow: [
          BoxShadow(color: rarityColor,
            blurRadius: 14, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Vinyl Record disk representation
          AnimatedRotation(
            turns: isPlaying ? 50 : 0,
            duration: const Duration(seconds: 100),
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 6),
                boxShadow: const [
                  BoxShadow(color: Colors.black45, blurRadius: 10),
                ],
              ),
              child: Center(
                // Vinyl Label
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: rarityColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1),
                  ),
                  child: Center(
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: const BoxDecoration(
                        color: Colors.black,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Interactive Needle Arm overlay
          Positioned(
            right: 40,
            top: 30,
            child: AnimatedRotation(
              turns: isPlaying ? 0.08 : 0.0,
              alignment: Alignment.topRight,
              duration: const Duration(milliseconds: 500),
              child: SizedBox(
                width: 60,
                height: 100,
                child: CustomPaint(
                  painter: _NeedleArmPainter(color: rarityColor),
                ),
              ),
            ),
          ),
          // Play Overlay Button
          GestureDetector(
            onTap: () {
              final audioUrl = product.previewUrl ?? 'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
              ref.read(storeAudioPreviewProvider.notifier).playPreview(product.id, audioUrl);
            },
            child: Container(
              width: 54,
              height: 54,
              decoration: const BoxDecoration(
                color: Colors.black,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 4)],
              ),
              child: Center(
                child: isLoading
                    ? CircularProgressIndicator(color: rarityColor, strokeWidth: 3)
                    : Icon(
                        isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: rarityColor,
                        size: 32,
                      ),
              ),
            ),
          ),
          // Subtitle info
          Positioned(
            bottom: 12,
            child: Text(
              isPlaying ? 'NOW PREVIEWING...' : 'TAP TO PREVIEW AUDIO',
              style: GoogleFonts.inter(
                color: isPlaying ? rarityColor : _white.withValues(alpha: 0.5),
                fontSize: 10,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
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
          style: GoogleFonts.inter(
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
                  style: GoogleFonts.inter(
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
              style: GoogleFonts.inter(
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
                  style: GoogleFonts.inter(
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
            color: Colors.black,
            border: Border.all(color: _neon, width: 1.5),
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
                      color: Colors.black,
                      border: Border.all(color: _neon, width: 1.5),
                    ),
                    child: const Icon(Icons.person, color: _neon, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Alex_Gamer',
                        style: GoogleFonts.inter(
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
                style: GoogleFonts.inter(
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

    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.45),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1.0)),
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
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isInWishlist ? Colors.red : Colors.white.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      isInWishlist ? Icons.favorite : Icons.favorite_border,
                      color: isInWishlist ? Colors.red : _white.withValues(alpha: 0.7),
                      size: 22,
                    ),
                  ),
                ),
                // Gift button
                GestureDetector(
                  onTap: () => _showGiftFriendSelector(context, ref, product),
                  child: Container(
                    width: 52,
                    height: 52,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _neon.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.card_giftcard,
                      color: _neon,
                      size: 22,
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
                        style: GoogleFonts.inter(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        isFree ? 'FREE' : '₹${product.price.toStringAsFixed(0)}',
                        style: GoogleFonts.epilogue(
                          color: isFree ? _lime : _white,
                          fontSize: 22,
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
                        color: inCart ? _lime : _neon,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: (inCart ? _lime : _neon).withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
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
                              inCart ? 'VIEW CART' : 'ADD TO CART',
                              style: GoogleFonts.inter(
                                color: Colors.black,
                                fontWeight: FontWeight.w900,
                                fontSize: 13,
                                letterSpacing: 0.5,
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
        ),
      ),
    );
  }

  void _showGiftFriendSelector(BuildContext context, WidgetRef ref, StoreProduct product) {
    final friends = [
      {'id': '1', 'username': 'alice', 'displayName': 'Alice', 'status': 'online'},
      {'id': '2', 'username': 'bob', 'displayName': 'Bob', 'status': 'idle'},
      {'id': '3', 'username': 'charlie', 'displayName': 'Charlie', 'status': 'dnd'},
      {'id': '4', 'username': 'dave', 'displayName': 'Dave', 'status': 'offline'},
      {'id': '5', 'username': 'eve', 'displayName': 'Eve', 'status': 'offline'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'GIFT TO A FRIEND',
                style: GoogleFonts.inter(
                  color: _white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Select a friend to gift "${product.name}" to:',
                style: GoogleFonts.inter(color: _muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  itemCount: friends.length,
                  itemBuilder: (ctx, index) {
                    final friend = friends[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8, right: 4),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: _neon.withValues(alpha: 0.3), width: 1.5),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _neon,
                          child: Text(
                            friend['displayName']![0],
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          friend['displayName']!,
                          style: GoogleFonts.inter(color: _white, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '@${friend['username']!}',
                          style: GoogleFonts.inter(color: _muted, fontSize: 11),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          margin: const EdgeInsets.only(right: 4, bottom: 4),
                          decoration: BoxDecoration(
                            color: _neon,
                            border: Border.all(color: Colors.black, width: 1.5),
                            boxShadow:  [
                              BoxShadow(color: Colors.white.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 2)),
                            ],
                          ),
                          child: Text(
                            'GIFT',
                            style: GoogleFonts.inter(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        onTap: () async {
                          Navigator.pop(ctx);
                          final storeService = ref.read(storeServiceProvider);
                          final success = await storeService.giftProduct(
                            product,
                            friend['id']!,
                            friend['displayName']!,
                          );
                          if (success && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Gifted ${product.name} to ${friend['displayName']!}!'),
                                backgroundColor: _lime,
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
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

class _NeedleArmPainter extends CustomPainter {
  final Color color;
  _NeedleArmPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width * 0.4, size.height * 0.5)
      ..lineTo(size.width * 0.2, size.height * 0.9);

    canvas.drawPath(path, paint);

    // Draw the cartridge
    final cartridgePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(size.width * 0.2, size.height * 0.9),
        width: 12,
        height: 18,
      ),
      cartridgePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
