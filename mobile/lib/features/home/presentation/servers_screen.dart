import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/home/application/servers_notifier.dart';
import '../../../../data/models/server_model.dart';
import 'widgets/server_rail.dart';
import 'widgets/channel_sidebar.dart';
import 'widgets/home_view.dart';
import 'package:mobile/features/voice/presentation/widgets/voice_hud.dart';

/// Servers tab — the home/landing screen.
///
/// Shows the server rail (left sidebar) and main content area
/// mirroring the React Native HomeScreen layout.
class ServersScreen extends ConsumerWidget {
  const ServersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final serversState = ref.watch(serversNotifierProvider);
    
    final username = authState.maybeWhen(
      authenticated: (user, profile) => profile?.username ?? user.email ?? 'User',
      orElse: () => 'User',
    );

    final selectedServerId = serversState.selectedServerId;
    final ServerModel? selectedServer = selectedServerId != null
        ? serversState.servers.firstWhere((s) => s.id == selectedServerId)
        : null;

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgTertiary),
      body: SafeArea(
        child: Stack(
          children: [
            Row(
              children: [
                // 1. Left Server Rail (bgTertiary)
                const ServerRail(),

                // 2. Main Content Area
                Expanded(
                  child: selectedServer != null
                      ? ChannelSidebar(server: selectedServer)
                      : Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: const BoxDecoration(
                            color: Color(FlickoColors.bgPrimary),
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(12),
                            ),
                          ),
                          child: HomeView(
                            username: username,
                            servers: serversState.servers,
                            isLoading: serversState.isLoading,
                          ),
                        ),
                ),
              ],
            ),
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VoiceHUD(),
            ),
          ],
        ),
      ),
    );
  }
}
