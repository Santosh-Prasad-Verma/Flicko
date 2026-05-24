import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      var query = Supabase.instance.client
          .from('audit_log')
          .select('*, profiles:user_id(id, username, avatar)')
          .eq('server_id', widget.serverId);

      if (_selectedFilter == 'Member Updates') {
        query = query.inFilter('action', [
          'ban',
          'kick',
          'timeout',
          'mute',
          'deafen',
          'role_update',
          'nickname_update'
        ]);
      } else if (_selectedFilter == 'Channel Updates') {
        query = query.inFilter('action',
            ['channel_create', 'channel_update', 'channel_delete']);
      } else if (_selectedFilter == 'Role Updates') {
        query = query.inFilter('action',
            ['role_create', 'role_update', 'role_delete']);
      }

      final response =
          await query.order('created_at', ascending: false).limit(100);

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
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
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
          icon: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
          onPressed: () => context.pop(),
        ),
        centerTitle: true,
        title: Column(
          children: [
            Text(
              'Audit Log',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            Text(
              _selectedFilter,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.brandLime),
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(FlickoColors.brandLime)),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(FlickoColors.brandLime)))
          : _logs.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) => _buildLogEntry(_logs[index]),
                ),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log) {
    final profile = log['profiles'] as Map<String, dynamic>?;
    final username = profile?['username'] as String? ?? 'System';
    final avatar = profile?['avatar'] as String?;
    final actionType = log['action'] as String? ?? 'unknown';
    final timestamp = DateTime.parse(log['created_at']);
    final Color actionColor = _getActionColor(actionType);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(FlickoColors.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgTertiary),
              borderRadius: BorderRadius.circular(12),
              image: avatar != null
                  ? DecorationImage(
                      image: NetworkImage(avatar), fit: BoxFit.cover)
                  : null,
            ),
            child: avatar == null
                ? const Icon(Icons.person_rounded, color: Color(FlickoColors.brandLime), size: 20)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      username,
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textPrimary),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _formatTime(timestamp),
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 13),
                    children: [
                      TextSpan(
                        text: _formatActionType(actionType),
                        style: GoogleFonts.inter(
                          color: actionColor,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: _getTargetName(log),
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textPrimary),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (log['reason'] != null && (log['reason'] as String).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(FlickoColors.bgPrimary),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(FlickoColors.border)),
                    ),
                    child: Text(
                      log['reason'],
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.textMuted),
                        fontSize: 12,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Color(FlickoColors.bgSecondary),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(FlickoColors.textMuted),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Filter Actions',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 20),
            ...['All Actions', 'Member Updates', 'Channel Updates', 'Role Updates']
                .map((filter) {
              final isSelected = _selectedFilter == filter;
              return InkWell(
                onTap: () {
                  setState(() => _selectedFilter = filter);
                  context.pop();
                  _loadLogs();
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(FlickoColors.brandLime).withValues(alpha: 0.08)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(FlickoColors.brandLime).withValues(alpha: 0.2)
                          : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        filter,
                        style: GoogleFonts.inter(
                          color: isSelected
                              ? const Color(FlickoColors.brandLime)
                              : const Color(FlickoColors.textSecondary),
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded,
                            color: Color(FlickoColors.brandLime), size: 20),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(FlickoColors.brandLime).withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.list_alt_rounded,
                size: 48, color: Color(FlickoColors.brandLime)),
          ),
          const SizedBox(height: 24),
          Text(
            'No Actions Found',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nothing has happened in this server yet.',
            style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14),
          ),
        ],
      ),
    );
  }

  String _formatActionType(String type) {
    return type.replaceAll('_', ' ').toUpperCase();
  }

  String _getTargetName(Map<String, dynamic> log) {
    final changes = log['changes'] as Map<String, dynamic>?;
    if (changes != null) {
      if (changes.containsKey('name')) return changes['name'].toString();
      if (changes.containsKey('target_name')) {
        return changes['target_name'].toString();
      }
    }
    return log['target_id']?.toString() ?? '';
  }

  Color _getActionColor(String type) {
    if (type.contains('create') || type.contains('add')) {
      return const Color(FlickoColors.success);
    }
    if (type.contains('delete') ||
        type.contains('remove') ||
        type.contains('ban')) {
      return Colors.redAccent;
    }
    if (type.contains('update')) return Colors.blueAccent;
    return Colors.white70;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
