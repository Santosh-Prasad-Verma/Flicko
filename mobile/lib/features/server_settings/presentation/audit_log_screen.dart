import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  final String serverId;

  const AuditLogScreen({super.key, required this.serverId});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _selectedFilter = 'All Actions';
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      var query = Supabase.instance.client
          .from('audit_logs')
          .select('*, profiles:actor_id(id, username, avatar)')
          .eq('server_id', widget.serverId);

      // Filtering logic based on typical action types
      if (_selectedFilter == 'Member Updates') {
        query = query.inFilter('action_type', ['ban', 'kick', 'timeout', 'mute', 'deafen', 'role_update', 'nickname_update']);
      } else if (_selectedFilter == 'Channel Updates') {
        query = query.inFilter('action_type', ['channel_create', 'channel_update', 'channel_delete']);
      } else if (_selectedFilter == 'Role Updates') {
        query = query.inFilter('action_type', ['role_create', 'role_update', 'role_delete']);
      }

      final response = await query.order('created_at', ascending: false).limit(100);
      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading audit logs: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Audit Log'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => ListView(
                  shrinkWrap: true,
                  children: ['All Actions', 'Member Updates', 'Channel Updates', 'Role Updates'].map((filter) {
                    return ListTile(
                      title: Text(filter, style: const TextStyle(color: Color(FlickoColors.textPrimary))),
                      trailing: _selectedFilter == filter ? const Icon(Icons.check, color: Color(FlickoColors.blurple)) : null,
                      onTap: () {
                        setState(() => _selectedFilter = filter);
                        Navigator.pop(context);
                        _loadLogs();
                      },
                    );
                  }).toList(),
                ),
                backgroundColor: const Color(FlickoColors.bgSecondary),
              );
            },
          ),
        ],
      ),
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(FlickoSpacing.md),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.bgSecondary),
                  borderRadius: BorderRadius.circular(FlickoRadius.md),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Color(FlickoColors.textSecondary), size: 20),
                    const SizedBox(width: FlickoSpacing.sm),
                    Expanded(
                      child: Text(
                        'Audit logs are kept for 90 days. Viewing $_selectedFilter.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: const Color(FlickoColors.textSecondary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Color(FlickoColors.blurple))),
            )
          else if (_logs.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No recent actions.',
                  style: TextStyle(color: Color(FlickoColors.textMuted)),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final log = _logs[index];
                  return _buildLogEntry(log, theme);
                },
                childCount: _logs.length,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log, ThemeData theme) {
    final actionType = log['action_type'] as String? ?? 'unknown';
    final String actionText = _formatActionType(actionType);
    final String targetId = log['target_id']?.toString() ?? 'target';
    
    // We try to use a target name from changes if present
    String target = targetId;
    final changes = log['changes'] as Map<String, dynamic>?;
    if (changes != null && changes.containsKey('name')) {
      target = changes['name'].toString();
    } else if (changes != null && changes.containsKey('target_name')) {
      target = changes['target_name'].toString();
    }

    final reason = log['reason'] as String?;
    final timestampStr = log['created_at'] as String?;
    final DateTime timestamp = timestampStr != null ? DateTime.parse(timestampStr) : DateTime.now();

    final profile = log['profiles'] as Map<String, dynamic>?;
    final username = profile?['username'] as String? ?? 'System';
    final avatar = profile?['avatar'] as String? ?? 'https://i.pravatar.cc/150';

    final int color = _getActionColor(actionType);
    final IconData icon = _getActionIcon(actionType);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: FlickoSpacing.md, vertical: FlickoSpacing.xs),
      padding: const EdgeInsets.all(FlickoSpacing.md),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(FlickoRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(avatar),
            radius: 18,
          ),
          const SizedBox(width: FlickoSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      username,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: const Color(FlickoColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: FlickoSpacing.xs),
                    Text(
                      '·',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(FlickoColors.textMuted),
                      ),
                    ),
                    const SizedBox(width: FlickoSpacing.xs),
                    Text(
                      _formatTimestamp(timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: const Color(FlickoColors.textMuted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: FlickoSpacing.xs),
                RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(FlickoColors.textSecondary),
                    ),
                    children: [
                      TextSpan(
                        text: actionText,
                        style: const TextStyle(
                          color: Color(FlickoColors.textPrimary),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: target,
                        style: TextStyle(
                          color: Color(color),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (reason != null && reason.isNotEmpty) ...[
                  const SizedBox(height: FlickoSpacing.xs),
                  Text(
                    'Reason: $reason',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: const Color(FlickoColors.textMuted),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            icon,
            color: const Color(FlickoColors.textMuted),
            size: 20,
          ),
        ],
      ),
    );
  }

  String _formatActionType(String type) {
    if (type.contains('_')) {
      final parts = type.split('_');
      return parts.map((e) => e.isNotEmpty ? '${e[0].toUpperCase()}${e.substring(1)}' : '').join(' ');
    }
    return type.isNotEmpty ? '${type[0].toUpperCase()}${type.substring(1)}' : 'Unknown';
  }

  int _getActionColor(String type) {
    if (type.contains('create') || type.contains('add')) {
      return FlickoColors.success;
    } else if (type.contains('delete') || type.contains('remove') || type.contains('ban') || type.contains('kick')) {
      return FlickoColors.danger;
    } else if (type.contains('timeout') || type.contains('warn')) {
      return FlickoColors.warning;
    } else {
      return FlickoColors.blurple;
    }
  }

  IconData _getActionIcon(String type) {
    if (type.contains('ban') || type.contains('kick')) return Icons.gavel;
    if (type.contains('timeout')) return Icons.timer;
    if (type.contains('role')) return Icons.shield;
    if (type.contains('channel')) return Icons.tag;
    if (type.contains('message')) return Icons.message;
    if (type.contains('user') || type.contains('member')) return Icons.person;
    if (type.contains('settings') || type.contains('update')) return Icons.settings;
    return Icons.info;
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      if (difference.inMinutes <= 0) return 'Just now';
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}
