import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/home/application/servers_notifier.dart';
import 'package:mobile/data/models/server_model.dart';
import 'package:mobile/data/models/channel_model.dart';

class ServersScreen extends ConsumerWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversState = ref.watch(serversNotifierProvider);
    final authState = ref.watch(authNotifierProvider);

    final avatarUrl = authState.maybeWhen(
      authenticated: (user, profile) => profile?.avatarUrl,
      orElse: () => null,
    );

    final currentUserId = authState.maybeWhen(
      authenticated: (user, profile) => user.id,
      orElse: () => '',
    );

    // Dynamic Server Fallbacks
    final List<ServerModel> normalServers = serversState.servers.isNotEmpty
        ? serversState.servers.where((s) => s.id != 'gaming').toList()
        : [
            ServerModel(
              id: 'sole-syndicate',
              name: 'Sole Syndicate',
              ownerId: 'system',
              createdAt: DateTime.now(),
            ),
          ];

    final servers = [...normalServers];

    final selectedServerId = serversState.selectedServerId ?? servers.first.id;

    final selectedServer = selectedServerId == 'gaming'
        ? ServerModel(
            id: 'gaming',
            name: 'Gaming Hub',
            ownerId: 'system',
            createdAt: DateTime.now(),
          )
        : servers.firstWhere(
            (s) => s.id == selectedServerId,
            orElse: () => servers.first,
          );

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Custom Top App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Flicko',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ),

            // Horizontal Server/Spaces Selection Rail
            SizedBox(
              height: 72,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: servers.length + 3, // normal servers + gaming button + explore + add button
                itemBuilder: (context, index) {
                  if (index == servers.length + 2) {
                    // Create Server button
                    return GestureDetector(
                      onTap: () => context.push('/server/create'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.transparent,
                              border: Border.all(
                                color: const Color(0xFF10B981).withValues(alpha: 0.5),
                                width: 1.5,
                                style: BorderStyle.solid,
                              ),
                            ),
                            child: const Icon(Icons.add, color: Color(0xFF10B981)),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  if (index == servers.length + 1) {
                    // Explore servers button
                    return GestureDetector(
                      onTap: () => context.push('/discover'),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: const Color(0xFF111111),
                              border: Border.all(color: const Color(0xFF1A1A1A), width: 1),
                            ),
                            child: const Icon(Icons.explore_outlined, color: Color(0xFF9CA3AF)),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 12),
                          ),
                        ],
                      ),
                    );
                  }

                  if (index == servers.length) {
                    // Gaming button
                    final isSelected = selectedServerId == 'gaming';
                    return GestureDetector(
                      onTap: () {
                        context.push('/gaming');
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 54,
                            height: 54,
                            margin: const EdgeInsets.only(right: 12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected ? const Color(0xFF10B981) : const Color(0xFF111111),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF10B981) : const Color(0xFF1A1A1A),
                                width: isSelected ? 2.5 : 1,
                              ),
                            ),
                            child: Icon(
                              Icons.sports_esports_outlined,
                              color: isSelected ? Colors.black : const Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (isSelected)
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF10B981),
                              ),
                            )
                          else
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(right: 12),
                            ),
                        ],
                      ),
                    );
                  }

                  final server = servers[index];
                  final isSelected = server.id == selectedServerId;

                  return GestureDetector(
                    onTap: () {
                      ref.read(serversNotifierProvider.notifier).selectServer(server.id);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? const Color(0xFFE4F98E) : Colors.white,
                            border: Border.all(
                              color: isSelected ? const Color(0xFFC0EB10) : const Color(0xFFE5E7EB),
                              width: isSelected ? 2.5 : 1,
                            ),
                            image: server.iconUrl != null && server.iconUrl!.isNotEmpty
                                ? DecorationImage(
                                    image: NetworkImage(server.iconUrl!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: server.iconUrl == null || server.iconUrl!.isEmpty
                              ? Center(
                                  child: Text(
                                    server.name.isNotEmpty ? server.name.substring(0, 1).toUpperCase() : 'S',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: isSelected ? Colors.black : const Color(0xFF4B5563),
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        if (isSelected)
                          Container(
                            margin: const EdgeInsets.only(right: 12),
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFC0EB10),
                            ),
                          )
                        else
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(right: 12),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 12),

            // Premium Neobrutalist Central Card
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(left: 16, right: 16, bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F0F0F),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.15), width: 1.0),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Visual Server Banner & Icon overlapping
                      SizedBox(
                        height: 156,
                        child: Stack(
                          children: [
                            Container(
                              height: 120,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFC0EB10),
                                image: selectedServer.bannerUrl != null && selectedServer.bannerUrl!.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(selectedServer.bannerUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                                gradient: selectedServer.bannerUrl == null || selectedServer.bannerUrl!.isEmpty
                                    ? const LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [Color(0xFFE4F98E), Color(0xFFC0EB10)],
                                      )
                                    : null,
                              ),
                              child: selectedServer.bannerUrl == null || selectedServer.bannerUrl!.isEmpty
                                  ? Center(
                                      child: Text(
                                        selectedServer.name.toUpperCase(),
                                        style: GoogleFonts.outfit(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: const Color(0xFF1A1A1A).withValues(alpha: 0.12),
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                            Positioned(
                              left: 20,
                              bottom: 0,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(color: const Color(0xFFF4F3ED), width: 3),
                                  image: selectedServer.iconUrl != null && selectedServer.iconUrl!.isNotEmpty
                                      ? DecorationImage(
                                          image: NetworkImage(selectedServer.iconUrl!),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: selectedServer.iconUrl == null || selectedServer.iconUrl!.isEmpty
                                    ? Center(
                                        child: Text(
                                          selectedServer.name.isNotEmpty
                                              ? selectedServer.name.substring(0, 1).toUpperCase()
                                              : 'S',
                                          style: GoogleFonts.outfit(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 24,
                                            color: Colors.black,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Header Content Inside the Card
                      Padding(
                        padding: const EdgeInsets.only(left: 20, right: 20, top: 12, bottom: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              selectedServer.name,
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.more_horiz, color: Color(0xFF10B981), size: 24),
                              onPressed: () {
                                final isOwner = selectedServer.ownerId == currentUserId;

                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: const Color(0xFF0F0F0F),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                                    side: BorderSide(color: Color(0xFF10B981), width: 0.5),
                                  ),
                                  builder: (context) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                                      color: const Color(0xFF0F0F0F),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Server Options',
                                            style: GoogleFonts.outfit(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 16),
                                          if (isOwner) ...[
                                            ListTile(
                                              leading: const Icon(Icons.settings, color: Color(0xFF10B981)),
                                              title: Text('Server Settings',
                                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                                              onTap: () {
                                                Navigator.pop(context);
                                                context.push('/server/${selectedServer.id}/settings');
                                              },
                                            ),
                                          ] else ...[
                                            ListTile(
                                              leading: const Icon(Icons.people, color: Color(0xFF10B981)),
                                              title: Text('View Members',
                                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                                              onTap: () {
                                                Navigator.pop(context);
                                                context.push('/server/${selectedServer.id}/members');
                                              },
                                            ),
                                            ListTile(
                                              leading: const Icon(Icons.person_add, color: Color(0xFF10B981)),
                                              title: Text('Invite Members',
                                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                                              onTap: () {
                                                Navigator.pop(context);
                                                context.push('/server/${selectedServer.id}/settings/invites');
                                              },
                                            ),
                                          ],
                                          ListTile(
                                            leading: const Icon(Icons.search, color: Color(0xFF10B981)),
                                            title: Text('Search Messages',
                                                style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white)),
                                            onTap: () {
                                              Navigator.pop(context);
                                              context.push('/advanced-search?serverId=${selectedServer.id}');
                                            },
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const Divider(height: 1, color: Color(0xFFF3F4F6)),

                      // Main List View for Channel Categories & Items
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (selectedServerId == 'gaming') ...[
                              _buildCategoryHeader('MINI GAMES'),
                              const SizedBox(height: 12),
                              _buildGameCard(
                                context: context,
                                title: 'Chess',
                                tag: 'STRATEGIC',
                                tagColor: const Color(0xFFD4E157),
                                description:
                                    'Engage in classic tactical warfare. Sharpen your mind with real-time multiplayer Chess and AI.',
                                imageUrl:
                                    'https://images.unsplash.com/photo-1529692236671-f1f6e9460272?q=80&w=500&auto=format&fit=crop',
                                onTap: () => context.push('/gaming/matchmaking?activity=Chess'),
                              ),
                              const SizedBox(height: 16),
                              _buildGameCard(
                                context: context,
                                title: 'Poker',
                                tag: 'CARD GAME',
                                tagColor: const Color(0xFFFFCDD2),
                                description:
                                    'High stakes and bluffing. Join lobbies of varying skill levels, invite friends, or practice.',
                                imageUrl:
                                    'https://images.unsplash.com/photo-1511193311914-0346f16efe90?q=80&w=500&auto=format&fit=crop',
                                onTap: () => context.push('/gaming/matchmaking?activity=Poker'),
                              ),
                              const SizedBox(height: 16),
                              _buildGameCard(
                                context: context,
                                title: 'Drawing',
                                tag: 'CREATIVE',
                                tagColor: const Color(0xFFE0E0E0),
                                description:
                                    'Unleash your creativity in collaborative canvas sessions. Match up with random artists.',
                                imageUrl:
                                    'https://images.unsplash.com/photo-1513364776144-60967b0f800f?q=80&w=500&auto=format&fit=crop',
                                onTap: () => context.push('/gaming/matchmaking?activity=Drawing'),
                              ),
                            ] else if (serversState.selectedServerChannels.isNotEmpty) ...[
                              _buildCategoryHeader('TEXT CHANNELS'),
                              const SizedBox(height: 8),
                              ...serversState.selectedServerChannels
                                  .where((c) => c.type == ChannelType.text || c.type == ChannelType.announcement)
                                  .map((ch) {
                                return _buildChannelItem(
                                  context: context,
                                  icon: ch.type == ChannelType.announcement ? Icons.campaign : Icons.tag,
                                  name: ch.name,
                                  serverId: selectedServer.id,
                                  channelId: ch.id,
                                  isSelected: false,
                                );
                              }),
                              const SizedBox(height: 20),
                              _buildCategoryHeader('VOICE CHANNELS'),
                              const SizedBox(height: 8),
                              ...serversState.selectedServerChannels.where((c) => c.type == ChannelType.voice).map((ch) {
                                return _buildChannelItem(
                                  context: context,
                                  icon: Icons.volume_up_outlined,
                                  name: ch.name,
                                  serverId: selectedServer.id,
                                  channelId: ch.id,
                                  isSelected: false,
                                  isVoice: true,
                                );
                              }),
                            ] else ...[
                              _buildCategoryHeader('TEXT CHANNELS'),
                              const SizedBox(height: 8),
                              // Announcements channel with orange unread dot
                              _buildChannelItem(
                                context: context,
                                icon: Icons.tag,
                                name: 'announcements',
                                serverId: selectedServer.id,
                                channelId: 'announcements',
                                isSelected: false,
                                trailing: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFF97316),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                              // General channel is hovered/active in screenshot
                              _buildChannelItem(
                                context: context,
                                icon: Icons.tag,
                                name: 'general',
                                serverId: selectedServer.id,
                                channelId: 'general',
                                isSelected: true,
                                trailing: const Icon(Icons.chevron_right, size: 16, color: Color(0xFF6B7280)),
                              ),
                              // Drop alerts channel with lime green NEW badge
                              _buildChannelItem(
                                context: context,
                                icon: Icons.tag,
                                name: 'drop-alerts',
                                serverId: selectedServer.id,
                                channelId: 'drop-alerts',
                                isSelected: false,
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE4F98E),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'NEW',
                                    style: GoogleFonts.outfit(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildCategoryHeader('VOICE CHANNELS'),
                              const SizedBox(height: 8),
                              // Lounge voice channel
                              _buildChannelItem(
                                context: context,
                                icon: Icons.volume_up_outlined,
                                name: 'Lounge',
                                serverId: selectedServer.id,
                                channelId: 'lounge',
                                isSelected: false,
                                isVoice: true,
                                trailing: Text(
                                  '3 / 10',
                                  style: GoogleFonts.outfit(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF6B7280),
                                  ),
                                ),
                              ),
                              // Overlapping voice user avatars shown in screenshot
                              Padding(
                                padding: const EdgeInsets.only(left: 44, bottom: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF3B82F6),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 2),
                                      ),
                                    ),
                                    Transform.translate(
                                      offset: const Offset(-8, 0),
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEC4899),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            'AL',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    Transform.translate(
                                      offset: const Offset(-16, 0),
                                      child: Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF6B7280),
                                          shape: BoxShape.circle,
                                          border: Border.all(color: Colors.white, width: 2),
                                        ),
                                        child: const Center(
                                          child: Text(
                                            '+1',
                                            style: TextStyle(
                                              fontSize: 8,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Gaming voice channel
                              _buildChannelItem(
                                context: context,
                                icon: Icons.volume_off_outlined,
                                name: 'Gaming',
                                serverId: selectedServer.id,
                                channelId: 'gaming-voice',
                                isSelected: false,
                                isVoice: true,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(String title) {
    return Row(
      children: [
        const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF6B7280)),
        const SizedBox(width: 4),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.8,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildChannelItem({
    required BuildContext context,
    required IconData icon,
    required String name,
    required String serverId,
    required String channelId,
    required bool isSelected,
    bool isVoice = false,
    Widget? trailing,
  }) {
    return GestureDetector(
      onTap: () {
        if (isVoice) {
          context.push('/server/$serverId/channel/$channelId/voice');
        } else {
          context.push('/server/$serverId/channel/$channelId');
        }
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? const Color(0xFF10B981) : const Color(0xFF9CA3AF),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFF10B981) : const Color(0xFFE5E7EB),
                ),
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildGameCard({
    required BuildContext context,
    required String title,
    required String tag,
    required Color tagColor,
    required String description,
    required String imageUrl,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1F1F1F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.15),
          width: 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(imageUrl),
                  fit: BoxFit.cover,
                  colorFilter: ColorFilter.mode(
                    Colors.black.withValues(alpha: 0.15),
                    BlendMode.darken,
                  ),
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.videogame_asset_outlined,
                  color: Colors.white38,
                  size: 36,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: tagColor.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          tag,
                          style: GoogleFonts.outfit(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: const Color(0xFF9CA3AF),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
