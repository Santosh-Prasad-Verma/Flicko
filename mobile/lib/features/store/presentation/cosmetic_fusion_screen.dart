import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/equipment_service.dart';
import 'package:mobile/features/store/data/cosmetic_fusion_service.dart';
import 'package:mobile/core/services/flicko_haptics.dart';

class CosmeticFusionScreen extends ConsumerStatefulWidget {
  const CosmeticFusionScreen({super.key});

  @override
  ConsumerState<CosmeticFusionScreen> createState() => _CosmeticFusionScreenState();
}

class _CosmeticFusionScreenState extends ConsumerState<CosmeticFusionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _spinController;

  static const Color _bg = Color(0xFF000000);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xFF71717A);
  static const Color _lime = Color(0xFF52B788);
  static const Color _orange = Color(0xFFFAA61A);
  static const Color _red = Color(0xFFED4245);

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fusionState = ref.watch(cosmeticFusionProvider);
    final notifier = ref.read(cosmeticFusionProvider.notifier);
    final inventoryAsync = ref.watch(inventoryProvider);

    // Watch for success to trigger reward modal
    ref.listen(cosmeticFusionProvider, (prev, next) {
      if (next.status == 'success' && next.reward != null) {
        FlickoHaptics.medium();
        _spinController.stop();
        _showRewardDialog(context, next.reward!);
      } else if (next.status == 'fusing') {
        FlickoHaptics.light();
        _spinController.repeat();
      } else if (next.status == 'error' && next.errorMessage != null) {
        FlickoHaptics.medium();
        _spinController.stop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!.toUpperCase()),
            backgroundColor: _red,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _white),
          onPressed: () {
            notifier.clearReactor();
            context.pop();
          },
        ),
        title: Text(
          'FUSION_REACTOR',
          style: GoogleFonts.inter(
            color: _white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 2,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.5),
          child: Container(
            color: _lime,
            height: 2.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _white),
            onPressed: () {
              FlickoHaptics.light();
              notifier.clearReactor();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Status indicator warning bar
          _buildWarningBar(fusionState),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // 2. The reactor core slots
                  _buildReactorSlots(fusionState, notifier),
                  const SizedBox(height: 24),

                  // 3. FUSE trigger button
                  _buildFuseButton(fusionState, notifier),
                  const SizedBox(height: 24),

                  // 4. Inventory Selection Grid
                  _buildInventoryPicker(inventoryAsync, fusionState, notifier),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBar(CosmeticFusionState state) {
    Color barColor = _orange;
    String text = 'REACTOR_READY: LOAD 3 UNIFORM RARITY ITEMS';

    if (state.status == 'fusing') {
      barColor = _red;
      text = 'FUSION_ACTIVE: SYNTHESIZING NUCLEAR PARTICLES...';
    } else if (state.status == 'success') {
      barColor = _lime;
      text = 'SYNTHESIS_COMPLETE: NEW PARTICLE DETECTED!';
    } else if (state.errorMessage != null) {
      barColor = _red;
      text = state.errorMessage!.toUpperCase();
    } else if (state.selectedItems.isNotEmpty) {
      final count = state.selectedItems.length;
      text = 'REACTOR_LOADING: $count/3 SLOTS FILLED';
    }

    return Container(
      width: double.infinity,
      color: barColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        text,
        style: GoogleFonts.inter(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 1,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildReactorSlots(CosmeticFusionState state, CosmeticFusionNotifier notifier) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: _lime, width: 1),
        boxShadow:  [
          BoxShadow(color: _lime.withValues(alpha: 0.25),
            blurRadius: 14, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Spin reactor background lines
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _spinController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _ReactorOrbitPainter(
                    angle: _spinController.value * 2 * math.pi,
                    color: state.status == 'fusing' ? _red : _lime,
                    isFusing: state.status == 'fusing',
                  ),
                );
              },
            ),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(3, (index) {
              final isLoaded = index < state.selectedItems.length;
              if (isLoaded) {
                final item = state.selectedItems[index];
                return _buildLoadedSlot(item, notifier);
              }
              return _buildEmptySlot(index + 1);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadedSlot(UserPurchase item, CosmeticFusionNotifier notifier) {
    return GestureDetector(
      onTap: () {
        FlickoHaptics.light();
        notifier.selectItem(item);
      },
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: _lime, width: 2),
          boxShadow: [
            BoxShadow(color: _lime.withValues(alpha: 0.3),
              blurRadius: 14, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_iconForType(item.productType), color: _lime, size: 24),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                item.productName.toUpperCase(),
                style: GoogleFonts.inter(
                  color: _white,
                  fontWeight: FontWeight.w900,
                  fontSize: 7,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySlot(int slotIndex) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(
          color: _muted.withValues(alpha: 0.5),
          width: 2,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add, color: _muted.withValues(alpha: 0.3), size: 20),
          const SizedBox(height: 6),
          Text(
            'SLOT_0$slotIndex',
            style: GoogleFonts.inter(
              color: _muted.withValues(alpha: 0.5),
              fontWeight: FontWeight.bold,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFuseButton(CosmeticFusionState state, CosmeticFusionNotifier notifier) {
    final active = notifier.canFuse && state.status != 'fusing';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: active
            ? () {
                FlickoHaptics.medium();
                notifier.executeFusion();
              }
            : null,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: active ? _orange : Colors.black,
            border: Border.all(color: active ? Colors.black : _muted, width: 1),
            boxShadow: active
                ? [
                    BoxShadow(color: _orange.withValues(alpha: 0.25),
                      blurRadius: 14, offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              state.status == 'fusing' ? 'SYNTHESIZING_CORE...' : 'ACTIVATE_FUSION_CORE',
              style: GoogleFonts.inter(
                color: active ? Colors.black : _muted,
                fontWeight: FontWeight.w900,
                fontSize: 13,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInventoryPicker(
    AsyncValue<List<UserPurchase>> inventoryAsync,
    CosmeticFusionState state,
    CosmeticFusionNotifier notifier,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'AVAILABLE_INVENTORY',
            style: GoogleFonts.inter(
              color: _white,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          height: 250,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            border: Border.all(color: _muted.withValues(alpha: 0.3), width: 1.5),
            color: Colors.black,
          ),
          child: inventoryAsync.when(
            data: (purchases) {
              if (purchases.isEmpty) {
                return Center(
                  child: Text(
                    'INVENTORY_EMPTY',
                    style: GoogleFonts.inter(color: _muted, fontSize: 10),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.95,
                ),
                itemCount: purchases.length,
                itemBuilder: (ctx, index) {
                  final item = purchases[index];
                  final isLoaded = state.selectedItems.any((x) => x.id == item.id);

                  return GestureDetector(
                    onTap: () {
                      FlickoHaptics.light();
                      notifier.selectItem(item);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isLoaded ? _lime.withValues(alpha: 0.15) : Colors.black,
                        border: Border.all(
                          color: isLoaded ? _lime : _muted.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_iconForType(item.productType), color: isLoaded ? _lime : _muted, size: 20),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Text(
                              item.productName.toUpperCase(),
                              style: GoogleFonts.inter(
                                color: isLoaded ? _lime : _white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.productType.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: _muted,
                              fontSize: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: _lime)),
            error: (_, __) => const Center(child: Text('ERROR LOADING INVENTORY', style: TextStyle(color: Colors.red))),
          ),
        ),
      ],
    );
  }

  void _showRewardDialog(BuildContext context, StoreProduct reward) {
    final borderCol = _getRarityColor(reward.rarity);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            border: Border.all(color: borderCol, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                color: borderCol,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                width: double.infinity,
                child: Text(
                  'FUSION_SUCCESSFUL',
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Card details
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Big product display card in brutalist outline
                    Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        border: Border.all(color: borderCol, width: 1),
                        boxShadow: [
                          BoxShadow(color: borderCol,
                            blurRadius: 14, offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(_iconForType(reward.type), color: borderCol, size: 40),
                          const SizedBox(height: 8),
                          Text(
                            reward.rarity.toUpperCase(),
                            style: GoogleFonts.inter(
                              color: borderCol,
                              fontWeight: FontWeight.w900,
                              fontSize: 9,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    Text(
                      reward.name.toUpperCase(),
                      style: GoogleFonts.inter(
                        color: _white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      reward.description ?? 'A highly synthesized elite store collectible.',
                      style: GoogleFonts.inter(
                        color: _muted,
                        fontSize: 10,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            ref.read(cosmeticFusionProvider.notifier).clearReactor();
                            Navigator.pop(ctx);
                          },
                          child: Text(
                            'DISMISS',
                            style: GoogleFonts.inter(
                              color: _muted,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () async {
                            FlickoHaptics.medium();
                            await ref.read(equipmentServiceProvider).equipItem(reward.id, reward.type);
                            ref.invalidate(equippedItemsProvider);
                            ref.read(cosmeticFusionProvider.notifier).clearReactor();
                            if (context.mounted) {
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${reward.name.toUpperCase()} EQUIPPED!'),
                                  backgroundColor: _lime,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: borderCol,
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: Text(
                            'EQUIP_NOW',
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w900,
                              fontSize: 12,
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
      ),
    );
  }

  Color _getRarityColor(String rarity) {
    switch (rarity.toLowerCase()) {
      case 'rare':
        return const Color(0xFF00E5FF);
      case 'epic':
        return const Color(0xFF9B84EE);
      case 'legendary':
        return const Color(0xFFFFD700);
      default:
        return const Color(0xFF71717A);
    }
  }

  IconData _iconForType(String type) {
    final clean = type.toLowerCase();
    if (clean.contains('theme')) {
      return Icons.palette;
    } else if (clean.contains('sticker')) {
      return Icons.sticky_note_2;
    } else if (clean.contains('sound')) {
      return Icons.volume_up;
    } else if (clean.contains('badge') || clean.contains('nameplate')) {
      return Icons.stars;
    } else {
      return Icons.shopping_bag;
    }
  }
}

class _ReactorOrbitPainter extends CustomPainter {
  final double angle;
  final Color color;
  final bool isFusing;

  _ReactorOrbitPainter({
    required this.angle,
    required this.color,
    required this.isFusing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..color = color.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Draw background orbital circles
    canvas.drawCircle(center, size.width * 0.35, paint);
    canvas.drawCircle(center, size.width * 0.25, paint);

    if (isFusing) {
      // Draw rotating orbit points
      final pointPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      for (int i = 0; i < 4; i++) {
        final double pointAngle = angle + (i * math.pi / 2);
        final double radius = size.width * 0.3;
        final dx = center.dx + radius * math.cos(pointAngle);
        final dy = center.dy + radius * math.sin(pointAngle);
        canvas.drawCircle(Offset(dx, dy), 5, pointPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ReactorOrbitPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.color != color || oldDelegate.isFusing != isFusing;
  }
}
