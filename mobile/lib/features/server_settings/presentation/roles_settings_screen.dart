import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final response = await _client
          .from('server_roles')
          .select('*')
          .eq('server_id', widget.serverId)
          .order('position', ascending: false);

      if (mounted) {
        setState(() {
          _roles = (response as List)
              .map((r) => _ServerRole.fromJson(r as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createRole() async {
    final name = _newRoleName.trim();
    if (name.isEmpty) return;

    setState(() => _isSubmitting = true);
    try {
      await _client.from('server_roles').insert({
        'server_id': widget.serverId,
        'name': name,
        'position': _roles.length,
        'color': '#C8FF00',
      });

      if (mounted) {
        setState(() {
          _showCreate = false;
          _newRoleName = '';
        });
        await _loadRoles();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating role: $e'), backgroundColor: Colors.redAccent),
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
    
    setState(() {});

    try {
      for (int i = 0; i < _roles.length; i++) {
        if (_roles[i].position != _roles.length - i) {
          await _client.from('server_roles').update({
            'position': _roles.length - i,
          }).eq('id', _roles[i].id);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving positions: $e'), backgroundColor: Colors.redAccent),
        );
      }
      await _loadRoles();
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
        backgroundColor: const Color(0xFF0D0D0D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'DELETE ROLE',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 1,
          ),
        ),
        content: Text(
          'Are you sure you want to delete "${role.name}"?',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('CANCEL', style: GoogleFonts.inter(color: Colors.white24, fontWeight: FontWeight.w800)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('DELETE', style: GoogleFonts.inter(color: Colors.redAccent, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _client.from('server_roles').delete().eq('id', role.id);
      await _loadRoles();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting role: $e'), backgroundColor: Colors.redAccent),
        );
      }
    }
  }

  Color _parseColor(String? colorStr) {
    if (colorStr == null || colorStr.isEmpty) return const Color(0xFFC8FF00);
    try {
      return Color(int.parse(colorStr.replaceAll('#', '0xFF')));
    } catch (_) {
      return const Color(0xFFC8FF00);
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'ROLES',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
            letterSpacing: 2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFFC8FF00)),
            onPressed: () => setState(() => _showCreate = true),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC8FF00)))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0D0D),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFC8FF00).withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Color(0xFFC8FF00), size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Drag to reorder roles. Higher roles have priority.',
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
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
      bottomSheet: _showCreate ? _buildCreateSheet() : null,
    );
  }

  Widget _buildRoleTile(_ServerRole role, {Key? key}) {
    final color = _parseColor(role.color);

    return Container(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: ListTile(
        onTap: () => context.push('/server/${widget.serverId}/settings/roles/${role.id}'),
        onLongPress: () => _deleteRole(role),
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8),
            ],
          ),
        ),
        title: Text(
          role.name,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          '${role.position} permissions configured',
          style: GoogleFonts.inter(
            color: Colors.white24,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.drag_indicator_rounded, color: Colors.white12),
      ),
    );
  }

  Widget _buildCreateSheet() {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 24,
        left: 24,
        right: 24,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0D0D0D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'NEW ROLE',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.5,
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _showCreate = false),
                icon: const Icon(Icons.close_rounded, color: Colors.white24),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (v) => setState(() => _newRoleName = v),
              autofocus: true,
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'Role name...',
                hintStyle: GoogleFonts.inter(color: Colors.white10),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 20),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _newRoleName.trim().isEmpty || _isSubmitting ? null : _createRole,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC8FF00),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.black)
                  : Text(
                      'CREATE ROLE',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w900, letterSpacing: 1),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
