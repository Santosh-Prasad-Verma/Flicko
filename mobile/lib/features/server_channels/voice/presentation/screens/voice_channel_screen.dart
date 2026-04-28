import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/collaboration/presentation/shared_whiteboard.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_state.dart' as voice_state;
import 'package:mobile/features/voice/presentation/soundboard_sheet.dart';

// Removed legacy VoiceParticipant model


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

class _VoiceChannelScreenState extends ConsumerState<VoiceChannelScreen> {
  Map<String, dynamic>? _channel;
  bool _isLoading = false;
  bool _showWhiteboard = false;



  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _loadChannel(),
      _loadParticipants(),
    ]);
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

  Future<void> _loadParticipants() async {
    // Participants are now handled by VoiceController
  }

  Color _getStatusColor(String state) {
    switch (state) {
      case 'connected':
        return const Color(FlickoColors.success);
      case 'connecting':
      case 'reconnecting':
        return const Color(FlickoColors.warning);
      case 'failed':
        return const Color(FlickoColors.danger);
      default:
        return const Color(FlickoColors.textMuted);
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


  void _handleActivities() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(FlickoColors.bgSecondary),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Text(
                  'Activities',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Divider(color: Color(FlickoColors.border), height: 1),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.blurple).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.brush, color: Color(FlickoColors.blurple)),
                ),
                title: Text('Whiteboard', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
                subtitle: Text('Draw together in real-time', style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 13)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _showWhiteboard = true);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.success).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note, color: Color(FlickoColors.success)),
                ),
                title: Text('Soundboard', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w500)),
                subtitle: Text('Play sounds for the channel', style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 13)),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => SoundboardSheet(serverId: widget.serverId),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceControllerProvider);
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(voiceState),
            Expanded(

              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(FlickoColors.blurple),
                      ),
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
                      : _buildParticipantsGrid(voiceState),
            ),
            _buildControls(voiceState),
          ],

        ),
      ),
    );
  }

  Widget _buildHeader(voice_state.VoiceState voiceState) {
    final isConnected = voiceState.isConnected;
    final connectionLabel = voiceState.isConnecting 
        ? 'Connecting...' 
        : isConnected ? 'Connected' : 'Not connected';

    return Container(

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        border: Border(
          bottom: BorderSide(color: Color(FlickoColors.border), width: 1),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.volume_up, color: Color(FlickoColors.textMuted), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _channel?['name'] ?? 'Voice Channel',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  isConnected ? connectionLabel : 'Not connected',
                  style: GoogleFonts.inter(
                    color: _getStatusColor(isConnected ? 'connected' : 'disconnected'),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              const Icon(Icons.people, color: Color(FlickoColors.textMuted), size: 16),
              const SizedBox(width: 4),
              Text(
                '${voiceState.participants.length}',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantsGrid(voice_state.VoiceState voiceState) {
    if (voiceState.participants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.volume_up_outlined,
              size: 48,
              color: Color(FlickoColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              'No one is in this voice channel',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: voiceState.participants.length,
      itemBuilder: (context, index) => _buildParticipantCard(
        voiceState.participants[index],
        voiceState.speakingParticipants.contains(voiceState.participants[index].sid),
      ),
    );
  }

  Widget _buildParticipantCard(Participant participant, bool isSpeaking) {
    final metadata = participant.metadata as Map<String, dynamic>?;
    final displayName = metadata?['username'] ?? participant.identity;
    final avatarUrl = metadata?['avatar_url'] as String?;

    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.bgTertiary),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSpeaking
                        ? const Color(FlickoColors.success)
                        : Colors.transparent,
                    width: 3,
                  ),
                ),
                child: avatarUrl != null
                    ? ClipOval(
                        child: Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Text(
                              displayName[0].toUpperCase(),
                              style: GoogleFonts.inter(
                                color: const Color(FlickoColors.textPrimary),
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          displayName[0].toUpperCase(),
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textPrimary),
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
              if (isSpeaking)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Color(FlickoColors.success),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            displayName,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!participant.isMicrophoneEnabled())
                const Icon(Icons.mic_off, size: 14, color: Color(FlickoColors.danger)),
              const SizedBox(width: 4),
              if (participant.isCameraEnabled())
                const Icon(Icons.videocam, size: 14, color: Color(FlickoColors.success)),
              const SizedBox(width: 4),
              if (participant.isScreenShareEnabled())
                const Icon(Icons.desktop_windows, size: 14, color: Color(FlickoColors.blurple)),
            ],
          ),
        ],
      ),
    );
  }


  Widget _buildControls(voice_state.VoiceState voiceState) {

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        border: Border(
          top: BorderSide(color: Color(FlickoColors.border), width: 1),
        ),
      ),
      child: voiceState.isConnected ? _buildConnectedControls(voiceState) : _buildJoinButton(voiceState),
    );
  }

  Widget _buildJoinButton(voice_state.VoiceState voiceState) {
    return GestureDetector(
      onTap: voiceState.isConnecting ? null : _handleConnect,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.success),
          borderRadius: BorderRadius.circular(24),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            else ...[
              const Icon(Icons.call, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Join Voice',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedControls(voice_state.VoiceState voiceState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildControlButton(
          icon: voiceState.isMuted ? Icons.mic_off : Icons.mic,
          backgroundColor: voiceState.isMuted
              ? const Color(FlickoColors.danger)
              : const Color(FlickoColors.bgTertiary),
          onTap: _handleToggleMute,
        ),
        _buildControlButton(
          icon: voiceState.isDeafened ? Icons.volume_off : Icons.volume_up,
          backgroundColor: voiceState.isDeafened
              ? const Color(FlickoColors.danger)
              : const Color(FlickoColors.bgTertiary),
          onTap: _handleToggleDeafen,
        ),
        _buildControlButton(
          icon: Icons.videocam_outlined,
          backgroundColor: const Color(FlickoColors.bgTertiary),
          onTap: _handleToggleVideo,
        ),
        _buildControlButton(
          icon: Icons.desktop_windows,
          backgroundColor: const Color(FlickoColors.bgTertiary),
          onTap: _handleToggleScreenShare,
        ),
        _buildControlButton(
          icon: Icons.sports_esports,
          backgroundColor: const Color(FlickoColors.bgTertiary),
          onTap: _handleActivities,
        ),
        _buildControlButton(
          icon: Icons.call_end,
          backgroundColor: const Color(FlickoColors.danger),
          onTap: _handleDisconnect,
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }
}
