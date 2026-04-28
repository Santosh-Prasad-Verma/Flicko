import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

/// Per-Server Profile Selector
///
/// Lists all servers the user is a member of, allowing them
/// to customise their nickname per-server.
/// Route: /u/settings/server-profiles
class ServerProfilesScreen extends ConsumerStatefulWidget {
  const ServerProfilesScreen({super.key});

  @override
  ConsumerState<ServerProfilesScreen> createState() => _ServerProfilesScreenState();
}

class _ServerProfile {
  final String id;
  final String name;
  final String? icon;
  final String? nickname;

  _ServerProfile({required this.id, required this.name, this.icon, this.nickname});
}

class _ServerProfilesScreenState extends ConsumerState<ServerProfilesScreen> {
  bool _isLoading = true;
  List<_ServerProfile> _servers = [];
  String? _editingServerId;
  String _nicknameInput = '';

  final _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadServers();
  }

  Future<void> _loadServers() async {
    setState(() => _isLoading = true);
    try {
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await _client
          .from('server_members')
          .select('server_id, nickname, servers(id, name, icon)')
          .eq('user_id', userId);

      setState(() {
        _servers = (response as List).map((d) => _ServerProfile(
          id: d['servers']['id'] as String,
          name: d['servers']['name'] as String,
          icon: d['servers']['icon'] as String?,
          nickname: d['nickname'] as String?,
        )).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNickname(String serverId) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    try {
      await _client
          .from('server_members')
          .update({'nickname': _nicknameInput.trim().isEmpty ? null : _nicknameInput.trim()})
          .eq('server_id', serverId)
          .eq('user_id', userId);

      setState(() {
        _editingServerId = null;
        _nicknameInput = '';
      });
      await _loadServers();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Server Profiles',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.blurple)))
          : _servers.isEmpty
              ? _buildEmptyState()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      'Set a unique nickname for each server. Other members will see this name instead of your global display name.',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textSecondary),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._servers.map((server) => _buildServerCard(server)),
                  ],
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.dns_outlined, size: 48, color: Color(FlickoColors.textMuted)),
          const SizedBox(height: 16),
          Text(
            "You're not in any servers yet",
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerCard(_ServerProfile server) {
    final isEditing = _editingServerId == server.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              UserAvatar(
                imageUrl: server.icon,
                name: server.name,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      server.name,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      server.nickname != null
                          ? 'Nickname: ${server.nickname}'
                          : 'No server nickname set',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textSecondary),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (!isEditing)
                IconButton(
                  icon: const Icon(Icons.edit, size: 18, color: Color(FlickoColors.textSecondary)),
                  onPressed: () => setState(() {
                    _editingServerId = server.id;
                    _nicknameInput = server.nickname ?? '';
                  }),
                ),
            ],
          ),
          if (isEditing) ...[
            const SizedBox(height: 12),
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _nicknameInput = v),
              controller: TextEditingController(text: _nicknameInput)
                ..selection = TextSelection.collapsed(offset: _nicknameInput.length),
              style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
              decoration: InputDecoration(
                hintText: 'Server nickname',
                hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                filled: true,
                fillColor: const Color(FlickoColors.bgTertiary),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
              maxLength: 32,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    _editingServerId = null;
                    _nicknameInput = '';
                  }),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _saveNickname(server.id),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(FlickoColors.blurple),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Save', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
