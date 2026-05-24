import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/data/repositories/auth_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// User Status Picker Screen
///
/// Set presence status (online/idle/dnd/invisible) and custom status.
/// Route: /u/settings/status
class StatusScreen extends ConsumerStatefulWidget {
  const StatusScreen({super.key});

  @override
  ConsumerState<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends ConsumerState<StatusScreen> {
  String _currentStatus = 'online';
  String _customText = '';
  String _customEmoji = '';
  int _expiryIndex = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeFromProfile();
  }

  void _initializeFromProfile() {
    final authState = ref.read(authNotifierProvider);
    authState.maybeWhen(
      authenticated: (user, profile) {
        if (profile != null) {
          setState(() {
            _currentStatus = profile.onlineStatus;
            _customText = profile.customStatus ?? '';
            _customEmoji = profile.customStatusEmoji ?? '';
          });
        }
      },
      orElse: () {},
    );
  }

  final List<_StatusOption> _statusOptions = const [
    _StatusOption(
        value: 'online',
        label: 'Online',
        color: Color(0xFF3BA55D),
        icon: Icons.circle),
    _StatusOption(
        value: 'idle',
        label: 'Idle',
        color: Color(0xFFFAA61A),
        icon: Icons.timelapse),
    _StatusOption(
        value: 'dnd',
        label: 'Do Not Disturb',
        color: Color(0xFFED4245),
        icon: Icons.do_not_disturb_on),
    _StatusOption(
        value: 'invisible',
        label: 'Invisible',
        color: Color(0xFF80848E),
        icon: Icons.circle_outlined),
  ];

  final List<_ExpiryOption> _expiryOptions = const [
    _ExpiryOption(label: "Don't clear", value: null),
    _ExpiryOption(label: '30 minutes', value: 30),
    _ExpiryOption(label: '1 hour', value: 60),
    _ExpiryOption(label: '4 hours', value: 240),
  ];

  final List<_StatusPreset> _presets = const [
    _StatusPreset(emoji: '🎮', text: 'Gaming'),
    _StatusPreset(emoji: '🎵', text: 'Listening to Music'),
    _StatusPreset(emoji: '💻', text: 'Working'),
    _StatusPreset(emoji: '🍿', text: 'Watching a Movie'),
    _StatusPreset(emoji: '📚', text: 'Studying'),
    _StatusPreset(emoji: '🍕', text: 'Eating'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        elevation: 0,
        leading: IconButton(
          icon: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Set Status',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(
                    'Save',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.blurple),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Presence Status
          _buildSectionHeader('STATUS'),
          Container(
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: _statusOptions.map((opt) {
                final selected = _currentStatus == opt.value;
                return InkWell(
                  onTap: () => setState(() => _currentStatus = opt.value),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? const Color(FlickoColors.bgTertiary) : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(opt.icon, size: 18, color: opt.color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            opt.label,
                            style: GoogleFonts.inter(
                              color: const Color(FlickoColors.textPrimary),
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (selected)
                          const Icon(Icons.check,
                              size: 20, color: Color(FlickoColors.blurple)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Custom Status
          _buildSectionHeader('CUSTOM STATUS'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: _cycleEmoji,
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(FlickoColors.bgTertiary),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Center(
                          child: Text(
                            _customEmoji.isEmpty ? '😀' : _customEmoji,
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _customText = v),
                        style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textPrimary)),
                        decoration: InputDecoration(
                          hintText: 'What are you up to?',
                          hintStyle: GoogleFonts.inter(
                              color: const Color(FlickoColors.textMuted)),
                          filled: true,
                          fillColor: const Color(FlickoColors.bgTertiary),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        maxLength: 128,
                      ),
                    ),
                  ],
                ),
                if (_customText.isNotEmpty || _customEmoji.isNotEmpty)
                  InkWell(
                    onTap: () => setState(() {
                      _customText = '';
                      _customEmoji = '';
                    }),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          const Icon(Icons.close,
                              size: 16, color: Color(FlickoColors.red)),
                          const SizedBox(width: 4),
                          Text(
                            'Clear custom status',
                            style: GoogleFonts.inter(
                              color: const Color(FlickoColors.red),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Quick Set Presets
          _buildSectionHeader('QUICK SET'),
          Container(
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: _presets.map((preset) {
                return InkWell(
                  onTap: () => setState(() {
                    _customEmoji = preset.emoji;
                    _customText = preset.text;
                  }),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        Text(preset.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 12),
                        Text(
                          preset.text,
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textPrimary),
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Clear After
          _buildSectionHeader('CLEAR AFTER'),
          Container(
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: _expiryOptions.asMap().entries.map((entry) {
                final index = entry.key;
                final opt = entry.value;
                final selected = _expiryIndex == index;

                return InkWell(
                  onTap: () => setState(() => _expiryIndex = index),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: selected ? const Color(FlickoColors.bgTertiary) : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          opt.label,
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textPrimary),
                            fontSize: 15,
                          ),
                        ),
                        if (selected)
                          const Icon(Icons.check,
                              size: 18, color: Color(FlickoColors.blurple)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),

          // Save Button
          ElevatedButton(
            onPressed: _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.blurple),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Save',
              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textMuted),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _cycleEmoji() {
    final emojis = _presets.map((p) => p.emoji).toList();
    final currentIdx = emojis.indexOf(_customEmoji);
    setState(() => _customEmoji = emojis[(currentIdx + 1) % emojis.length]);
  }

  Future<void> _handleSave() async {
    final authState = ref.read(authNotifierProvider);
    final user =
        authState.maybeWhen(authenticated: (user, _) => user, orElse: () => null);

    if (user == null) return;

    setState(() => _isSaving = true);

    try {
      final repository = ref.read(authRepositoryProvider);
      final updates = <String, dynamic>{
        'online_status': _currentStatus,
        'custom_status':
            _customText.trim().isEmpty ? null : _customText.trim(),
        'custom_status_emoji':
            _customEmoji.isEmpty ? null : _customEmoji,
      };

      // Handle expiry if needed
      final expiryMinutes = _expiryOptions[_expiryIndex].value;
      if (expiryMinutes != null) {
        updates['custom_status_expires_at'] = DateTime.now()
            .add(Duration(minutes: expiryMinutes))
            .toIso8601String();
      } else {
        updates['custom_status_expires_at'] = null;
      }

      await repository.updateProfile(user.id, updates);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status updated successfully'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Color(FlickoColors.statusOnline),
          ),
        );
        // Refresh profile without completely rebuilding notifier and losing frame
        await ref.read(authNotifierProvider.notifier).refreshProfile();
        if (mounted) {
          context.pop();
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: const Color(FlickoColors.red),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _StatusOption {
  final String value;
  final String label;
  final Color color;
  final IconData icon;

  const _StatusOption({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });
}

class _ExpiryOption {
  final String label;
  final int? value;

  const _ExpiryOption({required this.label, required this.value});
}

class _StatusPreset {
  final String emoji;
  final String text;

  const _StatusPreset({required this.emoji, required this.text});
}
