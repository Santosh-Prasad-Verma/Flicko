import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/server_channels/voice/presentation/widgets/activity_picker.dart';

/// Voice Activities Screen
///
/// Full-screen activity browser for voice channels.
/// Shows available activities grouped by category with search and launch.
/// Route: /server/:serverId/channel/:channelId/activities
class VoiceActivitiesScreen extends ConsumerStatefulWidget {
  final String serverId;
  final String channelId;

  const VoiceActivitiesScreen({
    super.key,
    required this.serverId,
    required this.channelId,
  });

  @override
  ConsumerState<VoiceActivitiesScreen> createState() => _VoiceActivitiesScreenState();
}

class _VoiceActivitiesScreenState extends ConsumerState<VoiceActivitiesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Activities',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _buildActivityGrid(),
    );
  }

  Widget _buildActivityGrid() {
    // Use the same activities from ActivityPicker
    final activities = [
      // Games
      VoiceActivity(
        id: '1',
        name: 'Chess in the Park',
        category: ActivityCategory.games,
        description: 'Play chess with friends',
        maxPlayers: 2,
      ),
      VoiceActivity(
        id: '2',
        name: 'Poker Night',
        category: ActivityCategory.games,
        description: "Texas Hold'em poker",
        maxPlayers: 8,
      ),
      VoiceActivity(
        id: '3',
        name: 'Sketch Heads',
        category: ActivityCategory.games,
        description: 'Draw and guess game',
        maxPlayers: 8,
      ),
      VoiceActivity(
        id: '4',
        name: 'Blazing 8s',
        category: ActivityCategory.games,
        description: 'Card matching game',
        maxPlayers: 8,
      ),
      VoiceActivity(
        id: '5',
        name: 'Letter League',
        category: ActivityCategory.games,
        description: 'Word puzzle game',
        maxPlayers: 6,
      ),
      // Watch Together
      VoiceActivity(
        id: '6',
        name: 'YouTube',
        category: ActivityCategory.watchTogether,
        description: 'Watch YouTube videos together',
        maxPlayers: 10,
      ),
      VoiceActivity(
        id: '7',
        name: 'Watch Together',
        category: ActivityCategory.watchTogether,
        description: 'Stream content together',
        maxPlayers: 50,
      ),
      // Premium
      VoiceActivity(
        id: '8',
        name: 'Putt Party',
        category: ActivityCategory.premium,
        description: 'Mini golf game',
        maxPlayers: 8,
        isPremium: true,
      ),
      VoiceActivity(
        id: '9',
        name: 'Bobble League',
        category: ActivityCategory.premium,
        description: 'Soccer strategy game',
        maxPlayers: 8,
        isPremium: true,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Games Section
        _buildCategorySection('Games', Icons.videogame_asset, activities.where((a) => a.category == ActivityCategory.games).toList()),
        const SizedBox(height: 24),

        // Watch Together Section
        _buildCategorySection('Watch Together', Icons.tv, activities.where((a) => a.category == ActivityCategory.watchTogether).toList()),
        const SizedBox(height: 24),

        // Premium Section
        _buildCategorySection('Premium', Icons.diamond, activities.where((a) => a.category == ActivityCategory.premium).toList()),
      ],
    );
  }

  Widget _buildCategorySection(String title, IconData icon, List<VoiceActivity> activities) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: const Color(FlickoColors.blurple)),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: activities.length,
          itemBuilder: (context, index) => _buildActivityCard(activities[index]),
        ),
      ],
    );
  }

  Widget _buildActivityCard(VoiceActivity activity) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Launching ${activity.name}...')),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgSecondary),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF232428)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon area
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Color(FlickoColors.bgTertiary),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(FlickoColors.blurple).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.videogame_asset,
                        size: 32,
                        color: Color(FlickoColors.blurple),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Info
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
                        const Icon(Icons.diamond, size: 14, color: Color(FlickoColors.fuchsia)),
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
                      const Icon(Icons.people, size: 12, color: Color(FlickoColors.textMuted)),
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
}
