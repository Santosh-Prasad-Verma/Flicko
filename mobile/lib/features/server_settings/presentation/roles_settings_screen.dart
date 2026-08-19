import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Role data model for server roles
class _ServerRole {
  final String id;
  final String name;
  final String? color;
  final int position;
  final bool hoist;
  final bool mentionable;
  final bool isEveryone;

  _ServerRole({
    required this.id,
    required this.name,
    this.color,
    required this.position,
    this.hoist = false,
    this.mentionable = false,
    this.isEveryone = false,
  });

  factory _ServerRole.fromJson(Map<String, dynamic> json) {
    return _ServerRole(
      id: json['id'] as String,
      name: json['name'] as String,
      color: json['color'] as String?,
      position: json['position'] as int? ?? 0,
      hoist: json['hoist'] as bool? ?? false,
      mentionable: json['mentionable'] as bool? ?? false,
      isEveryone: json['is_everyone'] as bool? ?? false,
    );
  }
}

/// Roles Settings Screen
///
/// Lists all server roles, allows create/delete, and navigates to role editor.
/// Route: /server/:serverId/settings/roles
class RolesSettingsScreen extends ConsumerStatefulWidget {
  final String serverId;

  const RolesSettingsScreen({super.key, required this.serverId});

  @override
  ConsumerState<RolesSettingsScreen> createState() => _RolesSettingsScreenState();
}

class _RolesSettingsScreenState extends ConsumerState<RolesSettingsScreen> {
  bool _isLoading = true;
  List<_ServerRole> _roles = [];
  bool _showCreate = false;
  bool _isSubmitting = false;
  String _newRoleName = '';

  final _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadRoles();
  }

  Future<void> _loadRoles() async {
    setState(() => _isLoading = true);
    try {
      final response = await _client
          .from('roles')
          .select('*')
          .eq('server_id', widget.serverId)
          .order('position', ascending: false);

      setState(() {
        _roles = (response as List)
            .map((r) => _ServerRole.fromJson(r as Map<String, dynamic>))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _createRole() async {
    final name = _newRoleName.trim();
    if (name.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await _client.from('roles').insert({
        'server_id': widget.serverId,
        'name': name,
        'position': _roles.length,
        'color': '#99AAB5',
      });

      setState(() {
        _showCreate = false;
        _newRoleName = '';
      });
      await _loadRoles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating role: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    
    final item = _roles.removeAt(oldIndex);
    _roles.insert(newIndex, item);
    
    // Optimistic UI update
    setState(() {});

    try {
      // Create batch updates
      final updates = <Map<String, dynamic>>[];
      for (int i = 0; i < _roles.length; i++) {
        // Only update if position actually changed
        if (_roles[i].position != _roles.length - i) {
          updates.add({
            'id': _roles[i].id,
            'position': _roles.length - i,
          });
        }
      }

      if (updates.isNotEmpty) {
        for (var update in updates) {
           await _client.from('roles').update({
             'position': update['position'],
           }).eq('id', update['id']);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving role positions: $e')),
        );
      }
      await _loadRoles(); // Revert
    }
  }

  Future<void> _deleteRole(_ServerRole role) async {
    if (role.isEveryone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The @everyone role cannot be deleted.')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Delete Role',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${role.name}"? This will remove the role from all members.',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(FlickoColors.red)),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _client.from('roles').delete().eq('id', role.id);
      await _loadRoles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting role: $e')),
        );
      }
    }
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return const Color(FlickoColors.textMuted);
    try {
      return Color(int.parse(colorStr.replaceAll('#', '0xFF')));
    } catch (_) {
      return const Color(FlickoColors.textMuted);
    }
  }

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
          'Roles',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Color(FlickoColors.blurple)),
            onPressed: () => setState(() => _showCreate = true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.blurple)))
          : Column(
              children: [
                // Help text
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Roles are listed from highest to lowest. Members get permissions from all their roles. Tap a role to edit, long-press to delete.',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ),

                // Role list
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _roles.length,
                    onReorder: _onReorder,
                    itemBuilder: (context, index) {
                      final role = _roles[index];
                      return _buildRoleTile(role, key: ValueKey(role.id));
                    },
                  ),
                ),
              ],
            ),

      // Create Role Bottom Sheet
      bottomSheet: _showCreate ? _buildCreateSheet() : null,
    );
  }

  Widget _buildRoleTile(_ServerRole role, {Key? key}) {
    final color = _parseColor(role.color);

    return InkWell(
      key: key,
      onTap: () {
        context.push('/server/${widget.serverId}/settings/roles/${role.id}');
      },
      onLongPress: () => _deleteRole(role),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgSecondary),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            // Drag handle
            const Icon(Icons.drag_indicator, color: Color(FlickoColors.textMuted), size: 18),
            const SizedBox(width: 8),

            // Color indicator
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),

            // Role info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    role.name,
                    style: GoogleFonts.inter(
                      color: color,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Position: ${role.position}${role.hoist ? ' · Hoisted' : ''}${role.mentionable ? ' · Mentionable' : ''}',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

            // Everyone badge
            if (role.isEveryone)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.bgTertiary),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'DEFAULT',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: Color(FlickoColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreateSheet() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.textMuted),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Create Role',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              onChanged: (v) => setState(() => _newRoleName = v),
              autofocus: true,
              style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
              decoration: InputDecoration(
                hintText: 'Role name',
                hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                filled: true,
                fillColor: const Color(FlickoColors.bgTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => setState(() => _showCreate = false),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(FlickoColors.bgTertiary),
                      foregroundColor: const Color(FlickoColors.textPrimary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text('Cancel', style: GoogleFonts.inter()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _newRoleName.trim().isEmpty || _isSubmitting ? null : _createRole,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(FlickoColors.blurple),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      disabledBackgroundColor: const Color(FlickoColors.bgTertiary),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : Text('Create', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
