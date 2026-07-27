import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/calling/presentation/voice_settings_bottom_sheet.dart';
import 'package:mobile/features/calling/presentation/invite_friends_bottom_sheet.dart';
import 'package:mobile/features/calling/presentation/stream_settings_sheet.dart';
import 'package:mobile/features/calling/presentation/floating_call_pip_overlay.dart';
import 'package:mobile/features/server_channels/voice/presentation/widgets/voice_channel_chat_sheet.dart';

class FlickoCallScreen extends StatefulWidget {
  final String title;
  final String peerName;
  final String? peerAvatarUrl;
  final bool isVideoCall;
  final bool isGroupCall;
  final VoidCallback? onEndCall;

  const FlickoCallScreen({
    super.key,
    this.title = 'Voice Call',
    required this.peerName,
    this.peerAvatarUrl,
    this.isVideoCall = false,
    this.isGroupCall = false,
    this.onEndCall,
  });

  @override
  State<FlickoCallScreen> createState() => _FlickoCallScreenState();
}

class _FlickoCallScreenState extends State<FlickoCallScreen> {
  bool _isMuted = false;
  bool _isVideoOn = false;
  bool _isSpeaker = true;
  bool _isDeafened = false;

  @override
  void initState() {
    super.initState();
    _isVideoOn = widget.isVideoCall;
  }

  void _minimizeToPip() {
    FloatingCallPipOverlay.show(
      context,
      userName: widget.peerName,
      avatarUrl: widget.peerAvatarUrl,
      isSpeaking: true,
      onTapExpand: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => FlickoCallScreen(
              title: widget.title,
              peerName: widget.peerName,
              peerAvatarUrl: widget.peerAvatarUrl,
              isVideoCall: _isVideoOn,
              isGroupCall: widget.isGroupCall,
              onEndCall: widget.onEndCall,
            ),
          ),
        );
      },
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const bgPrimary = Color(FlickoColors.bgPrimary);

    return Scaffold(
      backgroundColor: bgPrimary,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Top Header Bar
                _buildHeaderBar(),

                // Main Call Content / Participant Cards
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        // Participant Card 1 (Local / Remote Participant)
                        _buildParticipantCard(
                          name: widget.peerName.isNotEmpty ? widget.peerName : 'Tarun_ OP',
                          avatarUrl: widget.peerAvatarUrl,
                          isSpeaking: true,
                          bgColor: const Color(FlickoColors.bgSecondary),
                        ),
                        const SizedBox(height: 12),

                        // Waiting / Secondary Participant Banner Card
                        _buildWaitingCard(),
                        const SizedBox(height: 14),

                        // Add People to Voice Chat Tile
                        _buildAddPeopleTile(),
                        const SizedBox(height: 80), // Padding for floating bottom bar
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Bottom Floating Action Control Pill
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _buildBottomControlPill(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBar() {
    const accentBlurple = Color(FlickoColors.blurple);
    const voiceGreen = Color(0xFF43B581);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 28),
            onPressed: _minimizeToPip,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    widget.title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: voiceGreen.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircleAvatar(
                        radius: 3,
                        backgroundColor: voiceGreen,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Connected',
                        style: GoogleFonts.inter(
                          color: voiceGreen,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Speaker / Audio settings
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: accentBlurple,
              ),
              child: const Icon(Icons.volume_up_rounded, color: Colors.white, size: 20),
            ),
            onPressed: () {
              VoiceSettingsBottomSheet.show(
                context,
                isMuted: _isMuted,
                isVideoOn: _isVideoOn,
                isDeafened: _isDeafened,
                onMuteChanged: (v) => setState(() => _isMuted = v),
                onVideoChanged: (v) => setState(() => _isVideoOn = v),
                onDeafenChanged: (v) => setState(() => _isDeafened = v),
                onEndCall: widget.onEndCall,
              );
            },
          ),
          // Add Member / Invite icon
          IconButton(
            icon: const Icon(Icons.person_add_rounded, color: Colors.white, size: 22),
            onPressed: () => InviteFriendsBottomSheet.show(context),
          ),
          // Chat bubble icon
          IconButton(
            icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 22),
            onPressed: () => VoiceChannelChatSheet.show(context, channelName: widget.title),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantCard({
    required String name,
    String? avatarUrl,
    bool isSpeaking = false,
    Color bgColor = const Color(FlickoColors.bgSecondary),
  }) {
    const brandGreen = Color(FlickoColors.brandLime);
    const bgTertiary = Color(FlickoColors.bgTertiary);

    return Container(
      width: double.infinity,
      height: 320,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: bgTertiary, width: 1.5),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Avatar Circle with Glowing Speaking Ring
          Container(
            width: 108,
            height: 108,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isSpeaking ? brandGreen : Colors.transparent,
                width: 3.5,
              ),
              boxShadow: isSpeaking
                  ? [
                      BoxShadow(
                        color: brandGreen.withValues(alpha: 0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: CircleAvatar(
              radius: 48,
              backgroundColor: bgTertiary,
              backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
              child: avatarUrl == null || avatarUrl.isEmpty
                  ? const Icon(Icons.face_rounded, size: 48, color: Colors.white70)
                  : null,
            ),
          ),

          // Bottom Floating Nameplate Pill
          Positioned(
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: bgTertiary, width: 1),
              ),
              child: Text(
                name,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingCard() {
    const bgSecondary = Color(FlickoColors.bgSecondary);
    const bgTertiary = Color(FlickoColors.bgTertiary);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bgSecondary,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: bgTertiary, width: 1.5),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: bgTertiary,
                child: Icon(Icons.face_rounded, size: 32, color: Colors.white70),
              ),
              const SizedBox(width: 8),
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.white10,
                child: Icon(Icons.person_rounded, size: 32, color: Colors.white.withValues(alpha: 0.3)),
              ),
            ],
          ),
          const SizedBox(height: 24),

          Text(
            "You're alone in this call.",
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${widget.peerName} can still join at any time while you are here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildAddPeopleTile() {
    const bgSecondary = Color(FlickoColors.bgSecondary);
    const bgTertiary = Color(FlickoColors.bgTertiary);

    return GestureDetector(
      onTap: () => InviteFriendsBottomSheet.show(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgSecondary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: bgTertiary, width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_add_rounded, color: Color(FlickoColors.brandLime), size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add people to Voice Chat',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Let the group know you are here!',
                    style: GoogleFonts.inter(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControlPill() {
    const bgSecondary = Color(FlickoColors.bgSecondary);
    const bgTertiary = Color(FlickoColors.bgTertiary);

    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity! < -100) {
          VoiceSettingsBottomSheet.show(
            context,
            isMuted: _isMuted,
            isVideoOn: _isVideoOn,
            isDeafened: _isDeafened,
            onMuteChanged: (v) => setState(() => _isMuted = v),
            onVideoChanged: (v) => setState(() => _isVideoOn = v),
            onDeafenChanged: (v) => setState(() => _isDeafened = v),
            onEndCall: widget.onEndCall,
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: bgSecondary,
          borderRadius: BorderRadius.circular(36),
          border: Border.all(color: bgTertiary, width: 1.5),
          boxShadow: const [
            BoxShadow(
              color: Colors.black87,
              blurRadius: 20,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 4,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPillBtn(
                  icon: _isVideoOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
                  isActive: _isVideoOn,
                  onTap: () => setState(() => _isVideoOn = !_isVideoOn),
                ),
                _buildPillBtn(
                  icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
                  isActive: !_isMuted,
                  onTap: () => setState(() => _isMuted = !_isMuted),
                ),
                _buildPillBtn(
                  icon: Icons.present_to_all_rounded,
                  isActive: false,
                  onTap: () => StreamSettingsSheet.show(context),
                ),
                _buildPillBtn(
                  icon: _isDeafened ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                  isActive: _isSpeaker,
                  onTap: () {
                    setState(() => _isSpeaker = !_isSpeaker);
                    VoiceSettingsBottomSheet.show(
                      context,
                      isMuted: _isMuted,
                      isVideoOn: _isVideoOn,
                      isDeafened: _isDeafened,
                      onMuteChanged: (v) => setState(() => _isMuted = v),
                      onVideoChanged: (v) => setState(() => _isVideoOn = v),
                      onDeafenChanged: (v) => setState(() => _isDeafened = v),
                      onEndCall: widget.onEndCall,
                    );
                  },
                ),
                _buildPillBtn(
                  icon: Icons.call_end_rounded,
                  isRed: true,
                  onTap: () {
                    FloatingCallPipOverlay.hide();
                    widget.onEndCall?.call();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillBtn({
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
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRed
              ? const Color(FlickoColors.danger)
              : isActive
                  ? accentBlurple.withValues(alpha: 0.25)
                  : bgTertiary,
          border: Border.all(
            color: isActive && !isRed ? accentBlurple : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          color: isRed ? Colors.white : (isActive ? accentBlurple : Colors.white54),
          size: 22,
        ),
      ),
    );
  }
}
