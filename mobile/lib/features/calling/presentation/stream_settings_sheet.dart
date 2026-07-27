import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

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
      backgroundColor: const Color(FlickoColors.bgSecondary),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
    const bgSecondary = Color(FlickoColors.bgSecondary);
    const bgTertiary = Color(FlickoColors.bgTertiary);
    const accentBlurple = Color(FlickoColors.blurple);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: bgSecondary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

                Center(
                  child: Text(
                    'Stream Settings',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Stream Mode',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: bgTertiary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        secondary: const Icon(Icons.phone_android_rounded, color: Colors.white70),
                        title: Text('Default', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text('Balanced quality and performance (720p, 30 fps)', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                        value: 'Default',
                        groupValue: _selectedMode,
                        activeColor: accentBlurple,
                        onChanged: (val) => setState(() => _selectedMode = val!),
                      ),
                      const Divider(height: 1, color: Colors.white10),

                      RadioListTile<String>(
                        secondary: const Icon(Icons.speed_rounded, color: Colors.white70),
                        title: Text('Performance', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text('Optimised for slower devices (480p, 30 fps)', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                        value: 'Performance',
                        groupValue: _selectedMode,
                        activeColor: accentBlurple,
                        onChanged: (val) => setState(() => _selectedMode = val!),
                      ),
                      const Divider(height: 1, color: Colors.white10),

                      RadioListTile<String>(
                        secondary: const Icon(Icons.auto_awesome_rounded, color: Colors.white70),
                        title: Row(
                          children: [
                            Text('High Quality', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 6),
                            const Icon(Icons.bolt_rounded, color: accentBlurple, size: 16),
                          ],
                        ),
                        subtitle: Text('For video and gaming (1080p, 60 fps)', style: GoogleFonts.inter(color: Colors.white38, fontSize: 12)),
                        value: 'High Quality',
                        groupValue: _selectedMode,
                        activeColor: accentBlurple,
                        onChanged: (val) => setState(() => _selectedMode = val!),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: bgTertiary,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: accentBlurple, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Stream in HD resolution with Flicko Plus',
                          style: GoogleFonts.inter(
                            color: accentBlurple,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: accentBlurple,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.bolt_rounded, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              'Get Plus',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  'Stream Audio',
                  style: GoogleFonts.inter(
                    color: Colors.white70,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),

                Container(
                  decoration: BoxDecoration(
                    color: bgTertiary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: SwitchListTile(
                    title: Text('Share App Audio', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                    value: _shareAppAudio,
                    activeColor: accentBlurple,
                    onChanged: (val) => setState(() => _shareAppAudio = val),
                  ),
                ),
                const SizedBox(height: 28),

                GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onStartStreaming?.call();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: accentBlurple,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Center(
                      child: Text(
                        'Start Streaming',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        );
      },
    );
  }
}
