import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:mobile/data/services/azure_calling_service.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

/// Discord-style Draggable Floating Voice & Video PIP Box Widget
/// Renders live video/screen-share or speaking avatar when navigating elsewhere in the app.
class VoiceHUD extends ConsumerStatefulWidget {
  const VoiceHUD({super.key});

  @override
  ConsumerState<VoiceHUD> createState() => _VoiceHUDState();
}

class _VoiceHUDState extends ConsumerState<VoiceHUD> {
  Offset? _position;
  final Map<String, Map<String, dynamic>> _profilesCache = {};
  final Set<String> _fetchingProfileIds = {};

  void _fetchProfile(String userId) async {
    if (userId.isEmpty || _profilesCache.containsKey(userId) || _fetchingProfileIds.contains(userId)) {
      return;
    }
    _fetchingProfileIds.add(userId);
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('username, display_name, avatar')
          .eq('id', userId)
          .maybeSingle();
      if (profile != null && mounted) {
        setState(() {
          _profilesCache[userId] = profile;
        });
      }
    } catch (_) {
      // Fail silently
    } finally {
      _fetchingProfileIds.remove(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceControllerProvider);

    if (!voiceState.isConnected && !voiceState.isConnecting) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;

    final activeServerId = ref.read(voiceControllerProvider.notifier).activeServerId;
    final activeChannelId = voiceState.activeChannelId;
    final controller = ref.read(voiceControllerProvider.notifier);
    final callingService = ref.watch(azureCallingServiceProvider);

    final bool isCameraActive = voiceState.isCameraEnabled;
    final bool isScreenShare = voiceState.isScreenSharing;
    final bool hasLiveVideo = isCameraActive || isScreenShare;
    final RTCVideoRenderer? activeRenderer = callingService.localVideoRenderer;

    // Adjust container dimensions if video stream is active
    final double boxWidth = hasLiveVideo ? 160 : 140;
    final double boxHeight = hasLiveVideo ? 120 : 135;

    _position ??= Offset(size.width - boxWidth - 16, size.height - boxHeight - 80);

    // Identify active speaker or local participant for avatar display when video is inactive
    AzureCallingParticipant? activeSpeakerParticipant;
    if (voiceState.speakingParticipants.isNotEmpty) {
      final speakingId = voiceState.speakingParticipants.first;
      for (final p in voiceState.participants) {
        if (p.id == speakingId) {
          activeSpeakerParticipant = p;
          break;
        }
      }
    }
    activeSpeakerParticipant ??=
        voiceState.participants.isNotEmpty ? voiceState.participants.first : null;

    final String? speakerUserId = activeSpeakerParticipant?.id;
    if (speakerUserId != null && speakerUserId.isNotEmpty && speakerUserId != 'me') {
      _fetchProfile(speakerUserId);
    }

    final currentAuthUser = ref.watch(authNotifierProvider).maybeWhen(
      authenticated: (user, _) => user,
      orElse: () => null,
    );

    final cachedProfile = speakerUserId != null ? _profilesCache[speakerUserId] : null;
    final String avatarUrl = cachedProfile?['avatar'] as String? ?? currentAuthUser?.userMetadata?['avatar_url'] as String? ?? '';
    final String displayName = cachedProfile?['display_name'] as String? ?? cachedProfile?['username'] as String? ?? currentAuthUser?.userMetadata?['username'] as String? ?? 'User';
    final bool isSpeaking = activeSpeakerParticipant != null && voiceState.speakingParticipants.contains(activeSpeakerParticipant.id);

    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (_position!.dx + details.delta.dx).clamp(8.0, size.width - boxWidth - 8.0),
              (_position!.dy + details.delta.dy).clamp(40.0, size.height - boxHeight - 20.0),
            );
          });
        },
        onTap: () {
          if (activeServerId != null && activeChannelId != null) {
            context.push('/server/$activeServerId/channel/$activeChannelId/voice');
          }
        },
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: boxWidth,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1F22).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isScreenShare
                    ? const Color(0xFFED4245)
                    : (isSpeaking ? const Color(0xFF52B788) : Colors.white.withValues(alpha: 0.12)),
                width: isSpeaking || isScreenShare ? 2.0 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isScreenShare
                      ? const Color(0xFFED4245).withValues(alpha: 0.3)
                      : (isSpeaking ? const Color(0xFF52B788).withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.5)),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header Bar: Member count & LIVE indicator
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isScreenShare
                            ? const Color(0xFFED4245)
                            : (voiceState.isConnected ? const Color(0xFF52B788) : Colors.amber),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        isScreenShare
                            ? 'LIVE SCREEN'
                            : (hasLiveVideo ? 'LIVE VIDEO' : '${voiceState.participants.length} in Voice'),
                        style: GoogleFonts.inter(
                          color: isScreenShare ? const Color(0xFFED4245) : Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Main Content Body: Render Live Video Stream OR User Avatar
                if (hasLiveVideo && activeRenderer != null && activeRenderer.srcObject != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 60,
                      width: double.infinity,
                      child: RTCVideoView(
                        activeRenderer,
                        objectFit: isScreenShare
                            ? RTCVideoViewObjectFit.RTCVideoViewObjectFitContain
                            : RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSpeaking ? const Color(0xFF52B788) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: UserAvatar(
                      imageUrl: avatarUrl.isNotEmpty ? avatarUrl : null,
                      name: displayName,
                      size: 38,
                      userId: speakerUserId,
                      showStatus: true,
                      status: isSpeaking ? UserStatus.online : UserStatus.offline,
                    ),
                  ),

                const SizedBox(height: 6),

                // Bottom Action Row: Mute & End Call
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: controller.toggleMute,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: voiceState.isMuted
                              ? const Color(0xFFED4245)
                              : Colors.white12,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          voiceState.isMuted
                              ? Icons.mic_off_rounded
                              : Icons.mic_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: controller.leaveChannel,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDA373C),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 15,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
