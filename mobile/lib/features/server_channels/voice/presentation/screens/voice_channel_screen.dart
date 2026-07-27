
import 'dart:math' show pi, sin, cos;
import 'dart:ui' show ImageFilter;
import 'dart:developer' as developer;
import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:go_router/go_router.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/collaboration/presentation/shared_whiteboard.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_state.dart' as voice_state;
import 'package:mobile/features/voice/presentation/soundboard_sheet.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/calling/presentation/voice_settings_bottom_sheet.dart';
import 'package:mobile/features/calling/presentation/invite_friends_bottom_sheet.dart';
import 'package:mobile/features/calling/presentation/floating_call_pip_overlay.dart';
import 'package:mobile/features/calling/presentation/stream_settings_sheet.dart';
import 'package:mobile/features/server_channels/voice/presentation/widgets/voice_channel_chat_sheet.dart';

/// Premium Glassmorphic Voice/Video Channel Screen
/// Features shifting radial orb backgrounds, frosted glass participant cards,
/// pulsing speaker halos, live video rendering, and a floating glass control bar.
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
    with TickerProviderStateMixin {
  Map<String, dynamic>? _channel;
  bool _isLoading = false;
  bool _showWhiteboard = false;
  bool _isWhiteboardActiveRemotely = false;
  bool _isScreenShareMinimized = false;
  String? _whiteboardHostId;
  RealtimeChannel? _whiteboardStatusChannel;
  
  // ── Lazy Profile Cache ─────────────────────────────────────────────────────
  final Map<String, Map<String, dynamic>> _profilesCache = {};
  final Set<String> _fetchingProfileIds = {};

  void _fetchProfile(String userId) async {
    if (_profilesCache.containsKey(userId) || _fetchingProfileIds.contains(userId)) {
      return;
    }
    _fetchingProfileIds.add(userId);
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('username, display_name, avatar')
          .eq('id', userId)
          .maybeSingle();
      if (profile != null) {
        if (mounted) {
          setState(() {
            _profilesCache[userId] = profile;
          });
        }
      }
    } catch (e) {
      developer.log('Error fetching user profile', name: 'VoiceChannelScreen', error: e);
    } finally {
      _fetchingProfileIds.remove(userId);
    }
  }

  // ── Theme Colors ──────────────────────────────────────────────────────────
  static const Color _bgBlack = Color(0xFF060608);
  static const Color _neonGreen = Color(0xFF52B788);
  static const Color _neonCyan = Color(0xFF00E5FF);
  static const Color _red = Color(0xFFFF3B3B);
  static const Color _white = Colors.white;

  // ── Animation Controllers ─────────────────────────────────────────────────
  late AnimationController _orbController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _loadData();

    // Slowly drifting orb background
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    // Pulsing speaker halo + breathing animations
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _setupWhiteboardStatusChannel();
  }

  @override
  void dispose() {
    if (_showWhiteboard && !_isWhiteboardActiveRemotely) {
      final currentUserId = ref.read(authNotifierProvider).maybeWhen(
            authenticated: (user, _) => user.id,
            orElse: () => '',
          );
      try {
        _whiteboardStatusChannel?.sendBroadcastMessage(
          event: 'status',
          payload: {
            'active': false,
            'userId': currentUserId,
          },
        );
      } catch (_) {}
    }
    _whiteboardStatusChannel?.unsubscribe();
    _orbController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _setupWhiteboardStatusChannel() {
    final currentUserId = ref.read(authNotifierProvider).maybeWhen(
          authenticated: (user, _) => user.id,
          orElse: () => '',
        );

    _whiteboardStatusChannel = Supabase.instance.client.channel(
      'whiteboard_status:${widget.channelId}',
    );

    _whiteboardStatusChannel!
      ..onBroadcast(
        event: 'status',
        callback: (payload) {
          if (!mounted) return;
          final data = payload['payload'] as Map<String, dynamic>;
          final hostId = data['userId'] as String?;
          if (hostId == currentUserId) return;

          final isActive = data['active'] as bool? ?? false;
          setState(() {
            if (isActive) {
              if (!_showWhiteboard) {
                _isWhiteboardActiveRemotely = true;
                _whiteboardHostId = hostId;
              }
            } else {
              if (hostId == _whiteboardHostId) {
                _isWhiteboardActiveRemotely = false;
                _whiteboardHostId = null;
                _showWhiteboard = false;
              }
            }
          });
        },
      )
      ..onBroadcast(
        event: 'request_status',
        callback: (payload) {
          if (!mounted) return;
          final data = payload['payload'] as Map<String, dynamic>;
          final senderId = data['userId'] as String?;
          if (senderId == currentUserId) return;

          if (_showWhiteboard) {
            _whiteboardStatusChannel?.sendBroadcastMessage(
              event: 'status',
              payload: {
                'active': true,
                'userId': currentUserId,
              },
            );
          }
        },
      )
      ..subscribe((status, [error]) {
        if (status == RealtimeSubscribeStatus.subscribed) {
          _whiteboardStatusChannel?.sendBroadcastMessage(
            event: 'request_status',
            payload: {
              'userId': currentUserId,
            },
          );
        }
      });
  }

  void _toggleWhiteboard(bool show) {
    setState(() {
      _showWhiteboard = show;
      if (show) {
        _isWhiteboardActiveRemotely = false;
      }
    });

    final currentUserId = ref.read(authNotifierProvider).maybeWhen(
          authenticated: (user, _) => user.id,
          orElse: () => '',
        );

    _whiteboardStatusChannel?.sendBroadcastMessage(
      event: 'status',
      payload: {
        'active': show,
        'userId': currentUserId,
      },
    );
  }

  Widget _buildWhiteboardBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: _neonCyan.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _neonCyan.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _neonCyan.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.brush_rounded,
                    color: _neonCyan,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Active Whiteboard',
                        style: GoogleFonts.outfit(
                          color: _white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'A shared canvas session has started.',
                        style: GoogleFonts.inter(
                          color: _white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _showWhiteboard = true;
                      _isWhiteboardActiveRemotely = false;
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _neonCyan,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Text(
                    'Join',
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Data Loading ──────────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    await Future.wait([_loadChannel(), _loadParticipants()]);
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
    } catch (_) {}
  }

  Future<void> _loadParticipants() async {
    // Participants are now driven by VoiceController
  }

  // ── Voice Control Handlers ────────────────────────────────────────────────
  void _handleConnect() {
    ref
        .read(voiceControllerProvider.notifier)
        .joinChannel(widget.channelId, widget.serverId);
  }

  void _handleDisconnect() {
    ref.read(voiceControllerProvider.notifier).leaveChannel();
    Navigator.of(context).pop();
  }

  void _handleToggleMute() =>
      ref.read(voiceControllerProvider.notifier).toggleMute();
  void _handleToggleDeafen() =>
      ref.read(voiceControllerProvider.notifier).toggleDeafen();
  void _handleToggleVideo() =>
      ref.read(voiceControllerProvider.notifier).toggleVideo();
  void _handleToggleScreenShare() async {
    try {
      await ref.read(voiceControllerProvider.notifier).toggleScreenShare();
    } catch (e) {
      debugPrint('Screen share toggle exception: $e');
    }
  }

  void _handleActivities() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.45),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                  color: _white.withValues(alpha: 0.08), width: 1),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: _white.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 8.0),
                      child: Text(
                        'Activities',
                        style: GoogleFonts.outfit(
                          color: _white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Divider(
                        color: _white.withValues(alpha: 0.06), height: 1),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _neonCyan.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.brush, color: _neonCyan),
                      ),
                      title: Text('Whiteboard',
                          style: GoogleFonts.inter(
                              color: _white, fontWeight: FontWeight.w500)),
                      subtitle: Text('Draw together in real-time',
                          style: GoogleFonts.inter(
                              color: _white.withValues(alpha: 0.45),
                              fontSize: 13)),
                      onTap: () {
                        Navigator.pop(context);
                        _toggleWhiteboard(true);
                      },
                    ),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: _neonGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child:
                            const Icon(Icons.music_note, color: _neonGreen),
                      ),
                      title: Text('Soundboard',
                          style: GoogleFonts.inter(
                              color: _white, fontWeight: FontWeight.w500)),
                      subtitle: Text('Play sounds for the channel',
                          style: GoogleFonts.inter(
                              color: _white.withValues(alpha: 0.45),
                              fontSize: 13)),
                      onTap: () {
                        Navigator.pop(context);
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) =>
                              SoundboardSheet(serverId: widget.serverId),
                        );
                      },
                    ),
                    ListTile(
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.movie_creation_outlined, color: Colors.purpleAccent),
                      ),
                      title: Text('Watch Together & Games',
                          style: GoogleFonts.inter(
                              color: _white, fontWeight: FontWeight.w500)),
                      subtitle: Text('Co-watch videos and play games',
                          style: GoogleFonts.inter(
                              color: _white.withValues(alpha: 0.45),
                              fontSize: 13)),
                      onTap: () {
                        Navigator.pop(context);
                        context.push(
                            '/server/${widget.serverId}/channel/${widget.channelId}/activities');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceControllerProvider);

    return Scaffold(
      backgroundColor: _bgBlack,
      body: Stack(
        children: [
          // ── Layer 1: Shifting radial orb background ──
          Positioned.fill(child: _buildOrbBackground()),

          // ── Layer 2: Frosted overlay ──
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: _bgBlack.withValues(alpha: 0.35)),
            ),
          ),

          // ── Layer 3: Content ──
          Positioned.fill(
            child: SafeArea(
              child: Column(
                children: [
                  _buildGlassHeader(voiceState),
                  if (voiceState.error != null) _buildErrorBanner(voiceState),
                  if (_isWhiteboardActiveRemotely) _buildWhiteboardBanner(),
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: _neonGreen,
                              strokeWidth: 2,
                            ),
                          )
                        : _showWhiteboard
                            ? SharedWhiteboard(
                                channelId: widget.channelId,
                                currentUserId: ref
                                    .read(authNotifierProvider)
                                    .maybeWhen(
                                      authenticated: (user, _) => user.id,
                                      orElse: () => '',
                                    ),
                                onClose: () => _toggleWhiteboard(false),
                              )
                            : _buildParticipantsGrid(voiceState),
                  ),
                  _buildAddPeopleTile(),
                  _buildFloatingGlassControls(voiceState),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  SHIFTING RADIAL ORB BACKGROUND
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildOrbBackground() {
    return AnimatedBuilder(
      animation: _orbController,
      builder: (context, child) {
        final t = _orbController.value;
        return CustomPaint(
          painter: _OrbBackgroundPainter(t),
          size: Size.infinite,
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FROSTED GLASS HEADER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildGlassHeader(voice_state.VoiceState voiceState) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.transparent,
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 26),
            onPressed: () {
              FloatingCallPipOverlay.show(
                context,
                userName: _channel?['name'] ?? 'Voice Channel',
                isSpeaking: true,
                onTapExpand: () {
                  context.push('/server/${widget.serverId}/channel/${widget.channelId}/voice');
                },
              );
              Navigator.of(context).pop();
            },
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    _channel?['name'] ?? 'General',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 18),
              ],
            ),
          ),
          // Speaker Audio Mode Button (White Pill Circle)
          GestureDetector(
            onTap: () {
              VoiceSettingsBottomSheet.show(
                context,
                isMuted: voiceState.isMuted,
                isVideoOn: voiceState.room?.localParticipant?.isCameraEnabled() ?? false,
                isDeafened: voiceState.isDeafened,
                onMuteChanged: (_) => _handleToggleMute(),
                onVideoChanged: (_) => _handleToggleVideo(),
                onDeafenChanged: (_) => _handleToggleDeafen(),
                onStartStreaming: () => _handleToggleScreenShare(),
                onShowActivities: _handleActivities,
                onShowChat: () => VoiceChannelChatSheet.show(
                  context,
                  channelName: _channel?['name'] ?? 'Voice Channel',
                ),
                onEndCall: _handleDisconnect,
              );
            },
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volume_up_rounded, color: Colors.black, size: 18),
            ),
          ),
          const SizedBox(width: 6),
          // View Members Button
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.group_rounded, color: Colors.white, size: 20),
            onPressed: () => _showMembersBottomSheet(context, voiceState),
          ),
          const SizedBox(width: 8),
          // Chat Button
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: const Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 20),
            onPressed: () => VoiceChannelChatSheet.show(
              context,
              channelName: _channel?['name'] ?? 'Voice Channel',
            ),
          ),
        ],
      ),
    );
  }

  void _showMembersBottomSheet(BuildContext context, voice_state.VoiceState voiceState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Color(FlickoColors.bgSecondary),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: Color(FlickoColors.bgSecondary),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Channel Members (${voiceState.participants.length})',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    InviteFriendsBottomSheet.show(context);
                  },
                  icon: Icon(Icons.person_add_rounded, color: Color(FlickoColors.brandLime), size: 18),
                  label: Text(
                    'Invite',
                    style: GoogleFonts.inter(
                      color: Color(FlickoColors.brandLime),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (voiceState.participants.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'No members in channel',
                    style: GoogleFonts.inter(color: Colors.white54),
                  ),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.45,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: voiceState.participants.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
                  itemBuilder: (context, index) {
                    final p = voiceState.participants[index];
                    final profile = _profilesCache[p.sid];
                    final name = profile?['display_name'] ?? profile?['username'] ?? p.identity ?? 'Member ${index + 1}';
                    final avatar = profile?['avatar'];
                      final currentVol = voiceState.participantVolumes[p.sid] ?? 1.0;
                    return Container(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: p.isSpeaking ? Color(FlickoColors.brandLime) : Colors.transparent,
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Color(FlickoColors.bgTertiary),
                                backgroundImage: (avatar != null && (avatar.startsWith('http://') || avatar.startsWith('https://'))) ? NetworkImage(avatar) : null,
                                child: (avatar == null || (!avatar.startsWith('http://') && !avatar.startsWith('https://'))) ? const Icon(Icons.person, color: Colors.white70) : null,
                              ),
                            ),
                            title: Text(
                              name,
                              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              p.isSpeaking ? 'Speaking' : (p.isMuted ? 'Muted' : 'Connected'),
                              style: GoogleFonts.inter(
                                color: p.isSpeaking ? Color(FlickoColors.brandLime) : Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (p.isMuted)
                                  const Icon(Icons.mic_off_rounded, color: Colors.redAccent, size: 18)
                                else
                                  Icon(Icons.mic_rounded, color: Color(FlickoColors.brandLime), size: 18),
                              ],
                            ),
                          ),
                          // Per-User Volume Control Slider (0% - 200%)
                          Padding(
                            padding: const EdgeInsets.only(left: 48, right: 8, bottom: 4),
                            child: Row(
                              children: [
                                const Icon(Icons.volume_down_rounded, color: Colors.white38, size: 16),
                                Expanded(
                                  child: SliderTheme(
                                    data: const SliderThemeData(
                                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 6),
                                      overlayShape: RoundSliderOverlayShape(overlayRadius: 10),
                                      trackHeight: 3,
                                    ),
                                    child: Slider(
                                      value: currentVol,
                                      min: 0.0,
                                      max: 2.0,
                                      activeColor: Color(FlickoColors.brandLime),
                                      inactiveColor: Colors.white12,
                                      onChanged: (val) {
                                        ref.read(voiceControllerProvider.notifier).setParticipantVolume(p.sid, val);
                                      },
                                    ),
                                  ),
                                ),
                                Text(
                                  '${(currentVol * 100).toInt()}%',
                                  style: GoogleFonts.spaceMono(
                                    color: Color(FlickoColors.brandLime),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  ERROR BANNER
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildErrorBanner(voice_state.VoiceState voiceState) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: _red.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: _red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              voiceState.error!,
              style: GoogleFonts.inter(color: _red, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullScreenVideo(VideoTrack track, String displayName) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black.withValues(alpha: 0.5),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: Text(
              displayName,
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 16),
            ),
          ),
          body: Center(
            child: InteractiveViewer(
              maxScale: 4.0,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: VideoTrackRenderer(
                  track,
                  fit: VideoViewFit.contain,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildParticipantsGrid(voice_state.VoiceState voiceState) {
    if (voiceState.participants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + 0.08 * sin(_pulseController.value * 2 * pi);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _neonGreen.withValues(alpha: 0.06),
                      border: Border.all(
                          color: _neonGreen.withValues(alpha: 0.15), width: 2),
                    ),
                    child: Icon(Icons.volume_up_rounded,
                        size: 36, color: _neonGreen.withValues(alpha: 0.5)),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'No one is here yet',
              style: GoogleFonts.outfit(
                color: _white.withValues(alpha: 0.5),
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Join to start the conversation',
              style: GoogleFonts.inter(
                color: _white.withValues(alpha: 0.25),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    final mainContent = GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.85,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: voiceState.participants.length,
      itemBuilder: (context, index) {
        final p = voiceState.participants[index];
        return _buildGlassParticipantCard(
          p,
          voiceState.speakingParticipants.contains(p.sid),
          ignoreScreenShare: true,
        );
      },
    );

    // Find screen share participant
    Participant? screenSharingParticipant;
    VideoTrack? screenShareTrack;
    for (final p in voiceState.participants) {
      final pubs = p.videoTrackPublications.where((pub) => pub.track != null && pub.isScreenShare).toList();
      if (pubs.isNotEmpty) {
        screenSharingParticipant = p;
        screenShareTrack = pubs.first.track as VideoTrack?;
        break;
      }
    }

    if (screenSharingParticipant != null && screenShareTrack != null) {
      final userId = screenSharingParticipant.identity;
      _fetchProfile(userId);
      final cachedProfile = _profilesCache[userId];
      final displayName = cachedProfile?['display_name'] as String? ?? 
                          cachedProfile?['username'] as String? ?? 
                          (screenSharingParticipant.name.isNotEmpty ? screenSharingParticipant.name : 'User');

      return Column(
        children: [
          // Pinned Screen Share Card (Collapsible & Fullscreenable)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: _isScreenShareMinimized ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              firstChild: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      VideoTrackRenderer(
                        screenShareTrack,
                        fit: VideoViewFit.contain,
                      ),
                      // Tap overlay detector
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showFullScreenVideo(screenShareTrack!, '$displayName\'s Screen'),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                      // "LIVE" Badge
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFED4245),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFED4245).withValues(alpha: 0.4),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'LIVE',
                                style: GoogleFonts.spaceGrotesk(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Minimize Button (Top Right)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: GestureDetector(
                          onTap: () => setState(() => _isScreenShareMinimized = true),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                      // Bottom Banner Overlay with Fullscreen Button
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.8),
                              ],
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '$displayName is sharing screen',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 22),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _showFullScreenVideo(screenShareTrack!, '$displayName\'s Screen'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              secondChild: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFED4245).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFED4245).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFED4245),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'LIVE',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$displayName\'s Screen Share',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white, size: 22),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => setState(() => _isScreenShareMinimized = false),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _showFullScreenVideo(screenShareTrack!, '$displayName\'s Screen'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Scrollable Grid of remaining participants
          Expanded(
            child: mainContent,
          ),
        ],
      );
    }

    return mainContent;
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  PARTICIPANT CARD (MATCHING SCREENSHOT)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildGlassParticipantCard(Participant participant, bool isSpeaking, {bool ignoreScreenShare = false}) {
    final userId = participant.identity;
    _fetchProfile(userId);

    final cachedProfile = _profilesCache[userId];
    final String displayName = cachedProfile?['display_name'] as String? ?? 
                               cachedProfile?['username'] as String? ?? 
                               (participant.name.isNotEmpty ? participant.name : 'User');
    final String? avatarUrl = cachedProfile?['avatar'] as String?;

    // Detect if participant has an active screen share track
    final screenShareTrack = participant.videoTrackPublications
        .where((pub) => pub.track != null && pub.isScreenShare)
        .toList();
    final hasScreenShare = !ignoreScreenShare && screenShareTrack.isNotEmpty;

    // Detect if participant has an active video track
    final videoTrack = participant.videoTrackPublications
        .where((pub) => pub.track != null && !pub.isScreenShare)
        .toList();
    final hasVideo = videoTrack.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: isSpeaking
              ? const Color(0xFF9E6479)
              : const Color(0xFF8A5A6D),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: isSpeaking
                ? _neonGreen
                : Colors.transparent,
            width: isSpeaking ? 2 : 0,
          ),
          boxShadow: isSpeaking
              ? [
                  BoxShadow(
                    color: _neonGreen.withValues(alpha: 0.3),
                    blurRadius: 18,
                    spreadRadius: 2,
                  )
                ]
              : [],
        ),
        child: hasScreenShare
            ? _buildVideoView(screenShareTrack.first.track as VideoTrack,
                participant, '$displayName (Screen)', isSpeaking, isScreenShare: true)
            : hasVideo
                ? _buildVideoView(videoTrack.first.track as VideoTrack,
                    participant, displayName, isSpeaking)
                : _buildAvatarView(
                    displayName, avatarUrl, participant, isSpeaking),
      ),
    );
  }

  /// Renders the live video stream inside the card
  Widget _buildVideoView(VideoTrack track, Participant participant,
      String displayName, bool isSpeaking, {bool isScreenShare = false}) {
    return GestureDetector(
      onTap: () => _showFullScreenVideo(track, '$displayName\'s ${isScreenShare ? 'Screen' : 'Camera'}'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: VideoTrackRenderer(
              track,
              fit: isScreenShare ? VideoViewFit.contain : VideoViewFit.cover,
            ),
          ),
        // Red "LIVE" badge for screen sharing
        if (isScreenShare)
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFED4245),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'LIVE',
                    style: GoogleFonts.spaceGrotesk(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
          ),
        // Bottom name overlay pill
        Positioned(
          left: 0,
          right: 0,
          bottom: 12,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.inter(
                      color: _white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(width: 4),
                  _buildStatusIcons(participant),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
    );
  }

  /// Renders the avatar-based view (matching screenshot)
  Widget _buildAvatarView(String displayName, String? avatarUrl,
      Participant participant, bool isSpeaking) {
    return Stack(
      children: [
        // Centered Avatar
        Center(
          child: AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              final pulseVal = sin(_pulseController.value * 2 * pi);
              final outerScale = isSpeaking ? 1.0 + 0.05 * pulseVal : 1.0;

              return Transform.scale(
                scale: outerScale,
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black12,
                    border: Border.all(
                      color: isSpeaking ? _neonGreen : Colors.white24,
                      width: isSpeaking ? 3 : 1.5,
                    ),
                  ),
                  child: UserAvatar(
                    imageUrl: avatarUrl,
                    name: displayName,
                    size: 84,
                    userId: participant.identity,
                    showStatus: false,
                    showBadge: false,
                  ),
                ),
              );
            },
          ),
        ),
        // Bottom Name Tag Pill (matching screenshot)
        Positioned(
          bottom: 14,
          left: 0,
          right: 0,
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayName,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  _buildStatusIcons(participant),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIcons(Participant participant) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!participant.isMicrophoneEnabled())
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(Icons.mic_off_rounded,
                size: 14, color: _red.withValues(alpha: 0.8)),
          ),
        if (participant.isCameraEnabled())
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(Icons.videocam_rounded,
                size: 14, color: _neonGreen.withValues(alpha: 0.8)),
          ),
        if (participant.isScreenShareEnabled())
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(Icons.desktop_windows_rounded,
                size: 14, color: _neonCyan.withValues(alpha: 0.8)),
          ),
      ],
    );
  }

  Widget _buildAddPeopleTile() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: GestureDetector(
        onTap: () => InviteFriendsBottomSheet.show(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1F22).withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
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
                child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add people to Voice Chat',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
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
              const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 22),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  //  FLOATING CONTROL BAR (MATCHING SCREENSHOT)
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildFloatingGlassControls(voice_state.VoiceState voiceState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1F22),
          borderRadius: BorderRadius.circular(36),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 20,
              spreadRadius: 2,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Drag Handle indicator (matching screenshot)
            Center(
              child: Container(
                width: 32,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            voiceState.isConnected
                ? _buildConnectedGlassControls(voiceState)
                : _buildGlassJoinButton(voiceState),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedGlassControls(voice_state.VoiceState voiceState) {
    final isScreenSharing = voiceState.room?.localParticipant?.isScreenShareEnabled() ?? false;
    final isCameraOn = voiceState.room?.localParticipant?.isCameraEnabled() ?? false;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 1. Camera Toggle Button
        _circleControlButton(
          icon: isCameraOn ? Icons.videocam_rounded : Icons.videocam_off_rounded,
          bgColor: isCameraOn ? Colors.white24 : Colors.white10,
          iconColor: Colors.white,
          onTap: _handleToggleVideo,
        ),
        // 2. Microphone Toggle Button
        _circleControlButton(
          icon: voiceState.isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
          bgColor: voiceState.isMuted ? const Color(0xFFED4245) : Colors.white10,
          iconColor: Colors.white,
          onTap: _handleToggleMute,
        ),
        // 3. Screen Share Button
        _circleControlButton(
          icon: Icons.mobile_screen_share_rounded,
          bgColor: isScreenSharing ? _neonCyan.withValues(alpha: 0.3) : Colors.white10,
          iconColor: Colors.white,
          onTap: () {
            if (isScreenSharing) {
              _handleToggleScreenShare();
            } else {
              StreamSettingsSheet.show(
                context,
                onStartStreaming: () => _handleToggleScreenShare(),
              );
            }
          },
        ),
        // 4. Activities / Soundboard Button
        _circleControlButton(
          icon: Icons.auto_awesome_rounded,
          bgColor: Colors.white10,
          iconColor: Colors.white,
          onTap: _handleActivities,
        ),
        // 5. End Call Red Circle Button
        _circleControlButton(
          icon: Icons.call_end_rounded,
          bgColor: const Color(0xFFDA373C),
          iconColor: Colors.white,
          onTap: _handleDisconnect,
        ),
      ],
    );
  }

  Widget _circleControlButton({
    required IconData icon,
    required Color bgColor,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: bgColor,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 22),
      ),
    );
  }

  Widget _buildGlassJoinButton(voice_state.VoiceState voiceState) {
    return GestureDetector(
      onTap: voiceState.isConnecting ? null : _handleConnect,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: _neonGreen,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: voiceState.isConnecting
              ? const [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(_white),
                    ),
                  ),
                ]
              : [
                  const Icon(Icons.call_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    'Join Voice',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  ORB BACKGROUND PAINTER
// ══════════════════════════════════════════════════════════════════════════════
class _OrbBackgroundPainter extends CustomPainter {
  final double t;
  _OrbBackgroundPainter(this.t);

  static const Color _neonGreen = Color(0xFF52B788);
  static const Color _neonCyan = Color(0xFF00E5FF);

  @override
  void paint(Canvas canvas, Size size) {
    // Dark base fill
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF060608),
    );

    // Orb 1 – large neon green, drifts from top-left to center
    final o1x = size.width * (0.15 + 0.35 * t);
    final o1y = size.height * (0.1 + 0.25 * t);
    final p1 = Paint()
      ..shader = RadialGradient(
        colors: [
          _neonGreen.withValues(alpha: 0.22),
          _neonGreen.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(o1x, o1y), radius: size.width * 0.55));
    canvas.drawCircle(Offset(o1x, o1y), size.width * 0.55, p1);

    // Orb 2 – neon cyan, drifts from bottom-right to center
    final o2x = size.width * (0.85 - 0.3 * t);
    final o2y = size.height * (0.85 - 0.25 * t);
    final p2 = Paint()
      ..shader = RadialGradient(
        colors: [
          _neonCyan.withValues(alpha: 0.16),
          _neonCyan.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(o2x, o2y), radius: size.width * 0.5));
    canvas.drawCircle(Offset(o2x, o2y), size.width * 0.5, p2);

    // Orb 3 – subtle secondary green, center-right
    final o3x = size.width * (0.6 + 0.15 * sin(t * pi));
    final o3y = size.height * (0.4 - 0.1 * cos(t * pi));
    final p3 = Paint()
      ..shader = RadialGradient(
        colors: [
          _neonGreen.withValues(alpha: 0.08),
          _neonGreen.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
          center: Offset(o3x, o3y), radius: size.width * 0.35));
    canvas.drawCircle(Offset(o3x, o3y), size.width * 0.35, p3);
  }

  @override
  bool shouldRepaint(covariant _OrbBackgroundPainter oldDelegate) =>
      oldDelegate.t != t;
}
