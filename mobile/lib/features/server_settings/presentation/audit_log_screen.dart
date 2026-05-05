import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
          .from('audit_logs')
          .select('*, profiles:actor_id(id, username, avatar)')
          .eq('server_id', widget.serverId);

      if (_selectedFilter == 'Member Updates') {
        query = query.inFilter('action_type', ['ban', 'kick', 'timeout', 'mute', 'deafen', 'role_update', 'nickname_update']);
      } else if (_selectedFilter == 'Channel Updates') {
        query = query.inFilter('action_type', ['channel_create', 'channel_update', 'channel_delete']);
      } else if (_selectedFilter == 'Role Updates') {
        query = query.inFilter('action_type', ['role_create', 'role_update', 'role_delete']);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(100);

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
              'AUDIT LOG',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 2,
              ),
            ),
            Text(
              _selectedFilter.toUpperCase(),
              style: GoogleFonts.inter(
                color: const Color(0xFFC8FF00),
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Color(0xFFC8FF00)),
            onPressed: _showFilterSheet,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFC8FF00)))
          : _logs.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _logs.length,
                  itemBuilder: (context, index) => _buildLogEntry(_logs[index]),
                ),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log) {
    final profile = log['profiles'] as Map<String, dynamic>?;
    final username = profile?['username'] as String? ?? 'System';
    final avatar = profile?['avatar'] as String?;
    final actionType = log['action_type'] as String? ?? 'unknown';
    final timestamp = DateTime.parse(log['created_at']);
    
    final Color actionColor = _getActionColor(actionType);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0D0D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFC8FF00).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              image: avatar != null 
                ? DecorationImage(image: NetworkImage(avatar), fit: BoxFit.cover)
                : null,
            ),
            child: avatar == null 
              ? const Icon(Icons.person_rounded, color: Color(0xFFC8FF00))
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
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      _formatTime(timestamp),
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
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
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                if (log['reason'] != null && (log['reason'] as String).isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
                    ),
                    child: Text(
                      log['reason'],
                      style: GoogleFonts.inter(
                        color: Colors.white38,
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
          color: Color(0xFF0D0D0D),
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
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
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'FILTER ACTIONS',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ...['All Actions', 'Member Updates', 'Channel Updates', 'Role Updates'].map((filter) {
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
                    color: isSelected ? const Color(0xFFC8FF00).withValues(alpha: 0.05) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? const Color(0xFFC8FF00).withValues(alpha: 0.2) : Colors.transparent,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        filter,
                        style: GoogleFonts.inter(
                          color: isSelected ? const Color(0xFFC8FF00) : Colors.white70,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded, color: Color(0xFFC8FF00), size: 20),
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
              color: const Color(0xFFC8FF00).withValues(alpha: 0.05),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.list_alt_rounded, size: 64, color: Color(0xFFC8FF00)),
          ),
          const SizedBox(height: 24),
          Text(
            'NO ACTIONS FOUND',
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 18,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nothing has happened in this server yet.',
            style: GoogleFonts.inter(color: Colors.white38, fontSize: 14),
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
      if (changes.containsKey('target_name')) return changes['target_name'].toString();
    }
    return log['target_id']?.toString() ?? '';
  }

  Color _getActionColor(String type) {
    if (type.contains('create') || type.contains('add')) return const Color(0xFFC8FF00);
    if (type.contains('delete') || type.contains('remove') || type.contains('ban')) return Colors.redAccent;
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
