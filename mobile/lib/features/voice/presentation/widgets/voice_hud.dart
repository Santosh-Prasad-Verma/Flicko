import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

/// Discord-style Draggable Floating Voice Box Widget
/// Displayed when connected to a voice channel while navigating elsewhere in the app.
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
    _position ??= Offset(size.width - 150, size.height - 220);

    final activeServerId = ref.read(voiceControllerProvider.notifier).activeServerId;
    final activeChannelId = voiceState.activeChannelId;
    final controller = ref.read(voiceControllerProvider.notifier);

    // Identify active speaker or local participant for avatar display
    Participant? activeSpeakerParticipant;
    if (voiceState.speakingParticipants.isNotEmpty) {
      final speakingSid = voiceState.speakingParticipants.first;
      for (final p in voiceState.participants) {
        if (p.sid == speakingSid) {
          activeSpeakerParticipant = p;
          break;
        }
      }
    }
    activeSpeakerParticipant ??= voiceState.participants.isNotEmpty ? voiceState.participants.first : null;

    final String? speakerUserId = activeSpeakerParticipant?.identity;
    if (speakerUserId != null && speakerUserId.isNotEmpty) {
      _fetchProfile(speakerUserId);
    }

    final currentAuthUser = ref.watch(authNotifierProvider).maybeWhen(
      authenticated: (user, _) => user,
      orElse: () => null,
    );

    final cachedProfile = speakerUserId != null ? _profilesCache[speakerUserId] : null;
    final String avatarUrl = cachedProfile?['avatar'] as String? ?? currentAuthUser?.userMetadata?['avatar_url'] as String? ?? '';
    final String displayName = cachedProfile?['display_name'] as String? ?? cachedProfile?['username'] as String? ?? currentAuthUser?.userMetadata?['username'] as String? ?? 'User';
    final bool isSpeaking = activeSpeakerParticipant != null && voiceState.speakingParticipants.contains(activeSpeakerParticipant.sid);

    return Positioned(
      left: _position!.dx,
      top: _position!.dy,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            _position = Offset(
              (_position!.dx + details.delta.dx).clamp(8.0, size.width - 145.0),
              (_position!.dy + details.delta.dy).clamp(50.0, size.height - 180.0),
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
            width: 140,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1F22).withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSpeaking
                    ? const Color(0xFF52B788)
                    : (voiceState.isConnected ? const Color(0xFF52B788).withValues(alpha: 0.5) : Colors.amber),
                width: isSpeaking ? 2.5 : 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSpeaking ? const Color(0xFF52B788).withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.6),
                  blurRadius: isSpeaking ? 16 : 12,
                  spreadRadius: isSpeaking ? 2 : 1,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top status indicator & member count
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: voiceState.isConnected ? const Color(0xFF52B788) : Colors.amber,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        voiceState.isConnecting
                            ? 'Connecting...'
                            : '${voiceState.participants.length} in Voice',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Center User Avatar with pulsating green speaking ring
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
                const SizedBox(height: 8),

                // Bottom Action Row: Mute & End Call
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    GestureDetector(
                      onTap: controller.toggleMute,
                      child: Container(
                        padding: const EdgeInsets.all(6),
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
                          size: 16,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: controller.leaveChannel,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFDA373C),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.call_end_rounded,
                          color: Colors.white,
                          size: 16,
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
