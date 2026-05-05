import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/home/application/servers_notifier.dart';
import 'package:mobile/data/models/server_model.dart';
import 'package:mobile/features/home/server_channels/presentation/widgets/create_server_dialog.dart';

class ServerRail extends ConsumerWidget {
  const ServerRail({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serversState = ref.watch(serversNotifierProvider);
    final servers = serversState.servers;
    final selectedId = serversState.selectedServerId;

    return Container(
      width: 72,
      color: const Color(FlickoColors.bgTertiary),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Home button
          _ServerRailIcon(
            isActive: selectedId == null,
            onTap: () => ref.read(serversNotifierProvider.notifier).selectServer(null),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: selectedId == null
                    ? const Color(FlickoColors.blurple)
                    : const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(selectedId == null ? 16 : 24),
              ),
              alignment: Alignment.center,
              child: const Text(
                'F',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          
          // DMs button
          _ServerRailIcon(
            isActive: false, 
            onTap: () {
              // TODO: Navigate to DMs tab
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgSecondary),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(Icons.chat_bubble, color: Colors.white, size: 22),
            ),
          ),

          const _RailDivider(),

          // Server icons
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              itemCount: servers.length + 2, // servers + add + explore
              itemBuilder: (context, index) {
                if (index < servers.length) {
                  final server = servers[index];
                  final isActive = selectedId == server.id;
                  return _ServerRailIcon(
                    isActive: isActive,
                    onTap: () => ref.read(serversNotifierProvider.notifier).selectServer(server.id),
                    child: _ServerIconWidget(server: server, isActive: isActive),
                  );
                }
                
                // Add button
                if (index == servers.length) {
                  return _ServerRailIcon(
                    isActive: false,
                    onTap: () => CreateServerDialog.show(context),
                    child: const _CircleIconButton(
                      icon: Icons.add,
                      color: Color(FlickoColors.green),
                    ),
                  );
                }
                
                // Explore button
                return _ServerRailIcon(
                  isActive: false,
                  onTap: () => context.go('/discover'),
                  child: const _CircleIconButton(
                    icon: Icons.explore,
                    color: Color(FlickoColors.green),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerRailIcon extends StatelessWidget {
  final bool isActive;
  final Widget child;
  final VoidCallback onTap;

  const _ServerRailIcon({
    required this.isActive,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 4,
              height: isActive ? 36 : 0,
              margin: const EdgeInsets.only(right: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(4),
                  bottomRight: Radius.circular(4),
                ),
              ),
            ),
            child,
          ],
        ),
      ),
    );
  }
}

class _ServerIconWidget extends StatelessWidget {
  final ServerModel server;
  final bool isActive;

  const _ServerIconWidget({required this.server, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: isActive ? const Color(FlickoColors.blurple) : const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(isActive ? 16 : 24),
      ),
      clipBehavior: Clip.antiAlias,
      child: server.iconUrl != null
          ? Image.network(server.iconUrl!, fit: BoxFit.cover)
          : Center(
              child: Text(
                server.name.split(' ').where((e) => e.isNotEmpty).map((e) => e[0]).join('').toUpperCase().substring(0, server.name.length > 1 ? 2 : 1),
                style: TextStyle(
                  color: isActive ? Colors.white : const Color(FlickoColors.textPrimary),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _CircleIconButton({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

class _RailDivider extends StatelessWidget {
  const _RailDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32,
      height: 2,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
