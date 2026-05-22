import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/equipment_service.dart';

/// Callback when a sticker is selected
typedef StickerSelectedCallback = void Function(String stickerId, String stickerUrl);

/// Sticker picker for use in chat
class StickerPickerWidget extends ConsumerStatefulWidget {
  final StickerSelectedCallback? onStickerSelected;
  final bool showSearch;

  const StickerPickerWidget({
    super.key,
    this.onStickerSelected,
    this.showSearch = true,
  });

  @override
  ConsumerState<StickerPickerWidget> createState() => _StickerPickerWidgetState();
}

class _StickerPickerWidgetState extends ConsumerState<StickerPickerWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';

  static const Color _bg = Color(0xFF050505);
  static const Color _surface = Color(0xFF0C0C0E);
  static const Color _neon = Color(0xFF9B84EE);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xFF71717A);
  static const Color _gold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);

    return Container(
      height: 320,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header with search
          if (widget.showSearch) _buildSearchBar(),
          // Tabs
          TabBar(
            controller: _tabController,
            indicatorColor: _neon,
            labelColor: _white,
            unselectedLabelColor: _muted,
            labelStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 11),
            tabs: const [
              Tab(text: 'OWNED'),
              Tab(text: 'RECENT'),
              Tab(text: 'STORE'),
            ],
          ),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOwnedStickers(inventoryAsync),
                _buildRecentStickers(),
                _buildStorePreview(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: GoogleFonts.spaceGrotesk(color: _white),
        decoration: InputDecoration(
          hintText: 'Search stickers...',
          hintStyle: GoogleFonts.spaceGrotesk(color: _muted),
          filled: true,
          fillColor: _bg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          prefixIcon: Icon(Icons.search, color: _muted, size: 20),
        ),
      ),
    );
  }

  Widget _buildOwnedStickers(AsyncValue<List<UserPurchase>> inventoryAsync) {
    return inventoryAsync.when(
      data: (items) {
        final stickers = items.where((i) =>
            i.productType.toLowerCase() == 'stickers' ||
            i.productType.toLowerCase() == 'sticker_pack');

        if (stickers.isEmpty) {
          return _buildEmptyState('No sticker packs owned', Icons.emoji_emotions_outlined);
        }

        return GridView.builder(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 32, // Show sample stickers from packs
          itemBuilder: (context, index) => _buildStickerItem(index),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: _neon)),
      error: (_, __) => _buildEmptyState('Error loading stickers', Icons.error_outline),
    );
  }

  Widget _buildRecentStickers() {
    // TODO: Load from local storage
    return _buildEmptyState('No recent stickers', Icons.history);
  }

  Widget _buildStorePreview() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.storefront, color: _muted, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Get more stickers from the store',
                  style: GoogleFonts.spaceGrotesk(color: _muted),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
              // Navigate to store
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: _neon,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'VISIT STORE',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStickerItem(int index) {
    final emojis = ['😀', '😂', '🥰', '😎', '🔥', '💯', '✨', '🎮', '💎', '🚀', '⚡', '🌟', '💖', '🎯', '🏆', '💪'];
    final colors = [_neon, _gold, const Color(0xFF00E5FF), const Color(0xFF52B788)];

    final emoji = emojis[index % emojis.length];
    final color = colors[index % colors.length];

    return GestureDetector(
      onTap: () {
        widget.onStickerSelected?.call('sticker_$index', '');
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            emoji,
            style: TextStyle(fontSize: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _muted, size: 48),
          const SizedBox(height: 12),
          Text(message, style: GoogleFonts.spaceGrotesk(color: _muted)),
        ],
      ),
    );
  }
}

/// Button to show sticker picker
class StickerPickerButton extends StatelessWidget {
  final VoidCallback? onTap;

  const StickerPickerButton({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF0C0C0E),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.emoji_emotions_outlined,
          color: Color(0xFF9B84EE),
          size: 24,
        ),
      ),
    );
  }
}

/// Function to show sticker picker modal
void showStickerPicker(
  BuildContext context, {
  StickerSelectedCallback? onStickerSelected,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => StickerPickerWidget(onStickerSelected: onStickerSelected),
  );
}
