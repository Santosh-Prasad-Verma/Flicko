import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/calling/presentation/stream_settings_sheet.dart';

class VoiceSettingsBottomSheet extends StatefulWidget {
  final bool isMuted;
  final bool isVideoOn;
  final bool isDeafened;
  final ValueChanged<bool>? onMuteChanged;
  final ValueChanged<bool>? onVideoChanged;
  final ValueChanged<bool>? onDeafenChanged;
  final VoidCallback? onEndCall;
  final VoidCallback? onShowChat;
  final VoidCallback? onStartStreaming;
  final VoidCallback? onShowActivities;

  const VoiceSettingsBottomSheet({
    super.key,
    this.isMuted = false,
    this.isVideoOn = false,
    this.isDeafened = false,
    this.onMuteChanged,
    this.onVideoChanged,
    this.onDeafenChanged,
    this.onEndCall,
    this.onShowChat,
    this.onStartStreaming,
    this.onShowActivities,
  });

  static void show(BuildContext context, {
    bool isMuted = false,
    bool isVideoOn = false,
    bool isDeafened = false,
    ValueChanged<bool>? onMuteChanged,
    ValueChanged<bool>? onVideoChanged,
    ValueChanged<bool>? onDeafenChanged,
    VoidCallback? onEndCall,
    VoidCallback? onShowChat,
    VoidCallback? onStartStreaming,
    VoidCallback? onShowActivities,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(FlickoColors.bgSecondary),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => VoiceSettingsBottomSheet(
        isMuted: isMuted,
        isVideoOn: isVideoOn,
        isDeafened: isDeafened,
        onMuteChanged: onMuteChanged,
        onVideoChanged: onVideoChanged,
        onDeafenChanged: onDeafenChanged,
        onEndCall: onEndCall,
        onShowChat: onShowChat,
        onStartStreaming: onStartStreaming,
        onShowActivities: onShowActivities,
      ),
    );
  }

  @override
  State<VoiceSettingsBottomSheet> createState() => _VoiceSettingsBottomSheetState();
}

class _VoiceSettingsBottomSheetState extends State<VoiceSettingsBottomSheet> {
  late bool _isMuted;
  late bool _isVideoOn;
  late bool _isDeafened;
  bool _onlyShowVideos = false;
  bool _showOwnCamera = true;
  String _noiseSuppression = 'Krisp'; // Krisp, Standard, None

  @override
  void initState() {
    super.initState();
    _isMuted = widget.isMuted;
    _isVideoOn = widget.isVideoOn;
    _isDeafened = widget.isDeafened;
  }

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
                // Drag handle
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

                // Top Quick Action Icons Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildTopCircleAction(
                      icon: _isVideoOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                      isActive: _isVideoOn,
                      onTap: () {
                        setState(() => _isVideoOn = !_isVideoOn);
                        widget.onVideoChanged?.call(_isVideoOn);
                      },
                    ),
                    _buildTopCircleAction(
                      icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      isActive: !_isMuted,
                      onTap: () {
                        setState(() => _isMuted = !_isMuted);
                        widget.onMuteChanged?.call(_isMuted);
                      },
                    ),
                    _buildTopCircleAction(
                      icon: Icons.present_to_all_rounded,
                      isActive: false,
                      onTap: () {
                        Navigator.pop(context);
                        StreamSettingsSheet.show(
                          context,
                          onStartStreaming: widget.onStartStreaming,
                        );
                      },
                    ),
                    _buildTopCircleAction(
                      icon: _isDeafened ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                      isActive: !_isDeafened,
                      onTap: () {
                        setState(() => _isDeafened = !_isDeafened);
                        widget.onDeafenChanged?.call(_isDeafened);
                      },
                    ),
                    _buildTopCircleAction(
                      icon: Icons.call_end_rounded,
                      isRed: true,
                      onTap: () {
                        Navigator.pop(context);
                        widget.onEndCall?.call();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Group 1: Activities & Show Chat
                Container(
                  decoration: BoxDecoration(
                    color: bgTertiary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _buildMenuTile(
                        icon: Icons.grid_view_rounded,
                        title: 'Activities',
                        onTap: () {
                          Navigator.pop(context);
                          widget.onShowActivities?.call();
                        },
                      ),
                      const Divider(height: 1, color: Colors.white10),
                      _buildMenuTile(
                        icon: Icons.chat_bubble_outline_rounded,
                        title: 'Show Chat',
                        onTap: () {
                          Navigator.pop(context);
                          widget.onShowChat?.call();
                        },
                      ),
                    ],
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

  Widget _buildTopCircleAction({
    required IconData icon,
    bool isActive = false,
    bool isRed = false,
    required VoidCallback onTap,
  }) {
    const accentBlurple = Color(FlickoColors.blurple);
    const bgTertiary = Color(FlickoColors.bgTertiary);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRed
              ? const Color(FlickoColors.danger)
              : isActive
                  ? accentBlurple.withValues(alpha: 0.18)
                  : bgTertiary,
          border: Border.all(
            color: isActive && !isRed ? accentBlurple : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: isRed ? Colors.white : (isActive ? accentBlurple : Colors.white70),
          size: 22,
        ),
      ),
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70, size: 22),
      title: Text(
        title,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    const accentBlurple = Color(FlickoColors.blurple);
    return SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeColor: accentBlurple,
      secondary: Icon(icon, color: Colors.white70, size: 22),
      title: Text(
        title,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
            )
          : null,
    );
  }

  Widget _buildRadioTile(String title, String subtitle) {
    const accentBlurple = Color(FlickoColors.blurple);
    final isSelected = _noiseSuppression == title;
    return RadioListTile<String>(
      value: title,
      groupValue: _noiseSuppression,
      activeColor: accentBlurple,
      onChanged: (v) {
        if (v != null) setState(() => _noiseSuppression = v);
      },
      title: Text(
        title,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
      ),
    );
  }
}
