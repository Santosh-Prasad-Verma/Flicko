import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/equipment_service.dart';
import 'package:mobile/features/store/data/nameplate_service.dart';
import 'package:mobile/features/shared/presentation/widgets/kinetic_nameplate_text.dart';
import 'package:mobile/core/services/flicko_haptics.dart';

class NameplateStoreScreen extends ConsumerStatefulWidget {
  const NameplateStoreScreen({super.key});

  @override
  ConsumerState<NameplateStoreScreen> createState() => _NameplateStoreScreenState();
}

class _NameplateStoreScreenState extends ConsumerState<NameplateStoreScreen> {
  String _selectedNameplateId = 'glitch-matrix-tag';

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
          'NAMEPLATE_DECK',
          style: GoogleFonts.inter(
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
              final allProducts = BuiltInNameplates.all;
              final selectedDefinition = BuiltInNameplates.getById(_selectedNameplateId)!;
              
              // Retrieve matching storefront product details
              final storeService = ref.read(storeServiceProvider);
              final List<StoreProduct> sampleProducts = storeService.getSampleProducts();
              final product = sampleProducts.firstWhere((p) => p.id == _selectedNameplateId);

              final isOwned = inventory.any((p) => p.productId == _selectedNameplateId);
              final isEquipped = equipped['NAMEPLATE']?.productId == _selectedNameplateId ||
                  equipped['nameplate']?.productId == _selectedNameplateId;

              return Column(
                children: [
                  // 1. Interactive Preview Dashboard Mirror
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
                              'AVAILABLE_NAMEPLATES',
                              style: GoogleFonts.inter(
                                color: _white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 4. Nameplates Grid
                            _buildNameplatesGrid(allProducts, equipped),
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

  Widget _buildPreviewMirror(NameplateDefinition spec) {
    return Container(
      width: double.infinity,
      color: _surface,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Center(
        child: Container(
          width: 300,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border.all(color: spec.primaryColor, width: 1),
            boxShadow: [
              BoxShadow(
                color: spec.primaryColor.withValues(alpha: 0.35),
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
                      crossAxisCount: 15,
                      crossAxisSpacing: 1,
                      mainAxisSpacing: 1,
                    ),
                    itemCount: 150,
                    itemBuilder: (ctx, index) => Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: _white, width: 0.5),
                      ),
                    ),
                  ),
                ),
              ),
              // Live animated text drip preview
              KineticNameplateText(
                text: 'SONIC_DRIPPER',
                decorationId: spec.id,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 1.5,
                ),
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
          BoxShadow(color: borderCol,
            blurRadius: 14, offset: const Offset(0, 4),
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
                style: GoogleFonts.inter(
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
                  style: GoogleFonts.inter(
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
            product.description ?? 'A high-fidelity premium procedural kinetic text drip effect.',
            style: GoogleFonts.inter(
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
        style: GoogleFonts.inter(
          color: color,
          fontWeight: FontWeight.w900,
          fontSize: 8,
        ),
      ),
    );
  }

  Widget _buildNameplatesGrid(List<NameplateDefinition> items, Map<String, EquippedItem> equipped) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.2,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final spec = items[index];
        final isSelected = spec.id == _selectedNameplateId;
        final isEquipped = equipped['NAMEPLATE']?.productId == spec.id ||
            equipped['nameplate']?.productId == spec.id;

        return GestureDetector(
          onTap: () {
            FlickoHaptics.light();
            setState(() {
              _selectedNameplateId = spec.id;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? spec.primaryColor.withValues(alpha: 0.1) : Colors.black,
              border: Border.all(
                color: isSelected ? spec.primaryColor : _muted.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                KineticNameplateText(
                  text: 'DRIP_TAG',
                  decorationId: spec.id,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    spec.name.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: isSelected ? spec.primaryColor : _muted,
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
                if (isEquipped) ...[
                  const SizedBox(height: 2),
                  Text(
                    'EQUIPPED',
                    style: GoogleFonts.inter(
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
                          await equipService.equipItem('none', 'NAMEPLATE');
                        } else {
                          await equipService.equipItem(product.id, 'NAMEPLATE');
                        }
                        ref.invalidate(equippedItemsProvider);
                        ref.invalidate(equippedNameplateProvider);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: isEquipped ? Colors.black : _orange,
                          border: Border.all(
                            color: isEquipped ? _muted : Colors.black,
                            width: 1,
                          ),
                          boxShadow: isEquipped
                              ? null
                              : [
                                  BoxShadow(color: _orange.withValues(alpha: 0.25),
                                    blurRadius: 14, offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Center(
                          child: Text(
                            isEquipped ? 'UNEQUIP_NAMEPLATE' : 'EQUIP_NAMEPLATE',
                            style: GoogleFonts.inter(
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
                          style: GoogleFonts.inter(
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
                          border: Border.all(color: Colors.black, width: 1),
                          boxShadow: [
                            BoxShadow(color: inCart ? _lime : borderCol,
                              blurRadius: 14, offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            inCart ? 'IN_CART' : 'ADD_TO_CART',
                            style: GoogleFonts.inter(
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
