import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

class ServerOptionsScreen extends ConsumerStatefulWidget {
  final String serverId;

  const ServerOptionsScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<ServerOptionsScreen> createState() => _ServerOptionsScreenState();
}

class _ServerOptionsScreenState extends ConsumerState<ServerOptionsScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _server;
  bool _isLeaving = false;
  String? _errorMessage;
  bool _canModerate = false;

  @override
  void initState() {
    super.initState();
    _loadServer();
  }

  Future<void> _loadServer() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await Supabase.instance.client
          .from('servers')
          .select('*')
          .eq('id', widget.serverId)
          .single();

      final currentUser = ref.read(currentUserProvider);
      bool canModerate = false;

      if (currentUser != null) {
        final memberResponse = await Supabase.instance.client
            .from('server_members')
            .select('roles')
            .eq('server_id', widget.serverId)
            .eq('user_id', currentUser.id)
            .maybeSingle();

        final isOwner = response['owner_id'] == currentUser.id;
        final roles = memberResponse?['roles'] as List?;
        final hasAdminRole = roles != null && roles.isNotEmpty;
        final isAdmin = hasAdminRole;
        canModerate = isOwner || isAdmin;
      }

      setState(() {
        _server = response;
        _canModerate = canModerate;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _leaveServer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Leave Server',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
        ),
        content: Text(
          'You won\'t be able to rejoin ${_server?['name'] ?? 'this server'} unless someone sends you a new invite.',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.danger),
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _performLeave();
    }
  }

  Future<void> _performLeave() async {
    setState(() => _isLeaving = true);

    try {
      final user = ref.read(authNotifierProvider).maybeWhen(
        authenticated: (user, _) => user,
        orElse: () => null,
      );

      if (user == null) {
        throw Exception('User not authenticated');
      }

      await Supabase.instance.client
          .from('server_members')
          .delete()
          .eq('server_id', widget.serverId)
          .eq('user_id', user.id);

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      setState(() => _isLeaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave server: ${e.toString()}'),
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      appBar: AppBar(
        
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(FlickoColors.textPrimary)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(FlickoColors.danger)),
            const SizedBox(height: 16),
            Text('Error loading server', style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 16)),
            const SizedBox(height: 8),
            Text(_errorMessage!, style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadServer, child: const Text('Retry')),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          _buildServerCard(),
          const SizedBox(height: 24),
          _buildSection('SERVER OPTIONS', [
            _buildOption(
              Icons.people_outline,
              'View Members',
              'See who\'s in this server',
              const Color(FlickoColors.blurple),
              () => context.push('/server/${widget.serverId}/members'),
            ),
            _buildOption(
              Icons.link,
              'Invite via Link',
              'Share an invite to this server',
              const Color(0xFF5865F2),
              () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite link - Coming Soon')),
                );
              },
            ),
          ]),
          if (_canModerate) ...[
            const SizedBox(height: 24),
            _buildSection('MODERATION', [
              _buildOption(
                Icons.gavel,
                'Bans',
                'Manage banned users',
                const Color(FlickoColors.danger),
                () => context.push('/server/${widget.serverId}/settings/bans'),
              ),
            ]),
          ],
          const SizedBox(height: 24),
          _buildSection('DANGER ZONE', [
            _buildOption(
              Icons.exit_to_app,
              'Leave Server',
              'You\'ll need an invite to rejoin',
              const Color(FlickoColors.danger),
              _leaveServer,
              isDestructive: true,
            ),
          ]),
        ],
      ),
    );
  }

  Widget _buildServerCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          if (_server?['banner'] != null)
            Container(
              height: 70,
              decoration: BoxDecoration(
                color: const Color(FlickoColors.blurple).withValues(alpha: 0.2),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            )
          else
            Container(
              height: 70,
              decoration: BoxDecoration(
                color: const Color(FlickoColors.blurple).withValues(alpha: 0.2),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundImage: _server?['icon'] != null ? NetworkImage(_server!['icon'] as String) : null,
                  child: _server?['icon'] == null
                      ? Text(
                          _server?['name']?[0] ?? '?',
                          style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _server?['name'] ?? 'Loading...',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textPrimary),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_server?['description'] != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          _server!['description'] as String,
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textMuted),
                            fontSize: 12,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildOption(
    IconData icon,
    String title,
    String subtitle,
    Color iconColor,
    VoidCallback onTap, {
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: _isLeaving ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: isDestructive ? const Color(FlickoColors.danger) : const Color(FlickoColors.textPrimary),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (_isLeaving && isDestructive)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              const Icon(Icons.chevron_right, color: Color(FlickoColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
