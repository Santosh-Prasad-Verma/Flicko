import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';

/// Role Editor Screen
///
/// Edit a single role: name, color, hoist, mentionable, and permissions.
/// Route: /server/:serverId/settings/roles/:roleId
class RoleEditorScreen extends ConsumerStatefulWidget {
  final String serverId;
  final String roleId;
  const RoleEditorScreen({super.key, required this.serverId, required this.roleId});

  @override
  ConsumerState<RoleEditorScreen> createState() => _RoleEditorScreenState();
}

class _Permission {
  final String name;
  final String label;
  final String description;
  final String category;
  final bool dangerous;

  _Permission({
    required this.name,
    required this.label,
    required this.description,
    required this.category,
    this.dangerous = false,
  });
}

class _RoleEditorScreenState extends ConsumerState<RoleEditorScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _dirty = false;
  bool _isEveryone = false;

  String _name = '';
  String? _roleColor;
  bool _hoist = false;
  bool _mentionable = false;
  Map<String, bool> _permissions = {};

  final _client = Supabase.instance.client;

  final List<String> _colorPresets = [
    '#99AAB5', '#1ABC9C', '#2ECC71', '#3498DB', '#9B59B6',
    '#E91E63', '#F1C40F', '#E67E22', '#E74C3C', '#95A5A6',
    '#607D8B', '#11806A', '#1F8B4C', '#206694', '#71368A',
    '#AD1457', '#C27C0E', '#A84300', '#992D22', '#979C9F',
  ];

  final List<_Permission> _allPermissions = [
    _Permission(name: 'VIEW_CHANNELS', label: 'View Channels', description: 'View channels and read messages', category: 'general'),
    _Permission(name: 'MANAGE_CHANNELS', label: 'Manage Channels', description: 'Create, edit, delete channels', category: 'general', dangerous: true),
    _Permission(name: 'MANAGE_ROLES', label: 'Manage Roles', description: 'Create, edit, assign roles', category: 'general', dangerous: true),
    _Permission(name: 'MANAGE_GUILD', label: 'Manage Server', description: 'Change server name, icon, region', category: 'general', dangerous: true),
    _Permission(name: 'KICK_MEMBERS', label: 'Kick Members', description: 'Remove members from the server', category: 'membership', dangerous: true),
    _Permission(name: 'BAN_MEMBERS', label: 'Ban Members', description: 'Ban members from the server', category: 'membership', dangerous: true),
    _Permission(name: 'CREATE_INVITE', label: 'Create Invite', description: 'Generate invite links', category: 'membership'),
    _Permission(name: 'CHANGE_NICKNAME', label: 'Change Nickname', description: 'Change own nickname', category: 'membership'),
    _Permission(name: 'MANAGE_NICKNAMES', label: 'Manage Nicknames', description: 'Change other members\' nicknames', category: 'membership'),
    _Permission(name: 'SEND_MESSAGES', label: 'Send Messages', description: 'Send text messages', category: 'text'),
    _Permission(name: 'SEND_TTS_MESSAGES', label: 'Send TTS Messages', description: 'Send text-to-speech messages', category: 'text'),
    _Permission(name: 'MANAGE_MESSAGES', label: 'Manage Messages', description: 'Delete, pin other users\' messages', category: 'text', dangerous: true),
    _Permission(name: 'EMBED_LINKS', label: 'Embed Links', description: 'Send embedded content', category: 'text'),
    _Permission(name: 'ATTACH_FILES', label: 'Attach Files', description: 'Upload files and images', category: 'text'),
    _Permission(name: 'READ_MESSAGE_HISTORY', label: 'Read History', description: 'View past messages', category: 'text'),
    _Permission(name: 'MENTION_EVERYONE', label: 'Mention @everyone', description: 'Ping all members', category: 'text'),
    _Permission(name: 'USE_VOICE', label: 'Connect to Voice', description: 'Join voice channels', category: 'voice'),
    _Permission(name: 'SPEAK', label: 'Speak', description: 'Talk in voice channels', category: 'voice'),
    _Permission(name: 'VIDEO', label: 'Video', description: 'Share video in voice channels', category: 'voice'),
    _Permission(name: 'MUTE_MEMBERS', label: 'Mute Members', description: 'Mute other members in voice', category: 'voice'),
    _Permission(name: 'DEAFEN_MEMBERS', label: 'Deafen Members', description: 'Deafen other members in voice', category: 'voice'),
    _Permission(name: 'MOVE_MEMBERS', label: 'Move Members', description: 'Move members between voice channels', category: 'voice'),
    _Permission(name: 'ADMINISTRATOR', label: 'Administrator', description: 'Grants ALL permissions', category: 'advanced', dangerous: true),
  ];

  final Map<String, String> _categoryLabels = {
    'general': 'General Server Permissions',
    'membership': 'Membership Permissions',
    'text': 'Text Channel Permissions',
    'voice': 'Voice Channel Permissions',
    'advanced': 'Advanced Permissions',
  };

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    setState(() => _isLoading = true);
    try {
      final role = await _client
          .from('server_roles')
          .select('*')
          .eq('id', widget.roleId)
          .single();

      setState(() {
        _name = role['name'] as String;
        _roleColor = role['color'] as String?;
        _hoist = role['hoist'] as bool? ?? false;
        _mentionable = role['mentionable'] as bool? ?? false;
        _isEveryone = role['is_everyone'] as bool? ?? false;

        // Initialize permissions from stored data if available, otherwise false
        final storedPerms = role['permissions'] as Map<String, dynamic>? ?? {};
        _permissions = {for (final p in _allPermissions) p.name: storedPerms[p.name] as bool? ?? false};
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      await _client.from('server_roles').update({
        'name': _name.trim(),
        'color': _roleColor,
        'hoist': _hoist,
        'mentionable': _mentionable,
        'permissions': _permissions,
      }).eq('id', widget.roleId);

      setState(() {
        _dirty = false;
        _isSaving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Role saved')),
        );
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  void _togglePerm(String name) {
    if (name == 'ADMINISTRATOR' && !_permissions[name]!) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(FlickoColors.bgSecondary),
          title: Text(
            'Enable Administrator?',
            style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
          ),
          content: Text(
            'This grants ALL permissions and bypasses channel overrides.',
            style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted))),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _permissions[name] = !_permissions[name]!;
                  _dirty = true;
                });
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(FlickoColors.red)),
              child: Text('Enable', style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      setState(() {
        _permissions[name] = !_permissions[name]!;
        _dirty = true;
      });
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

    final categories = _categoryLabels.keys.toList();

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
        title: Text(
          'EDIT ROLE',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFC8FF00)))
                  : Text(
                      'SAVE',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFC8FF00),
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSectionHeader('ROLE NAME'),
          _buildTextField(),
          const SizedBox(height: 32),

          _buildSectionHeader('ROLE COLOR'),
          _buildColorPicker(),
          const SizedBox(height: 32),

          _buildSectionHeader('SETTINGS'),
          _buildSettingsCard([
            _buildToggleRow(
              'Display separately',
              'Show members separately in the list',
              _hoist,
              (v) => setState(() { _hoist = v; _dirty = true; }),
            ),
            _buildToggleRow(
              'Allow @mention',
              'Allow anyone to mention this role',
              _mentionable,
              (v) => setState(() { _mentionable = v; _dirty = true; }),
            ),
          ]),
          const SizedBox(height: 32),

          ...categories.expand((cat) {
            final catPerms = _allPermissions.where((p) => p.category == cat).toList();
            if (catPerms.isEmpty) return <Widget>[];
            return [
              _buildSectionHeader(_categoryLabels[cat]!.toUpperCase()),
              _buildSettingsCard(
                catPerms.map((perm) {
                  final enabled = _permissions[perm.name] ?? false;
                  return _buildToggleRow(
                    perm.label,
                    perm.description,
                    enabled,
                    (_) => _togglePerm(perm.name),
                    isDangerous: perm.dangerous,
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
            ];
          }),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: Colors.white.withValues(alpha: 0.4),
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: TextField(
        controller: TextEditingController(text: _name)..selection = TextSelection.collapsed(offset: _name.length),
        onChanged: (v) { _name = v; _dirty = true; setState(() {}); },
        enabled: !_isEveryone,
        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: 'Role name',
          hintStyle: GoogleFonts.inter(color: Colors.white10),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  Widget _buildColorPicker() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          ..._colorPresets.map((c) {
            final color = Color(int.parse(c.replaceFirst('#', '0xFF')));
            final isSelected = _roleColor == c;
            return GestureDetector(
              onTap: () => setState(() { _roleColor = c; _dirty = true; }),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                  border: isSelected ? Border.all(color: Colors.white, width: 3) : null,
                  boxShadow: isSelected ? [
                    BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 2),
                  ] : null,
                ),
                child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
              ),
            );
          }),
          GestureDetector(
            onTap: () => setState(() { _roleColor = null; _dirty = true; }),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white10),
              ),
              child: const Icon(Icons.close, size: 20, color: Colors.white24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildToggleRow(String label, String description, bool value, ValueChanged<bool> onChanged, {bool isDangerous = false}) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: isDangerous && value ? Colors.redAccent : Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: const Color(0xFFC8FF00),
            activeThumbColor: Colors.black,
            inactiveTrackColor: Colors.white10,
          ),
        ],
      ),
    );
  }
}
