import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/server_channels/voice/presentation/widgets/activity_picker.dart';
import 'package:mobile/features/server_channels/voice/presentation/screens/watch_together_screen.dart';
import 'package:mobile/features/server_channels/voice/presentation/controllers/watch_together_controller.dart';

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
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Watch Together Section
        _buildCategorySection('Watch Together', Icons.tv, activities),
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
        if (activity.category == ActivityCategory.watchTogether) {
          _showLaunchWatchTogetherDialog(activity);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Launching ${activity.name}...')),
          );
        }
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

  void _showLaunchWatchTogetherDialog(VoiceActivity activity) {
    final controller = TextEditingController();
    final List<Map<String, String>> presets = activity.name.toLowerCase() == 'youtube'
        ? const [
            {
              'title': 'Flicko Promo (YT)',
              'url': 'https://www.youtube.com/watch?v=aqz-KE-bpKQ'
            },
            {
              'title': 'Flutter Intro (YT)',
              'url': 'https://www.youtube.com/watch?v=fq4N0pxg5_s'
            }
          ]
        : const [
            {
              'title': 'Big Buck Bunny (MP4)',
              'url': 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4'
            },
            {
              'title': 'Sintel Trailer (HLS)',
              'url': 'https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8'
            }
          ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(FlickoColors.bgSecondary),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Launch ${activity.name}',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the video or YouTube URL you want to watch together:',
                style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                style: GoogleFonts.inter(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'https://...',
                  hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                  filled: true,
                  fillColor: const Color(FlickoColors.bgTertiary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'QUICK PRESETS',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: presets.map((preset) {
                  return ActionChip(
                    backgroundColor: const Color(FlickoColors.bgTertiary),
                    side: const BorderSide(color: Color(0xFF222222)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    label: Text(
                      preset['title']!,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.brandLime),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      controller.text = preset['url']!;
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(FlickoColors.blurple),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final url = controller.text.trim();
                if (url.isEmpty) return;

                Navigator.pop(context); // Close dialog

                final kind = activity.name.toLowerCase() == 'youtube' ? 'youtube' : 'mp4';
                
                // Start Session via WatchTogetherController
                await ref.read(watchTogetherControllerProvider.notifier).startSession(
                  roomId: widget.channelId,
                  url: url,
                  title: '${activity.name} Session',
                  kind: kind,
                );

                // Push WatchTogetherScreen
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => WatchTogetherScreen(
                        serverId: widget.serverId,
                        channelId: widget.channelId,
                      ),
                    ),
                  );
                }
              },
              child: Text(
                'Launch',
                style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    );
  }
}
