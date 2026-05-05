import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/application/auth_notifier.dart';
import '../../../../core/constants/flicko_colors.dart';

/// Change Password Screen
///
/// Allows the authenticated user to update their password.
/// Uses Supabase Auth's updateUser() via AuthNotifier.
/// Route: /u/settings/change-password
class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _minPasswordLength = 8;

  String _currentPassword = '';
  String _newPassword = '';
  String _confirmPassword = '';
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _isLoading = false;

  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  bool get _canSave {
    return _currentPassword.trim().isNotEmpty &&
        _newPassword.length >= _minPasswordLength &&
        _confirmPassword.length >= _minPasswordLength &&
        !_isLoading;
  }

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_currentPassword.trim().isEmpty) {
      _showAlert('Validation Error', 'Please enter your current password.');
      return;
    }
    if (_newPassword.length < _minPasswordLength) {
      _showAlert('Validation Error', 'New password must be at least $_minPasswordLength characters.');
      return;
    }
    if (_newPassword != _confirmPassword) {
      _showAlert('Validation Error', 'New passwords do not match.');
      return;
    }
    if (_newPassword == _currentPassword) {
      _showAlert('Validation Error', 'New password must be different from your current password.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authNotifierProvider.notifier).changePassword(
        _newPassword,
      );

      _showAlert(
        'Password Updated',
        'Your password has been changed successfully.',
        onOk: () => context.pop(),
      );
    } catch (e) {
      _showAlert('Error', e.toString());
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
    final passwordsMatch = _confirmPassword.isNotEmpty && _confirmPassword == _newPassword;

    return Scaffold(
      
      appBar: AppBar(
        
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Change Password',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _canSave ? _handleSave : null,
            child: _isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(FlickoColors.blurple)))
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
          // Section hint
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 16),
            child: Text(
              'Your password must be at least $_minPasswordLength characters.',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 13),
            ),
          ),

          // Current Password
          _buildSectionHeader('CURRENT PASSWORD'),
          _buildPasswordField(
            controller: _currentController,
            value: _currentPassword,
            onChanged: (v) => setState(() => _currentPassword = v),
            obscure: !_showCurrent,
            onToggle: () => setState(() => _showCurrent = !_showCurrent),
            placeholder: 'Enter current password',
          ),

          const SizedBox(height: 16),

          // New Password
          _buildSectionHeader('NEW PASSWORD'),
          _buildPasswordField(
            controller: _newController,
            value: _newPassword,
            onChanged: (v) => setState(() => _newPassword = v),
            obscure: !_showNew,
            onToggle: () => setState(() => _showNew = !_showNew),
            placeholder: 'Enter new password',
          ),

          const SizedBox(height: 16),

          // Confirm New Password
          _buildSectionHeader('CONFIRM NEW PASSWORD'),
          _buildPasswordField(
            controller: _confirmController,
            value: _confirmPassword,
            onChanged: (v) => setState(() => _confirmPassword = v),
            obscure: !_showConfirm,
            onToggle: () => setState(() => _showConfirm = !_showConfirm),
            placeholder: 'Re-enter new password',
            borderColor: _confirmPassword.isNotEmpty && !passwordsMatch ? const Color(FlickoColors.red) : null,
          ),

          if (_confirmPassword.isNotEmpty && !passwordsMatch)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                'Passwords do not match',
                style: GoogleFonts.inter(color: const Color(FlickoColors.red), fontSize: 12),
              ),
            ),

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
                    'Update Password',
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

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String value,
    required ValueChanged<String> onChanged,
    required bool obscure,
    required VoidCallback onToggle,
    required String placeholder,
    Color? borderColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: borderColor ?? const Color(0xFF232428)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          obscureText: obscure,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
          decoration: InputDecoration(
            hintText: placeholder,
            hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            filled: true,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                size: 20,
                color: const Color(FlickoColors.textMuted),
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      ),
    );
  }
}
