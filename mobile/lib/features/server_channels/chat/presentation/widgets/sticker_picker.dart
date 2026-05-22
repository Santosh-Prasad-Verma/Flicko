import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/equipment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

/// Sticker pack item from store
class StickerItem {
  final String id;
  final String name;
  final String url;
  final String? packId;

  const StickerItem({
    required this.id,
    required this.name,
    required this.url,
    this.packId,
  });
}

class StickerPicker extends ConsumerStatefulWidget {
  final Function(String stickerUrl) onStickerSelected;

  const StickerPicker({super.key, required this.onStickerSelected});

  @override
  ConsumerState<StickerPicker> createState() => _StickerPickerState();
}

class _StickerPickerState extends ConsumerState<StickerPicker>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<StickerItem> _recentStickers = [];
  
  static const Color _neon = Color(0xFF9B84EE);
  static const Color _bg = Color(0xFF050505);
  static const Color _surface = Color(0xFF0C0C0E);
  static const Color _white = Color(0xFFFBF9FA);
  static const Color _muted = Color(0xFF71717A);

  // Default stickers for users without purchased ones
  static const List<StickerItem> _defaultStickers = [
    StickerItem(id: 'wave', name: 'Wave', url: '👋'),
    StickerItem(id: 'fire', name: 'Fire', url: '🔥'),
    StickerItem(id: 'heart', name: 'Heart', url: '❤️'),
    StickerItem(id: 'thumbsup', name: 'Thumbs Up', url: '👍'),
    StickerItem(id: 'laugh', name: 'Laugh', url: '😂'),
    StickerItem(id: 'star', name: 'Star', url: '⭐'),
    StickerItem(id: 'rocket', name: 'Rocket', url: '🚀'),
    StickerItem(id: 'party', name: 'Party', url: '🎉'),
    StickerItem(id: 'cool', name: 'Cool', url: '😎'),
    StickerItem(id: 'think', name: 'Think', url: '🤔'),
    StickerItem(id: 'clap', name: 'Clap', url: '👏'),
    StickerItem(id: 'sparkles', name: 'Sparkles', url: '✨'),
    StickerItem(id: 'hundred', name: '100', url: '💯'),
    StickerItem(id: 'eyes', name: 'Eyes', url: '👀'),
    StickerItem(id: 'flex', name: 'Flex', url: '💪'),
    StickerItem(id: 'shrug', name: 'Shrug', url: '🤷'),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRecentStickers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentStickers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recent = prefs.getString('recent_stickers');
      if (recent != null) {
        final List<dynamic> decoded = json.decode(recent);
        setState(() {
          _recentStickers = decoded
              .map((e) => StickerItem(
                    id: e['id'] ?? '',
                    name: e['name'] ?? '',
                    url: e['url'] ?? '',
                  ))
              .toList();
        });
      }
    } catch (_) {}
  }

  Future<void> _saveRecentStickers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'recent_stickers',
        json.encode(_recentStickers.map((e) => {
          'id': e.id,
          'name': e.name,
          'url': e.url,
        }).toList()),
      );
    } catch (_) {}
  }

  void _onStickerSelected(StickerItem sticker) {
    // Add to recent
    _recentStickers.removeWhere((s) => s.id == sticker.id);
    _recentStickers.insert(0, sticker);
    if (_recentStickers.length > 16) {
      _recentStickers = _recentStickers.sublist(0, 16);
    }
    _saveRecentStickers();
    
    widget.onStickerSelected(sticker.url);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);

    return Container(
      decoration: const BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      height: 380,
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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Stickers',
                  style: GoogleFonts.inter(
                    color: _white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: _muted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
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
              Tab(text: 'DEFAULT'),
            ],
          ),
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOwnedStickers(inventoryAsync),
                _buildRecentStickers(),
                _buildDefaultStickers(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnedStickers(AsyncValue<List<UserPurchase>> inventoryAsync) {
    return inventoryAsync.when(
      data: (items) {
        final stickerPacks = items.where((i) =>
            i.productType.toLowerCase() == 'stickers' ||
            i.productType.toLowerCase() == 'sticker_pack');

        if (stickerPacks.isEmpty) {
          return _buildEmptyState(
            'No sticker packs owned',
            'Purchase sticker packs from the store',
            Icons.emoji_emotions_outlined,
          );
        }

        // For now, show default stickers as preview
        // In real app, would load from purchased pack data
        return _buildStickerGrid(_defaultStickers);
      },
      loading: () => const Center(child: CircularProgressIndicator(color: _neon)),
      error: (_, __) => _buildEmptyState('Error loading stickers', null, Icons.error_outline),
    );
  }

  Widget _buildRecentStickers() {
    if (_recentStickers.isEmpty) {
      return _buildEmptyState(
        'No recent stickers',
        'Used stickers will appear here',
        Icons.history,
      );
    }
    return _buildStickerGrid(_recentStickers);
  }

  Widget _buildDefaultStickers() {
    return _buildStickerGrid(_defaultStickers);
  }

  Widget _buildStickerGrid(List<StickerItem> stickers) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final sticker = stickers[index];
        final colors = [_neon, const Color(0xFFFFD700), const Color(0xFF00E5FF), const Color(0xFF52B788)];
        final color = colors[index % colors.length];

        return GestureDetector(
          onTap: () => _onStickerSelected(sticker),
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Center(
              child: Text(
                sticker.url,
                style: const TextStyle(fontSize: 28),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String title, String? subtitle, IconData icon) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _muted, size: 48),
          const SizedBox(height: 12),
          Text(title, style: GoogleFonts.spaceGrotesk(color: _muted, fontSize: 14)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle, style: GoogleFonts.spaceGrotesk(color: _muted.withValues(alpha: 0.7), fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

extension StickerPickerContext on BuildContext {
  void showStickerPicker({required Function(String stickerUrl) onStickerSelected}) {
    showModalBottomSheet(
      context: this,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StickerPicker(onStickerSelected: onStickerSelected),
    );
  }
}
