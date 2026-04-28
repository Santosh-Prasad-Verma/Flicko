import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';
import 'widgets/user_timeout_bottom_sheet.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

/// Server Member List Screen
///
/// Shows all members of a server grouped by role/status.
/// Route: /server/:serverId/members
class ServerMembersScreen extends ConsumerStatefulWidget {
  final String serverId;
  const ServerMembersScreen({super.key, required this.serverId});

  @override
  ConsumerState<ServerMembersScreen> createState() => _ServerMembersScreenState();
}

class _Member {
  final String id;
  final String userId;
  final String? displayName;
  final String username;
  final String? avatarUrl;
  final String? status;
  final String? customStatus;
  final String roleLabel;
  final DateTime? timeoutUntil;

  _Member({
    required this.id,
    required this.userId,
    this.displayName,
    required this.username,
    this.avatarUrl,
    this.status,
    this.customStatus,
    required this.roleLabel,
    this.timeoutUntil,
  });
}

class _ServerMembersScreenState extends ConsumerState<ServerMembersScreen> {
  bool _isLoading = true;
  bool _canModerate = false;
  List<_Member> _members = [];
  final _client = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    setState(() => _isLoading = true);
    try {
      final server = await _client
          .from('servers')
          .select('owner_id')
          .eq('id', widget.serverId)
          .single();
      final ownerId = server['owner_id'] as String?;

      final adminRoles = await _client
          .from('roles')
          .select('id')
          .eq('server_id', widget.serverId)
          .ilike('name', '%admin%');
      final adminRoleIds = (adminRoles as List).map((r) => r['id'] as String).toSet();

      final data = await _client
          .from('server_members')
          .select('id, user_id, roles, timeout_until, profiles!user_id(id, username, display_name, avatar, status, custom_status)')
          .eq('server_id', widget.serverId);

      final currentUserId = ref.read(currentUserIdProvider);
      bool canMod = false;

      setState(() {
        _members = (data as List).map((m) {
          final profile = m['profiles'];
          final roles = (m['roles'] as List<dynamic>?) ?? [];
          String roleLabel = 'Member';
          
          final isOwner = ownerId == m['user_id'];
          final isAdmin = roles.any((rid) => adminRoleIds.contains(rid));
          
          if (isOwner) {
            roleLabel = 'Owner';
          } else if (isAdmin) {
            roleLabel = 'Admin';
          }
          
          if (m['user_id'] == currentUserId) {
            canMod = isOwner || isAdmin;
          }

          return _Member(
            id: m['id'] as String,
            userId: m['user_id'] as String,
            username: profile?['username'] as String? ?? 'Unknown',
            displayName: profile?['display_name'] as String?,
            avatarUrl: profile?['avatar'] as String?,
            status: profile?['status'] as String?,
            customStatus: profile?['custom_status'] as String?,
            roleLabel: roleLabel,
            timeoutUntil: m['timeout_until'] != null ? DateTime.tryParse(m['timeout_until'] as String) : null,
          );
        }).toList();
        _canModerate = canMod;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  List<_Member> get _sortedMembers {
    final order = {'Owner': 0, 'Admin': 1, 'Member': 2};
    return [..._members]..sort((a, b) => order[a.roleLabel]!.compareTo(order[b.roleLabel]!));
  }

  Map<String, List<_Member>> get _groupedMembers {
    final grouped = <String, List<_Member>>{};
    for (final m in _sortedMembers) {
      grouped.putIfAbsent(m.roleLabel, () => []).add(m);
    }
    final order = ['Owner', 'Admin', 'Member'];
    final result = <String, List<_Member>>{};
    for (final key in order) {
      if (grouped.containsKey(key)) result[key] = grouped[key]!;
    }
    return result;
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'online': return const Color(0xFF43b581);
      case 'idle': return const Color(0xFFFAA61A);
      case 'dnd': return const Color(0xFFED4245);
      default: return const Color(0xFF72767d);
    }
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupedMembers;
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFF232428))),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
                    onPressed: () => context.pop(),
                  ),
                  Expanded(
                    child: Text(
                      'Members',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.person_add_outlined, color: Color(FlickoColors.blurple)),
                    onPressed: () => context.push('/server/${widget.serverId}/settings/invites'),
                  ),
                ],
              ),
            ),
            // List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.blurple)))
                  : _members.isEmpty
                      ? Center(
                          child: Text(
                            'No members',
                            style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: grouped.entries.fold<int>(0, (sum, e) => sum + e.value.length + 1),
                          itemBuilder: (context, index) {
                            int current = 0;
                            for (final entry in grouped.entries) {
                              if (index == current) {
                                return Padding(
                                  padding: const EdgeInsets.only(left: 4, top: 8, bottom: 4),
                                  child: Text(
                                    '${entry.key} — ${entry.value.length}',
                                    style: GoogleFonts.inter(
                                      color: const Color(FlickoColors.textMuted),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                );
                              }
                              current++;
                              for (final member in entry.value) {
                                if (index == current) {
                                  return _buildMemberRow(member);
                                }
                                current++;
                              }
                            }
                            return const SizedBox.shrink();
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  void _onMemberTap(_Member member) {
    if (!_canModerate || member.userId == ref.read(currentUserIdProvider)) {
      context.push('/u/${member.userId}');
      return;
    }

    final isTimedOut = member.timeoutUntil != null && member.timeoutUntil!.isAfter(DateTime.now());

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(FlickoColors.bgSecondary),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Manage ${member.displayName ?? member.username}',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline, color: Color(FlickoColors.textPrimary)),
                title: Text('View Profile', style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary))),
                onTap: () {
                  context.pop();
                  context.push('/u/${member.userId}');
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined, color: Color(FlickoColors.textPrimary)),
                title: Text(isTimedOut ? 'Remove Timeout' : 'Timeout', style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary))),
                onTap: () async {
                  context.pop();
                  // We need to import UserTimeoutBottomSheet at the top
                  await UserTimeoutBottomSheet.show(
                    context,
                    serverId: widget.serverId,
                    userId: member.userId,
                    username: member.displayName ?? member.username,
                    currentTimeout: member.timeoutUntil,
                  );
                  _loadMembers();
                },
              ),
              ListTile(
                leading: const Icon(Icons.person_remove_outlined, color: Color(FlickoColors.danger)),
                title: Text('Kick from Server', style: GoogleFonts.inter(color: const Color(FlickoColors.danger))),
                onTap: () {
                  context.pop();
                  _showKickBanDialog(member, isBan: false);
                },
              ),
              ListTile(
                leading: const Icon(Icons.gavel_outlined, color: Color(FlickoColors.danger)),
                title: Text('Ban from Server', style: GoogleFonts.inter(color: const Color(FlickoColors.danger))),
                onTap: () {
                  context.pop();
                  _showKickBanDialog(member, isBan: true);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showKickBanDialog(_Member member, {required bool isBan}) async {
    final action = isBan ? 'Ban' : 'Kick';
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text('$action Member', style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary))),
        content: Text(
          'Are you sure you want to $action ${member.displayName ?? member.username}?${isBan ? ' They will not be able to rejoin.' : ''}',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted))),
          ),
          TextButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.of(context).pop();
              try {
                if (isBan) {
                  await _client.from('bans').insert({
                    'server_id': widget.serverId,
                    'user_id': member.userId,
                    'banned_by': ref.read(currentUserIdProvider),
                    'reason': 'Banned via Moderator UI',
                  });
                }
                
                // Kick logic (applies to both kick and ban)
                await _client
                    .from('server_members')
                    .delete()
                    .eq('server_id', widget.serverId)
                    .eq('user_id', member.userId);
                    
                await _client
                    .from('member_roles')
                    .delete()
                    .eq('server_id', widget.serverId)
                    .eq('user_id', member.userId);
                    
                _loadMembers();
              } catch (e) {
                if (context.mounted) {
                  messenger.showSnackBar(SnackBar(content: Text('Failed to $action: $e')));
                }
              }
            },
            child: Text(action, style: GoogleFonts.inter(color: const Color(FlickoColors.danger), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberRow(_Member member) {
    final displayName = member.displayName ?? member.username;
    final isTimedOut = member.timeoutUntil != null && member.timeoutUntil!.isAfter(DateTime.now());

    return InkWell(
      onTap: () => _onMemberTap(member),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            UserAvatar(
              imageUrl: member.avatarUrl,
              name: displayName,
              status: member.status,
              size: 36,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: GoogleFonts.inter(
                            color: member.roleLabel == 'Owner'
                                ? const Color(FlickoColors.blurple)
                                : const Color(FlickoColors.textPrimary),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isTimedOut)
                        const Padding(
                          padding: EdgeInsets.only(left: 4.0),
                          child: Icon(Icons.timer_outlined, size: 14, color: Color(FlickoColors.warning)),
                        ),
                    ],
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _statusColor(member.status),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          member.customStatus != null && member.customStatus!.trim().isNotEmpty
                              ? member.customStatus!
                              : (member.status == 'online'
                                  ? 'Online'
                                  : member.status == 'idle'
                                      ? 'Idle'
                                      : 'Offline'),
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textMuted),
                            fontSize: 12,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (member.roleLabel == 'Owner')
              const Icon(Icons.shield, size: 16, color: Color(FlickoColors.blurple)),
            if (_canModerate && member.userId != ref.read(currentUserIdProvider))
               const Icon(Icons.more_vert, size: 18, color: Color(FlickoColors.textMuted)),
          ],
        ),
      ),
    );
  }
}
