import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

/// Change Email Screen
///
/// Allows the authenticated user to change their account email address.
/// Supabase will send a confirmation link to both the old and new email before committing the change.
/// Route: /profile/settings/change-email
class ChangeEmailScreen extends ConsumerStatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  ConsumerState<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen> {
  String _newEmail = '';
  bool _isLoading = false;

  final _emailController = TextEditingController();

  bool _isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim());
  }

  bool get _canSave {
    return _newEmail.trim().isNotEmpty &&
        _isValidEmail(_newEmail) &&
        _newEmail.trim().toLowerCase() != _currentEmail?.toLowerCase() &&
        !_isLoading;
  }

  String? get _currentEmail {
    return ref.read(authNotifierProvider).maybeWhen(
      authenticated: (user, _) => user.email,
      orElse: () => null,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final trimmedEmail = _newEmail.trim().toLowerCase();

    if (!_isValidEmail(trimmedEmail)) {
      _showAlert('Invalid Email', 'Please enter a valid email address.');
      return;
    }

    if (trimmedEmail == _currentEmail?.toLowerCase()) {
      _showAlert('No Change', 'This is already your current email address.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final error = await Supabase.instance.client.auth.updateUser(
        UserAttributes(email: trimmedEmail),
      );

      if (error != null) throw error;

      _showAlert(
        'Confirmation Sent',
        'A confirmation link has been sent to both $_currentEmail and $trimmedEmail.\n\nFollow the links in both emails to complete the change.',
        onOk: () => context.pop(),
      );
    } catch (e) {
      _showAlert('Error', e.toString() ?? 'Failed to update email. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAlert(String title, String message, {VoidCallback? onOk}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          title,
          style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onOk?.call();
            },
            child: Text(
              'OK',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Change Email',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _canSave ? _handleSave : null,
            child: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(FlickoColors.blurple)),
                  )
                : Text(
                    'Save',
                    style: GoogleFonts.inter(
                      color: _canSave ? const Color(FlickoColors.blurple) : const Color(FlickoColors.textMuted),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current email display
          _buildSectionHeader('CURRENT EMAIL'),
          _buildCurrentEmailBox(),

          const SizedBox(height: 16),

          // New email input
          _buildSectionHeader('NEW EMAIL ADDRESS'),
          _buildEmailInput(),

          const SizedBox(height: 16),

          // Info notice
          _buildInfoBox(),

          const SizedBox(height: 24),

          // Submit button
          ElevatedButton(
            onPressed: _canSave ? _handleSave : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canSave ? const Color(FlickoColors.blurple) : const Color(FlickoColors.bgTertiary),
              foregroundColor: _canSave ? Colors.white : const Color(FlickoColors.textMuted),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    'Send Confirmation',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
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

  Widget _buildCurrentEmailBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.mail_outline, size: 18, color: Color(FlickoColors.textMuted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _currentEmail ?? 'Not set',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 15,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailInput() {
    final hasError = _newEmail.isNotEmpty && !_isValidEmail(_newEmail);

    return Container(
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: hasError ? const Color(FlickoColors.red) : const Color(0xFF232428),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: _emailController,
              onChanged: (v) => setState(() => _newEmail = v),
              keyboardType: TextInputType.emailAddress,
              textCapitalization: TextCapitalization.none,
              autocorrect: false,
              style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
              decoration: InputDecoration(
                hintText: 'Enter new email address',
                hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                suffixIcon: _newEmail.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Color(FlickoColors.textMuted)),
                        onPressed: () {
                          _emailController.clear();
                          setState(() => _newEmail = '');
                        },
                      )
                    : null,
              ),
            ),
          ),
          if (hasError)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Text(
                'Please enter a valid email address',
                style: GoogleFonts.inter(color: const Color(FlickoColors.red), fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        border: Border.all(color: const Color(FlickoColors.blurple), left: BorderSide.none),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: Color(FlickoColors.blurple)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'A confirmation link will be sent to both your current and new email addresses. You must confirm both to complete the change.',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
