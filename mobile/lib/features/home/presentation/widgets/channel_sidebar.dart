import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/models/channel_model.dart';
import 'package:mobile/data/models/server_model.dart';
import 'package:mobile/features/home/application/servers_notifier.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/voice/presentation/controllers/voice_controller.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:mobile/features/voice/presentation/widgets/active_speaker_indicator.dart';
import 'package:mobile/features/voice/presentation/widgets/voice_permission_dialog.dart';

class ChannelSidebar extends ConsumerStatefulWidget {
  final ServerModel server;
  const ChannelSidebar({super.key, required this.server});

  @override
  ConsumerState<ChannelSidebar> createState() => _ChannelSidebarState();
}

class _ChannelSidebarState extends ConsumerState<ChannelSidebar> {
  final Set<String> _collapsedCategories = {};

  void _toggleCategory(String categoryId) {
    setState(() {
      if (_collapsedCategories.contains(categoryId)) {
        _collapsedCategories.remove(categoryId);
      } else {
        _collapsedCategories.add(categoryId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(voiceControllerProvider.select((s) => s.error), (previous, next) {
      if (next == 'Microphone permission denied') {
        showDialog(
          context: context,
          builder: (context) => const VoicePermissionDialog(),
        );
      }
    });

    final serversState = ref.watch(serversNotifierProvider);
    final channels = serversState.selectedServerChannels;

    // Group channels by category
    final categories = channels.where((c) => c.type == ChannelType.category).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    
    final orphanChannels = channels.where((c) => c.type != ChannelType.category && c.parentId == null).toList()
      ..sort((a, b) => a.position.compareTo(b.position));

    return Container(
      width: 240,
      color: const Color(FlickoColors.bgSecondary),
      child: Column(
        children: [
          _ServerHeader(name: widget.server.name),
          
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                ...orphanChannels.map((c) => _ChannelRow(serverId: widget.server.id, channel: c)),
                
                ...categories.map((category) {
                  final sectionChannels = channels.where((c) => c.parentId == category.id).toList()
                    ..sort((a, b) => a.position.compareTo(b.position));
                  final isCollapsed = _collapsedCategories.contains(category.id);
                  
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _CategoryHeader(
                        name: category.name,
                        isCollapsed: isCollapsed,
                        onTap: () => _toggleCategory(category.id),
                      ),
                      if (!isCollapsed)
                        ...sectionChannels.map((c) => _ChannelRow(serverId: widget.server.id, channel: c)),
                    ],
                  );
                }),
              ],
            ),
          ),
          
          const _CurrentUserBar(),
        ],
      ),
    );
  }
}

class _ServerHeader extends StatelessWidget {
  final String name;
  const _ServerHeader({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(FlickoColors.bgTertiary), width: 1.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Icon(Icons.expand_more, color: Colors.white),
        ],
      ),
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  final String name;
  final bool isCollapsed;
  final VoidCallback onTap;

  const _CategoryHeader({
    required this.name,
    required this.isCollapsed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Row(
          children: [
            Icon(
              isCollapsed ? Icons.keyboard_arrow_right : Icons.keyboard_arrow_down,
              size: 12,
              color: const Color(FlickoColors.textMuted),
            ),
            const SizedBox(width: 4),
            Text(
              name.toUpperCase(),
              style: const TextStyle(
                color: Color(FlickoColors.textMuted),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChannelRow extends StatelessWidget {
  final String serverId;
  final ChannelModel channel;
  const _ChannelRow({required this.serverId, required this.channel});

  @override
  Widget build(BuildContext context) {
    if (channel.type == ChannelType.voice) {
      return _VoiceChannelRow(channel: channel);
    }

    return InkWell(
      onTap: () => context.push('/server/$serverId/channel/${channel.id}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              const Icon(Icons.tag, size: 20, color: Color(FlickoColors.textMuted)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  channel.name,
                  style: const TextStyle(
                    color: Color(FlickoColors.textSecondary),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VoiceChannelRow extends ConsumerWidget {
  final ChannelModel channel;
  const _VoiceChannelRow({required this.channel});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final voiceState = ref.watch(voiceControllerProvider);
    final participants = voiceState.participants;

    return InkWell(
      onTap: () => ref.read(voiceControllerProvider.notifier).joinChannel(channel.id, channel.serverId),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.volume_up, size: 20, color: Color(FlickoColors.textMuted)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      channel.name,
                      style: const TextStyle(
                        color: Color(FlickoColors.textSecondary),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Icon(Icons.person_add_alt_1, size: 16, color: Color(FlickoColors.textMuted)),
                ],
              ),
            ),
            if (participants.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 4),
                child: Column(
                  children: participants
                      .map((p) => _VoiceParticipantRow(participant: p))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VoiceParticipantRow extends StatelessWidget {
  final Participant participant;
  const _VoiceParticipantRow({required this.participant});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          _ParticipantBubble(participant: participant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              participant.name.isNotEmpty ? participant.name : participant.identity,
              style: const TextStyle(
                color: Color(FlickoColors.textSecondary),
                fontSize: 13,
              ),
            ),
          ),
          if (participant.isMuted)
            const Icon(Icons.mic_off, size: 12, color: Color(FlickoColors.red)),
        ],
      ),
    );
  }
}

class _ParticipantBubble extends StatelessWidget {
  final Participant participant;
  const _ParticipantBubble({required this.participant});

  @override
  Widget build(BuildContext context) {
    return ActiveSpeakerIndicator(
      participantSid: participant.sid,
      child: CircleAvatar(
        radius: 9,
        backgroundColor: const Color(FlickoColors.blurple),
        child: Text(
                ((participant.name.isNotEmpty ? participant.name : participant.identity).isNotEmpty
                        ? (participant.name.isNotEmpty ? participant.name : participant.identity)[0]
                        : 'U')
                    .toUpperCase(),
                style: const TextStyle(
                  fontSize: 7,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              )
      ),
    );
  }
}

class _CurrentUserBar extends ConsumerWidget {
  const _CurrentUserBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final voiceState = ref.watch(voiceControllerProvider);
    final voiceController = ref.read(voiceControllerProvider.notifier);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      color: const Color(FlickoColors.bgTertiary),
      child: Row(
        children: [
          authState.maybeWhen(
            authenticated: (user, profile) => Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: const Color(FlickoColors.blurple),
                  backgroundImage: profile?.avatarUrl != null 
                      ? NetworkImage(profile!.avatarUrl!) 
                      : null,
                  child: profile?.avatarUrl == null
                      ? Text(
                          (profile?.username ?? 'U')[0].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      profile?.username ?? 'User',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '#${user.id.substring(0, 4)}',
                      style: const TextStyle(
                        color: Color(FlickoColors.textMuted),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            orElse: () => const SizedBox(),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(
              voiceState.isMuted ? Icons.mic_off : Icons.mic,
              size: 20,
              color: voiceState.isMuted ? const Color(FlickoColors.red) : Colors.white,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: voiceController.toggleMute,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(
              voiceState.isDeafened ? Icons.headset_off : Icons.headset,
              size: 20,
              color: voiceState.isDeafened ? const Color(FlickoColors.red) : Colors.white,
            ),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: voiceController.toggleDeafen,
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.settings, size: 20, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              // TODO: Navigate to settings
            },
          ),
        ],
      ),
    );
  }
}
