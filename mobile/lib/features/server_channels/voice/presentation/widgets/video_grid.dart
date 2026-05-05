import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';

/// Video Grid Widget
///
/// Discord-style video grid layout for voice/video calls.
/// Supports multiple layouts: grid, spotlight, and screen share.
class VideoGrid extends StatelessWidget {
  final List<VideoParticipant> participants;
  final VideoLayout layout;
  final String? focusedId;
  final Function(String id) onParticipantTap;
  final Function(String id) onParticipantLongPress;

  const VideoGrid({
    super.key,
    required this.participants,
    this.layout = VideoLayout.grid,
    this.focusedId,
    required this.onParticipantTap,
    required this.onParticipantLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final videoParticipants = participants.where((p) => p.hasVideo).toList();
    final screenShareParticipant = participants.firstWhere(
      (p) => p.isScreenSharing,
      orElse: () => VideoParticipant(id: '', name: ''),
    );
    final hasScreenShare = screenShareParticipant.id.isNotEmpty;

    // Spotlight layout (focused participant)
    if (layout == VideoLayout.spotlight && focusedId != null) {
      return _buildSpotlightLayout(focusedId!, hasScreenShare);
    }

    // Screen share layout
    if (hasScreenShare) {
      return _buildScreenShareLayout(screenShareParticipant);
    }

    // Grid layout (default)
    return _buildGridLayout(videoParticipants);
  }

  Widget _buildSpotlightLayout(String focusedId, bool hasScreenShare) {
    final focusedParticipant = participants.firstWhere(
      (p) => p.id == focusedId,
      orElse: () => participants.first,
    );
    final otherParticipants = participants.where((p) => p.id != focusedId).toList();

    return Column(
      children: [
        // Main spotlight video
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.all(4),
            child: VideoTile(
              participant: focusedParticipant,
              size: VideoTileSize.large,
              isSpeaking: focusedParticipant.isSpeaking,
              isSpotlight: true,
              onTap: () => onParticipantTap(focusedParticipant.id),
              onLongPress: () => onParticipantLongPress(focusedParticipant.id),
            ),
          ),
        ),

        // Other participants strip
        if (otherParticipants.isNotEmpty)
          Container(
            height: 100,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: otherParticipants.length,
              itemBuilder: (context, index) {
                final p = otherParticipants[index];
                return Container(
                  width: 140,
                  margin: const EdgeInsets.only(right: 4),
                  child: VideoTile(
                    participant: p,
                    size: VideoTileSize.small,
                    isSpeaking: p.isSpeaking,
                    onTap: () => onParticipantTap(p.id),
                    onLongPress: () => onParticipantLongPress(p.id),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildScreenShareLayout(VideoParticipant screenShareParticipant) {
    final otherParticipants = participants
        .where((p) => p.id != screenShareParticipant.id)
        .toList();

    return Row(
      children: [
        // Main screen share area
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Screen share content placeholder
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    color: Colors.black,
                    child: const Center(
                      child: Icon(
                        Icons.screen_share,
                        size: 64,
                        color: Colors.white54,
                      ),
                    ),
                  ),
                ),

                // Screen sharer info overlay
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.screen_share,
                          size: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${screenShareParticipant.displayName}\'s screen',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Sidebar with other participants
        Container(
          width: 120,
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: ListView.builder(
            itemCount: otherParticipants.length,
            itemBuilder: (context, index) {
              final p = otherParticipants[index];
              return Container(
                height: 80,
                margin: const EdgeInsets.only(bottom: 4, right: 4),
                child: VideoTile(
                  participant: p,
                  size: VideoTileSize.small,
                  isSpeaking: p.isSpeaking,
                  onTap: () => onParticipantTap(p.id),
                  onLongPress: () => onParticipantLongPress(p.id),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGridLayout(List<VideoParticipant> videoParticipants) {
    // Calculate grid layout
    final count = videoParticipants.length;
    final gridConfig = _calculateGridLayout(count);

    return Container(
      padding: const EdgeInsets.all(4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        children: videoParticipants.map((p) {
          return SizedBox(
            width: gridConfig.cellWidth,
            height: gridConfig.cellHeight,
            child: VideoTile(
              participant: p,
              size: gridConfig.tileSize,
              isSpeaking: p.isSpeaking,
              onTap: () => onParticipantTap(p.id),
              onLongPress: () => onParticipantLongPress(p.id),
            ),
          );
        }).toList(),
      ),
    );
  }

  GridLayoutConfig _calculateGridLayout(int count) {
    const gap = 4.0;
    final screenSize = MediaQueryData.fromView(WidgetsBinding.instance.window);
    final availableWidth = screenSize.size.width - gap * 2;
    final availableHeight = screenSize.size.height - 200;

    int columns;
    VideoTileSize tileSize;

    if (count <= 1) {
      columns = 1;
      tileSize = VideoTileSize.large;
    } else if (count <= 4) {
      columns = 2;
      tileSize = VideoTileSize.medium;
    } else if (count <= 9) {
      columns = 3;
      tileSize = VideoTileSize.small;
    } else if (count <= 16) {
      columns = 4;
      tileSize = VideoTileSize.small;
    } else {
      columns = 5;
      tileSize = VideoTileSize.small;
    }

    final rows = (count / columns).ceil();
    final cellWidth = (availableWidth / columns) - gap;
    final cellHeight = ((availableHeight / rows) - gap).clamp(
      cellWidth * 0.5,
      cellWidth * 0.75,
    );

    return GridLayoutConfig(
      columns: columns,
      rows: rows,
      cellWidth: cellWidth,
      cellHeight: cellHeight,
      gap: gap,
      tileSize: tileSize,
    );
  }
}

/// Grid layout configuration
class GridLayoutConfig {
  final int columns;
  final int rows;
  final double cellWidth;
  final double cellHeight;
  final double gap;
  final VideoTileSize tileSize;

  GridLayoutConfig({
    required this.columns,
    required this.rows,
    required this.cellWidth,
    required this.cellHeight,
    required this.gap,
    required this.tileSize,
  });
}

/// Video layout types
enum VideoLayout {
  grid,
  spotlight,
}

/// Video Participant Model
class VideoParticipant {
  final String id;
  final String name;
  String? displayName;
  String? avatarUrl;
  bool hasVideo;
  bool hasAudio;
  bool isSpeaking;
  bool isScreenSharing;
  bool isPinned;

  VideoParticipant({
    required this.id,
    required this.name,
    this.displayName,
    this.avatarUrl,
    this.hasVideo = true,
    this.hasAudio = true,
    this.isSpeaking = false,
    this.isScreenSharing = false,
    this.isPinned = false,
  });

  String get effectiveName => displayName ?? name;
}

/// Video Tile Widget
class VideoTile extends StatelessWidget {
  final VideoParticipant participant;
  final VideoTileSize size;
  final bool isSpeaking;
  final bool isSpotlight;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const VideoTile({
    super.key,
    required this.participant,
    required this.size,
    this.isSpeaking = false,
    this.isSpotlight = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgSecondary),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSpeaking
                ? const Color(FlickoColors.green)
                : Colors.transparent,
            width: isSpeaking ? 3 : 0,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video or avatar placeholder
              participant.hasVideo
                  ? _buildVideoPlaceholder()
                  : _buildAvatarPlaceholder(),

              // Bottom gradient overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: size == VideoTileSize.small ? 30 : 40,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withOpacity(0.7),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // Name and status
              Positioned(
                bottom: size == VideoTileSize.small ? 4 : 8,
                left: size == VideoTileSize.small ? 4 : 8,
                right: size == VideoTileSize.small ? 4 : 8,
                child: Row(
                  children: [
                    // Speaking indicator
                    if (isSpeaking)
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(right: 4),
                        decoration: const BoxDecoration(
                          color: Color(FlickoColors.green),
                          shape: BoxShape.circle,
                        ),
                      ),

                    // Name
                    Expanded(
                      child: Text(
                        participant.effectiveName,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: size == VideoTileSize.small ? 10 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Muted indicator
                    if (!participant.hasAudio)
                      Icon(
                        Icons.mic_off,
                        size: size == VideoTileSize.small ? 12 : 16,
                        color: Colors.red,
                      ),
                  ],
                ),
              ),

              // Pinned indicator
              if (participant.isPinned)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.push_pin,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVideoPlaceholder() {
    return Container(
      color: Colors.black87,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.videocam,
              size: size == VideoTileSize.small ? 24 : 40,
              color: Colors.white54,
            ),
            const SizedBox(height: 8),
            Text(
              'Video',
              style: GoogleFonts.inter(
                color: Colors.white54,
                fontSize: size == VideoTileSize.small ? 10 : 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarPlaceholder() {
    return Container(
      color: const Color(FlickoColors.bgTertiary),
      child: Center(
        child: UserAvatar(
          imageUrl: participant.avatarUrl,
          size: size == VideoTileSize.small ? 40 : size == VideoTileSize.medium ? 60 : 80,
          status: 'offline',
        ),
      ),
    );
  }
}

/// Video tile size options
enum VideoTileSize {
  small,
  medium,
  large,
}

/// Video Grid Controls
class VideoGridControls extends StatelessWidget {
  final VideoLayout currentLayout;
  final bool isScreenSharing;
  final Function(VideoLayout) onLayoutChange;
  final VoidCallback onToggleScreenShare;
  final VoidCallback onEndCall;

  const VideoGridControls({
    super.key,
    required this.currentLayout,
    required this.isScreenSharing,
    required this.onLayoutChange,
    required this.onToggleScreenShare,
    required this.onEndCall,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Layout toggle
            _buildControlButton(
              icon: currentLayout == VideoLayout.grid
                  ? Icons.grid_view
                  : Icons.fullscreen,
              label: currentLayout == VideoLayout.grid ? 'Grid' : 'Spotlight',
              onTap: () => onLayoutChange(
                currentLayout == VideoLayout.grid
                    ? VideoLayout.spotlight
                    : VideoLayout.grid,
              ),
            ),

            // Screen share
            _buildControlButton(
              icon: isScreenSharing ? Icons.stop_screen_share : Icons.screen_share,
              label: isScreenSharing ? 'Stop' : 'Share',
              isActive: isScreenSharing,
              onTap: onToggleScreenShare,
            ),

            // Camera
            _buildControlButton(
              icon: Icons.videocam,
              label: 'Camera',
              onTap: () {},
            ),

            // Microphone
            _buildControlButton(
              icon: Icons.mic,
              label: 'Mic',
              onTap: () {},
            ),

            // End call
            _buildControlButton(
              icon: Icons.call_end,
              label: 'End',
              isDestructive: true,
              onTap: onEndCall,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    bool isActive = false,
    bool isDestructive = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDestructive
                  ? Colors.red
                  : isActive
                      ? const Color(FlickoColors.blurple)
                      : const Color(FlickoColors.bgTertiary),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isDestructive || isActive ? Colors.white : const Color(FlickoColors.textSecondary),
              size: 24,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
