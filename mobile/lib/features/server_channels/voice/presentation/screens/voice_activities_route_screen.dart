import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class VoiceActivitiesRouteScreen extends ConsumerStatefulWidget {
  final String channelId;
  final String serverId;

  const VoiceActivitiesRouteScreen({
    super.key,
    required this.channelId,
    required this.serverId,
  });

  @override
  ConsumerState<VoiceActivitiesRouteScreen> createState() => _VoiceActivitiesRouteScreenState();
}

class _VoiceActivitiesRouteScreenState extends ConsumerState<VoiceActivitiesRouteScreen> {
  bool _showPicker = true;
  String? _currentActivity;

  @override
  void initState() {
    super.initState();
    // Show picker by default
    _showPicker = true;
  }

  void _selectActivity(String activityName) {
    setState(() {
      _currentActivity = activityName;
      _showPicker = false;
    });
  }

  void _closeActivity() {
    setState(() {
      _currentActivity = null;
      _showPicker = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        
        elevation: 0,
        title: Text(
          _currentActivity ?? 'Activities',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _showPicker ? _buildActivityPicker() : _buildActivitySession(),
    );
  }

  Widget _buildActivityPicker() {
    final activities = [
      {'name': 'Watch Together', 'icon': Icons.play_circle_outline, 'color': Colors.red},
      {'name': 'Poker Night', 'icon': Icons.casino, 'color': Colors.purple},
      {'name': 'Fishington', 'icon': Icons.set_meal, 'color': Colors.blue},
      {'name': 'Chess in the Park', 'icon': Icons.extension, 'color': Colors.brown},
      {'name': 'Letter Tile', 'icon': Icons.text_fields, 'color': Colors.orange},
      {'name': 'Word Snacks', 'icon': Icons.restaurant, 'color': Colors.green},
      {'name': 'Doodle Crew', 'icon': Icons.brush, 'color': Colors.pink},
      {'name': 'Spell Cast', 'icon': Icons.auto_fix_high, 'color': Colors.indigo},
    ];

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: activities.length,
      itemBuilder: (context, index) {
        final activity = activities[index];
        return GestureDetector(
          onTap: () => _selectActivity(activity['name'] as String),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  activity['icon'] as IconData,
                  size: 48,
                  color: activity['color'] as Color,
                ),
                const SizedBox(height: 12),
                Text(
                  activity['name'] as String,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActivitySession() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.play_circle_outline,
            size: 64,
            color: const Color(FlickoColors.blurple),
          ),
          const SizedBox(height: 16),
          Text(
            _currentActivity ?? 'Activity',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 24,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Activity session in progress',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _closeActivity,
            icon: const Icon(Icons.close),
            label: const Text('End Activity'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.danger),
            ),
          ),
        ],
      ),
    );
  }
}
