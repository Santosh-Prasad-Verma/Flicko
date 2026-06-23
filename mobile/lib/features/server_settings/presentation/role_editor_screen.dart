import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Role Editor Screen
///
/// Edit a single role: name, color, hoist, mentionable, and permissions.
/// Permissions are stored as a bigint bitmask in the database.
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
  final int bit; // Bit position (0-indexed)
  final bool dangerous;

  _Permission({
    required this.name,
    required this.label,
    required this.description,
    required this.category,
    required this.bit,
    this.dangerous = false,
  });
}

class _RoleEditorScreenState extends ConsumerState<RoleEditorScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _dirty = false;

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

  /// Permission definitions with their corresponding bit positions.
  /// These mirror Discord's permission bitmask layout.
  final List<_Permission> _allPermissions = [
    _Permission(name: 'VIEW_CHANNELS', label: 'View Channels', description: 'View channels and read messages', category: 'general', bit: 0),
    _Permission(name: 'MANAGE_CHANNELS', label: 'Manage Channels', description: 'Create, edit, delete channels', category: 'general', bit: 1, dangerous: true),
    _Permission(name: 'MANAGE_ROLES', label: 'Manage Roles', description: 'Create, edit, assign roles', category: 'general', bit: 2, dangerous: true),
    _Permission(name: 'MANAGE_GUILD', label: 'Manage Server', description: 'Change server name, icon, region', category: 'general', bit: 3, dangerous: true),
    _Permission(name: 'KICK_MEMBERS', label: 'Kick Members', description: 'Remove members from the server', category: 'membership', bit: 4, dangerous: true),
    _Permission(name: 'BAN_MEMBERS', label: 'Ban Members', description: 'Ban members from the server', category: 'membership', bit: 5, dangerous: true),
    _Permission(name: 'CREATE_INVITE', label: 'Create Invite', description: 'Generate invite links', category: 'membership', bit: 6),
    _Permission(name: 'CHANGE_NICKNAME', label: 'Change Nickname', description: 'Change own nickname', category: 'membership', bit: 7),
    _Permission(name: 'MANAGE_NICKNAMES', label: 'Manage Nicknames', description: 'Change other members\' nicknames', category: 'membership', bit: 8),
    _Permission(name: 'SEND_MESSAGES', label: 'Send Messages', description: 'Send text messages', category: 'text', bit: 9),
    _Permission(name: 'SEND_TTS_MESSAGES', label: 'Send TTS Messages', description: 'Send text-to-speech messages', category: 'text', bit: 10),
    _Permission(name: 'MANAGE_MESSAGES', label: 'Manage Messages', description: 'Delete, pin other users\' messages', category: 'text', bit: 11, dangerous: true),
    _Permission(name: 'EMBED_LINKS', label: 'Embed Links', description: 'Send embedded content', category: 'text', bit: 12),
    _Permission(name: 'ATTACH_FILES', label: 'Attach Files', description: 'Upload files and images', category: 'text', bit: 13),
    _Permission(name: 'READ_MESSAGE_HISTORY', label: 'Read History', description: 'View past messages', category: 'text', bit: 14),
    _Permission(name: 'MENTION_EVERYONE', label: 'Mention @everyone', description: 'Ping all members', category: 'text', bit: 15),
    _Permission(name: 'USE_VOICE', label: 'Connect to Voice', description: 'Join voice channels', category: 'voice', bit: 16),
    _Permission(name: 'SPEAK', label: 'Speak', description: 'Talk in voice channels', category: 'voice', bit: 17),
    _Permission(name: 'VIDEO', label: 'Video', description: 'Share video in voice channels', category: 'voice', bit: 18),
    _Permission(name: 'MUTE_MEMBERS', label: 'Mute Members', description: 'Mute other members in voice', category: 'voice', bit: 19),
    _Permission(name: 'DEAFEN_MEMBERS', label: 'Deafen Members', description: 'Deafen other members in voice', category: 'voice', bit: 20),
    _Permission(name: 'MOVE_MEMBERS', label: 'Move Members', description: 'Move members between voice channels', category: 'voice', bit: 21),
    _Permission(name: 'ADMINISTRATOR', label: 'Administrator', description: 'Grants ALL permissions', category: 'advanced', bit: 31, dangerous: true),
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

  /// Decode a bigint bitmask into a Map<String, bool> of permission states.
  Map<String, bool> _decodeBitmask(int bitmask) {
    final result = <String, bool>{};
    for (final p in _allPermissions) {
      result[p.name] = (bitmask & (1 << p.bit)) != 0;
    }
    return result;
  }

  /// Encode a Map<String, bool> of permission states into a bigint bitmask.
  int _encodeBitmask(Map<String, bool> permissions) {
    int bitmask = 0;
    for (final p in _allPermissions) {
      if (permissions[p.name] == true) {
        bitmask |= (1 << p.bit);
      }
    }
    return bitmask;
  }

  Future<void> _loadRole() async {
    setState(() => _isLoading = true);
    try {
      final role = await _client
          .from('roles')
          .select('*')
          .eq('id', widget.roleId)
          .single();

      setState(() {
        _name = role['name'] as String;
        _roleColor = role['color'] as String?;
        _hoist = role['hoist'] as bool? ?? false;
        _mentionable = role['mentionable'] as bool? ?? false;

        // Decode permissions bitmask from bigint
        final rawPerms = role['permissions'];
        int bitmask = 0;
        if (rawPerms is int) {
          bitmask = rawPerms;
        } else if (rawPerms is String) {
          bitmask = int.tryParse(rawPerms) ?? 0;
        }
        _permissions = _decodeBitmask(bitmask);
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading role: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      // Encode permissions back to bigint bitmask
      final bitmask = _encodeBitmask(_permissions);

      await _client.from('roles').update({
        'name': _name.trim(),
        'color': _roleColor,
        'hoist': _hoist,
        'mentionable': _mentionable,
        'permissions': bitmask,
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
        backgroundColor: Color(FlickoColors.bgPrimary),
        body: Center(child: CircularProgressIndicator(color: Color(FlickoColors.brandLime))),
      );
    }

    final isAdmin = _permissions['ADMINISTRATOR'] ?? false;
    final categories = _categoryLabels.keys.toList();

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
          'Edit Role',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (_dirty)
            TextButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('Save', style: GoogleFonts.inter(color: const Color(FlickoColors.green), fontWeight: FontWeight.w600)),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Role Name
          _buildSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ROLE NAME', style: _sectionLabelStyle()),
                const SizedBox(height: 8),
                TextField(
                  controller: TextEditingController(text: _name)..selection = TextSelection.collapsed(offset: _name.length),
                  onChanged: (v) { setState(() { _name = v; _dirty = true; }); },
                  style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                  decoration: InputDecoration(
                    hintText: 'Role name',
                    hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                    filled: true,
                    fillColor: const Color(FlickoColors.bgTertiary),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  maxLength: 100,
                ),
              ],
            ),
          ),

          // Role Color
          _buildSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ROLE COLOR', style: _sectionLabelStyle()),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._colorPresets.map((c) => GestureDetector(
                      onTap: () => setState(() { _roleColor = c; _dirty = true; }),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: Color(int.parse(c.replaceFirst('#', '0xFF'))),
                          shape: BoxShape.circle,
                          border: _roleColor == c ? Border.all(color: Colors.white, width: 3) : null,
                        ),
                      ),
                    )),
                    GestureDetector(
                      onTap: () => setState(() { _roleColor = null; _dirty = true; }),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(FlickoColors.bgTertiary),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(FlickoColors.textMuted)),
                        ),
                        child: const Icon(Icons.close, size: 14, color: Color(FlickoColors.textMuted)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Toggles
          _buildSection(
            child: Column(
              children: [
                _buildToggleRow(
                  'Display role members separately',
                  'Members with this role will be shown separately in the member list',
                  _hoist,
                  (v) => setState(() { _hoist = v; _dirty = true; }),
                ),
                Divider(height: 1, color: const Color(FlickoColors.bgTertiary)),
                _buildToggleRow(
                  'Allow anyone to @mention this role',
                  'Members can mention this role in messages',
                  _mentionable,
                  (v) => setState(() { _mentionable = v; _dirty = true; }),
                ),
              ],
            ),
          ),

          // Admin warning
          if (isAdmin)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x14FAA61A),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, size: 16, color: Color(0xFFFAA61A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Administrator permission grants ALL permissions and bypasses channel overrides.',
                      style: GoogleFonts.inter(color: const Color(0xFFFAA61A), fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Permissions by category
          ...categories.expand((cat) {
            final catPerms = _allPermissions.where((p) => p.category == cat).toList();
            if (catPerms.isEmpty) return <Widget>[];
            return [
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  _categoryLabels[cat]!.toUpperCase(),
                  style: _sectionLabelStyle(),
                ),
              ),
              _buildSection(
                child: Column(
                  children: catPerms.asMap().entries.map((entry) {
                    final perm = entry.value;
                    final enabled = _permissions[perm.name] ?? false;
                    return Column(
                      children: [
                        if (entry.key > 0) Divider(height: 1, color: const Color(FlickoColors.bgTertiary)),
                        _buildToggleRow(
                          '${perm.label}${perm.dangerous ? ' ⚠️' : ''}',
                          perm.description,
                          enabled,
                          (_) => _togglePerm(perm.name),
                          isDangerous: perm.dangerous && enabled,
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
            ];
          }),
        ],
      ),
    );
  }

  Widget _buildSection({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  TextStyle _sectionLabelStyle() {
    return GoogleFonts.inter(
      color: const Color(FlickoColors.textMuted),
      fontSize: 11,
      fontWeight: FontWeight.bold,
      letterSpacing: 0.5,
    );
  }

  Widget _buildToggleRow(String label, String description, bool value, ValueChanged<bool> onChanged, {bool isDangerous = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: isDangerous ? const Color(FlickoColors.red) : const Color(FlickoColors.textPrimary),
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: isDangerous ? const Color(FlickoColors.red) : const Color(FlickoColors.brandLime),
          ),
        ],
      ),
    );
  }
}
