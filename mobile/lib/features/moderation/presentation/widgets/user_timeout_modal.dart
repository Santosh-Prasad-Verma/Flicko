import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class UserTimeoutModal extends ConsumerStatefulWidget {
  final String userId;
  final String username;
  final String avatarUrl;
  final String serverId;

  const UserTimeoutModal({
    super.key,
    required this.userId,
    required this.username,
    required this.avatarUrl,
    required this.serverId,
  });

  static void show(BuildContext context, {
    required String userId,
    required String username,
    required String avatarUrl,
    required String serverId,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UserTimeoutModal(
        userId: userId,
        username: username,
        avatarUrl: avatarUrl,
        serverId: serverId,
      ),
    );
  }

  @override
  ConsumerState<UserTimeoutModal> createState() => _UserTimeoutModalState();
}

class _UserTimeoutModalState extends ConsumerState<UserTimeoutModal> {
  String? _selectedDuration;
  final TextEditingController _reasonController = TextEditingController();
  bool _isSubmitting = false;

  final List<Map<String, dynamic>> _durations = [
    {'label': '60 seconds', 'value': '60s', 'seconds': 60},
    {'label': '5 minutes', 'value': '5m', 'seconds': 300},
    {'label': '10 minutes', 'value': '10m', 'seconds': 600},
    {'label': '1 hour', 'value': '1h', 'seconds': 3600},
    {'label': '1 day', 'value': '1d', 'seconds': 86400},
    {'label': '1 week', 'value': '1w', 'seconds': 604800},
  ];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Duration _parseDuration(String value) {
    final match = _durations.firstWhere((d) => d['value'] == value);
    return Duration(seconds: match['seconds'] as int);
  }

  Future<void> _handleTimeout() async {
    if (_selectedDuration == null || _isSubmitting) return;

    setState(() => _isSubmitting = true);
    HapticFeedback.mediumImpact();

    try {
      final client = Supabase.instance.client;
      final actorId = client.auth.currentUser?.id;
      final duration = _parseDuration(_selectedDuration!);
      final disabledUntil = DateTime.now().toUtc().add(duration).toIso8601String();
      final reason = _reasonController.text.trim();

      // 1. Update server_members to set communication_disabled_until
      await client
          .from('server_members')
          .update({'communication_disabled_until': disabledUntil})
          .eq('server_id', widget.serverId)
          .eq('user_id', widget.userId);

      // 2. Write an audit log entry
      if (actorId != null) {
        await client.from('audit_logs').insert({
          'server_id': widget.serverId,
          'actor_id': actorId,
          'action_type': 'member_timeout',
          'target_type': 'member',
          'target_id': widget.userId,
          'reason': reason.isNotEmpty ? reason : null,
          'changes': {
            'duration': _selectedDuration,
            'disabled_until': disabledUntil,
            'username': widget.username,
          },
        });
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.username} has been timed out for ${_durations.firstWhere((d) => d['value'] == _selectedDuration)['label']}'),
            backgroundColor: const Color(FlickoColors.blurple),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to timeout: $e'),
            backgroundColor: const Color(FlickoColors.danger),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.all(FlickoSpacing.md),
      padding: EdgeInsets.only(
        bottom: bottomInset + FlickoSpacing.xl,
        left: FlickoSpacing.xl,
        right: FlickoSpacing.xl,
        top: FlickoSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgPrimary),
        borderRadius: BorderRadius.circular(FlickoRadius.lg),
        border: Border.all(
          color: const Color(FlickoColors.bgTertiary),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header ──
          Row(
            children: [
              CircleAvatar(
                backgroundImage: widget.avatarUrl.isNotEmpty
                    ? NetworkImage(widget.avatarUrl)
                    : null,
                backgroundColor: const Color(FlickoColors.bgTertiary),
                radius: 18,
                child: widget.avatarUrl.isEmpty
                    ? Text(
                        widget.username.isNotEmpty ? widget.username[0].toUpperCase() : '?',
                        style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                      )
                    : null,
              ),
              const SizedBox(width: FlickoSpacing.md),
              Expanded(
                child: Text(
                  'Timeout ${widget.username}',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textPrimary),
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Color(FlickoColors.textSecondary), size: 20),
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: FlickoSpacing.md),

          Text(
            'Members in timeout cannot send messages, react to messages, '
            'or speak in voice channels.',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textSecondary),
              fontSize: 13,
              height: 1.5,
            ),
          ),
          const SizedBox(height: FlickoSpacing.xl),

          // ── Duration chips ──
          Text(
            'DURATION',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: FlickoSpacing.sm),
          Wrap(
            spacing: FlickoSpacing.sm,
            runSpacing: FlickoSpacing.sm,
            children: _durations.map((duration) {
              final isSelected = _selectedDuration == duration['value'];
              return ChoiceChip(
                label: Text(duration['label']!),
                selected: isSelected,
                onSelected: (selected) {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedDuration = selected ? duration['value'] : null;
                  });
                },
                backgroundColor: const Color(FlickoColors.bgTertiary),
                selectedColor: const Color(FlickoColors.blurple).withValues(alpha: 0.2),
                labelStyle: GoogleFonts.inter(
                  color: isSelected
                      ? const Color(FlickoColors.blurpleLight)
                      : const Color(FlickoColors.textPrimary),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(FlickoRadius.md),
                  side: BorderSide(
                    color: isSelected
                        ? const Color(FlickoColors.blurple)
                        : Colors.transparent,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: FlickoSpacing.xl),

          // ── Reason text field ──
          Text(
            'REASON',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: FlickoSpacing.sm),
          TextField(
            controller: _reasonController,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 14,
            ),
            maxLength: 512,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Any reason given will be shown to the user.',
              hintStyle: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 13,
              ),
              filled: true,
              fillColor: const Color(FlickoColors.bgTertiary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(FlickoRadius.md),
                borderSide: BorderSide.none,
              ),
              counterStyle: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(height: FlickoSpacing.xl),

          // ── Action buttons ──
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(FlickoColors.textSecondary),
                ),
                child: Text('Cancel', style: GoogleFonts.inter(fontSize: 14)),
              ),
              const SizedBox(width: FlickoSpacing.sm),
              ElevatedButton(
                onPressed: _selectedDuration == null || _isSubmitting ? null : _handleTimeout,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(FlickoColors.danger),
                  disabledBackgroundColor: const Color(FlickoColors.danger).withValues(alpha: 0.4),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(FlickoRadius.md),
                  ),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Text(
                        'Timeout Member',
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
