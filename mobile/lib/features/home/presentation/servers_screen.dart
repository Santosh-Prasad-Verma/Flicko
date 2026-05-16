import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/data/models/channel_model.dart';
import 'package:mobile/data/models/server_model.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/home/application/servers_notifier.dart';
import 'package:mobile/features/server_channels/presentation/widgets/create_server_dialog.dart';

// HTML Colors
const Color _bgMain = Color(0xFF0D0B14);
const Color _bgSidebar = Color(0xFF0A0812);
const Color _purple = Color(0xFF8B5CF6);
const Color _purpleLight = Color(0xFFA78BFA);
const Color _purpleDark = Color(0xFF6D28D9);
const _green = Color(0xFF22C55E);

class ServersScreen extends ConsumerWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final serversState = ref.watch(serversNotifierProvider);
    final selectedServerId = serversState.selectedServerId;
    
    ServerModel? selectedServer;
    if (selectedServerId != null) {
      for (final server in serversState.servers) {
        if (server.id == selectedServerId) {
          selectedServer = server;
          break;
        }
      }
    }

    final profile = authState.maybeWhen(
      authenticated: (_, profile) => profile,
      orElse: () => null,
    );
    final displayName = profile?.displayName ?? profile?.username ?? 'F';

    final currentUserId = authState.maybeWhen(
      authenticated: (user, _) => user.id,
      orElse: () => null,
    );

    if (serversState.isLoading && serversState.servers.isEmpty) {
      return const Scaffold(
        backgroundColor: _bgMain,
        body: Center(
          child: CircularProgressIndicator(color: _purple),
        ),
      );
    }

    final textChannels = serversState.selectedServerChannels
        .where((c) => c.type == ChannelType.text || c.type == ChannelType.announcement || c.type == ChannelType.forum)
        .toList();
    final voiceChannels = serversState.selectedServerChannels
        .where((c) => c.type == ChannelType.voice || c.type == ChannelType.stage)
        .toList();

    return Scaffold(
      backgroundColor: _bgMain,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
            // SIDEBAR
            _Sidebar(
              servers: serversState.servers,
              selectedServerId: selectedServerId,
              onSelect: (id) => ref.read(serversNotifierProvider.notifier).selectServer(id),
              onCreate: () => context.push('/server/create'),
            ),
            // MAIN CONTENT
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(displayName: displayName),
                  _SpacesRow(
                    servers: serversState.servers,
                    selectedServerId: selectedServerId,
                    onSelect: (id) => ref.read(serversNotifierProvider.notifier).selectServer(id),
                    onCreate: () => context.push('/server/create'),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (selectedServer != null)
                            _MainPanel(
                              server: selectedServer,
                              isOwner: selectedServer.ownerId == currentUserId,
                              textChannels: textChannels,
                              voiceChannels: voiceChannels,
                              onChannelTap: (channel) {
                                context.push('/server/${selectedServer!.id}/channel/${channel.id}');
                              },
                            )
                          else
                            _NoServerState(
                              onCreate: () => context.push('/server/create'),
                              onDiscover: () => context.go('/discover'),
                            ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      ),
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final List<ServerModel> servers;
  final String? selectedServerId;
  final ValueChanged<String?> onSelect;
  final VoidCallback onCreate;

  const _Sidebar({
    required this.servers,
    required this.selectedServerId,
    required this.onSelect,
    required this.onCreate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      decoration: const BoxDecoration(
        color: _bgSidebar,
        border: Border(right: BorderSide(color: Colors.white10, width: 1)),
      ),
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        children: [
          // Search
          GestureDetector(
            onTap: () => context.push('/search'),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(bottom: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.search, color: Colors.white54, size: 20),
            ),
          ),
          const SizedBox(height: 10),
          Container(width: 28, height: 1, color: Colors.white10),
          const SizedBox(height: 10),
          // Home
          GestureDetector(
            onTap: () => onSelect(null),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: selectedServerId == null ? _purple.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06),
                border: selectedServerId == null ? Border.all(color: _purple.withValues(alpha: 0.6), width: 1.5) : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.home_rounded,
                color: selectedServerId == null ? const Color(0xFFC4B5FD) : Colors.white.withValues(alpha: 0.38),
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 10),
          // Servers
          Expanded(
            child: ListView.separated(
              padding: EdgeInsets.zero,
              itemCount: servers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final server = servers[index];
                final isSelected = selectedServerId == server.id;
                return GestureDetector(
                  onTap: () => onSelect(server.id),
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: isSelected ? Border.all(color: _purple, width: 2) : null,
                            color: Colors.white10,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: server.iconUrl != null && server.iconUrl!.isNotEmpty
                              ? Image.network(
                                  server.iconUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Center(
                                    child: Text(
                                      server.name.isNotEmpty ? server.name[0].toUpperCase() : 'S',
                                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                )
                              : Center(
                                  child: Text(
                                    server.name.isNotEmpty ? server.name[0].toUpperCase() : 'S',
                                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ),
                        ),
                        if (index % 2 == 0) // Mock online status
                          Positioned(
                            bottom: -1,
                            right: -1,
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                color: _green,
                                shape: BoxShape.circle,
                                border: Border.all(color: _bgSidebar, width: 2),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          Container(width: 28, height: 1, color: Colors.white10),
          const SizedBox(height: 10),
          // Add
          GestureDetector(
            onTap: onCreate,
            behavior: HitTestBehavior.opaque,
            child: CustomPaint(
              painter: _DashedBorderPainter(color: Colors.white24, strokeWidth: 1.5, radius: 12),
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                child: const Icon(Icons.add, color: Colors.white30, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String displayName;
  const _Header({required this.displayName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    displayName[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Flicko', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      Text('Your space. Your people.', style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Row(
            children: [
              _IconBtn(icon: Icons.search, onTap: () => context.push('/search')),
              const SizedBox(width: 8),
              _IconBtn(icon: Icons.notifications_none, hasDot: true, onTap: () => context.push('/notifications')),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.go('/profile'),
                behavior: HitTestBehavior.opaque,
                child: Stack(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(colors: [_purpleDark, _purple]),
                        border: Border.all(color: _purpleLight, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: _green,
                          shape: BoxShape.circle,
                          border: Border.all(color: _bgMain, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            ],
          )
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData icon;
  final bool hasDot;
  final VoidCallback? onTap;
  const _IconBtn({required this.icon, this.hasDot = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          shape: BoxShape.circle,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.65), size: 18),
            if (hasDot)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _purpleLight,
                    shape: BoxShape.circle,
                    border: Border.all(color: _bgMain, width: 1.5),
                  ),
                ),
              )
          ],
        ),
      ),
    );
  }
}

class _SpacesRow extends StatelessWidget {
  final List<ServerModel> servers;
  final String? selectedServerId;
  final ValueChanged<String?> onSelect;
  final VoidCallback onCreate;

  const _SpacesRow({required this.servers, required this.selectedServerId, required this.onSelect, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        scrollDirection: Axis.horizontal,
        itemCount: servers.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == servers.length) {
            return GestureDetector(
              onTap: onCreate,
              behavior: HitTestBehavior.opaque,
              child: CustomPaint(
                painter: _DashedBorderPainter(color: Colors.white24, strokeWidth: 1.5, radius: 16),
                child: SizedBox(
                  width: 72,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(color: Colors.white10, shape: BoxShape.circle),
                        alignment: Alignment.center,
                        child: const Text('+', style: TextStyle(color: Colors.white54, fontSize: 18)),
                      ),
                      const SizedBox(height: 5),
                      const Text('Add Space', style: TextStyle(color: Colors.white30, fontSize: 8)),
                    ],
                  ),
                ),
              ),
            );
          }
          final server = servers[index];
          final isSelected = selectedServerId == server.id;
          return GestureDetector(
            onTap: () => onSelect(server.id),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: const Color(0xFF1A1625),
                border: isSelected ? Border.all(color: _purple, width: 2) : null,
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  // Server Background Image
                  if (server.bannerUrl != null && server.bannerUrl!.isNotEmpty)
                    Positioned.fill(
                      child: Image.network(
                        server.bannerUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1E3A8A)),
                      ),
                    )
                  else if (server.iconUrl != null && server.iconUrl!.isNotEmpty)
                    Positioned.fill(
                      child: Image.network(
                        server.iconUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(color: Color(0xFF1E3A8A)),
                      ),
                    )
                  else
                    const Positioned.fill(
                      child: ColoredBox(color: Color(0xFF1E3A8A)),
                    ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent]),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(server.name, style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          Row(
                            children: [
                              Container(width: 5, height: 5, decoration: const BoxDecoration(color: _green, shape: BoxShape.circle)),
                              const SizedBox(width: 3),
                              const Text('Online', style: TextStyle(color: _green, fontSize: 8.5)),
                            ],
                          )
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _MainPanel extends StatelessWidget {
  final ServerModel server;
  final bool isOwner;
  final List<ChannelModel> textChannels;
  final List<ChannelModel> voiceChannels;
  final ValueChanged<ChannelModel> onChannelTap;

  const _MainPanel({
    required this.server,
    required this.isOwner,
    required this.textChannels,
    required this.voiceChannels,
    required this.onChannelTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isNarrow = MediaQuery.of(context).size.width < 550;

    final channelsContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _SecLabel('TEXT CHANNELS'),
        if (textChannels.isEmpty)
          const Text('No text channels', style: TextStyle(color: Colors.white54, fontSize: 11))
        else
          ...textChannels.map((c) => _ChRow(channel: c, onTap: () => onChannelTap(c))),
        const SizedBox(height: 9),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SecLabel('VOICE CHANNELS'),
            GestureDetector(
              onTap: () => context.push('/server/${server.id}/channel/create'),
              child: const Icon(Icons.add, color: Colors.white30, size: 15),
            ),
          ],
        ),
        if (voiceChannels.isEmpty)
          const Text('No voice channels', style: TextStyle(color: Colors.white54, fontSize: 11))
        else
          ...voiceChannels.map((c) => _VcRow(channel: c, onTap: () => onChannelTap(c))),
      ],
    );

    final actionsContent = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Activity
        Container(
          padding: const EdgeInsets.all(9),
          margin: const EdgeInsets.only(bottom: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white10),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Members Activity', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
              SizedBox(height: 7),
              _ActItem(icon: '🏆', name: 'Champion', sub: 'Just joined'),
              _ActItem(icon: 'Ar', name: 'Archer', sub: 'Sent a message', color: _purpleLight),
              _ActItem(icon: 'Ph', name: 'Phoenix', sub: 'Streaming', color: Colors.orange),
            ],
          ),
        ),
        // Quick Actions
        Container(
          padding: const EdgeInsets.all(9),
          margin: const EdgeInsets.only(bottom: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Quick Actions', style: TextStyle(color: Colors.white54, fontSize: 9, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              _QItem(icon: Icons.person_add, label: 'Invite People', onTap: () => context.push('/server/${server.id}/settings/invites')),
              _QItem(icon: Icons.add_circle_outline, label: 'Create Channel', onTap: () => context.push('/server/${server.id}/channel/create')),
              _QItem(icon: Icons.settings, label: 'Server Settings', onTap: () => context.push('/server/${server.id}/settings')),
            ],
          ),
        ),
        // Premium
        GestureDetector(
          onTap: () => context.push('/premium/plus'),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_purple.withValues(alpha: 0.28), _purpleDark.withValues(alpha: 0.28)]),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _purple.withValues(alpha: 0.32)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, _purpleDark]), borderRadius: BorderRadius.circular(7)),
                  alignment: Alignment.center,
                  child: const Text('👑', style: TextStyle(fontSize: 10)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Upgrade to Premium', style: TextStyle(color: Color(0xFFC4B5FD), fontSize: 8.5, fontWeight: FontWeight.bold)),
                      Text('Unlock custom themes.', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 7.5, height: 1.2)),
                    ],
                  ),
                )
              ],
            ),
          ),
        )
      ],
    );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Server Banner
          if (server.bannerUrl != null && server.bannerUrl!.isNotEmpty)
            Container(
              height: 100,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                image: DecorationImage(
                  image: NetworkImage(server.bannerUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              height: 50,
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: [_purpleDark.withValues(alpha: 0.3), _bgMain],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          // Panel Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (server.iconUrl != null && server.iconUrl!.isNotEmpty) ...[
                          Container(
                            width: 26,
                            height: 26,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white12),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: Image.network(
                              server.iconUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const Icon(Icons.dns, size: 14, color: Colors.white70),
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Flexible(
                          child: Text(server.name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                        if (isOwner) ...[
                          const SizedBox(width: 7),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [_purple, _purpleDark]),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: const Text('OWNER', style: TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold, letterSpacing: 0.4)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text('${server.memberCount} Members • Community', style: TextStyle(color: Colors.white.withValues(alpha: 0.38), fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Row(
                children: [
                  _PanelBtn(icon: Icons.person_add_alt_1, onTap: () => context.push('/server/${server.id}/settings/invites')),
                  const SizedBox(width: 7),
                  _PanelBtn(icon: Icons.calendar_today, onTap: () => context.push('/server/${server.id}/settings/events')),
                  const SizedBox(width: 7),
                  _PanelBtn(icon: Icons.more_horiz, onTap: () => context.push('/server/${server.id}/server-options')),
                ],
              )
            ],
          ),
          const SizedBox(height: 12),
          // Grid (Responsive Column/Row layout)
          isNarrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    channelsContent,
                    const SizedBox(height: 16),
                    actionsContent,
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: channelsContent),
                    const SizedBox(width: 12),
                    SizedBox(width: 110, child: actionsContent),
                  ],
                ),
        ],
      ),
    );
  }
}

class _PanelBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _PanelBtn({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.07), shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white54, size: 14),
      ),
    );
  }
}

class _SecLabel extends StatelessWidget {
  final String text;
  const _SecLabel(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(width: 2, height: 9, decoration: BoxDecoration(color: _purple, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 5),
          Text(text, style: TextStyle(color: Colors.white38, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.8)),
        ],
      ),
    );
  }
}

class _ChRow extends StatelessWidget {
  final ChannelModel channel;
  final VoidCallback onTap;
  const _ChRow({required this.channel, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isActive = channel.name == 'general';
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        margin: const EdgeInsets.only(bottom: 3),
        decoration: BoxDecoration(
          color: isActive ? _purple.withValues(alpha: 0.22) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: isActive ? Border.all(color: _purple.withValues(alpha: 0.38)) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Text('#', style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(channel.name, style: TextStyle(color: isActive ? Colors.white : Colors.white70, fontSize: 11, fontWeight: isActive ? FontWeight.bold : FontWeight.normal), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(4)),
                child: const Text('● LIVE', style: TextStyle(color: Colors.white, fontSize: 7.5, fontWeight: FontWeight.bold)),
              )
            else
              const Icon(Icons.chevron_right, color: Colors.white24, size: 12)
          ],
        ),
      ),
    );
  }
}

class _VcRow extends StatelessWidget {
  final ChannelModel channel;
  final VoidCallback onTap;
  const _VcRow({required this.channel, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        margin: const EdgeInsets.only(bottom: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.volume_up, color: Colors.white38, size: 12),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(channel.name, style: const TextStyle(color: Colors.white60, fontSize: 10.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('0', style: TextStyle(color: Colors.white30, fontSize: 10))
          ],
        ),
      ),
    );
  }
}

class _ActItem extends StatelessWidget {
  final String icon;
  final String name;
  final String sub;
  final Color? color;
  const _ActItem({required this.icon, required this.name, required this.sub, this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 21,
            height: 21,
            decoration: BoxDecoration(
              color: color,
              gradient: color == null ? const LinearGradient(colors: [Colors.orangeAccent, Colors.orange]) : null,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(icon, style: const TextStyle(fontSize: 7.5, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(sub, style: TextStyle(color: Colors.white38, fontSize: 7.5), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _QItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _QItem({required this.icon, required this.label, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(icon, color: Colors.white54, size: 10),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 8.5), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, color: Colors.white24, size: 10),
          ],
        ),
      ),
    );
  }
}

class _NoServerState extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onDiscover;
  const _NoServerState({required this.onCreate, required this.onDiscover});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 50),
          const Text('No Spaces yet', style: TextStyle(color: Colors.white54)),
          TextButton(onPressed: onCreate, child: const Text('Create one', style: TextStyle(color: _purpleLight))),
        ],
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double radius;

  _DashedBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.radius = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double dashWidth = 5.0;
    const double dashSpace = 5.0;

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Radius.circular(radius),
      ));

    final dashPath = Path();
    for (PathMetric measurePath in path.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < measurePath.length) {
        final length = draw ? dashWidth : dashSpace;
        if (draw) {
          dashPath.addPath(
            measurePath.extractPath(distance, distance + length),
            Offset.zero,
          );
        }
        distance += length;
        draw = !draw;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.radius != radius;
  }
}
