import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

class ServerSettingsHubScreen extends ConsumerStatefulWidget {
  final String serverId;

  const ServerSettingsHubScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<ServerSettingsHubScreen> createState() => _ServerSettingsHubScreenState();
}

class _ServerSettingsHubScreenState extends ConsumerState<ServerSettingsHubScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _serverData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadServerData();
  }

  Future<void> _loadServerData() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authState = ref.read(authNotifierProvider);
      final currentUser = authState.maybeWhen(
        authenticated: (user, _) => user,
        orElse: () => null,
      );

      if (currentUser == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'Not authenticated';
            _isLoading = false;
          });
        }
        return;
      }

      final response = await Supabase.instance.client
          .from('servers')
          .select('*, server_members!inner(roles)')
          .eq('id', widget.serverId)
          .eq('server_members.user_id', currentUser.id)
          .maybeSingle();

      if (response == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'You are not a member of this server';
            _isLoading = false;
          });
        }
        return;
      }

      final isOwner = response['owner_id'] == currentUser.id;

      // Only the server owner can access server settings
      if (!isOwner && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only the server owner can edit server settings'),
            backgroundColor: Colors.redAccent,
          ),
        );
        context.pop();
        return;
      }

      if (mounted) {
        setState(() {
          _serverData = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Error loading server: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator(color: Color(0xFFC8FF00))),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, size: 64, color: Colors.redAccent),
                const SizedBox(height: 20),
                Text(
                  'ERROR',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.inter(color: Colors.white54, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _buildRetryButton(),
              ],
            ),
          ),
        ),
      );
    }

    final serverName = _serverData?['name'] as String? ?? 'Unknown Server';
    final sections = _getSections();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFFC8FF00), size: 20),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              'SERVER SETTINGS',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 2,
              ),
            ),
            Text(
              serverName.toUpperCase(),
              style: GoogleFonts.inter(
                color: const Color(0xFFC8FF00),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        itemCount: sections.length + 1,
        itemBuilder: (context, index) {
          if (index == sections.length) {
            return _buildFooter();
          }
          final section = sections[index];
          return _buildSection(section);
        },
      ),
    );
  }

  Widget _buildRetryButton() {
    return InkWell(
      onTap: _loadServerData,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFC8FF00),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          'RETRY',
          style: GoogleFonts.inter(
            color: Colors.black,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Center(
            child: Opacity(
              opacity: 0.2,
              child: Image.asset(
                'assets/branding/Flicko-for-black-background.png',
                height: 40,
                errorBuilder: (c, e, s) => const SizedBox(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'FLICKO SERVER VERSION 1.0.4',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.1),
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(_SettingsSectionData section) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16, top: 12),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFC8FF00),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFC8FF00).withValues(alpha: 0.5),
                      blurRadius: 8,
                      spreadRadius: -2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                section.title.toUpperCase(),
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ),
        ...section.items.map((item) => _buildSettingsItem(item)),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSettingsItem(_SettingsItemData item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push(item.route),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: item.isDanger 
                ? Colors.redAccent.withValues(alpha: 0.1) 
                : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.isDanger 
                    ? Colors.red.withValues(alpha: 0.1) 
                    : const Color(0xFFC8FF00).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  item.icon, 
                  color: item.isDanger ? Colors.redAccent : const Color(0xFFC8FF00), 
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: GoogleFonts.inter(
                        color: item.isDanger ? Colors.redAccent : Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (item.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        item.description!,
                        style: GoogleFonts.inter(
                          color: Colors.white38,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded, 
                color: item.isDanger 
                  ? Colors.redAccent.withValues(alpha: 0.2) 
                  : Colors.white.withValues(alpha: 0.1), 
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_SettingsSectionData> _getSections() {
    final sId = widget.serverId;
    return [
      _SettingsSectionData(
        title: 'MANAGEMENT',
        items: [
          _SettingsItemData(
            id: 'overview',
            icon: Icons.info_outline_rounded,
            label: 'Overview',
            description: 'Name, icon, and basic info',
            route: '/server/$sId/settings/overview',
          ),
          _SettingsItemData(
            id: 'roles',
            icon: Icons.shield_outlined,
            label: 'Roles',
            description: 'Manage permissions and members',
            route: '/server/$sId/settings/roles',
          ),
          _SettingsItemData(
            id: 'channels',
            icon: Icons.tag_rounded,
            label: 'Channels',
            description: 'Manage channels and categories',
            route: '/server/$sId/settings/channels',
          ),
          _SettingsItemData(
            id: 'emoji',
            icon: Icons.emoji_emotions_outlined,
            label: 'Emoji',
            description: 'Upload and manage custom emojis',
            route: '/server/$sId/settings/emojis',
          ),
          _SettingsItemData(
            id: 'stickers',
            icon: Icons.image_outlined,
            label: 'Stickers',
            description: 'Upload and manage stickers',
            route: '/server/$sId/settings/stickers',
          ),
        ],
      ),
      _SettingsSectionData(
        title: 'COMMUNITY',
        items: [
          _SettingsItemData(
            id: 'events',
            icon: Icons.event_outlined,
            label: 'Events',
            description: 'Create and manage scheduled events',
            route: '/server/$sId/settings/events',
          ),
          _SettingsItemData(
            id: 'onboarding',
            icon: Icons.rocket_launch_outlined,
            label: 'Onboarding',
            description: 'Welcome screen and onboarding questions',
            route: '/server/$sId/settings/onboarding',
          ),
        ],
      ),
      _SettingsSectionData(
        title: 'SAFETY & SECURITY',
        items: [
          _SettingsItemData(
            id: 'safety',
            icon: Icons.security_rounded,
            label: 'Safety Setup',
            description: 'Verification level and content filter',
            route: '/server/$sId/settings/moderation',
          ),
          _SettingsItemData(
            id: 'automod',
            icon: Icons.smart_toy_outlined,
            label: 'AutoMod',
            description: 'Automated content moderation',
            route: '/server/$sId/settings/automod',
          ),
        ],
      ),
      _SettingsSectionData(
        title: 'USER MANAGEMENT',
        items: [
          _SettingsItemData(
            id: 'members',
            icon: Icons.people_outline_rounded,
            label: 'Members',
            description: 'Manage server members',
            route: '/server/$sId/members',
          ),
          _SettingsItemData(
            id: 'invites',
            icon: Icons.link_rounded,
            label: 'Invites',
            description: 'Manage active invite links',
            route: '/server/$sId/settings/invites',
          ),
          _SettingsItemData(
            id: 'bans',
            icon: Icons.gavel_rounded,
            label: 'Bans',
            description: 'Manage banned users',
            route: '/server/$sId/settings/bans',
          ),
        ],
      ),
      _SettingsSectionData(
        title: 'ADVANCED',
        items: [
          _SettingsItemData(
            id: 'webhooks',
            icon: Icons.code_rounded,
            label: 'Webhooks',
            description: 'Manage incoming webhooks',
            route: '/server/$sId/settings/webhooks',
          ),
          _SettingsItemData(
            id: 'templates',
            icon: Icons.description_outlined,
            label: 'Server Template',
            description: 'Pre-made layouts and saves',
            route: '/server/$sId/settings/templates',
          ),
          _SettingsItemData(
            id: 'audit_log',
            icon: Icons.list_alt_rounded,
            label: 'Audit Log',
            description: 'History of all server changes',
            route: '/server/$sId/settings/audit-log',
          ),
        ],
      ),
      _SettingsSectionData(
        title: 'DANGER ZONE',
        items: [
          _SettingsItemData(
            id: 'delete_server',
            icon: Icons.delete_forever_rounded,
            label: 'Delete Server',
            description: 'Permanently remove this server',
            route: '/server/$sId/settings/delete',
            isDanger: true,
          ),
        ],
      ),
    ];
  }
}

class _SettingsSectionData {
  final String title;
  final List<_SettingsItemData> items;

  _SettingsSectionData({
    required this.title,
    required this.items,
  });
}

class _SettingsItemData {
  final String id;
  final IconData icon;
  final String label;
  final String route;
  final String? description;
  final bool isDanger;

  _SettingsItemData({
    required this.id,
    required this.icon,
    required this.label,
    required this.route,
    this.description,
    this.isDanger = false,
  });
}
