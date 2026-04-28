import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';

/// Safety Settings Screen
///
/// Manage verification level, content filter, and other safety settings.
class SafetySettingsScreen extends ConsumerStatefulWidget {
  final String serverId;

  const SafetySettingsScreen({super.key, required this.serverId});

  @override
  ConsumerState<SafetySettingsScreen> createState() => _SafetySettingsScreenState();
}

class _SafetySettingsScreenState extends ConsumerState<SafetySettingsScreen> {
  final _client = Supabase.instance.client;

  bool _isLoading = true;
  String? _errorMessage;

  // Safety settings
  int _verificationLevel = 0; // 0: None, 1: Low, 2: Medium, 3: High

  @override
  void initState() {
    super.initState();
    _loadSafetySettings();
  }

  Future<void> _loadSafetySettings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _client
          .from('servers')
          .select('verification_level')
          .eq('id', widget.serverId)
          .maybeSingle();

      if (response != null) {
        setState(() {
          _verificationLevel = response['verification_level'] as int? ?? 0;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateSafetySettings() async {
    setState(() => _isLoading = true);

    try {
      await _client
          .from('servers')
          .update({
            'verification_level': _verificationLevel,
          })
          .eq('id', widget.serverId);

      setState(() => _isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Safety settings updated'),
            backgroundColor: Color(FlickoColors.success),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating settings: $e'),
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
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
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
          TextButton(
            onPressed: _isLoading ? null : _updateSafetySettings,
            child: Text(
              'Save',
              style: GoogleFonts.inter(
                color: _isLoading
                    ? const Color(FlickoColors.textMuted)
                    : const Color(FlickoColors.blurple),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(FlickoColors.blurple)))
          : _errorMessage != null
              ? _buildErrorState()
              : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Color(FlickoColors.danger)),
          const SizedBox(height: 16),
          Text(
            'Error loading safety settings',
            style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage ?? '',
            style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadSafetySettings,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSectionTitle('Verification Level'),
        _buildVerificationLevelSelector(),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textPrimary),
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildVerificationLevelSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVerificationOption(
            0,
            'None',
            'No verification required. Anyone can join and participate.',
            Icons.check_circle_outline,
          ),
          const Divider(height: 32),
          _buildVerificationOption(
            1,
            'Low',
            'Members must have a verified email on their account.',
            Icons.email_outlined,
          ),
          const Divider(height: 32),
          _buildVerificationOption(
            2,
            'Medium',
            'Members must be registered on the platform for at least 5 minutes.',
            Icons.schedule_outlined,
          ),
          const Divider(height: 32),
          _buildVerificationOption(
            3,
            'High',
            'Members must be a member of the server for at least 10 minutes.',
            Icons.shield_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationOption(
    int level,
    String title,
    String description,
    IconData icon,
  ) {
    final isSelected = _verificationLevel == level;
    return InkWell(
      onTap: () => setState(() => _verificationLevel = level),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(FlickoColors.blurple).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? const Color(FlickoColors.blurple)
                : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? const Color(FlickoColors.blurple)
                  : const Color(FlickoColors.textMuted),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textPrimary),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(FlickoColors.blurple),
              ),
          ],
        ),
      ),
    );
  }

}
