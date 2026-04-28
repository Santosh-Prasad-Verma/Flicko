import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/models/server_model.dart';
import 'package:mobile/data/repositories/server_repository.dart';
import 'package:mobile/features/home/application/servers_notifier.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

class ServerDiscoveryScreen extends ConsumerStatefulWidget {
  const ServerDiscoveryScreen({super.key});

  @override
  ConsumerState<ServerDiscoveryScreen> createState() => _ServerDiscoveryScreenState();
}

class _ServerDiscoveryScreenState extends ConsumerState<ServerDiscoveryScreen> {
  bool _isLoading = true;
  List<ServerModel> _servers = [];

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    setState(() => _isLoading = true);
    final repository = ref.read(serverRepositoryProvider);
    final servers = await repository.getDiscoverableServers();
    if (mounted) {
      setState(() {
        _servers = servers;
        _isLoading = false;
      });
    }
  }

  Future<void> _joinServer(ServerModel server) async {
    final userId = ref.read(authNotifierProvider).maybeWhen(
      authenticated: (user, _) => user.id,
      orElse: () => null,
    );

    if (userId == null) return;

    try {
      await ref.read(serverRepositoryProvider).joinServer(server.id, userId);
      // Refresh the user's servers in the global state
      final uid = ref.read(authNotifierProvider).maybeWhen(authenticated: (u,_)=>u.id, orElse: ()=>'');
      if (uid.isNotEmpty) await ref.read(serversNotifierProvider.notifier).fetchServers(uid);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Joined ${server.name}!')),
        );
        Navigator.pop(context);
        // We could also navigate to the newly joined server here
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join server: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        title: Text(
          'Explore Servers',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _servers.isEmpty
              ? _buildEmptyState()
              : _buildServerList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.search_off, size: 64, color: Color(FlickoColors.textMuted)),
          const SizedBox(height: 16),
          Text(
            'No servers found to explore.',
            style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
          ),
        ],
      ),
    );
  }

  Widget _buildServerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _servers.length,
      itemBuilder: (context, index) {
        final server = _servers[index];
        return Card(
          color: const Color(FlickoColors.bgSecondary),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (server.bannerUrl != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  child: Image.network(
                    server.bannerUrl!,
                    height: 120,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 120,
                        width: double.infinity,
                        color: const Color(FlickoColors.blurple),
                      );
                    },
                  ),
                )
              else
                Container(
                  height: 60,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Color(FlickoColors.blurple),
                    borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                  ),
                ),
              ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: const Color(FlickoColors.bgTertiary),
                  backgroundImage: server.iconUrl != null ? NetworkImage(server.iconUrl!) : null,
                  onBackgroundImageError: server.iconUrl != null ? (e, s) {} : null,
                  child: server.iconUrl == null
                      ? Text(
                          server.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        )
                      : null,
                ),
                title: Text(
                  server.name,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (server.description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          server.description!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 13),
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.people, size: 14, color: Color(FlickoColors.textMuted)),
                        const SizedBox(width: 4),
                        Text(
                          '${server.memberCount} members',
                          style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ),
                trailing: ElevatedButton(
                  onPressed: () => _joinServer(server),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(FlickoColors.blurple),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('Join'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
