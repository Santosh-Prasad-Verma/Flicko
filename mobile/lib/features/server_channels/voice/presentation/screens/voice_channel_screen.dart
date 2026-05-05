import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:livekit_client/livekit_client.dart';

import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/collaboration/presentation/shared_whiteboard.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_state.dart' as voice_state;


/// Voice Channel "Studio" screen — black theme with neon green accents.
///
/// Shows participant avatar tiles in a centered grid, floating control
/// pill bar at the bottom, and a collapsible soundboard panel.
class VoiceChannelScreen extends ConsumerStatefulWidget {
  final String serverId;
  final String channelId;

  const VoiceChannelScreen({
    super.key,
    required this.serverId,
    required this.channelId,
  });

  @override
  ConsumerState<VoiceChannelScreen> createState() => _VoiceChannelScreenState();
}

class _VoiceChannelScreenState extends ConsumerState<VoiceChannelScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _channel;
  bool _isLoading = false;
  bool _showWhiteboard = false;
  bool _showSoundboard = false; // ignore: prefer_final_fields

  // ── Design Tokens ──
  static const _bg = Color(0xFF0A0A0A);
  static const _surface = Color(0xFF1A1A1A);
  static const _surfaceLight = Color(0xFF222222);
  static const _neonGreen = Color(0xFFCBEF17);
  static const _border = Color(0xFF2A2A2A);
  static const _textPrimary = Colors.white;
  static const _textDim = Color(0xFF888888);
  static const _red = Color(0xFFFF3B3B);

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await _loadChannel();
    setState(() => _isLoading = false);
  }

  Future<void> _loadChannel() async {
    try {
      final response = await Supabase.instance.client
          .from('channels')
          .select('*')
          .eq('id', widget.channelId)
          .single();
      setState(() => _channel = response);
    } catch (e) {
      // Handle error
    }
  }

  void _handleConnect() {
    ref.read(voiceControllerProvider.notifier).joinChannel(widget.channelId);
  }

  void _handleDisconnect() {
    ref.read(voiceControllerProvider.notifier).leaveChannel();
    Navigator.of(context).pop();
  }

  void _handleToggleMute() {
    ref.read(voiceControllerProvider.notifier).toggleMute();
  }

  void _handleToggleDeafen() {
    ref.read(voiceControllerProvider.notifier).toggleDeafen();
  }

  void _handleToggleVideo() {
    ref.read(voiceControllerProvider.notifier).toggleVideo();
  }

  void _handleToggleScreenShare() {
    ref.read(voiceControllerProvider.notifier).toggleScreenShare();
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceControllerProvider);
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(voiceState),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _neonGreen),
                    )
                  : _showWhiteboard
                      ? SharedWhiteboard(
                          channelId: widget.channelId,
                          currentUserId: ref.read(authNotifierProvider).maybeWhen(
                            authenticated: (user, _) => user.id,
                            orElse: () => '',
                          ),
                          onClose: () => setState(() => _showWhiteboard = false),
                        )
                      : _buildParticipantsArea(voiceState),
            ),
            if (voiceState.isConnected) _buildControlPill(voiceState),
            if (voiceState.isConnected && _showSoundboard) _buildSoundboardPanel(),
            if (!voiceState.isConnected) _buildJoinButton(voiceState),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── HEADER ──
  // ═══════════════════════════════════════════
  Widget _buildHeader(voice_state.VoiceState voiceState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close, color: _textPrimary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _channel?['name']?.toString().toUpperCase() ?? 'THE STUDIO',
              style: GoogleFonts.spaceGrotesk(
                color: _textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              ),
            ),
          ),
          // Server logo / Flicko badge
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _border, width: 1),
              color: _surface,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Image.asset(
                'assets/branding/Flicko-for-black-background.png',
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) =>
                    const Icon(Icons.bolt, color: _neonGreen, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── PARTICIPANTS AREA ──
  // ═══════════════════════════════════════════
  Widget _buildParticipantsArea(voice_state.VoiceState voiceState) {
    if (voiceState.participants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.headphones, size: 48, color: _textDim.withValues(alpha: 0.4)),
            const SizedBox(height: 16),
            Text(
              'Waiting for others to join...',
              style: GoogleFonts.inter(color: _textDim, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Text(
              'Share the invite to get started',
              style: GoogleFonts.inter(
                color: _textDim.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          alignment: WrapAlignment.center,
          runAlignment: WrapAlignment.center,
          children: voiceState.participants.map((participant) {
            final isSpeaking = voiceState.speakingParticipants.contains(participant.sid);
            return _buildParticipantTile(participant, isSpeaking);
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildParticipantTile(Participant participant, bool isSpeaking) {
    final metadata = participant.metadata as Map<String, dynamic>?;
    final displayName = metadata?['username'] ?? participant.identity;
    final avatarUrl = metadata?['avatar_url'] as String?;
    final isMuted = !participant.isMicrophoneEnabled();

    return SizedBox(
      width: 140,
      height: 155,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar card
          Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSpeaking ? _neonGreen : _border,
                width: isSpeaking ? 2 : 1,
              ),
              boxShadow: isSpeaking
                  ? [
                      BoxShadow(
                        color: _neonGreen.withValues(alpha: 0.15),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Stack(
              children: [
                // Avatar / fallback
                Center(
                  child: avatarUrl != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            avatarUrl,
                            width: 128,
                            height: 128,
                            fit: BoxFit.cover,
                            errorBuilder: (c, e, s) => _avatarFallback(displayName),
                          ),
                        )
                      : _avatarFallback(displayName),
                ),
                // Name overlay at bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          _bg.withValues(alpha: 0.85),
                        ],
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(15),
                      ),
                    ),
                    child: Text(
                      displayName.toString().toUpperCase(),
                      style: GoogleFonts.jetBrainsMono(
                        color: _textPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                // Mic status indicator
                Positioned(
                  bottom: 6,
                  right: 6,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isMuted
                          ? _red.withValues(alpha: 0.8)
                          : _neonGreen.withValues(alpha: 0.8),
                    ),
                    child: Icon(
                      isMuted ? Icons.mic_off : Icons.mic,
                      color: isMuted ? _textPrimary : _bg,
                      size: 11,
                    ),
                  ),
                ),
                // Video icon if enabled
                if (participant.isCameraEnabled())
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _bg.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.videocam, color: _neonGreen, size: 12),
                    ),
                  ),
                // Screen share icon if enabled
                if (participant.isScreenShareEnabled())
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: _bg.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.screen_share, color: _neonGreen, size: 12),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatarFallback(dynamic name) {
    final initial = name != null && name.toString().isNotEmpty
        ? name.toString()[0].toUpperCase()
        : '?';
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _surfaceLight,
            border: Border.all(color: _border, width: 1),
          ),
          child: Center(
            child: Text(
              initial,
              style: GoogleFonts.spaceGrotesk(
                color: _textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════
  // ── FLOATING CONTROL PILL ──
  // ═══════════════════════════════════════════
  Widget _buildControlPill(voice_state.VoiceState voiceState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(40),
          border: Border.all(color: _border, width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mic
            _pillButton(
              icon: voiceState.isMuted ? Icons.mic_off : Icons.mic,
              isActive: !voiceState.isMuted,
              activeColor: _neonGreen,
              inactiveColor: _red,
              onTap: _handleToggleMute,
            ),
            // Headphones / Deafen
            _pillButton(
              icon: voiceState.isDeafened ? Icons.headset_off : Icons.headphones,
              isActive: !voiceState.isDeafened,
              activeColor: _neonGreen,
              inactiveColor: _textDim,
              onTap: _handleToggleDeafen,
            ),
            // Video
            _pillButton(
              icon: Icons.videocam,
              isActive: false,
              activeColor: _neonGreen,
              inactiveColor: _neonGreen,
              onTap: _handleToggleVideo,
            ),
            // Screen Share
            _pillButton(
              icon: Icons.screen_share,
              isActive: false,
              activeColor: _neonGreen,
              inactiveColor: _neonGreen,
              onTap: _handleToggleScreenShare,
            ),
            // Disconnect
            GestureDetector(
              onTap: _handleDisconnect,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _red,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.call_end, color: _textPrimary, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pillButton({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required Color inactiveColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _surfaceLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? activeColor.withValues(alpha: 0.3) : _border,
            width: 1,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? activeColor : inactiveColor,
          size: 20,
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── SOUNDBOARD PANEL ──
  // ═══════════════════════════════════════════
  Widget _buildSoundboardPanel() {
    final sounds = [
      {'icon': Icons.front_hand, 'label': 'CLAP'},
      {'icon': Icons.campaign, 'label': 'HORN'},
      {'icon': Icons.music_note, 'label': 'BGM'},
      {'icon': Icons.volume_up, 'label': 'CHEER'},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SOUNDBOARD',
            style: GoogleFonts.spaceGrotesk(
              color: _textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: sounds.map((s) {
              return GestureDetector(
                onTap: () {
                  // TODO: Play sound
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: _surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _border, width: 1),
                      ),
                      child: Icon(
                        s['icon'] as IconData,
                        color: _textDim,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      s['label'] as String,
                      style: GoogleFonts.jetBrainsMono(
                        color: _textDim,
                        fontSize: 8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // ── JOIN BUTTON ──
  // ═══════════════════════════════════════════
  Widget _buildJoinButton(voice_state.VoiceState voiceState) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: GestureDetector(
        onTap: voiceState.isConnecting ? null : _handleConnect,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _neonGreen,
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (voiceState.isConnecting)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0A0A0A)),
                  ),
                )
              else ...[
                const Icon(Icons.call, color: Color(0xFF0A0A0A), size: 20),
                const SizedBox(width: 8),
                Text(
                  'JOIN THE STUDIO',
                  style: GoogleFonts.spaceGrotesk(
                    color: const Color(0xFF0A0A0A),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
