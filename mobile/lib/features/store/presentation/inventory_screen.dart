import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/equipment_service.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const Color _bgDark = Color(0xFF111214);
  static const Color _cardBg = Color(0xFF1E1F22);
  static const Color _cardBgLight = Color(0xFF2B2D31);
  static const Color _blurple = Color(0xFF5865F2);
  static const Color _greenAccent = Color(0xFF23A55A);
  static const Color _textMuted = Color(0xFF949BA4);

  final _tabs = ['ALL', 'THEMES', 'STICKERS', 'SOUNDS', 'BADGES'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryAsync = ref.watch(inventoryProvider);
    final equippedAsync = ref.watch(equippedItemsProvider);

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Text(
              'My Items',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _blurple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${inventoryAsync.value?.length ?? 0}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_none_rounded, color: _blurple, size: 22),
            tooltip: 'Sound Studio',
            onPressed: () => context.push('/store/sound-studio'),
          ),
          IconButton(
            icon: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
            onPressed: () => context.push('/store'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: _blurple,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: _textMuted,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
          unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: inventoryAsync.when(
        data: (items) => equippedAsync.when(
          data: (equipped) => _buildInventoryList(items, equipped),
          loading: () => const Center(child: CircularProgressIndicator(color: _blurple)),
          error: (_, __) => const Center(child: Text('Error loading equipped items', style: TextStyle(color: Colors.red))),
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: _blurple)),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: Colors.red))),
      ),
    );
  }

  Widget _buildInventoryList(List<UserPurchase> items, Map<String, EquippedItem> equipped) {
    return TabBarView(
      controller: _tabController,
      children: _tabs.map((tab) {
        final filtered = tab == 'ALL'
            ? items
            : items.where((item) {
                final type = item.productType.toUpperCase();
                if (tab == 'THEMES') return type.contains('THEME') || type.contains('DECORATION');
                if (tab == 'BADGES') return type.contains('BADGE') || type.contains('NAMEPLATE');
                return type == tab;
              }).toList();

        if (filtered.isEmpty) {
          return _buildEmptyState(tab);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filtered.length,
          itemBuilder: (context, index) => _buildInventoryItem(filtered[index], equipped),
        );
      }).toList(),
    );
  }

  Widget _buildEmptyState(String tab) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getEmptyIcon(tab),
            color: _textMuted,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'No ${tab == 'ALL' ? 'items' : tab.toLowerCase()} yet',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Visit the shop to discover new cosmetics!',
            style: GoogleFonts.inter(color: _textMuted, fontSize: 13),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.push('/store'),
            icon: const Icon(Icons.storefront_rounded, size: 18),
            label: Text(
              'VISIT STORE',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryItem(UserPurchase item, Map<String, EquippedItem> equipped) {
    final typeKey = item.productType.toLowerCase();
    final isEquipped = equipped[typeKey]?.productId == item.productId;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEquipped ? _greenAccent : Colors.white.withValues(alpha: 0.06),
          width: isEquipped ? 1.8 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Item icon
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _cardBgLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  _getTypeIcon(item.productType),
                  color: _getTypeColor(item.productType),
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 14),
            // Item info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.productName,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isEquipped) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _greenAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: _greenAccent.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_rounded, color: _greenAccent, size: 12),
                              const SizedBox(width: 4),
                              Text(
                                'EQUIPPED',
                                style: GoogleFonts.inter(
                                  color: _greenAccent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.productType.replaceAll('_', ' ').toUpperCase(),
                    style: GoogleFonts.inter(
                      color: _textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Purchased ${_formatDate(item.purchasedAt)}',
                    style: GoogleFonts.inter(
                      color: _textMuted.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            // Action button
            IconButton(
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white70, size: 20),
              onPressed: () => _showItemOptions(item, isEquipped),
            ),
          ],
        ),
      ),
    );
  }

  void _showItemOptions(UserPurchase item, bool isEquipped) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _bgDark,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                item.productName,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 20),
              if (!isEquipped)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _greenAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: _greenAccent, size: 20),
                  ),
                  title: Text('Equip', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  subtitle: Text('Use this ${item.productType.toLowerCase()}', style: GoogleFonts.inter(color: _textMuted)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _equipItem(item);
                  },
                ),
              if (isEquipped)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.remove_circle_outline_rounded, color: Colors.redAccent, size: 20),
                  ),
                  title: Text('Unequip', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                  subtitle: Text('Stop using this ${item.productType.toLowerCase()}', style: GoogleFonts.inter(color: _textMuted)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _unequipItem(item);
                  },
                ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _blurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.card_giftcard_rounded, color: _blurple, size: 20),
                ),
                title: Text('Gift to Friend', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                subtitle: Text('Coming soon', style: GoogleFonts.inter(color: _textMuted)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gifting coming soon!'), backgroundColor: _blurple),
                  );
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _equipItem(UserPurchase item) async {
    final service = ref.read(equipmentServiceProvider);
    final success = await service.equipItem(item.productId, item.productType);
    
    if (success) {
      ref.invalidate(equippedItemsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.productName} equipped!'),
            backgroundColor: _greenAccent,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to equip item'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  Future<void> _unequipItem(UserPurchase item) async {
    final service = ref.read(equipmentServiceProvider);
    final success = await service.unequipItem(item.productId);
    
    if (success) {
      ref.invalidate(equippedItemsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.productName} unequipped'),
            backgroundColor: _blurple,
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  IconData _getTypeIcon(String type) {
    switch (type.toUpperCase()) {
      case 'THEME':
      case 'AVATAR_DECORATION':
        return Icons.palette_rounded;
      case 'STICKERS':
        return Icons.emoji_emotions_rounded;
      case 'SOUNDS':
        return Icons.music_note_rounded;
      case 'BADGE':
      case 'NAMEPLATE':
        return Icons.verified_rounded;
      default:
        return Icons.inventory_2_rounded;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toUpperCase()) {
      case 'THEME':
      case 'AVATAR_DECORATION':
        return _blurple;
      case 'STICKERS':
        return const Color(0xFFFEE75C);
      case 'SOUNDS':
        return const Color(0xFF57F287);
      case 'BADGE':
      case 'NAMEPLATE':
        return _greenAccent;
      default:
        return _textMuted;
    }
  }

  IconData _getEmptyIcon(String tab) {
    switch (tab) {
      case 'THEMES':
        return Icons.palette_outlined;
      case 'STICKERS':
        return Icons.emoji_emotions_outlined;
      case 'SOUNDS':
        return Icons.music_note_outlined;
      case 'BADGES':
        return Icons.verified_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }
}
