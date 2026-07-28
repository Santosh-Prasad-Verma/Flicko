import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Clean & Simple Stream Settings Bottom Sheet (Discord Dark Theme)
class StreamSettingsSheet extends StatefulWidget {
  final VoidCallback? onStartStreaming;

  const StreamSettingsSheet({
    super.key,
    this.onStartStreaming,
  });

  static void show(BuildContext context, {VoidCallback? onStartStreaming}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1F22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StreamSettingsSheet(onStartStreaming: onStartStreaming),
    );
  }

  @override
  State<StreamSettingsSheet> createState() => _StreamSettingsSheetState();
}

class _StreamSettingsSheetState extends State<StreamSettingsSheet> {
  String _selectedMode = 'Default';
  bool _shareAppAudio = true;

  @override
  Widget build(BuildContext context) {
    const bgCard = Color(0xFF1E1F22);
    const itemBg = Color(0xFF2B2D31);
    const blurple = Color(FlickoColors.blurple);
    const mutedText = Colors.white54;
    const greenStatus = Color(0xFF23A55A);

    return Container(
      decoration: const BoxDecoration(
        color: bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top drag indicator
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title Row: Icon + Title + READY pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.screen_share_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Stream Settings',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: greenStatus.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: greenStatus,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'READY',
                          style: GoogleFonts.inter(
                            color: greenStatus,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Section Header: Stream Quality
              Text(
                'STREAM QUALITY',
                style: GoogleFonts.inter(
                  color: mutedText,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              _buildCleanModeCard(
                title: 'Default',
                subtitle: 'Balanced quality and performance',
                resolutionBadge: '720p 30fps',
                icon: Icons.phone_android_rounded,
                modeKey: 'Default',
                itemBg: itemBg,
                accentColor: blurple,
              ),
              const SizedBox(height: 8),

              _buildCleanModeCard(
                title: 'Performance',
                subtitle: 'Optimised for slower networks & devices',
                resolutionBadge: '480p 30fps',
                icon: Icons.speed_rounded,
                modeKey: 'Performance',
                itemBg: itemBg,
                accentColor: blurple,
              ),
              const SizedBox(height: 8),

              _buildCleanModeCard(
                title: 'High Quality',
                subtitle: 'Crystal clear gaming & video playback',
                resolutionBadge: '1080p 60fps',
                icon: Icons.auto_awesome_rounded,
                modeKey: 'High Quality',
                itemBg: itemBg,
                accentColor: blurple,
                isPro: true,
              ),
              const SizedBox(height: 14),

              // Flicko Plus Pro HD Banner (Subtle Dark Card)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: itemBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white10,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.bolt_rounded, color: blurple, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Flicko Plus HD Streaming',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Unlock 60 FPS & 1080p resolution',
                            style: GoogleFonts.inter(
                              color: mutedText,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push('/premium/plus');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blurple,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: Text(
                        'Get Plus',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section Header: Audio Preferences
              Text(
                'AUDIO PREFERENCES',
                style: GoogleFonts.inter(
                  color: mutedText,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 10),

              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: itemBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.volume_up_rounded, color: Colors.white70, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Share Device & App Audio',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Includes system sound & media playback',
                                  style: GoogleFonts.inter(
                                    color: mutedText,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _shareAppAudio,
                      activeColor: Colors.white,
                      activeTrackColor: blurple,
                      inactiveThumbColor: Colors.white38,
                      inactiveTrackColor: Colors.white10,
                      onChanged: (val) => setState(() => _shareAppAudio = val),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Clean Blurple CTA Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onStartStreaming?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blurple,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(22),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.cast_connected_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Text(
                        'Start Streaming',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
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
    );
  }

  Widget _buildCleanModeCard({
    required String title,
    required String subtitle,
    required String resolutionBadge,
    required IconData icon,
    required String modeKey,
    required Color itemBg,
    required Color accentColor,
    bool isPro = false,
  }) {
    final isSelected = _selectedMode == modeKey;

    return InkWell(
      onTap: () => setState(() => _selectedMode = modeKey),
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: itemBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.05),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected ? accentColor : Colors.white60,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isPro) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.bolt_rounded, color: Colors.amber, size: 14),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                resolutionBadge,
                style: GoogleFonts.inter(
                  color: isSelected ? accentColor : Colors.white60,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? accentColor : Colors.white38,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
