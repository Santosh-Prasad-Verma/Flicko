import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';

/// Screen Share Viewer Widget
///
/// Displays a participant's shared screen with controls.
/// Mirrors the React Native ScreenShareViewer component.
class ScreenShareViewer extends StatelessWidget {
  final String sharerId;
  final String sharerName;
  final String? sharerAvatar;
  final bool isLive;
  final VoidCallback? onStop;
  final VoidCallback? onFullscreen;
  final VoidCallback? onMinimize;

  const ScreenShareViewer({
    super.key,
    required this.sharerId,
    required this.sharerName,
    this.sharerAvatar,
    this.isLive = true,
    this.onStop,
    this.onFullscreen,
    this.onMinimize,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Screen share area
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Screen content placeholder
                Container(
                  color: const Color(FlickoColors.bgSecondary),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.desktop_windows,
                          size: 64,
                          color: Color(FlickoColors.textMuted),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Screen sharing active',
                          style: TextStyle(
                            color: Color(FlickoColors.textMuted),
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // LIVE indicator
                if (isLive)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'LIVE',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Sharer info overlay
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        UserAvatar(
                          imageUrl: sharerAvatar,
                          size: 24,
                          status: 'online',
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$sharerName\'s screen',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Controls
                Positioned(
                  top: 12,
                  right: 12,
                  child: Row(
                    children: [
                      if (onFullscreen != null)
                        _buildControlButton(
                          icon: Icons.fullscreen,
                          onTap: onFullscreen!,
                        ),
                      if (onMinimize != null)
                        _buildControlButton(
                          icon: Icons.close_fullscreen,
                          onTap: onMinimize!,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom controls bar
          if (onStop != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(8)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: onStop,
                    icon: const Icon(Icons.stop_screen_share),
                    label: const Text('Stop Sharing'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.black54,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          icon,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }
}

/// Go Live Modal
///
/// Modal for starting a live stream (Go Live) in a voice channel.
/// Similar to Discord's Go Live feature.
class GoLiveModal extends StatefulWidget {
  final String channelId;
  final String serverId;
  final Function(String source) onGoLive;

  const GoLiveModal({
    super.key,
    required this.channelId,
    required this.serverId,
    required this.onGoLive,
  });

  @override
  State<GoLiveModal> createState() => _GoLiveModalState();
}

class _GoLiveModalState extends State<GoLiveModal> {
  String _selectedSource = 'screen';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.5,
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
                    'Go Live',
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

          const Divider(color: Color(FlickoColors.bgTertiary), height: 1),

          // Source selection
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Choose what to share',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textSecondary),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),

                // Screen option
                _buildSourceOption(
                  id: 'screen',
                  icon: Icons.desktop_windows,
                  title: 'Your Screen',
                  subtitle: 'Share your entire screen',
                ),

                const SizedBox(height: 12),

                // Application option
                _buildSourceOption(
                  id: 'application',
                  icon: Icons.apps,
                  title: 'Application Window',
                  subtitle: 'Share a specific application',
                ),

                const SizedBox(height: 24),

                // Quality settings
                Text(
                  'Stream Quality',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textSecondary),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _buildQualityInfo(),
              ],
            ),
          ),

          // Go Live button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : () {
                  setState(() => _isLoading = true);
                  widget.onGoLive(_selectedSource);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(FlickoColors.danger),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.videocam, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Go Live',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceOption({
    required String id,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final isSelected = _selectedSource == id;

    return GestureDetector(
      onTap: () => setState(() => _selectedSource = id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(FlickoColors.blurple).withOpacity(0.2)
              : const Color(FlickoColors.bgTertiary),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(FlickoColors.blurple)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(FlickoColors.blurple)
                    : const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : const Color(FlickoColors.textMuted),
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(FlickoColors.blurple),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgTertiary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: Color(FlickoColors.textMuted),
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '720p at 30fps • H.264 encoding',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Extensions for showing modals
extension VoiceVideoExtensions on BuildContext {
  void showScreenShareViewer({
    required String sharerId,
    required String sharerName,
    String? sharerAvatar,
    VoidCallback? onStop,
  }) {
    showDialog(
      context: this,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.6,
          child: ScreenShareViewer(
            sharerId: sharerId,
            sharerName: sharerName,
            sharerAvatar: sharerAvatar,
            onStop: onStop,
            onFullscreen: () {},
            onMinimize: () => Navigator.pop(context),
          ),
        ),
      ),
    );
  }

  void showGoLiveModal({
    required String channelId,
    required String serverId,
    required Function(String source) onGoLive,
  }) {
    showModalBottomSheet(
      context: this,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => GoLiveModal(
        channelId: channelId,
        serverId: serverId,
        onGoLive: onGoLive,
      ),
    );
  }
}
