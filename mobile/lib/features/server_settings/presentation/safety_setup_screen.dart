import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Safety Setup screen — manages server verification level and content filter.
/// Maps to servers.verification_level and servers.explicit_content_filter columns.
class SafetySetupScreen extends ConsumerStatefulWidget {
  final String serverId;
  const SafetySetupScreen({super.key, required this.serverId});

  @override
  ConsumerState<SafetySetupScreen> createState() => _SafetySetupScreenState();
}

class _SafetySetupScreenState extends ConsumerState<SafetySetupScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  String _verificationLevel = 'none';
  String _contentFilter = 'disabled';
  String? _errorMessage;

  static const _verificationLevels = [
    {
      'value': 'none',
      'label': 'None',
      'description': 'Unrestricted — anyone can join and send messages.',
      'icon': Icons.lock_open_rounded,
    },
    {
      'value': 'low',
      'label': 'Low',
      'description': 'Must have a verified email on their account.',
      'icon': Icons.email_outlined,
    },
    {
      'value': 'medium',
      'label': 'Medium',
      'description': 'Must be registered on the platform for more than 5 minutes.',
      'icon': Icons.timer_outlined,
    },
    {
      'value': 'high',
      'label': 'High',
      'description': 'Must be a member of this server for more than 10 minutes.',
      'icon': Icons.hourglass_bottom_rounded,
    },
    {
      'value': 'highest',
      'label': 'Highest',
      'description': 'Must have a verified phone number.',
      'icon': Icons.phone_android_rounded,
    },
  ];

  static const _contentFilters = [
    {
      'value': 'disabled',
      'label': 'Don\'t scan any media content',
      'description': 'No automatic content scanning.',
      'icon': Icons.visibility_off_outlined,
    },
    {
      'value': 'members_without_roles',
      'label': 'Scan content from members without a role',
      'description': 'Only scans media from members with no assigned roles.',
      'icon': Icons.person_outline,
    },
    {
      'value': 'all_members',
      'label': 'Scan content from all members',
      'description': 'Scans all media content for explicit material.',
      'icon': Icons.shield_outlined,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await Supabase.instance.client
          .from('servers')
          .select('verification_level, explicit_content_filter')
          .eq('id', widget.serverId)
          .single();

      if (mounted) {
        setState(() {
          _verificationLevel = (data['verification_level'] as String?) ?? 'none';
          _contentFilter = (data['explicit_content_filter'] as String?) ?? 'disabled';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      await Supabase.instance.client
          .from('servers')
          .update({
            'verification_level': _verificationLevel,
            'explicit_content_filter': _contentFilter,
          })
          .eq('id', widget.serverId);

      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Safety settings updated',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(FlickoColors.success),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save: ${e.toString()}'),
            backgroundColor: const Color(FlickoColors.danger),
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
        title: Text(
          'Safety Setup',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          if (!_isLoading && _errorMessage == null)
            TextButton(
              onPressed: _isSaving ? null : _saveSettings,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(FlickoColors.brandLime),
                      ),
                    )
                  : Text(
                      'Save',
                      style: GoogleFonts.inter(
                        color: const Color(FlickoColors.brandLime),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(FlickoColors.brandLime)),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(FlickoColors.danger)),
            const SizedBox(height: 16),
            Text(
              'Failed to load safety settings',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadSettings,
              icon: const Icon(Icons.refresh),
              label: Text('Retry', style: GoogleFonts.inter(fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(FlickoColors.brandLime),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.brandLime).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.shield_rounded, color: Color(FlickoColors.brandLime), size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Safety Setup',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Control who can join and what content is allowed.',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textSecondary),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        // Verification Level
        Text(
          'VERIFICATION LEVEL',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Members must meet these requirements before they can send messages.',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textSecondary),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: _verificationLevels.asMap().entries.map((entry) {
              final index = entry.key;
              final level = entry.value;
              final isSelected = _verificationLevel == level['value'];
              return Column(
                children: [
                  if (index > 0)
                    const Divider(height: 1, indent: 56, color: Color(FlickoColors.border)),
                  InkWell(
                    onTap: () => setState(() => _verificationLevel = level['value'] as String),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(index == 0 ? 12 : 0),
                      topRight: Radius.circular(index == 0 ? 12 : 0),
                      bottomLeft: Radius.circular(index == _verificationLevels.length - 1 ? 12 : 0),
                      bottomRight: Radius.circular(index == _verificationLevels.length - 1 ? 12 : 0),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(FlickoColors.brandLime).withValues(alpha: 0.06)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            level['icon'] as IconData,
                            color: isSelected
                                ? const Color(FlickoColors.brandLime)
                                : const Color(FlickoColors.textMuted),
                            size: 20,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  level['label'] as String,
                                  style: GoogleFonts.inter(
                                    color: isSelected
                                        ? const Color(FlickoColors.brandLime)
                                        : const Color(FlickoColors.textPrimary),
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  level['description'] as String,
                                  style: GoogleFonts.inter(
                                    color: const Color(FlickoColors.textMuted),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Radio<String>(
                            value: level['value'] as String,
                            groupValue: _verificationLevel,
                            onChanged: (v) => setState(() => _verificationLevel = v!),
                            activeColor: const Color(FlickoColors.brandLime),
                            fillColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return const Color(FlickoColors.brandLime);
                              }
                              return const Color(FlickoColors.textMuted);
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 28),

        // Content Filter
        Text(
          'EXPLICIT CONTENT FILTER',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Automatically scan and delete media containing explicit content.',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textSecondary),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: const Color(FlickoColors.bgSecondary),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: _contentFilters.asMap().entries.map((entry) {
              final index = entry.key;
              final filter = entry.value;
              final isSelected = _contentFilter == filter['value'];
              return Column(
                children: [
                  if (index > 0)
                    const Divider(height: 1, indent: 56, color: Color(FlickoColors.border)),
                  InkWell(
                    onTap: () => setState(() => _contentFilter = filter['value'] as String),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(index == 0 ? 12 : 0),
                      topRight: Radius.circular(index == 0 ? 12 : 0),
                      bottomLeft: Radius.circular(index == _contentFilters.length - 1 ? 12 : 0),
                      bottomRight: Radius.circular(index == _contentFilters.length - 1 ? 12 : 0),
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? const Color(FlickoColors.brandLime).withValues(alpha: 0.06)
                            : Colors.transparent,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            filter['icon'] as IconData,
                            color: isSelected
                                ? const Color(FlickoColors.brandLime)
                                : const Color(FlickoColors.textMuted),
                            size: 20,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  filter['label'] as String,
                                  style: GoogleFonts.inter(
                                    color: isSelected
                                        ? const Color(FlickoColors.brandLime)
                                        : const Color(FlickoColors.textPrimary),
                                    fontSize: 15,
                                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  filter['description'] as String,
                                  style: GoogleFonts.inter(
                                    color: const Color(FlickoColors.textMuted),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Radio<String>(
                            value: filter['value'] as String,
                            groupValue: _contentFilter,
                            onChanged: (v) => setState(() => _contentFilter = v!),
                            activeColor: const Color(FlickoColors.brandLime),
                            fillColor: WidgetStateProperty.resolveWith((states) {
                              if (states.contains(WidgetState.selected)) {
                                return const Color(FlickoColors.brandLime);
                              }
                              return const Color(FlickoColors.textMuted);
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}
