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

  static const Color _bg = Color(0xFF050505);
  static const Color _surface = Color(0xFF0C0C0E);
  static const Color _neon = Color(0xFF9B84EE);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xFF71717A);
  static const Color _lime = Color(0xFF52B788);
  static const Color _gold = Color(0xFFFFD700);

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
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _white),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Text(
              'My Items',
              style: GoogleFonts.epilogue(
                color: _white,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _neon.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${inventoryAsync.value?.length ?? 0}',
                style: GoogleFonts.spaceGrotesk(
                  color: _neon,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined, color: _white),
            onPressed: () => context.push('/store'),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: _neon,
          indicatorWeight: 2,
          labelColor: _white,
          unselectedLabelColor: _muted,
          labelStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 12),
          tabs: _tabs.map((t) => Tab(text: t)).toList(),
        ),
      ),
      body: inventoryAsync.when(
        data: (items) => equippedAsync.when(
          data: (equipped) => _buildInventoryList(items, equipped),
          loading: () => const Center(child: CircularProgressIndicator(color: _neon)),
          error: (_, __) => const Center(child: Text('Error loading equipped items', style: TextStyle(color: Colors.red))),
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: _neon)),
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
            color: _muted,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            'NO ${tab == 'ALL' ? 'ITEMS' : tab} YET',
            style: GoogleFonts.epilogue(
              color: _white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Visit the store to get some!',
            style: GoogleFonts.spaceGrotesk(color: _muted),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => context.push('/store'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              decoration: BoxDecoration(
                color: _neon,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'VISIT STORE',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                ),
              ),
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
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isEquipped ? _lime : _white.withValues(alpha: 0.1),
          width: isEquipped ? 2 : 1,
        ),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Item icon
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _getTypeColor(item.productType).withValues(alpha: 0.3),
                        _getTypeColor(item.productType).withValues(alpha: 0.1),
                      ],
                    ),
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
                const SizedBox(width: 16),
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
                              style: GoogleFonts.spaceGrotesk(
                                color: _white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isEquipped) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _lime,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.check, color: Colors.black, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    'EQUIPPED',
                                    style: GoogleFonts.spaceGrotesk(
                                      color: Colors.black,
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
                        item.productType.toUpperCase(),
                        style: GoogleFonts.spaceMono(
                          color: _muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Purchased ${_formatDate(item.purchasedAt)}',
                        style: GoogleFonts.spaceGrotesk(
                          color: _muted.withValues(alpha: 0.7),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Action button
          Positioned(
            right: 16,
            bottom: 16,
            child: GestureDetector(
              onTap: () => _showItemOptions(item, isEquipped),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.more_vert,
                  color: _white.withValues(alpha: 0.7),
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showItemOptions(UserPurchase item, bool isEquipped) {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 40, height: 4, decoration: BoxDecoration(color: _white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text(
                item.productName,
                style: GoogleFonts.epilogue(
                  color: _white,
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 24),
              if (!isEquipped)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _lime.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.check_circle, color: _lime),
                  ),
                  title: Text('Equip', style: GoogleFonts.spaceGrotesk(color: _white, fontWeight: FontWeight.w600)),
                  subtitle: Text('Use this ${item.productType.toLowerCase()}', style: GoogleFonts.spaceGrotesk(color: _muted)),
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
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  ),
                  title: Text('Unequip', style: GoogleFonts.spaceGrotesk(color: Colors.red, fontWeight: FontWeight.w600)),
                  subtitle: Text('Stop using this ${item.productType.toLowerCase()}', style: GoogleFonts.spaceGrotesk(color: _muted)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await _unequipItem(item);
                  },
                ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _neon.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.card_giftcard, color: _neon),
                ),
                title: Text('Gift to Friend', style: GoogleFonts.spaceGrotesk(color: _white, fontWeight: FontWeight.w600)),
                subtitle: const Text('Coming soon', style: TextStyle(color: _muted)),
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Gifting coming soon!'), backgroundColor: _neon),
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
            backgroundColor: _lime,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to equip item'),
            backgroundColor: Colors.red,
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
            backgroundColor: _neon,
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
        return _neon;
      case 'STICKERS':
        return _gold;
      case 'SOUNDS':
        return Colors.cyan;
      case 'BADGE':
      case 'NAMEPLATE':
        return _lime;
      default:
        return _muted;
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
