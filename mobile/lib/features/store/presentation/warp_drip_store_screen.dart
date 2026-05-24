import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/equipment_service.dart';
import 'package:mobile/features/store/data/warp_service.dart';
import 'package:mobile/features/store/data/drip_card_service.dart';
import 'package:mobile/features/shared/presentation/widgets/message_drip_card.dart';
import 'package:mobile/features/shared/presentation/widgets/entrance_warp_overlay.dart';
import 'package:mobile/core/services/flicko_haptics.dart';

class WarpDripStoreScreen extends ConsumerStatefulWidget {
  const WarpDripStoreScreen({super.key});

  @override
  ConsumerState<WarpDripStoreScreen> createState() => _WarpDripStoreScreenState();
}

class _WarpDripStoreScreenState extends ConsumerState<WarpDripStoreScreen> with SingleTickerProviderStateMixin {
  String _selectedId = 'cyber-matrix-warp';
  bool _playingWarp = false;
  String? _activeWarpId;
  
  late AnimationController _wiggleController;
  late Animation<double> _wiggleAnimation;

  static const Color _bg = Color(0xFF000000);
  static const Color _surface = Color(0xFF0C0C0E);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xFF71717A);
  static const Color _lime = Color(0xFF00FF66);
  static const Color _orange = Color(0xFFFAA61A);
  static const Color _cyberBlue = Color(0xFF00E5FF);
  static const Color _magenta = Color(0xFFFF007F);

  @override
  void initState() {
    super.initState();
    // Continuous subtle wiggle animation for card mockups
    _wiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _wiggleAnimation = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _wiggleController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _wiggleController.dispose();
    super.dispose();
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'legendary':
        return _orange;
      case 'epic':
        return _magenta;
      case 'rare':
        return _cyberBlue;
      default:
        return _lime;
    }
  }

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
          'WARP_DRIPS_DECK',
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
      body: Stack(
        children: [
          // Main content
          inventoryAsync.when(
            data: (inventory) {
              return equippedAsync.when(
                data: (equipped) {
                  // Look up matching product details
                  final storeService = ref.read(storeServiceProvider);
                  final sampleProducts = storeService.getSampleProducts();
                  final product = sampleProducts.firstWhere((p) => p.id == _selectedId);

                  final isWarp = product.type == 'ENTRANCE_WARP';

                  final isOwned = inventory.any((p) => p.productId == _selectedId);
                  final isEquipped = isWarp
                      ? (equipped['ENTRANCE_WARP']?.productId == _selectedId || equipped['entrance_warp']?.productId == _selectedId)
                      : (equipped['DRIP_CARD']?.productId == _selectedId || equipped['drip_card']?.productId == _selectedId);

                  return Column(
                    children: [
                      // 1. Preview Mirror
                      _buildPreviewMirror(product),

                      // 2. Main scroll area
                      Expanded(
                        child: SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Specs card
                                _buildSpecsCard(product, isOwned, isEquipped),
                                const SizedBox(height: 28),

                                // Categories Divider
                                Text(
                                  'ENTRANCE_WARP_TRANSITIONS',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: _white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildItemsGrid(BuiltInWarps.all.map((w) => w.id).toList(), equipped, true),

                                const SizedBox(height: 24),

                                Text(
                                  'PREMIUM_MESSAGE_DRIP_CARDS',
                                  style: GoogleFonts.spaceGrotesk(
                                    color: _white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildItemsGrid(BuiltInDripCards.all.map((d) => d.id).toList(), equipped, false),

                                const SizedBox(height: 30),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 3. Action buy / equip bar footer
                      _buildActionsFooter(product, isOwned, isEquipped),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator(color: _lime)),
                error: (_, __) => const Center(child: Text('ERROR LOADING EQUIPPED ITEMS', style: TextStyle(color: Colors.red))),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: _lime)),
            error: (_, __) => const Center(child: Text('ERROR LOADING INVENTORY', style: TextStyle(color: Colors.red))),
          ),

          // Dynamic overlay for full screen warp testing
          if (_playingWarp && _activeWarpId != null)
            EntranceWarpOverlay(
              warpId: _activeWarpId!,
              onComplete: () {
                setState(() {
                  _playingWarp = false;
                  _activeWarpId = null;
                });
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPreviewMirror(StoreProduct product) {
    final isWarp = product.type == 'ENTRANCE_WARP';

    return Container(
      width: double.infinity,
      color: _surface,
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: AnimatedBuilder(
          animation: _wiggleAnimation,
          builder: (context, child) {
            // Apply subtle wiggle transition
            return Transform.rotate(
              angle: isWarp ? 0.0 : (_wiggleAnimation.value * math.pi / 180),
              child: Container(
                width: 320,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(
                    color: _getRarityColor(product.rarity),
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _getRarityColor(product.rarity).withOpacity(0.2),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: isWarp ? _buildWarpPreview(product) : _buildDripCardPreview(product),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWarpPreview(StoreProduct product) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Icon(Icons.blur_circular, color: _lime, size: 20),
            const SizedBox(width: 8),
            Text(
              'ENTRANCE_PORTAL_MOCK',
              style: GoogleFonts.spaceMono(
                color: _lime,
                fontWeight: FontWeight.w900,
                fontSize: 10,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 100,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF070708),
            border: Border.all(color: const Color(0xFF1E1E24)),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Retro portal circles
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _getRarityColor(product.rarity).withOpacity(0.5),
                    width: 1.5,
                  ),
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: _getRarityColor(product.rarity),
                    width: 2.0,
                  ),
                ),
              ),
              Icon(
                Icons.bolt,
                color: _getRarityColor(product.rarity),
                size: 24,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () {
            FlickoHaptics.heavy();
            setState(() {
              _activeWarpId = product.id;
              _playingWarp = true;
            });
          },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: _getRarityColor(product.rarity),
              border: Border.all(color: Colors.black, width: 2.0),
              boxShadow: const [
                BoxShadow(
                  color: Colors.white24,
                  offset: Offset(2, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                'TEST TRANSITION',
                style: GoogleFonts.spaceMono(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 11,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDripCardPreview(StoreProduct product) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: _orange,
              ),
              child: Center(
                child: Text(
                  'F',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.black,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'FLICKO_MEMBER',
              style: GoogleFonts.spaceMono(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
            const Spacer(),
            Text(
              '15:40',
              style: GoogleFonts.spaceMono(
                color: _muted,
                fontSize: 8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        MessageDripCard(
          dripCardId: product.id,
          forcePreview: true,
          child: Text(
            'YO FLICKO! THIS CARD BORDER IS DRIPPING NEON GLINT! 🔥🚀',
            style: GoogleFonts.spaceGrotesk(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSpecsCard(StoreProduct product, bool isOwned, bool isEquipped) {
    final borderCol = _getRarityColor(product.rarity);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        border: Border.all(color: const Color(0xFF1F1F23), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: borderCol.withOpacity(0.1),
                  border: Border.all(color: borderCol),
                ),
                child: Text(
                  product.rarity.toUpperCase(),
                  style: GoogleFonts.spaceMono(
                    color: borderCol,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E24),
                  border: Border.all(color: const Color(0xFF3F3F46)),
                ),
                child: Text(
                  product.type.replaceAll('_', ' '),
                  style: GoogleFonts.spaceMono(
                    color: _white,
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            product.name,
            style: GoogleFonts.spaceGrotesk(
              color: _white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            product.description ?? '',
            style: GoogleFonts.spaceMono(
              color: _muted,
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsGrid(List<String> ids, Map<String, EquippedItem> equipped, bool isWarp) {
    final storeService = ref.read(storeServiceProvider);
    final sampleProducts = storeService.getSampleProducts();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: ids.length,
      itemBuilder: (context, index) {
        final id = ids[index];
        final product = sampleProducts.firstWhere((p) => p.id == id);
        final isSelected = _selectedId == id;
        final borderCol = _getRarityColor(product.rarity);
        
        final bool isEquipped = isWarp
            ? (equipped['ENTRANCE_WARP']?.productId == id || equipped['entrance_warp']?.productId == id)
            : (equipped['DRIP_CARD']?.productId == id || equipped['drip_card']?.productId == id);

        return GestureDetector(
          onTap: () {
            FlickoHaptics.light();
            setState(() {
              _selectedId = id;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? borderCol.withOpacity(0.08) : Colors.black,
              border: Border.all(
                color: isSelected ? borderCol : const Color(0xFF1E1E24),
                width: isSelected ? 2.0 : 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isWarp ? Icons.blur_on : Icons.crop_portrait,
                  color: isSelected ? borderCol : _muted,
                  size: 28,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    product.name.replaceAll(' Warp', '').replaceAll(' Card', '').toUpperCase(),
                    style: GoogleFonts.spaceMono(
                      color: isSelected ? borderCol : _white,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (isEquipped) ...[
                  const SizedBox(height: 4),
                  Text(
                    'EQUIPPED',
                    style: GoogleFonts.spaceMono(
                      color: _orange,
                      fontSize: 6.5,
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
    final inCart = ref.watch(cartProvider).any((item) => item.product.id == product.id);

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
                        final type = product.type; // ENTRANCE_WARP or DRIP_CARD
                        
                        if (isEquipped) {
                          await equipService.equipItem('none', type);
                        } else {
                          await equipService.equipItem(product.id, type);
                        }
                        
                        ref.invalidate(equippedItemsProvider);
                        ref.invalidate(equippedWarpProvider);
                        ref.invalidate(equippedDripCardProvider);
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
                            isEquipped
                                ? (product.type == 'ENTRANCE_WARP' ? 'UNEQUIP_WARP' : 'UNEQUIP_CARD')
                                : (product.type == 'ENTRANCE_WARP' ? 'EQUIP_WARP' : 'EQUIP_CARD'),
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
                          '₹${product.price.toStringAsFixed(0)}',
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
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: inCart ? Colors.black : _lime,
                          border: Border.all(
                            color: inCart ? _lime : Colors.black,
                            width: 2.5,
                          ),
                          boxShadow: inCart
                              ? null
                              : const [
                                  BoxShadow(
                                    color: _lime,
                                    offset: Offset(3, 3),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: Text(
                            inCart ? 'VIEW_CART' : 'ADD_TO_CART',
                            style: GoogleFonts.spaceMono(
                              color: inCart ? _lime : Colors.black,
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
              ),
      ),
    );
  }
}
