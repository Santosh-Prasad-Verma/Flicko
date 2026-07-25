
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
  void _handleToggleScreenShare() =>
      ref.read(voiceControllerProvider.notifier).toggleScreenShare();

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
    final isConnected = voiceState.isConnected;
    final connectionLabel = voiceState.isConnecting
        ? 'Connecting...'
        : isConnected
            ? 'Connected'
            : 'Not connected';

    final statusColor = isConnected
        ? _neonGreen
        : voiceState.isConnecting
            ? _neonCyan
            : _white.withValues(alpha: 0.35);

    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            border: Border(
              bottom:
                  BorderSide(color: _white.withValues(alpha: 0.06), width: 1),
            ),
          ),
          child: Row(
            children: [
              IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: _white.withValues(alpha: 0.8), size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 4),
              Icon(Icons.volume_up_rounded,
                  color: _neonGreen.withValues(alpha: 0.7), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _channel?['name'] ?? 'Voice Channel',
                      style: GoogleFonts.outfit(
                        color: _white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          connectionLabel,
                          style: GoogleFonts.inter(
                            color: statusColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: _white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people_rounded,
                        color: _white.withValues(alpha: 0.5), size: 15),
                    const SizedBox(width: 5),
                    Text(
                      '${voiceState.participants.length}',
                      style: GoogleFonts.inter(
                        color: _white.withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
      final pubs = p.videoTrackPublications.where((pub) => pub.track != null && (pub.isScreenShare || pub.source == TrackSource.screenShare)).toList();
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
          // Pinned Screen Share Card
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: AspectRatio(
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
                    // Tap to full-screen overlay detector
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
                    // Bottom Banner Overlay
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
                                '$displayName is sharing their screen',
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.fullscreen_rounded, color: Colors.white, size: 22),
                          ],
                        ),
                      ),
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
  //  FROSTED GLASS PARTICIPANT CARD
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
        .where((pub) => pub.track != null && (pub.isScreenShare || pub.source == TrackSource.screenShare))
        .toList();
    final hasScreenShare = !ignoreScreenShare && screenShareTrack.isNotEmpty;

    // Detect if participant has an active video track
    final videoTrack = participant.videoTrackPublications
        .where((pub) => pub.track != null && !(pub.isScreenShare || pub.source == TrackSource.screenShare))
        .toList();
    final hasVideo = videoTrack.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isSpeaking
                ? _neonGreen.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSpeaking
                  ? _neonGreen.withValues(alpha: 0.35)
                  : _white.withValues(alpha: 0.08),
              width: isSpeaking ? 1.5 : 1,
            ),
            boxShadow: isSpeaking
                ? [
                    BoxShadow(
                      color: _neonGreen.withValues(alpha: 0.15),
                      blurRadius: 20,
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
      ),
    );
  }

  /// Renders the live video stream inside the frosted card
  Widget _buildVideoView(VideoTrack track, Participant participant,
      String displayName, bool isSpeaking, {bool isScreenShare = false}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
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
                color: const Color(0xFFED4245), // Discord/Flicko Red
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFED4245).withValues(alpha: 0.4),
                    blurRadius: 8,
                    spreadRadius: 1,
                  )
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
        // Bottom name overlay
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayName,
                    style: GoogleFonts.inter(
                      color: _white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _buildStatusIcons(participant),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Renders the avatar-based view (when camera is off)
  Widget _buildAvatarView(String displayName, String? avatarUrl,
      Participant participant, bool isSpeaking) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Spacer(flex: 2),
        // ── Avatar with pulsing halo ──
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulseVal = sin(_pulseController.value * 2 * pi);
            final outerScale = isSpeaking ? 1.0 + 0.06 * pulseVal : 1.0;
            final glowAlpha = isSpeaking ? 0.18 + 0.12 * pulseVal : 0.0;

            return Transform.scale(
              scale: outerScale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Outer breathing halo ring
                  if (isSpeaking)
                    Container(
                      width: 82,
                      height: 82,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _neonGreen.withValues(alpha: glowAlpha),
                          width: 2.5,
                        ),
                      ),
                    ),
                  // Middle halo ring
                  if (isSpeaking)
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color:
                              _neonGreen.withValues(alpha: glowAlpha * 0.6),
                          width: 1.5,
                        ),
                      ),
                    ),
                  // Avatar circle
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _white.withValues(alpha: 0.06),
                      border: Border.all(
                        color: isSpeaking
                            ? _neonGreen.withValues(alpha: 0.5)
                            : _white.withValues(alpha: 0.1),
                        width: 2,
                      ),
                      boxShadow: isSpeaking
                          ? [
                              BoxShadow(
                                color: _neonGreen.withValues(alpha: 0.2),
                                blurRadius: 16,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                    child: UserAvatar(
                      imageUrl: avatarUrl,
                      name: displayName,
                      size: 64,
                      userId: participant.identity,
                      showStatus: false,
                      showBadge: false,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        // ── Display name ──
        Text(
          displayName,
          style: GoogleFonts.inter(
            color: _white.withValues(alpha: 0.85),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 6),
        // ── Status icons ──
        _buildStatusIcons(participant),
        const Spacer(flex: 1),
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

  // ══════════════════════════════════════════════════════════════════════════
  //  FLOATING FROSTED GLASS CONTROL BAR
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildFloatingGlassControls(voice_state.VoiceState voiceState) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                  color: _white.withValues(alpha: 0.08), width: 1),
              boxShadow: [
                BoxShadow(
                  color: _neonGreen.withValues(alpha: 0.06),
                  blurRadius: 30,
                  spreadRadius: 0,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: voiceState.isConnected
                ? _buildConnectedGlassControls(voiceState)
                : _buildGlassJoinButton(voiceState),
          ),
        ),
      ),
    );
  }

  Widget _buildGlassJoinButton(voice_state.VoiceState voiceState) {
    return GestureDetector(
      onTap: voiceState.isConnecting ? null : _handleConnect,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_neonGreen, Color(0xFF40916C)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _neonGreen.withValues(alpha: 0.3),
              blurRadius: 16,
              spreadRadius: 0,
            ),
          ],
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
                  valueColor: AlwaysStoppedAnimation<Color>(_white),
                ),
              )
            else ...[
              const Icon(Icons.call_rounded, color: _white, size: 20),
              const SizedBox(width: 10),
              Text(
                'Join Voice',
                style: GoogleFonts.outfit(
                  color: _white,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMoreOptionsSheet(voice_state.VoiceState voiceState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: _white.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle line
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: _white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _moreSheetBtn(
                            icon: Icons.videocam_rounded,
                            label: 'Camera',
                            activeColor: _neonGreen,
                            isActive: voiceState.room?.localParticipant?.isCameraEnabled() ?? false,
                            onTap: () {
                              Navigator.pop(context);
                              _handleToggleVideo();
                            },
                          ),
                          _moreSheetBtn(
                            icon: Icons.desktop_windows_rounded,
                            label: 'Share Screen',
                            activeColor: _neonCyan,
                            isActive: voiceState.room?.localParticipant?.isScreenShareEnabled() ?? false,
                            onTap: () {
                              Navigator.pop(context);
                              _handleToggleScreenShare();
                            },
                          ),
                          _moreSheetBtn(
                            icon: Icons.sports_esports_rounded,
                            label: 'Activities',
                            activeColor: _neonCyan,
                            isActive: false,
                            onTap: () {
                              Navigator.pop(context);
                              _handleActivities();
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _moreSheetBtn(
                            icon: Icons.brush_rounded,
                            label: 'Whiteboard',
                            activeColor: _neonCyan,
                            isActive: _showWhiteboard,
                            onTap: () {
                              Navigator.pop(context);
                              _toggleWhiteboard(!_showWhiteboard);
                            },
                          ),
                          _moreSheetBtn(
                            icon: Icons.music_note_rounded,
                            label: 'Soundboard',
                            activeColor: _neonGreen,
                            isActive: false,
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
                          // Placeholder to keep spacing alignment neat
                          const SizedBox(width: 80),
                        ],
                      ),
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

  Widget _moreSheetBtn({
    required IconData icon,
    required String label,
    required Color activeColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    final bgColor = isActive ? activeColor.withValues(alpha: 0.18) : _white.withValues(alpha: 0.06);
    final iconColor = isActive ? activeColor : _white.withValues(alpha: 0.7);

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive ? activeColor.withValues(alpha: 0.2) : _white.withValues(alpha: 0.06),
                  width: 1,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.15),
                          blurRadius: 12,
                          spreadRadius: 0,
                        )
                      ]
                    : [],
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: _white.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectedGlassControls(voice_state.VoiceState voiceState) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _glassControlBtn(
          icon: voiceState.isMuted
              ? Icons.mic_off_rounded
              : Icons.mic_rounded,
          isActive: voiceState.isMuted,
          activeColor: _red,
          onTap: _handleToggleMute,
          label: 'Mute',
        ),
        _glassControlBtn(
          icon: voiceState.isDeafened
              ? Icons.volume_off_rounded
              : Icons.volume_up_rounded,
          isActive: voiceState.isDeafened,
          activeColor: _red,
          onTap: _handleToggleDeafen,
          label: 'Deafen',
        ),
        _glassControlBtn(
          icon: Icons.keyboard_arrow_up_rounded,
          isActive: false,
          activeColor: _neonCyan,
          onTap: () => _showMoreOptionsSheet(voiceState),
          label: 'More',
        ),
        _glassControlBtn(
          icon: Icons.call_end_rounded,
          isActive: true,
          activeColor: _red,
          onTap: _handleDisconnect,
          label: 'Leave',
          isDestructive: true,
        ),
      ],
    );
  }

  Widget _glassControlBtn({
    required IconData icon,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
    required String label,
    bool isDestructive = false,
  }) {
    final bgColor = isDestructive
        ? _red.withValues(alpha: 0.2)
        : isActive
            ? activeColor.withValues(alpha: 0.18)
            : _white.withValues(alpha: 0.06);
    final iconColor = isDestructive
        ? _red
        : isActive
            ? activeColor
            : _white.withValues(alpha: 0.7);

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: isDestructive
                    ? _red.withValues(alpha: 0.25)
                    : isActive
                        ? activeColor.withValues(alpha: 0.2)
                        : _white.withValues(alpha: 0.06),
                width: 1,
              ),
              boxShadow: isDestructive || isActive
                  ? [
                      BoxShadow(
                        color: activeColor.withValues(alpha: 0.15),
                        blurRadius: 12,
                        spreadRadius: 0,
                      ),
                    ]
                  : [],
            ),
            child: Icon(icon, color: iconColor, size: 21),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: _white.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
