import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class UserTimeoutBottomSheet extends StatefulWidget {
  final String serverId;
  final String userId;
  final String username;
  final DateTime? currentTimeout;

  const UserTimeoutBottomSheet({
    super.key,
    required this.serverId,
    required this.userId,
    required this.username,
    this.currentTimeout,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String serverId,
    required String userId,
    required String username,
    DateTime? currentTimeout,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => UserTimeoutBottomSheet(
        serverId: serverId,
        userId: userId,
        username: username,
        currentTimeout: currentTimeout,
      ),
    );
  }

  @override
  State<UserTimeoutBottomSheet> createState() => _UserTimeoutBottomSheetState();
}

class _UserTimeoutBottomSheetState extends State<UserTimeoutBottomSheet> {
  final _client = Supabase.instance.client;
  bool _isLoading = false;

  final List<Map<String, dynamic>> _durations = [
    {'label': '60 seconds', 'seconds': 60},
    {'label': '5 minutes', 'seconds': 300},
    {'label': '10 minutes', 'seconds': 600},
    {'label': '1 hour', 'seconds': 3600},
    {'label': '1 day', 'seconds': 86400},
    {'label': '1 week', 'seconds': 604800},
  ];

  Future<void> _applyTimeout(int seconds) async {
    setState(() => _isLoading = true);
    try {
      final until = DateTime.now().toUtc().add(Duration(seconds: seconds)).toIso8601String();
      await _client
          .from('server_members')
          .update({'timeout_until': until})
          .eq('server_id', widget.serverId)
          .eq('user_id', widget.userId);
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to apply timeout: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeTimeout() async {
    setState(() => _isLoading = true);
    try {
      await _client
          .from('server_members')
          .update({'timeout_until': null})
          .eq('server_id', widget.serverId)
          .eq('user_id', widget.userId);
      if (mounted) context.pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to remove timeout: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatRemaining(DateTime until) {
    final diff = until.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    if (diff.inDays > 0) return '${diff.inDays}d ${diff.inHours % 24}h remaining';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes % 60}m remaining';
    return '${diff.inMinutes}m remaining';
  }

  @override
  Widget build(BuildContext context) {
    final isTimedOut = widget.currentTimeout != null && widget.currentTimeout!.isAfter(DateTime.now());

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).padding.bottom + 16,
        top: 24,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Timeout ${widget.username}',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Prevents the user from sending messages, reacting, or joining voice channels.',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          
          if (isTimedOut) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.warning).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.timer_outlined, color: Color(FlickoColors.warning), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Currently timed out — ${_formatRemaining(widget.currentTimeout!)}',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.warning),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_isLoading)
            const Center(child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
            ))
          else ...[
            for (final d in _durations)
              InkWell(
                onTap: () => _applyTimeout(d['seconds'] as int),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule, color: Color(FlickoColors.textSecondary), size: 20),
                      const SizedBox(width: 12),
                      Text(
                        d['label'] as String,
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textPrimary),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            if (isTimedOut)
              InkWell(
                onTap: _removeTimeout,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.cancel_outlined, color: Color(FlickoColors.danger), size: 20),
                      const SizedBox(width: 12),
                      Text(
                        'Remove Timeout',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.danger),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.pop(),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: const Color(FlickoColors.bgTertiary),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
