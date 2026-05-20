import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class ServerSettingsHubScreen extends ConsumerStatefulWidget {
  final String serverId;

  const ServerSettingsHubScreen({
    super.key,
    required this.serverId,
  });

  @override
  ConsumerState<ServerSettingsHubScreen> createState() =>
      _ServerSettingsHubScreenState();
}

class _ServerSettingsHubScreenState
    extends ConsumerState<ServerSettingsHubScreen> {
  static const Color _neonGreen = Color(FlickoColors.brandLime);
  static const Color _bgBlack = Color(FlickoColors.bgPrimary);
  static const Color _surfaceContainer = Color(FlickoColors.bgSecondary);
  static const Color _textWhite = Color(FlickoColors.textPrimary);
  static const Color _textMuted = Color(FlickoColors.textMuted);

  bool _isLoading = true;
  String _serverName = 'Server Settings';
  String? _iconUrl;
  String? _bannerUrl;
  bool _isOwner = false;
  int _membersCount = 0;
  int _channelsCount = 0;
  int _rolesCount = 0;
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
      final client = Supabase.instance.client;

      // Fetch server details
      final serverData = await client
          .from('servers')
          .select('*')
          .eq('id', widget.serverId)
          .single();

      // Fetch members count
      final membersRes = await client
          .from('server_members')
          .select('id')
          .eq('server_id', widget.serverId);

      // Fetch channels count
      final channelsRes = await client
          .from('channels')
          .select('id')
          .eq('server_id', widget.serverId);

      // Fetch roles count
      final rolesRes = await client
          .from('roles')
          .select('id')
          .eq('server_id', widget.serverId);

      final currentUserId = client.auth.currentUser?.id;
      final isOwner = serverData['owner_id'] == currentUserId;

      if (mounted) {
        setState(() {
          _serverName = serverData['name'] ?? 'Server';
          _iconUrl = serverData['icon'];
          _bannerUrl = serverData['banner'];
          _membersCount = membersRes.length;
          _channelsCount = channelsRes.length;
          _rolesCount = rolesRes.length;
          _isOwner = isOwner;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: _neonGreen.withValues(alpha: 0.1), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.arrow_back, color: _textWhite, size: 20),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'SERVER SETTINGS',
                  style: GoogleFonts.spaceGrotesk(
                    color: _neonGreen.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'MANAGE SERVER AND PREFERENCES',
                  style: GoogleFonts.spaceMono(
                    color: _textWhite.withValues(alpha: 0.3),
                    fontSize: 8,
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasPermission(String permission) => true; // Safe fallback for permissions

    // All settings sections with their items
    final sections = _buildSettingsSections(
      context: context,
      serverId: widget.serverId,
      isOwner: _isOwner,
      hasPermission: hasPermission,
    );

    // Filter sections based on permissions
    final visibleSections = sections
        .map((section) {
          final visibleItems = section.items.where((item) {
            // Server delete is owner-only
            if (item.id == 'delete') return _isOwner;
            // Check required permission
            if (item.requiredPermission == null) return true;
            return hasPermission(item.requiredPermission!);
          }).toList();
          return section.copyWith(items: visibleItems);
        })
        .where((s) => s.items.isNotEmpty)
        .toList();

    return Scaffold(
      backgroundColor: _bgBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _neonGreen,
                        strokeWidth: 3,
                      ),
                    )
                  : _errorMessage != null
                      ? _buildErrorState()
                      : SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 24),
                                Text(
                                  'SERVER\nSETTINGS',
                                  style: GoogleFonts.epilogue(
                                    color: _textWhite,
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -2,
                                    height: 0.9,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildServerHeader(),
                                ...visibleSections.expand((section) => [
                                  const SizedBox(height: 32),
                                  _buildSectionHeader(section.title.toUpperCase()),
                                  ...section.items.map((item) => _buildSettingsRow(context, item)),
                                ]),
                                const SizedBox(height: 48),
                                Center(
                                  child: Column(
                                    children: [
                                      Image.asset(
                                        'assets/branding/Flicko-for-black-background.png',
                                        height: 48,
                                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'FLICKO // SYSTEM_OK v1.2.4',
                                        style: GoogleFonts.spaceMono(
                                          color: _textWhite.withValues(alpha: 0.15),
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 48),
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

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: Colors.redAccent, size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to load server settings',
              style: GoogleFonts.spaceGrotesk(
                color: _textWhite,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ?? 'Unknown error occurred.',
              textAlign: TextAlign.center,
              style: GoogleFonts.spaceMono(
                color: _textMuted,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _neonGreen,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              icon: const Icon(Icons.replay_rounded),
              label: Text(
                'Retry',
                style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w900),
              ),
              onPressed: _loadServerData,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServerHeader() {
    final hasIcon = _iconUrl != null && _iconUrl!.isNotEmpty;
    final initials = _serverName.isNotEmpty
        ? _serverName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').take(2).join().toUpperCase()
        : 'S';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _surfaceContainer,
        border: Border.all(color: _textWhite.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _neonGreen, width: 1.5),
                ),
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _surfaceContainer,
                    image: hasIcon ? DecorationImage(image: NetworkImage(_iconUrl!), fit: BoxFit.cover) : null,
                  ),
                  alignment: Alignment.center,
                  child: !hasIcon ? Text(
                    initials,
                    style: GoogleFonts.spaceGrotesk(
                      color: _neonGreen,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ) : null,
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _serverName.toUpperCase(),
                      style: GoogleFonts.epilogue(
                        color: _textWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        fontStyle: FontStyle.italic,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'ID: ${widget.serverId}',
                      style: GoogleFonts.spaceMono(
                        color: _neonGreen,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem(
                icon: Icons.people_alt_rounded,
                value: _membersCount.toString(),
                label: 'Members',
              ),
              _buildStatItem(
                icon: Icons.tag_rounded,
                value: _channelsCount.toString(),
                label: 'Channels',
              ),
              _buildStatItem(
                icon: Icons.shield_rounded,
                value: _rolesCount.toString(),
                label: 'Roles',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: _neonGreen),
            const SizedBox(width: 6),
            Text(
              value,
              style: GoogleFonts.spaceGrotesk(
                color: _textWhite,
                fontWeight: FontWeight.w900,
                fontSize: 15,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: GoogleFonts.spaceMono(
            color: _textMuted.withValues(alpha: 0.8),
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.epilogue(
            color: _textWhite,
            fontSize: 22,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
          ),
        ),
        Container(
          height: 2,
          color: _neonGreen,
          margin: const EdgeInsets.only(top: 6, bottom: 16),
        ),
      ],
    );
  }

  Widget _buildSettingsRow(BuildContext context, SettingsItem item) {
    final bool isDanger = item.isDanger;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _surfaceContainer,
        border: Border.all(
          color: isDanger
              ? Colors.red.withValues(alpha: 0.2)
              : _textWhite.withValues(alpha: 0.05),
        ),
      ),
      child: InkWell(
        onTap: () => context.push(item.route),
        splashColor: isDanger
            ? Colors.red.withValues(alpha: 0.1)
            : _neonGreen.withValues(alpha: 0.1),
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDanger
                      ? Colors.red.withValues(alpha: 0.1)
                      : _neonGreen.withValues(alpha: 0.05),
                  border: Border.all(
                    color: isDanger
                        ? Colors.red.withValues(alpha: 0.2)
                        : _neonGreen.withValues(alpha: 0.1),
                  ),
                ),
                child: Icon(
                  item.icon,
                  color: isDanger ? Colors.redAccent : _neonGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                        color: isDanger ? Colors.redAccent : _textWhite,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.0,
                      ),
                    ),
                    if (item.description != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.description!,
                        style: GoogleFonts.spaceMono(
                          color: _textMuted.withValues(alpha: 0.8),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: _textWhite.withValues(alpha: 0.15),
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<SettingsSection> _buildSettingsSections({
    required BuildContext context,
    required String serverId,
    required bool isOwner,
    required Function(String) hasPermission,
  }) {
    return [
      SettingsSection(
        title: 'SERVER BASICS',
        items: [
          SettingsItem(
            id: 'overview',
            icon: Icons.info_outline_rounded,
            label: 'Overview',
            route: '/server/$serverId/settings/overview',
            description: 'Server name, icon, and basic info',
            requiredPermission: 'MANAGE_GUILD',
          ),
          SettingsItem(
            id: 'channels',
            icon: Icons.folder_outlined,
            label: 'Channels',
            route: '/server/$serverId/settings/channels',
            description: 'Create, edit, and organize channels',
            requiredPermission: 'MANAGE_CHANNELS',
          ),
          SettingsItem(
            id: 'roles',
            icon: Icons.badge_outlined,
            label: 'Roles',
            route: '/server/$serverId/settings/roles',
            description: 'Manage server roles and permissions',
            requiredPermission: 'MANAGE_ROLES',
          ),
          SettingsItem(
            id: 'emojis',
            icon: Icons.emoji_emotions_outlined,
            label: 'Emoji',
            route: '/server/$serverId/settings/emojis',
            description: 'Upload and manage custom emojis',
            requiredPermission: 'MANAGE_EMOJIS_AND_STICKERS',
          ),
          SettingsItem(
            id: 'stickers',
            icon: Icons.image_outlined,
            label: 'Stickers',
            route: '/server/$serverId/settings/stickers',
            description: 'Upload and manage stickers',
            requiredPermission: 'MANAGE_EMOJIS_AND_STICKERS',
          ),
        ],
      ),
      SettingsSection(
        title: 'MODERATION',
        items: [
          SettingsItem(
            id: 'moderation',
            icon: Icons.shield_outlined,
            label: 'Safety Setup',
            route: '/server/$serverId/settings/moderation',
            description: 'Verification level, content filter',
            requiredPermission: 'MANAGE_GUILD',
          ),
          SettingsItem(
            id: 'automod',
            icon: Icons.auto_fix_high_rounded,
            label: 'AutoMod',
            route: '/server/$serverId/settings/automod',
            description: 'Automated moderation rules',
            requiredPermission: 'MANAGE_GUILD',
          ),
          SettingsItem(
            id: 'audit-log',
            icon: Icons.receipt_long_outlined,
            label: 'Audit Log',
            route: '/server/$serverId/settings/audit-log',
            description: 'View all administrative actions',
            requiredPermission: 'VIEW_AUDIT_LOG',
          ),
          SettingsItem(
            id: 'bans',
            icon: Icons.gavel_rounded,
            label: 'Bans',
            route: '/server/$serverId/settings/bans',
            description: 'View and manage banned members',
            requiredPermission: 'BAN_MEMBERS',
          ),
          SettingsItem(
            id: 'invites',
            icon: Icons.link_rounded,
            label: 'Invites',
            route: '/server/$serverId/settings/invites',
            description: 'View and manage server invites',
            requiredPermission: 'MANAGE_GUILD',
          ),
        ],
      ),
      SettingsSection(
        title: 'INTEGRATIONS',
        items: [
          SettingsItem(
            id: 'bots',
            icon: Icons.memory_rounded,
            label: 'Bots',
            route: '/server/$serverId/settings/bots',
            description: 'Manage server bots and automation',
            requiredPermission: 'MANAGE_GUILD',
          ),
          SettingsItem(
            id: 'webhooks',
            icon: Icons.code_rounded,
            label: 'Webhooks',
            route: '/server/$serverId/settings/webhooks',
            description: 'Manage incoming webhooks',
            requiredPermission: 'MANAGE_WEBHOOKS',
          ),
          SettingsItem(
            id: 'events',
            icon: Icons.event_note_rounded,
            label: 'Events',
            route: '/server/$serverId/settings/events',
            description: 'Create and manage scheduled events',
            requiredPermission: 'MANAGE_EVENTS',
          ),
        ],
      ),
      SettingsSection(
        title: 'COMMUNITY',
        items: [
          SettingsItem(
            id: 'onboarding',
            icon: Icons.rocket_launch_rounded,
            label: 'Onboarding',
            route: '/server/$serverId/settings/onboarding',
            description: 'Welcome screen and onboarding questions',
            requiredPermission: 'MANAGE_GUILD',
          ),
          SettingsItem(
            id: 'templates',
            icon: Icons.description_outlined,
            label: 'Server Template',
            route: '/server/$serverId/settings/templates',
            description: 'Pre-made layouts and saves',
            requiredPermission: 'MANAGE_GUILD',
          ),
        ],
      ),
      SettingsSection(
        title: 'DANGER ZONE',
        items: [
          SettingsItem(
            id: 'delete',
            icon: Icons.delete_outline_rounded,
            label: 'Delete Server',
            route: '/server/$serverId/settings/delete',
            description: 'Permanently delete this server',
            isDanger: true,
          ),
        ],
      ),
    ];
  }
}

class SettingsItem {
  final String id;
  final IconData icon;
  final String label;
  final String route;
  final String? description;
  final String? requiredPermission;
  final bool isDanger;

  SettingsItem({
    required this.id,
    required this.icon,
    required this.label,
    required this.route,
    this.description,
    this.requiredPermission,
    this.isDanger = false,
  });
}

class SettingsSection {
  final String title;
  final List<SettingsItem> items;

  SettingsSection({
    required this.title,
    required this.items,
  });

  SettingsSection copyWith({String? title, List<SettingsItem>? items}) {
    return SettingsSection(
      title: title ?? this.title,
      items: items ?? this.items,
    );
  }
}
