import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Activity Picker Widget
///
/// Discord-style activity picker for voice channels.
/// Shows available activities grouped by category (Games, Watch Together, Premium)
/// with search and launch functionality.
class ActivityPicker extends StatefulWidget {
  final String channelId;
  final String serverId;
  final Function(VoiceActivity) onActivityLaunch;

  const ActivityPicker({
    super.key,
    required this.channelId,
    required this.serverId,
    required this.onActivityLaunch,
  });

  @override
  State<ActivityPicker> createState() => _ActivityPickerState();
}

class _ActivityPickerState extends State<ActivityPicker> {
  final TextEditingController _searchController = TextEditingController();
  ActivityCategory _selectedCategory = ActivityCategory.games;
  final bool _isLoading = false;
  String? _error;

  // Activity categories with icons
  final List<ActivityCategoryData> _categories = [
    ActivityCategoryData(
      category: ActivityCategory.games,
      label: 'Games',
      icon: Icons.gamepad,
    ),
    ActivityCategoryData(
      category: ActivityCategory.watchTogether,
      label: 'Watch',
      icon: Icons.tv,
    ),
    ActivityCategoryData(
      category: ActivityCategory.premium,
      label: 'Premium',
      icon: Icons.diamond,
    ),
  ];

  // Mock activities (in production, fetch from API)
  final List<VoiceActivity> _activities = [
    // Games
    VoiceActivity(
      id: '1',
      name: 'Chess in the Park',
      category: ActivityCategory.games,
      description: 'Play chess with friends',
      maxPlayers: 2,
      iconUrl: null,
    ),
    VoiceActivity(
      id: '2',
      name: 'Poker Night',
      category: ActivityCategory.games,
      description: 'Texas Hold\'em poker',
      maxPlayers: 8,
      iconUrl: null,
    ),
    VoiceActivity(
      id: '3',
      name: 'Sketch Heads',
      category: ActivityCategory.games,
      description: 'Draw and guess game',
      maxPlayers: 8,
      iconUrl: null,
    ),
    VoiceActivity(
      id: '4',
      name: 'Blazing 8s',
      category: ActivityCategory.games,
      description: 'Card matching game',
      maxPlayers: 8,
      iconUrl: null,
    ),
    VoiceActivity(
      id: '5',
      name: 'Letter League',
      category: ActivityCategory.games,
      description: 'Word puzzle game',
      maxPlayers: 6,
      iconUrl: null,
    ),

    // Watch Together
    VoiceActivity(
      id: '6',
      name: 'YouTube',
      category: ActivityCategory.watchTogether,
      description: 'Watch YouTube videos together',
      maxPlayers: 10,
      iconUrl: null,
    ),
    VoiceActivity(
      id: '7',
      name: 'Watch Together',
      category: ActivityCategory.watchTogether,
      description: 'Stream content together',
      maxPlayers: 50,
      iconUrl: null,
    ),

    // Premium
    VoiceActivity(
      id: '8',
      name: 'Putt Party',
      category: ActivityCategory.premium,
      description: 'Mini golf game',
      maxPlayers: 8,
      iconUrl: null,
      isPremium: true,
    ),
    VoiceActivity(
      id: '9',
      name: 'Bobble League',
      category: ActivityCategory.premium,
      description: 'Soccer strategy game',
      maxPlayers: 8,
      iconUrl: null,
      isPremium: true,
    ),
  ];

  List<VoiceActivity> get _filteredActivities {
    List<VoiceActivity> filtered = _activities
        .where((a) => a.category == _selectedCategory)
        .toList();

    // Filter by search query
    if (_searchController.text.isNotEmpty) {
      final query = _searchController.text.toLowerCase();
      filtered = filtered.where((a) =>
        a.name.toLowerCase().contains(query) ||
        (a.description?.toLowerCase().contains(query) ?? false)
      ).toList();
    }

    return filtered;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 8),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(FlickoColors.textMuted),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Activities',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(FlickoColors.textMuted)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
              decoration: InputDecoration(
                hintText: 'Search activities...',
                hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                prefixIcon: const Icon(Icons.search, color: Color(FlickoColors.textMuted)),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: Color(FlickoColors.textMuted)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(FlickoColors.bgTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Category tabs
          _buildCategoryTabs(),

          const Divider(color: Color(FlickoColors.bgTertiary), height: 1),

          // Activity grid
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _buildError()
                    : _buildActivityGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _categories.map((catData) {
          final isSelected = _selectedCategory == catData.category;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedCategory = catData.category),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(FlickoColors.blurple)
                      : const Color(FlickoColors.bgTertiary),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(FlickoColors.blurple)
                        : const Color(FlickoColors.bgTertiary),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      catData.icon,
                      size: 18,
                      color: isSelected
                          ? Colors.white
                          : const Color(FlickoColors.textMuted),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      catData.label,
                      style: GoogleFonts.inter(
                        color: isSelected
                            ? Colors.white
                            : const Color(FlickoColors.textMuted),
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 48,
            color: Color(FlickoColors.textMuted),
          ),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityGrid() {
    final activities = _filteredActivities;

    if (activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              size: 48,
              color: Color(FlickoColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              'No activities found',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return _buildActivityCard(activity);
      },
    );
  }

  Widget _buildActivityCard(VoiceActivity activity) {
    return GestureDetector(
      onTap: () {
        widget.onActivityLaunch(activity);
        Navigator.pop(context);
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgTertiary),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(FlickoColors.bgTertiary),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Activity icon/thumbnail
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.bgSecondary),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(FlickoColors.blurple).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        _getActivityIcon(activity.category),
                        size: 32,
                        color: const Color(FlickoColors.blurple),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Activity info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          activity.name,
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textPrimary),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (activity.isPremium)
                        const Icon(
                          Icons.diamond,
                          size: 14,
                          color: Color(FlickoColors.fuchsia),
                        ),
                    ],
                  ),
                  if (activity.description != null)
                    Text(
                      activity.description!,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 11,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.people,
                        size: 12,
                        color: Color(FlickoColors.textMuted),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Up to ${activity.maxPlayers}',
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
          ],
        ),
      ),
    );
  }

  IconData _getActivityIcon(ActivityCategory category) {
    switch (category) {
      case ActivityCategory.games:
        return Icons.videogame_asset;
      case ActivityCategory.watchTogether:
        return Icons.tv;
      case ActivityCategory.premium:
        return Icons.diamond;
    }
  }
}

/// Activity category data
class ActivityCategoryData {
  final ActivityCategory category;
  final String label;
  final IconData icon;

  ActivityCategoryData({
    required this.category,
    required this.label,
    required this.icon,
  });
}

/// Voice Activity Model
class VoiceActivity {
  final String id;
  final String name;
  final ActivityCategory category;
  final String? description;
  final int maxPlayers;
  final String? iconUrl;
  final bool isPremium;

  VoiceActivity({
    required this.id,
    required this.name,
    required this.category,
    this.description,
    required this.maxPlayers,
    this.iconUrl,
    this.isPremium = false,
  });
}

/// Activity categories
enum ActivityCategory {
  games,
  watchTogether,
  premium,
}

/// Extension to show ActivityPicker
extension ActivityPickerExtension on BuildContext {
  void showActivityPicker({
    required String channelId,
    required String serverId,
    required Function(VoiceActivity) onActivityLaunch,
  }) {
    showModalBottomSheet(
      context: this,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => ActivityPicker(
        channelId: channelId,
        serverId: serverId,
        onActivityLaunch: onActivityLaunch,
      ),
    );
  }
}
