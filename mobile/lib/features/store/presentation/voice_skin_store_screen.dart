import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/equipment_service.dart';
import 'package:mobile/features/voice/data/voice_filter_service.dart';
import 'package:mobile/features/voice/presentation/widgets/voice_synth_board_sheet.dart';
import 'package:mobile/core/services/flicko_haptics.dart';

class VoiceSkinStoreScreen extends ConsumerStatefulWidget {
  const VoiceSkinStoreScreen({super.key});

  @override
  ConsumerState<VoiceSkinStoreScreen> createState() => _VoiceSkinStoreScreenState();
}

class _VoiceSkinStoreScreenState extends ConsumerState<VoiceSkinStoreScreen>
    with SingleTickerProviderStateMixin {
  String _selectedSkinId = '8bit-arcade-skin';
  
  // Interactive Cassette Tape State
  bool _isRecording = false;
  bool _isPlaying = false;
  double _recordingTime = 0.0;
  double _playbackProgress = 0.0;
  Timer? _tapeTimer;

  late AnimationController _visualizerController;

  static const Color _bg = Color(0xFF000000);
  static const Color _surface = Color(0xFF0C0C0E);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xFF71717A);
  static const Color _lime = Color(0xFF52B788);
  static const Color _orange = Color(0xFFFAA61A);
  static const Color _magenta = Color(0xFFFF007F);
  static const Color _cyberBlue = Color(0xFF00E5FF);

  @override
  void initState() {
    super.initState();
    _visualizerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _tapeTimer?.cancel();
    _visualizerController.dispose();
    super.dispose();
  }

  void _startRecording() {
    FlickoHaptics.medium();
    _tapeTimer?.cancel();
    setState(() {
      _isRecording = true;
      _isPlaying = false;
      _recordingTime = 0.0;
    });

    _tapeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _recordingTime += 0.1;
        if (_recordingTime >= 3.0) {
          _stopRecording();
        }
      });
    });
  }

  void _stopRecording() {
    FlickoHaptics.light();
    _tapeTimer?.cancel();
    setState(() {
      _isRecording = false;
    });
  }

  void _startPlayback() {
    FlickoHaptics.medium();
    _tapeTimer?.cancel();
    setState(() {
      _isPlaying = true;
      _isRecording = false;
      _playbackProgress = 0.0;
    });

    _tapeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      setState(() {
        _playbackProgress += 0.1 / 3.0;
        if (_playbackProgress >= 1.0) {
          _stopPlayback();
        }
      });
    });
  }

  void _stopPlayback() {
    FlickoHaptics.light();
    _tapeTimer?.cancel();
    setState(() {
      _isPlaying = false;
      _playbackProgress = 0.0;
    });
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
          'VOICE_SKIN_DECK',
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
              final allProducts = BuiltInVoiceSkins.all;
              final selectedDefinition = BuiltInVoiceSkins.getById(_selectedSkinId)!;
              
              // Retrieve storefront product details
              final storeService = ref.read(storeServiceProvider);
              final List<StoreProduct> sampleProducts = storeService.getSampleProducts();
              final product = sampleProducts.firstWhere((p) => p.id == _selectedSkinId);

              final isOwned = inventory.any((p) => p.productId == _selectedSkinId);
              final isEquipped = equipped['VOICE_SKIN']?.productId == _selectedSkinId ||
                  equipped['voice_skin']?.productId == _selectedSkinId;

              return Column(
                children: [
                  // 1. Interactive Preview Cassette Tape Mirror
                  _buildPreviewTape(selectedDefinition),

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
                              'AVAILABLE_VOICE_SKINS',
                              style: GoogleFonts.inter(
                                color: _white,
                                fontWeight: FontWeight.w900,
                                fontSize: 11,
                                letterSpacing: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // 4. Voice Skins Grid
                            _buildSkinsGrid(allProducts, equipped),
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

  Widget _buildPreviewTape(VoiceSkinDefinition spec) {
    return Container(
      width: double.infinity,
      color: _surface,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      child: Column(
        children: [
          // 1. Brutalist Cassette Tape Platter
          Container(
            width: double.infinity,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: spec.filter.isEnabled ? spec.primaryColor : _muted, width: 1),
              boxShadow: [
                if (spec.filter.isEnabled)
                  BoxShadow(
                    color: spec.primaryColor.withValues(alpha: 0.25),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Scanline mesh
                Positioned.fill(
                  child: Opacity(
                    opacity: 0.04,
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 16,
                        crossAxisSpacing: 1,
                        mainAxisSpacing: 1,
                      ),
                      itemCount: 160,
                      itemBuilder: (ctx, idx) => Container(
                        decoration: BoxDecoration(border: Border.all(color: _white, width: 0.5)),
                      ),
                    ),
                  ),
                ),
                // Cassette details/labels
                Positioned(
                  top: 10,
                  left: 15,
                  child: Text(
                    'FLICKO_TAPE_T-90',
                    style: GoogleFonts.inter(color: _muted, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 15,
                  child: Text(
                    spec.filter.activePresetName.toUpperCase(),
                    style: GoogleFonts.inter(color: spec.primaryColor, fontSize: 8, fontWeight: FontWeight.w900),
                  ),
                ),
                
                // Centered dynamic bouncing waveform
                Positioned(
                  bottom: 30,
                  left: 15,
                  right: 15,
                  top: 30,
                  child: AnimatedBuilder(
                    animation: _visualizerController,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: SynthesizerWavePainter(
                          animationValue: _visualizerController.value,
                          preset: spec.filter.activePresetName,
                          pitch: spec.filter.pitchSemitones,
                          reverb: spec.filter.reverbRoom,
                          bitcrush: spec.filter.bitcrushFrequency,
                          isEnabled: _isRecording || _isPlaying,
                          neonColor: _lime,
                          goldColor: _orange,
                          skinId: spec.id,
                        ),
                      );
                    },
                  ),
                ),
                
                // Playback progress bar (glowing line)
                if (_isPlaying)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 4,
                      alignment: Alignment.centerLeft,
                      color: spec.primaryColor.withValues(alpha: 0.15),
                      child: FractionallySizedBox(
                        widthFactor: _playbackProgress,
                        child: Container(color: spec.primaryColor),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 2. Brutalist Deck Controls
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Recording Button
              GestureDetector(
                onTap: _isRecording ? _stopRecording : _startRecording,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: _isRecording ? _magenta : Colors.black,
                    border: Border.all(color: _isRecording ? Colors.black : _magenta, width: 2),
                    boxShadow: _isRecording
                        ? null
                        : [BoxShadow(color: _magenta.withValues(alpha: 0.3), blurRadius: 14, spreadRadius: 1)],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _isRecording ? Colors.black : _magenta,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isRecording ? 'STOP' : 'RECORD TEST',
                        style: GoogleFonts.inter(
                          color: _isRecording ? Colors.black : _white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Playback Button
              GestureDetector(
                onTap: (_isRecording || _recordingTime == 0.0)
                    ? null
                    : _isPlaying
                        ? _stopPlayback
                        : _startPlayback,
                child: Opacity(
                  opacity: _recordingTime > 0.0 ? 1.0 : 0.4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: _isPlaying ? _cyberBlue : Colors.black,
                      border: Border.all(color: _isPlaying ? Colors.black : _cyberBlue, width: 2),
                      boxShadow: _isPlaying
                          ? null
                          : [BoxShadow(color: _cyberBlue.withValues(alpha: 0.3), blurRadius: 14, spreadRadius: 1)],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          _isPlaying ? Icons.stop : Icons.play_arrow,
                          color: _isPlaying ? Colors.black : _white,
                          size: 12,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _isPlaying ? 'STOP' : 'PLAY LOOP',
                          style: GoogleFonts.inter(
                            color: _isPlaying ? Colors.black : _white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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
            product.description ?? 'A high-fidelity premium voice skin with audio effects.',
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

  Widget _buildSkinsGrid(List<VoiceSkinDefinition> items, Map<String, EquippedItem> equipped) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.5,
      ),
      itemCount: items.length,
      itemBuilder: (ctx, index) {
        final skin = items[index];
        final isSelected = skin.id == _selectedSkinId;
        final isEquipped = equipped['VOICE_SKIN']?.productId == skin.id ||
            equipped['voice_skin']?.productId == skin.id;

        return GestureDetector(
          onTap: () {
            FlickoHaptics.light();
            setState(() {
              _selectedSkinId = skin.id;
              _recordingTime = 0.0; // Reset recorder preview on swap
              _isPlaying = false;
              _isRecording = false;
            });
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? skin.primaryColor.withValues(alpha: 0.1) : Colors.black,
              border: Border.all(
                color: isSelected ? skin.primaryColor : _muted.withValues(alpha: 0.3),
                width: isSelected ? 2 : 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Render small bouncy wave preview icon
                Icon(
                  Icons.audiotrack_rounded,
                  color: isSelected ? skin.primaryColor : _muted,
                  size: 24,
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    skin.name.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: isSelected ? skin.primaryColor : _white,
                      fontSize: 8.5,
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
                          await equipService.equipItem('none', 'VOICE_SKIN');
                        } else {
                          await equipService.equipItem(product.id, 'VOICE_SKIN');
                        }
                        ref.invalidate(equippedItemsProvider);
                        ref.invalidate(equippedVoiceSkinProvider);
                        ref.invalidate(voiceFilterProvider);
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
                            isEquipped ? 'UNEQUIP_VOICE_SKIN' : 'EQUIP_VOICE_SKIN',
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

extension on VoiceSkinDefinition {
  Color get primaryColor {
    switch (id) {
      case '8bit-arcade-skin':
        return const Color(0xFF00FF66);
      case 'retro-radio-skin':
        return const Color(0xFF00E5FF);
      case 'lofi-tape-skin':
        return const Color(0xFFFAA61A);
      case 'cyber-vocoder-skin':
        return const Color(0xFF00FF66);
      default:
        return const Color(0xFF52B788);
    }
  }
}
