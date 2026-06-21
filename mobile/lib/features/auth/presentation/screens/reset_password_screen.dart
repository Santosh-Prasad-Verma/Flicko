import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/keyboard_dismiss_on_tap.dart';
import 'package:mobile/data/repositories/auth_repository.dart';

/// Reset Password Screen — Discord-inspired
///
/// Users land here after clicking the reset link in their email.
/// Allows setting a new password.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String? _passwordError;
  String? _confirmError;
  String? _generalError;
  bool _isLoading = false;
  bool _success = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validatePassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'\d'))) return false;
    if (!password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};:\x22\x27\\|,.<>\/?]'))) return false;
    return true;
  }

  bool _validate() {
    setState(() {
      _passwordError = null;
      _confirmError = null;
      _generalError = null;
    });

    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;

    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      return false;
    } else if (!_validatePassword(password)) {
      setState(() => _passwordError = 'Password must be 8+ chars with upper, lower, number, and special');
      return false;
    }

    if (confirm != password) {
      setState(() => _confirmError = 'Passwords do not match');
      return false;
    }

    return true;
  }

  Future<void> _handleReset() async {
    if (!_validate()) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.changePassword(_passwordController.text);

      setState(() => _success = true);
      
      // Auto-navigate after 3 seconds
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) context.go('/login');
      });
    } catch (e) {
      debugPrint('Reset password error: $e');
      setState(() => _generalError = 'Failed to reset password. The link may have expired.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(FlickoColors.black),
      body: KeyboardDismissOnTap(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: topPadding + 60,
            bottom: bottomPadding + 40,
            left: 24,
            right: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo
                  _buildLogo(),
                  
                  const SizedBox(height: 24),
                  
                  // Header
                  _buildHeader(),
                  
                  const SizedBox(height: 24),
                  
                  // Form or Success
                  _success ? _buildSuccessView() : _buildForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/Flicko-for-black-background.png',
      width: 120,
      height: 40,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: const Color(FlickoColors.brandLime),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.flash_on, color: Colors.black),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'RESET\nPASSWORD',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 48,
            fontWeight: FontWeight.w900,
            height: 0.9,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "CHOOSE A STRONG NEW PASSWORD",
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_generalError != null) _buildErrorBanner(),
        
        _buildTextField(
          label: 'NEW PASSWORD',
          hint: '••••••••',
          controller: _passwordController,
          error: _passwordError,
          isPassword: true,
          onChanged: () {
            if (_passwordError != null) setState(() => _passwordError = null);
          },
        ),
        
        const SizedBox(height: 24),
        
        _buildTextField(
          label: 'CONFIRM NEW PASSWORD',
          hint: '••••••••',
          controller: _confirmPasswordController,
          error: _confirmError,
          isPassword: true,
          onSubmitted: _handleReset,
          onChanged: () {
            if (_confirmError != null) setState(() => _confirmError = null);
          },
        ),
        
        const SizedBox(height: 16),
        
        _buildStyledButton(
          label: 'UPDATE PASSWORD',
          onPressed: _isLoading ? null : _handleReset,
          isLoading: _isLoading,
          color: const Color(FlickoColors.brandLime),
          textColor: Colors.black,
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      children: [
        Stack(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4, left: 4),
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(color: Colors.white),
              child: const Opacity(opacity: 0, child: Text('placeholder')),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline, color: Color(FlickoColors.brandLime), size: 48),
                  const SizedBox(height: 24),
                  Text(
                    'PASSWORD UPDATED!',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.0),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your password has been changed successfully. Redirecting you to login...',
                    style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted), fontSize: 14, fontWeight: FontWeight.w600, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),
        _buildStyledButton(
          label: 'GO TO LOGIN NOW',
          onPressed: () => context.go('/login'),
          color: const Color(FlickoColors.brandLime),
          textColor: Colors.black,
        ),
      ],
    );
  }

  Widget _buildStyledButton({
    required String label,
    required VoidCallback? onPressed,
    bool isLoading = false,
    required Color color,
    required Color textColor,
  }) {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          height: 56,
          margin: const EdgeInsets.only(top: 4, left: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: textColor,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                side: BorderSide(color: Colors.black, width: 2),
              ),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.black)),
                  )
                : Text(label, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.0)),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.danger).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _generalError!,
        style: GoogleFonts.inter(color: const Color(FlickoColors.danger), fontSize: 14, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? error,
    bool isPassword = false,
    VoidCallback? onChanged,
    VoidCallback? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.0),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          obscureText: isPassword,
          onChanged: (_) => onChanged?.call(),
          onSubmitted: (_) => onSubmitted?.call(),
          style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          cursorColor: const Color(FlickoColors.brandLime),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(color: const Color(0xFF333333), fontSize: 16, fontWeight: FontWeight.w600),
            filled: true,
            fillColor: const Color(0xFF0F0F0F),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1), width: 1),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Color(FlickoColors.brandLime), width: 2),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: Colors.red, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            errorText: error,
          ),
        ),
      ],
    );
  }
}
