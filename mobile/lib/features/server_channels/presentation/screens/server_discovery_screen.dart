import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
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

  static const Color _neon = Color(0xFFC0F500);
  static const Color _bg = Color(0xFF050505);
  static const Color _surface = Color(0xFF0C0C0E);
  static const Color _white = Color(0xFFFBF9FA);
  static const Color _muted = Color(0xFF71717A);

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
          SnackBar(
            content: Text('Joined ${server.name}!', style: GoogleFonts.spaceGrotesk(color: Colors.black, fontWeight: FontWeight.bold)),
            backgroundColor: _neon,
            shape: const RoundedRectangleBorder(),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to join server: $e', style: GoogleFonts.spaceGrotesk(color: _white, fontWeight: FontWeight.bold)),
            backgroundColor: const Color(0xFFED4245),
            shape: const RoundedRectangleBorder(),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: _white),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(color: _white.withValues(alpha: 0.1), height: 1.0),
        ),
        title: Text(
          'EXPLORE SERVERS',
          style: GoogleFonts.epilogue(
            color: _white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: _neon))
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
          const Icon(Icons.search_off, size: 64, color: _muted),
          const SizedBox(height: 16),
          Text(
            'NO SERVERS FOUND',
            style: GoogleFonts.spaceGrotesk(
              color: _muted,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      physics: const BouncingScrollPhysics(),
      itemCount: _servers.length,
      itemBuilder: (context, index) {
        final server = _servers[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: _surface,
            border: Border.all(color: _white.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (server.bannerUrl != null)
                Container(
                  height: 140,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: _white.withValues(alpha: 0.1))),
                    image: DecorationImage(
                      image: NetworkImage(server.bannerUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              else
                Container(
                  height: 60,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _surface,
                    border: Border(bottom: BorderSide(color: _white.withValues(alpha: 0.1))),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _bg,
                        border: Border.all(color: _neon),
                        image: server.iconUrl != null
                            ? DecorationImage(image: NetworkImage(server.iconUrl!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: server.iconUrl == null
                          ? Center(
                              child: Text(
                                server.name.substring(0, 1).toUpperCase(),
                                style: GoogleFonts.epilogue(
                                  color: _neon,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            server.name.toUpperCase(),
                            style: GoogleFonts.epilogue(
                              color: _white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              fontStyle: FontStyle.italic,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (server.description != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              server.description!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(color: _white.withValues(alpha: 0.7), fontSize: 13, height: 1.4),
                            ),
                          ],
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              const Icon(Icons.people, size: 14, color: _muted),
                              const SizedBox(width: 6),
                              Text(
                                '${server.memberCount} MEMBERS',
                                style: GoogleFonts.spaceMono(color: _muted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: _white.withValues(alpha: 0.05))),
                ),
                child: GestureDetector(
                  onTap: () => _joinServer(server),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: const BoxDecoration(color: _neon),
                    child: Center(
                      child: Text(
                        'JOIN SERVER',
                        style: GoogleFonts.spaceGrotesk(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
