import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';

/// Active Speaker Grid Component for LiveKit Voice & Video Room
class ActiveSpeakerGrid extends StatelessWidget {
  final Room room;
  final List<Participant> activeSpeakers;
  final Map<String, Map<String, dynamic>> profilesCache;

  const ActiveSpeakerGrid({
    super.key,
    required this.room,
    required this.activeSpeakers,
    required this.profilesCache,
  });

  @override
  Widget build(BuildContext context) {
    final allParticipants = <Participant>[
      if (room.localParticipant != null) room.localParticipant!,
      ...room.remoteParticipants.values,
    ];

    if (allParticipants.isEmpty) {
      return Center(
        child: Text(
          'Waiting for participants to join...',
          style: GoogleFonts.inter(color: Colors.white54, fontSize: 16),
        ),
      );
    }

    final activeSpeakerIds = activeSpeakers.map((p) => p.sid).toSet();

    // Determine grid crossAxisCount
    int crossAxisCount = 1;
    if (allParticipants.length > 1 && allParticipants.length <= 4) {
      crossAxisCount = 2;
    } else if (allParticipants.length > 4) {
      crossAxisCount = 3;
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: allParticipants.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.0,
      ),
      itemBuilder: (context, index) {
        final participant = allParticipants[index];
        final isSpeaking = activeSpeakerIds.contains(participant.sid) || participant.isSpeaking;
        final profile = profilesCache[participant.identity] ?? {};
        final displayName = profile['full_name'] as String? ?? participant.name.ifEmpty(participant.identity);
        final avatarUrl = profile['avatar_url'] as String?;

        // Check for video track publication
        VideoTrack? videoTrack;
        for (final pub in participant.videoTrackPublications) {
          final track = pub.track;
          if (pub.subscribed && track is VideoTrack && !pub.muted) {
            videoTrack = track;
            break;
          }
        }

        return _buildParticipantTile(
          context: context,
          participant: participant,
          displayName: displayName,
          avatarUrl: avatarUrl,
          videoTrack: videoTrack,
          isSpeaking: isSpeaking,
        );
      },
    );
  }

  Widget _buildParticipantTile({
    required BuildContext context,
    required Participant participant,
    required String displayName,
    required String? avatarUrl,
    required VideoTrack? videoTrack,
    required bool isSpeaking,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSpeaking
              ? const Color(FlickoColors.green)
              : Colors.white.withValues(alpha: 0.1),
          width: isSpeaking ? 2.5 : 1.0,
        ),
        boxShadow: isSpeaking
            ? [
                BoxShadow(
                  color: const Color(FlickoColors.green).withValues(alpha: 0.4),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // If video track is active, render VideoTrackRenderer
            if (videoTrack != null)
              VideoTrackRenderer(videoTrack)
            else
              // Audio-only Avatar layout
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  UserAvatar(
                    imageUrl: avatarUrl,
                    name: displayName,
                    size: 56,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: isSpeaking ? FontWeight.bold : FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),

            // Microphone status indicator tag
            Positioned(
              bottom: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      participant.isMicrophoneEnabled() ? Icons.mic : Icons.mic_off,
                      size: 14,
                      color: participant.isMicrophoneEnabled()
                          ? const Color(FlickoColors.green)
                          : Colors.redAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      participant is LocalParticipant ? 'You' : displayName,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension _StringExtension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}
