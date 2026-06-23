import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/gacha_service.dart';
import 'package:mobile/features/store/data/equipment_service.dart';
import 'package:mobile/core/services/flicko_haptics.dart';
import 'package:mobile/features/store/data/badge_alchemy_service.dart';

class GachaUnboxingScreen extends ConsumerStatefulWidget {
  const GachaUnboxingScreen({super.key});

  @override
  ConsumerState<GachaUnboxingScreen> createState() => _GachaUnboxingScreenState();
}

class _GachaUnboxingScreenState extends ConsumerState<GachaUnboxingScreen> with TickerProviderStateMixin {
  late AnimationController _vinylRotationController;
  late AnimationController _tonearmController;
  late ScrollController _rouletteScrollController;
  late AnimationController _rouletteAnimationController;

  static const Color _bg = Color(0xFF000000);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xFF71717A);
  static const Color _lime = Color(0xFF52B788);
  static const Color _orange = Color(0xFFFAA61A);
  static const Color _magenta = Color(0xFFFF007F);
  static const Color _cyberBlue = Color(0xFF00E5FF);

  final List<StoreProduct> _rouletteReel = [];
  int _targetIndex = -1;
  int _lastTickIndex = -1;

  @override
  void initState() {
    super.initState();
    _vinylRotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );

    _tonearmController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _rouletteScrollController = ScrollController();
    _rouletteAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _rouletteAnimationController.addListener(() {
      if (_targetIndex != -1 && _rouletteReel.isNotEmpty) {
        final double itemWidth = 110.0; // 100 card + 10 margin
        final double targetScroll = (_targetIndex * itemWidth) - (MediaQuery.of(context).size.width / 2) + (itemWidth / 2);
        
        final double currentScroll = Curves.easeOutCubic.transform(_rouletteAnimationController.value) * targetScroll;
        if (_rouletteScrollController.hasClients) {
          _rouletteScrollController.jumpTo(currentScroll.clamp(0.0, _rouletteScrollController.position.maxScrollExtent));
        }

        // Haptic feedback tick on item boundaries
        final int currentTickIndex = (currentScroll / itemWidth).round();
        if (currentTickIndex != _lastTickIndex && currentTickIndex <= _targetIndex) {
          FlickoHaptics.light();
          _lastTickIndex = currentTickIndex;
        }
      }
    });

    _prepareRouletteReel();
  }

  @override
  void dispose() {
    _vinylRotationController.dispose();
    _tonearmController.dispose();
    _rouletteScrollController.dispose();
    _rouletteAnimationController.dispose();
    super.dispose();
  }

  Future<void> _prepareRouletteReel() async {
    final storeService = ref.read(storeServiceProvider);
    final allProducts = await storeService.getProducts();
    final candidates = allProducts.where((p) => 
      p.id != 'mystery-crate' && 
      p.id != 'sonic-cyber-bundle' && 
      p.price > 0
    ).toList();

    if (candidates.isEmpty) return;

    final random = math.Random();
    setState(() {
      _rouletteReel.clear();
      // Generate a long dummy strip of 45 random products
      for (int i = 0; i < 45; i++) {
        _rouletteReel.add(candidates[random.nextInt(candidates.length)]);
      }
    });
  }

  void _triggerUnboxing(GachaState state) async {
    if (state.ownedCrates.isEmpty || state.status == 'unboxing') return;

    FlickoHaptics.medium();
    
    // 1. Move tonearm onto the record
    await _tonearmController.forward();
    
    // 2. Start vinyl record spin
    _vinylRotationController.repeat();

    // 3. Reset scroll parameters
    if (_rouletteScrollController.hasClients) {
      _rouletteScrollController.jumpTo(0.0);
    }
    _lastTickIndex = -1;
    _rouletteAnimationController.reset();

    // 4. Trigger logic
    ref.read(gachaProvider.notifier).executeUnboxing();
  }

  @override
  Widget build(BuildContext context) {
    final gachaState = ref.watch(gachaProvider);
    final notifier = ref.read(gachaProvider.notifier);

    // Watch status changes to coordinate visuals
    ref.listen(gachaProvider, (prev, next) {
      if (next.status == 'success' && next.reward != null) {
        // We received the reward, let's configure the reel exactly to stop on it
        setState(() {
          // Set a random landing slot near the end of our roulette reel (e.g. index 35)
          _targetIndex = 35;
          // Inject the exact reward product at our target landing slot
          _rouletteReel[_targetIndex] = next.reward!;
        });

        // Trigger horizontal deceleration
        _rouletteAnimationController.forward().then((_) {
          // Unboxing complete! Stop vinyl spin, lift tonearm, show reveal
          _vinylRotationController.stop();
          _tonearmController.reverse();
          FlickoHaptics.heavy();
          ref.read(badgeAlchemyProvider.notifier).incrementCratesOpened();
          _showRevealDialog(context, next.reward!, next.isDuplicate);
        });
      } else if (next.status == 'error' && next.errorMessage != null) {
        _vinylRotationController.stop();
        _tonearmController.reverse();
        FlickoHaptics.medium();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!.toUpperCase()), backgroundColor: Colors.red),
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
            notifier.reset();
            context.pop();
          },
        ),
        title: Text(
          'MYSTERY_DECK',
          style: GoogleFonts.inter(
            color: _white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 2,
          ),
        ),
        actions: [
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: _lime, width: 1.5),
                  color: Colors.black,
                ),
                child: Text(
                  '${gachaState.ownedCrates.length} CRATES',
                  style: GoogleFonts.inter(
                    color: _lime,
                    fontWeight: FontWeight.w900,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2.5),
          child: Container(color: _magenta, height: 2.5),
        ),
      ),
      body: Column(
        children: [
          // 1. Alert Ticker Banner
          _buildAlertTicker(gachaState),

          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  
                  // 2. Vinyl Turntable Display
                  _buildTurntable(gachaState),
                  const SizedBox(height: 32),

                  // 3. Horizontal Roulette Slider
                  _buildRouletteCarousel(gachaState),
                  const SizedBox(height: 36),

                  // 4. Action Button Panel
                  _buildActionsPanel(gachaState),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertTicker(GachaState state) {
    Color barColor = _lime;
    String text = 'TURNTABLE_ONLINE: DRIP AUDIO SPINS ENABLED';

    if (state.status == 'unboxing') {
      barColor = _magenta;
      text = 'NEEDLE_DROPPING: DECELERATING VINYL RECORD DISC...';
    } else if (state.status == 'success') {
      barColor = _lime;
      text = 'SPIN_COMPLETE: CRATE OPENED SUCCESSFULLY!';
    } else if (state.errorMessage != null) {
      barColor = Colors.red;
      text = state.errorMessage!.toUpperCase();
    } else if (state.ownedCrates.isEmpty) {
      barColor = _orange;
      text = 'CRATE_CAPACITY_ZERO: VISIT SHORTS TO STOCK UP!';
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

  Widget _buildTurntable(GachaState state) {
    return Container(
      width: 280,
      height: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0E),
        border: Border.all(color: _magenta, width: 1),
        boxShadow:  [
          BoxShadow(color: _magenta.withValues(alpha: 0.25),
            blurRadius: 14, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Circular record platter lines
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _muted.withValues(alpha: 0.3), width: 1.5),
                ),
              ),
            ),
          ),

          // Spinning Record Disc
          AnimatedBuilder(
            animation: _vinylRotationController,
            builder: (ctx, child) {
              return Transform.rotate(
                angle: _vinylRotationController.value * 2 * math.pi,
                child: child,
              );
            },
            child: _buildVinylRecord(),
          ),

          // Glowing Center Indicator
          Container(
            width: 14,
            height: 14,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _magenta,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),

          // Turntable Tonearm
          Positioned(
            top: 10,
            right: 10,
            child: AnimatedBuilder(
              animation: _tonearmController,
              builder: (ctx, child) {
                // Animate rotation angle of the tonearm onto the record
                final double angle = _tonearmController.value * 0.45;
                return Transform.rotate(
                  angle: angle,
                  origin: const Offset(30, -10),
                  child: _buildTonearmArm(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVinylRecord() {
    return Container(
      width: 210,
      height: 210,
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.black, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Vinyl record grooves
          ...List.generate(4, (index) {
            final double radius = 40.0 + (index * 22.0);
            return Container(
              width: radius * 2,
              height: radius * 2,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.8),
                  width: 1,
                ),
              ),
            );
          }),

          // Center Label Sticker
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: _lime,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 2),
            ),
            child: Center(
              child: Text(
                'SONIC\nDRIP',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontSize: 8,
                  fontWeight: FontWeight.w900,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTonearmArm() {
    return SizedBox(
      width: 80,
      height: 140,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Pivot Base
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF27272A),
                shape: BoxShape.circle,
                border: Border.all(color: _muted, width: 2),
              ),
            ),
          ),

          // Metallic Arm
          Positioned(
            top: 16,
            right: 12,
            child: Container(
              width: 5,
              height: 100,
              decoration: const BoxDecoration(
                color: Color(0xFFD4D4D8),
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),

          // Headshell Needle Cartridge
          Positioned(
            bottom: 8,
            left: 20,
            child: Transform.rotate(
              angle: -0.15,
              child: Container(
                width: 18,
                height: 32,
                decoration: const BoxDecoration(
                  color: Color(0xFF18181B),
                  border: Border(
                    left: BorderSide(color: _lime, width: 2),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouletteCarousel(GachaState state) {
    return Container(
      height: 130,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF09090B),
        border: Border.symmetric(
          horizontal: BorderSide(color: Color(0xFF1F1F23), width: 1.5),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // The horizontal scrollable cards
          _rouletteReel.isEmpty
              ? const Center(child: CircularProgressIndicator(color: _lime))
              : ListView.builder(
                  controller: _rouletteScrollController,
                  physics: const NeverScrollableScrollPhysics(), // Scroll controlled by listener
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: MediaQuery.of(context).size.width / 2 - 55),
                  itemCount: _rouletteReel.length,
                  itemBuilder: (ctx, idx) {
                    final item = _rouletteReel[idx];
                    return _buildRouletteCard(item, idx == _targetIndex && state.status == 'success');
                  },
                ),

          // Center Selection Needle / Pointer
          Positioned(
            top: 0,
            bottom: 0,
            child: Container(
              width: 1.5,
              color: _magenta,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Top triangle pointer
                  Positioned(
                    top: -1,
                    left: -6.5,
                    child: CustomPaint(
                      painter: _TrianglePointerPainter(isTop: true),
                      size: const Size(16, 10),
                    ),
                  ),
                  // Bottom triangle pointer
                  Positioned(
                    bottom: -1,
                    left: -6.5,
                    child: CustomPaint(
                      painter: _TrianglePointerPainter(isTop: false),
                      size: const Size(16, 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRouletteCard(StoreProduct item, bool isWinning) {
    final Color rarityCol = _getRarityColor(item.rarity);
    return Container(
      width: 100,
      margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(
          color: isWinning ? _magenta : rarityCol.withValues(alpha: 0.6),
          width: isWinning ? 2.5 : 1.5,
        ),
        boxShadow: isWinning
            ? const [
                BoxShadow(
                  color: _magenta,
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(_iconForType(item.type), color: rarityCol, size: 28),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              item.name.toUpperCase(),
              style: GoogleFonts.inter(
                color: _white,
                fontWeight: FontWeight.w900,
                fontSize: 8,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
            color: rarityCol.withValues(alpha: 0.15),
            child: Text(
              item.rarity.toUpperCase(),
              style: GoogleFonts.inter(
                color: rarityCol,
                fontWeight: FontWeight.bold,
                fontSize: 6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsPanel(GachaState state) {
    final bool hasCrates = state.ownedCrates.isNotEmpty;
    final bool isUnboxing = state.status == 'unboxing';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          GestureDetector(
            onTap: (hasCrates && !isUnboxing) ? () => _triggerUnboxing(state) : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                color: (hasCrates && !isUnboxing) ? _magenta : Colors.black,
                border: Border.all(
                  color: (hasCrates && !isUnboxing) ? Colors.black : _muted,
                  width: 1,
                ),
                boxShadow: (hasCrates && !isUnboxing)
                    ? [
                        BoxShadow(color: _magenta.withValues(alpha: 0.25),
                          blurRadius: 14, offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  isUnboxing ? 'NEEDLE_ENGAGED_SPINNING...' : 'DROP_THE_NEEDLE',
                  style: GoogleFonts.inter(
                    color: (hasCrates && !isUnboxing) ? Colors.black : _muted,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 2.5,
                  ),
                ),
              ),
            ),
          ),
          if (state.ownedCrates.isEmpty) ...[
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () {
                FlickoHaptics.light();
                context.pop(); // Returns to main store discovered tab
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: _lime, width: 2),
                  boxShadow:  [
                    BoxShadow(color: _lime.withValues(alpha: 0.25),
                      blurRadius: 14, offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'BUY_MORE_CRATES',
                    style: GoogleFonts.inter(
                      color: _lime,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showRevealDialog(BuildContext context, StoreProduct reward, bool isDuplicate) {
    final borderCol = _getRarityColor(reward.rarity);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            border: Border.all(color: isDuplicate ? _orange : borderCol, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Rarity Header with Warning duplication alert
              Container(
                color: isDuplicate ? _orange : borderCol,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                width: double.infinity,
                child: Text(
                  isDuplicate ? 'DUPLICATE_COSMETIC_UNLOCKED' : 'NEW_COSMETIC_UNLOCKED',
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    // Giant glowing unboxed item card
                    Container(
                      height: 130,
                      width: 130,
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
                          Icon(_iconForType(reward.type), color: borderCol, size: 44),
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
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),

                    Text(
                      reward.description ?? 'A high-fidelity premium vinyl gacha roll reward.',
                      style: GoogleFonts.inter(
                        color: _muted,
                        fontSize: 10,
                        height: 1.45,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (isDuplicate) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _orange.withValues(alpha: 0.15),
                          border: Border.all(color: _orange, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.warning_amber_rounded, color: _orange, size: 16),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'ALREADY_OWNED: RECYCLE IN FUSION CORE!',
                                style: GoogleFonts.inter(
                                  color: _orange,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 26),

                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  ref.read(gachaProvider.notifier).reset();
                                  Navigator.pop(ctx);
                                  _prepareRouletteReel();
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: _muted, width: 2),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text(
                                  'DISMISS',
                                  style: GoogleFonts.inter(
                                    color: _muted,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  FlickoHaptics.medium();
                                  await ref.read(equipmentServiceProvider).equipItem(reward.id, reward.type);
                                  ref.invalidate(equippedItemsProvider);
                                  ref.read(gachaProvider.notifier).reset();
                                  if (context.mounted) {
                                    Navigator.pop(ctx);
                                    _prepareRouletteReel();
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
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                child: Text(
                                  'EQUIP_NOW',
                                  style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isDuplicate) ...[
                          const SizedBox(height: 10),
                          GestureDetector(
                            onTap: () {
                              ref.read(gachaProvider.notifier).reset();
                              Navigator.pop(ctx);
                              // Route directly to Cosmetic Fusion Chamber
                              context.pushReplacement('/store/fusion');
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              decoration: BoxDecoration(
                                color: _orange,
                                border: Border.all(color: Colors.black, width: 2),
                              ),
                              child: Center(
                                child: Text(
                                  'OPEN_FUSION_CHAMBER',
                                  style: GoogleFonts.inter(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
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
        return _cyberBlue;
      case 'epic':
        return const Color(0xFF9B84EE);
      case 'legendary':
        return _orange;
      default:
        return _lime;
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

class _TrianglePointerPainter extends CustomPainter {
  final bool isTop;

  _TrianglePointerPainter({required this.isTop});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFFF007F)
      ..style = PaintingStyle.fill;

    final path = Path();
    if (isTop) {
      path.moveTo(0, 0);
      path.lineTo(size.width, 0);
      path.lineTo(size.width / 2, size.height);
    } else {
      path.moveTo(size.width / 2, 0);
      path.lineTo(size.width, size.height);
      path.lineTo(0, size.height);
    }
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
