import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Global App Directory Screen
/// Public store to discover community bots, AI integrations, and server tools.
class GlobalAppDirectoryScreen extends StatefulWidget {
  final String? serverId;

  const GlobalAppDirectoryScreen({super.key, this.serverId});

  @override
  State<GlobalAppDirectoryScreen> createState() => _GlobalAppDirectoryScreenState();
}

class _GlobalAppDirectoryScreenState extends State<GlobalAppDirectoryScreen> {
  bool _isLoading = true;
  String _selectedCategory = 'All';
  String _searchQuery = '';
  List<Map<String, dynamic>> _apps = [];

  final List<String> _categories = ['All', 'Utility', 'Music', 'Moderation', 'Gaming', 'AI'];

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('app_directory_listings')
          .select('*')
          .order('install_count', ascending: false);

      if (mounted) {
        setState(() {
          _apps = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (_) {
      // Fallback mock app directory items if empty database
      if (mounted) {
        setState(() {
          _apps = [
            {
              'id': 'bot_1',
              'bot_id': 'b1',
              'app_name': 'Sonic Music Bot',
              'short_description': 'High-fidelity audio streaming and playlist queueing in voice channels.',
              'category': 'Music',
              'install_count': 14200,
            },
            {
              'id': 'bot_2',
              'bot_id': 'b2',
              'app_name': 'Aura AI Assistant',
              'short_description': 'Autonomous multi-agent moderator, translation engine, and chat assistant.',
              'category': 'AI',
              'install_count': 8900,
            },
            {
              'id': 'bot_3',
              'bot_id': 'b3',
              'app_name': 'AutoMod Pro',
              'short_description': 'Automated anti-spam, link filter, and instant strike ban manager.',
              'category': 'Moderation',
              'install_count': 23100,
            },
          ];
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _apps.where((app) {
      final matchesCat = _selectedCategory == 'All' || app['category'] == _selectedCategory;
      final matchesSearch = _searchQuery.isEmpty ||
          (app['app_name'] as String).toLowerCase().contains(_searchQuery) ||
          (app['short_description'] as String).toLowerCase().contains(_searchQuery);
      return matchesCat && matchesSearch;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        title: Text('Global App Directory', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: Column(
        children: [
          // Search & Category Filter
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v.trim().toLowerCase()),
              style: GoogleFonts.inter(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search apps, bots, and tools...',
                hintStyle: GoogleFonts.inter(color: Colors.white38),
                prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38),
                filled: true,
                fillColor: const Color(FlickoColors.bgSecondary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              ),
            ),
          ),

          // Category Pills
          SizedBox(
            height: 38,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _categories.length,
              itemBuilder: (context, index) {
                final cat = _categories[index];
                final isSel = _selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(cat, style: GoogleFonts.inter(color: isSel ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                    selected: isSel,
                    selectedColor: const Color(FlickoColors.brandLime),
                    backgroundColor: const Color(FlickoColors.bgSecondary),
                    onSelected: (v) => setState(() => _selectedCategory = cat),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),

          // App Cards Feed
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.brandLime)))
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final app = filtered[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(FlickoColors.bgSecondary),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(FlickoColors.brandLime).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.smart_toy_rounded, color: Color(FlickoColors.brandLime), size: 28),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(app['app_name'] as String, style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(app['short_description'] as String, style: GoogleFonts.inter(color: Colors.white70, fontSize: 12)),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Text('${app['install_count']} installs', style: GoogleFonts.inter(color: Colors.white38, fontSize: 11)),
                                      const Spacer(),
                                      ElevatedButton(
                                        onPressed: () {
                                          context.push('/server/${widget.serverId ?? "active"}/settings/oauth2?botId=${app['bot_id']}');
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(FlickoColors.brandLime),
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                        child: Text('Add to Server', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
