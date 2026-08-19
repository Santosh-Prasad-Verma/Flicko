import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Base placeholder screen for server settings
class ServerSettingsPlaceholderScreen extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const ServerSettingsPlaceholderScreen({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
          onPressed: () => context.pop(),
        ),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: const Color(FlickoColors.textMuted),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                description,
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textSecondary),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Remaining placeholder screens (not yet migrated) ──

class DeleteServerScreen extends StatelessWidget {
  final String serverId;
  const DeleteServerScreen({super.key, required this.serverId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Delete Server',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.danger),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.danger).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(FlickoColors.danger).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber,
                    color: Color(FlickoColors.danger),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Deleting this server is irreversible. All data, channels, messages, and members will be permanently lost.',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: const Color(FlickoColors.bgSecondary),
                      title: Text(
                        'Confirm Deletion',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.danger),
                        ),
                      ),
                      content: Text(
                        'Are you absolutely sure? This action cannot be undone.',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textSecondary),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: GoogleFonts.inter(
                              color: const Color(FlickoColors.textMuted),
                            ),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            try {
                              await Supabase.instance.client
                                  .from('servers')
                                  .delete()
                                  .eq('id', serverId);
                              if (context.mounted) {
                                context.go('/');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Server deleted successfully'),
                                    backgroundColor: Color(FlickoColors.success),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to delete server: $e'),
                                    backgroundColor: const Color(FlickoColors.danger),
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(FlickoColors.danger),
                          ),
                          child: Text(
                            'Delete',
                            style: GoogleFonts.inter(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(FlickoColors.danger),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  'Delete Server',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Server Detail Screen - Full Implementation
class ServerDetailScreen extends ConsumerStatefulWidget {
  final String serverId;
  const ServerDetailScreen({super.key, required this.serverId});

  @override
  ConsumerState<ServerDetailScreen> createState() => _ServerDetailScreenState();
}

class _ServerDetailScreenState extends ConsumerState<ServerDetailScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _server;
  int _memberCount = 0;
  bool _isOwner = false;
  String? _error;

  final _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadServer();
  }

  Future<void> _loadServer() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await _client
          .from('servers')
          .select('*')
          .eq('id', widget.serverId)
          .single();

      final countResponse = await _client
          .from('server_members')
          .select('id')
          .eq('server_id', widget.serverId);

      final currentUser = _client.auth.currentUser;

      if (mounted) {
        setState(() {
          _server = response;
          _memberCount = (countResponse as List).length;
          _isOwner = currentUser?.id == response['owner_id'];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        appBar: AppBar(
          backgroundColor: const Color(FlickoColors.bgSecondary),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
            onPressed: () => context.pop(),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Color(FlickoColors.brandLime)),
        ),
      );
    }

    if (_error != null || _server == null) {
      return Scaffold(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        appBar: AppBar(
          backgroundColor: const Color(FlickoColors.bgSecondary),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Color(FlickoColors.textMuted)),
              const SizedBox(height: 16),
              Text(
                'Server not found',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error ?? 'Unable to load server details.',
                style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 13),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final name = _server!['name'] ?? 'Unnamed Server';
    final icon = _server!['icon'] as String?;
    final description = _server!['description'] as String? ?? 'No description.';

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          name,
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_isOwner)
            IconButton(
              icon: const Icon(Icons.settings, color: Color(FlickoColors.textPrimary)),
              onPressed: () => context.push('/server/${widget.serverId}/settings'),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 48,
              backgroundColor: const Color(FlickoColors.bgTertiary),
              backgroundImage: icon != null ? CachedNetworkImageProvider(icon) : null,
              child: icon == null
                  ? Text(
                      name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'S',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 20),
            Text(
              name,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_memberCount members',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                description,
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textSecondary),
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => context.go('/'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(FlickoColors.brandLime),
                foregroundColor: const Color(FlickoColors.black),
                minimumSize: const Size(double.infinity, 48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                'View Channels',
                style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
