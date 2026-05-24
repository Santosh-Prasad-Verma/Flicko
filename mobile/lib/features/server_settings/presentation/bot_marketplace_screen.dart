import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/server_settings/data/bot_marketplace_data.dart';

class BotMarketplaceScreen extends StatefulWidget {
  final String serverId;

  const BotMarketplaceScreen({
    super.key,
    required this.serverId,
  });

  @override
  State<BotMarketplaceScreen> createState() => _BotMarketplaceScreenState();
}

class _BotMarketplaceScreenState extends State<BotMarketplaceScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          _buildSearchBar(),
          _buildTabs(),
          _buildGrid(),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: const Color(FlickoColors.bgSecondary),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(
          'Bot Marketplace',
          style: GoogleFonts.inter(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF5865F2),
                    Color(0xFF4752C4),
                    Color(0xFF3B44A3),
                  ],
                ),
              ),
            ),
            Positioned(
              right: -20,
              top: -20,
              child: Opacity(
                opacity: 0.1,
                child: Icon(Icons.smart_toy, size: 200, color: Colors.white),
              ),
            ),
            Positioned(
              left: 20,
              bottom: 60,
              child: Text(
                'Explore AI Agents & Tools',
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      leading: IconButton(
        icon: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
        onPressed: () => context.pop(),
      ),
    );
  }

  Widget _buildSearchBar() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(FlickoColors.bgTertiary)),
          ),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
            decoration: InputDecoration(
              hintText: 'Search for bots, agents, or tools...',
              hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
              prefixIcon: const Icon(Icons.search, color: Color(FlickoColors.textMuted)),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: TabBar(
          controller: _tabController,
          indicatorColor: const Color(FlickoColors.blurple),
          labelColor: const Color(FlickoColors.textPrimary),
          unselectedLabelColor: const Color(FlickoColors.textMuted),
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'AI Agents'),
            Tab(text: 'Core Bots'),
            Tab(text: 'All Tools'),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid() {
    return SliverPadding(
      padding: const EdgeInsets.all(16),
      sliver: ValueListenableBuilder(
        valueListenable: ValueNotifier(_tabController.index),
        builder: (context, tabIndex, _) {
          List<BotMarketplaceItem> items = [];
          if (_tabController.index == 0) {
            items = BotMarketplaceData.aiSkills;
          } else if (_tabController.index == 1) {
            items = BotMarketplaceData.coreBots;
          } else {
            items = [...BotMarketplaceData.aiSkills, ...BotMarketplaceData.coreBots];
          }

          if (_searchQuery.isNotEmpty) {
            items = items.where((i) => 
              i.name.toLowerCase().contains(_searchQuery) || 
              i.description.toLowerCase().contains(_searchQuery)
            ).toList();
          }

          return SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildBotCard(items[index]),
              childCount: items.length,
            ),
          );
        },
      ),
    );
  }

  Widget _buildBotCard(BotMarketplaceItem item) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(FlickoColors.bgTertiary)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showBotDetails(item),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(FlickoColors.bgTertiary),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Center(
                        child: Text(
                          item.icon,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    if (item.isPremium)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.5)),
                        ),
                        child: Text(
                          'PLUS',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFFD700),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item.name,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  item.category,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.blurple),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: Text(
                    item.description,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 12,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.star, color: Color(0xFFFFD700), size: 12),
                    const SizedBox(width: 2),
                    Text(
                      item.rating.toString(),
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textSecondary),
                        fontSize: 11,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(item.installs / 1000).toStringAsFixed(1)}k',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBotDetails(BotMarketplaceItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(FlickoColors.bgPrimary),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _BotDetailSheet(item: item, serverId: widget.serverId),
    );
  }
}

class _BotDetailSheet extends StatelessWidget {
  final BotMarketplaceItem item;
  final String serverId;

  const _BotDetailSheet({required this.item, required this.serverId});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.bgSecondary),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(item.icon, style: const TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'by ${item.author}',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Description',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            item.description,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 15,
              height: 1.5,
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Installing ${item.name} to server...'),
                    backgroundColor: const Color(FlickoColors.success),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5865F2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Add to Server',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
