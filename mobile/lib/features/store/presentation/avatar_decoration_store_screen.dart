import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/equipment_service.dart';
import 'package:mobile/features/store/data/avatar_decoration_service.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/core/services/flicko_haptics.dart';

class AvatarDecorationStoreScreen extends ConsumerStatefulWidget {
  const AvatarDecorationStoreScreen({super.key});

  @override
  ConsumerState<AvatarDecorationStoreScreen> createState() => _AvatarDecorationStoreScreenState();
}

class _AnimatedMockAvatar extends StatefulWidget {
  final String decorationId;
  final double size;

  const _AnimatedMockAvatar({required this.decorationId, required this.size});

  @override
  State<_AnimatedMockAvatar> createState() => _AnimatedMockAvatarState();
}

class _AnimatedMockAvatarState extends State<_AnimatedMockAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      size: widget.size,
      name: 'PREVIEW',
      imageUrl: null, // Initials mockup
      decoration: widget.decorationId,
      showStatus: false,
      showBadge: false,
    );
  }
}

class _AvatarDecorationStoreScreenState extends ConsumerState<AvatarDecorationStoreScreen> {
  String _selectedFrameId = 'neon-cyber-frame';

  static const Color _bg = Color(0xFF000000);
  static const Color _surface = Color(0xFF0C0C0E);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xFF71717A);
  static const Color _lime = Color(0xFF52B788);
  static const Color _orange = Color(0xFFFAA61A);
  static const Color _magenta = Color(0xFFFF007F);
  static const Color _cyberBlue = Color(0xFF00E5FF);

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final equippedAsync = ref.watch(equippedItemsProvider);

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _white),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'DECORATION_DECK',
          style: GoogleFonts.spaceGrotesk(
            color: _white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.5),
          child: Container(color: _lime, height: 2.5),
        ),
      ),
      body: inventoryAsync.when(
        data: (inventory) {
          return equippedAsync.when(
            data: (equipped) {
              final allProducts = BuiltInDecorations.all;
              final selectedDefinition = BuiltInDecorations.getById(_selectedFrameId)!;
              
              // Retrieve matching storefront product details
              final storeService = ref.read(storeServiceProvider);
              final List<StoreProduct> sampleProducts = storeService.getSampleProducts();
              final product = sampleProducts.firstWhere((p) => p.id == _selectedFrameId);

              final isOwned = inventory.any((p) => p.productId == _selectedFrameId);
              final isEquipped = equipped['avatar_decoration']?.productId == _selectedFrameId;

              return Column(
                children: [
                  // 1. Interactive Preview Mirror Platter
                  _buildPreviewMirror(selectedDefinition),

                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 2. Specifications card
                            _buildSpecsCard(product, isOwned, isEquipped),
                            const SizedBox(height: 28),

                            // 3. Selection Slider Header
                            Text(
                              'AVAILABLE_BORDERS',
                              style: GoogleFonts.spaceGrotesk(
                                color: _white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 4. Frames Carousel Grid
                            _buildFramesGrid(allProducts, equipped),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 5. Actions footer
                  _buildActionsFooter(product, isOwned, isEquipped),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: _lime)),
            error: (_, __) => const Center(child: Text('ERROR LOADING EQUIPPED ITEMS')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: _lime)),
        error: (_, __) => const Center(child: Text('ERROR LOADING INVENTORY')),
      ),
    );
  }

  Widget _buildPreviewMirror(AvatarDecorationDefinition dec) {
    return Container(
      width: double.infinity,
      color: _surface,
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Container(
          width: 170,
          height: 170,
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: dec.primaryColor, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: dec.primaryColor.withValues(alpha: 0.35),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Retro grid scanline background lines
              Positioned.fill(
                child: Opacity(
                  opacity: 0.05,
                  child: GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 10,
                      crossAxisSpacing: 1,
                      mainAxisSpacing: 1,
                    ),
                    itemCount: 100,
                    itemBuilder: (ctx, index) => Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: _white, width: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
              // Glowing live mockup avatar inside mirror platter
              _AnimatedMockAvatar(
                decorationId: dec.id,
                size: 110,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSpecsCard(StoreProduct product, bool isOwned, bool isEquipped) {
    final borderCol = _getRarityColor(product.rarity);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: borderCol, width: 2),
        boxShadow: [
          BoxShadow(
            color: borderCol,
            offset: const Offset(3, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                product.name.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  color: _white,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                color: borderCol,
                child: Text(
                  product.rarity.toUpperCase(),
                  style: GoogleFonts.spaceMono(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    fontSize: 8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            product.description ?? 'A high-fidelity premium procedural kinetic profile frame.',
            style: GoogleFonts.spaceMono(
              color: _muted,
              fontSize: 10,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _buildSpecPill(
                isOwned ? 'OWNED' : 'NOT OWNED',
                isOwned ? _lime : _muted,
              ),
              const SizedBox(width: 8),
              if (isEquipped)
                _buildSpecPill('EQUIPPED', _orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecPill(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color, width: 1.5),
      ),
      child: Text(
        text,
        style: GoogleFonts.spaceMono(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 8,
        ),
      ),
    );
  }

  Widget _buildFramesGrid(List<AvatarDecorationDefinition> items, Map<String, EquippedItem> equipped) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: 0.95,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final dec = items[index];
        final isSelected = dec.id == _selectedFrameId;
        final isEquipped = equipped['avatar_decoration']?.productId == dec.id;

        return GestureDetector(
          onTap: () {
            FlickoHaptics.light();
            setState(() {
              _selectedFrameId = dec.id;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? dec.primaryColor.withValues(alpha: 0.1) : Colors.black,
              border: Border.all(
                color: isSelected ? dec.primaryColor : _muted.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _AnimatedMockAvatar(decorationId: dec.id, size: 40),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    dec.name.replaceFirst(' Frame', '').toUpperCase(),
                    style: GoogleFonts.spaceMono(
                      color: isSelected ? dec.primaryColor : _white,
                      fontSize: 7.5,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (isEquipped) ...[
                  const SizedBox(height: 3),
                  Text(
                    'EQUIPPED',
                    style: GoogleFonts.spaceMono(
                      color: _orange,
                      fontSize: 6,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionsFooter(StoreProduct product, bool isOwned, bool isEquipped) {
    final borderCol = _getRarityColor(product.rarity);
    final cart = ref.watch(cartProvider);
    final inCart = cart.any((item) => item.product.id == product.id);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Color(0xFF1F1F23), width: 1.5)),
      ),
      child: SafeArea(
        child: isOwned
            ? Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        FlickoHaptics.medium();
                        final equipService = ref.read(equipmentServiceProvider);
                        if (isEquipped) {
                          // Unequip: equip 'none' or delete active
                          await equipService.equipItem('none', 'AVATAR_DECORATION');
                        } else {
                          await equipService.equipItem(product.id, 'AVATAR_DECORATION');
                        }
                        ref.invalidate(equippedItemsProvider);
                        ref.invalidate(equippedDecorationProvider);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isEquipped ? Colors.black : _orange,
                          border: Border.all(
                            color: isEquipped ? _muted : Colors.black,
                            width: 2.5,
                          ),
                          boxShadow: isEquipped
                              ? null
                              : const [
                                  BoxShadow(
                                    color: _orange,
                                    offset: Offset(3, 3),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: Text(
                            isEquipped ? 'UNEQUIP_BORDER_DECORATION' : 'EQUIP_BORDER_DECORATION',
                            style: GoogleFonts.spaceMono(
                              color: isEquipped ? _muted : Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
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
                          '\$${product.price.toStringAsFixed(2)}',
                          style: GoogleFonts.epilogue(
                            color: _white,
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
                        FlickoHaptics.medium();
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
                              label: 'VIEW',
                              textColor: Colors.black,
                              onPressed: () => context.push('/store/cart'),
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: inCart ? _lime : borderCol,
                          border: Border.all(color: Colors.black, width: 2.5),
                          boxShadow: [
                            BoxShadow(
                              color: inCart ? _lime : borderCol,
                              offset: const Offset(3, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            inCart ? 'IN_CART' : 'ADD_TO_CART',
                            style: GoogleFonts.spaceMono(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
                              letterSpacing: 1,
                            ),
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

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'rare':
        return _cyberBlue;
      case 'epic':
        return const Color(0xFF9B84EE);
      case 'legendary':
        return _orange;
      default:
        return _lime;
    }
  }
}
