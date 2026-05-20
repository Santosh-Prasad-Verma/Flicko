import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedCategory = 0;

  static const _bg = Color(0xFF050505);
  static const _surface = Color(0xFF0C0C0E);
  static const _neon = Color(0xFF9B84EE);
  static const _white = Color(0xFFFBF9FA);
  static const _muted = Color(0xFF71717A);

  final _categories = ['ALL', 'THEMES', 'STICKERS', 'SOUNDS', 'BADGES'];

  final _items = [
    {'name': 'Neon Pulse', 'type': 'THEME', 'price': '4.99', 'color': 0xFF9B84EE, 'hot': true},
    {'name': 'Cyber Glow', 'type': 'THEME', 'price': '3.99', 'color': 0xFF00E5FF, 'hot': false},
    {'name': 'Midnight', 'type': 'THEME', 'price': 'FREE', 'color': 0xFF9B84EE, 'hot': false},
    {'name': 'Flame Pack', 'type': 'STICKERS', 'price': '1.99', 'color': 0xFFFF6B6B, 'hot': true},
    {'name': 'Space Vibes', 'type': 'STICKERS', 'price': '2.49', 'color': 0xFFFFD700, 'hot': false},
    {'name': 'Retro Beeps', 'type': 'SOUNDS', 'price': '0.99', 'color': 0xFFF47FFF, 'hot': false},
    {'name': 'OG Badge', 'type': 'BADGE', 'price': '9.99', 'color': 0xFFFFD700, 'hot': true},
    {'name': 'Verified+', 'type': 'BADGE', 'price': '14.99', 'color': 0xFF00E5FF, 'hot': false},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> get _filteredItems {
    if (_selectedCategory == 0) return _items;
    final cat = _categories[_selectedCategory];
    return _items.where((i) {
      final type = (i['type'] as String).toUpperCase();
      if (cat == 'THEMES') return type == 'THEME';
      if (cat == 'STICKERS') return type == 'STICKERS';
      if (cat == 'SOUNDS') return type == 'SOUNDS';
      if (cat == 'BADGES') return type == 'BADGE';
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _white),
          onPressed: () => context.pop(),
        ),
        title: Text('Store',
            style: GoogleFonts.epilogue(
                color: _white, fontWeight: FontWeight.w900,
                fontSize: 20, fontStyle: FontStyle.italic)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: _white),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.shopping_bag_outlined, color: _white),
            onPressed: () {},
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: _neon,
          indicatorWeight: 2,
          labelColor: _white,
          unselectedLabelColor: _muted,
          labelStyle: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [Tab(text: 'DISCOVER'), Tab(text: 'MY ITEMS')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildDiscover(), _buildMyItems()],
      ),
    );
  }

  Widget _buildDiscover() {
    return CustomScrollView(
      slivers: [
        // Featured banner
        SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.all(16),
            height: 140,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF9B84EE), Color(0xFF00E5FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -20, top: -20,
                  child: Container(
                    width: 120, height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('FEATURED DROP',
                          style: GoogleFonts.spaceMono(
                              color: Colors.black54, fontSize: 11,
                              fontWeight: FontWeight.w900, letterSpacing: 2)),
                      const SizedBox(height: 6),
                      Text('Neon Pulse Theme',
                          style: GoogleFonts.epilogue(
                              color: Colors.black, fontSize: 24,
                              fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        color: Colors.black,
                        child: Text('\$4.99',
                            style: GoogleFonts.spaceGrotesk(
                                color: _white, fontWeight: FontWeight.w900)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Category chips
        SliverToBoxAdapter(
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final selected = _selectedCategory == index;
                return GestureDetector(
                  onTap: () => setState(() => _selectedCategory = index),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? _neon : _surface,
                      border: Border.all(
                          color: selected ? _neon : Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Text(_categories[index],
                        style: GoogleFonts.spaceGrotesk(
                            color: selected ? Colors.black : _muted,
                            fontWeight: FontWeight.w700,
                            fontSize: 12)),
                  ),
                );
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // Grid
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.85,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildStoreItem(_filteredItems[index]),
              childCount: _filteredItems.length,
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 32)),
      ],
    );
  }

  Widget _buildStoreItem(Map<String, dynamic> item) {
    final color = Color(item['color'] as int);
    final isFree = item['price'] == 'FREE';
    final isHot = item['hot'] as bool;

    return GestureDetector(
      onTap: () => _showItemDetail(item),
      child: Container(
        decoration: BoxDecoration(
          color: _surface,
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.05)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        _iconForType(item['type'] as String),
                        color: color,
                        size: 40,
                      ),
                    ),
                  ),
                  if (isHot)
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        color: const Color(0xFFFF6B6B),
                        child: Text('HOT',
                            style: GoogleFonts.spaceMono(
                                color: Colors.white, fontSize: 9,
                                fontWeight: FontWeight.w900)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['name'] as String,
                      style: GoogleFonts.spaceGrotesk(
                          color: _white, fontWeight: FontWeight.w700, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(item['type'] as String,
                      style: GoogleFonts.spaceMono(
                          color: _muted, fontSize: 10, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(isFree ? 'FREE' : '\$${item['price']}',
                      style: GoogleFonts.epilogue(
                          color: isFree ? _neon : _white,
                          fontWeight: FontWeight.w900,
                          fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toUpperCase()) {
      case 'THEME': return Icons.palette_rounded;
      case 'STICKERS': return Icons.emoji_emotions_rounded;
      case 'SOUNDS': return Icons.music_note_rounded;
      case 'BADGE': return Icons.verified_rounded;
      default: return Icons.store_rounded;
    }
  }

  Widget _buildMyItems() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.shopping_bag_outlined, color: _muted, size: 64),
          const SizedBox(height: 16),
          Text('NO ITEMS YET',
              style: GoogleFonts.epilogue(
                  color: _white, fontSize: 20,
                  fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
          const SizedBox(height: 8),
          Text('Items you purchase will appear here.',
              style: GoogleFonts.inter(color: _muted, fontSize: 14)),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: () => _tabController.animateTo(0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              color: _neon,
              child: Text('BROWSE STORE',
                  style: GoogleFonts.spaceGrotesk(
                      color: Colors.black, fontWeight: FontWeight.w900)),
            ),
          ),
        ],
      ),
    );
  }

  void _showItemDetail(Map<String, dynamic> item) {
    final color = Color(item['color'] as int);
    final isFree = item['price'] == 'FREE';

    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                height: 100, width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.05)],
                  ),
                ),
                child: Center(child: Icon(_iconForType(item['type'] as String), color: color, size: 48)),
              ),
              const SizedBox(height: 20),
              Text(item['name'] as String,
                  style: GoogleFonts.epilogue(
                      color: _white, fontSize: 24,
                      fontWeight: FontWeight.w900, fontStyle: FontStyle.italic)),
              const SizedBox(height: 4),
              Text(item['type'] as String,
                  style: GoogleFonts.spaceMono(color: _muted, fontSize: 12)),
              const SizedBox(height: 24),
              GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${item['name']} ${isFree ? 'added' : 'purchased'}!')));
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  color: isFree ? _neon : color,
                  child: Center(
                    child: Text(isFree ? 'GET FOR FREE' : 'BUY FOR \$${item['price']}',
                        style: GoogleFonts.spaceGrotesk(
                            color: Colors.black, fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
