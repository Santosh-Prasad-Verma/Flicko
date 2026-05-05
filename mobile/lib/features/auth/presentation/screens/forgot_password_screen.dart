import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

/// Forgot Password Screen — Discord-inspired
///
/// Allows users to request a password reset email.
/// Flow: Enter email → Send reset link → Check email → Reset password.
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  String? _emailError;
  String? _generalError;
  String? _successMessage;
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  bool _validate() {
    setState(() {
      _emailError = null;
      _generalError = null;
      _successMessage = null;
    });

    final trimmedEmail = _emailController.text.trim();
    if (trimmedEmail.isEmpty) {
      setState(() => _emailError = 'Email is required');
      return false;
    } else if (!_validateEmail(trimmedEmail)) {
      setState(() => _emailError = 'Enter a valid email address');
      return false;
    }

    return true;
  }

  Future<void> _handleSendReset() async {
    if (!_validate()) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      final sanitizedEmail = _emailController.text.trim().toLowerCase();
      
      // CRIT-008: Additional validation
      if (sanitizedEmail.length > 254) {
        setState(() => _generalError = 'Email address too long');
        return;
      }

      if (sanitizedEmail.contains('\0')) {
        setState(() => _generalError = 'Invalid characters in email');
        return;
      }

      final supabase = Supabase.instance.client;
      await supabase.auth.resetPasswordForEmail(
        sanitizedEmail,
        redirectTo: 'flicko://reset-password', // Deep link for mobile app
      );

      setState(() {
        _emailSent = true;
        _successMessage = 'Password reset email sent! Check your inbox and spam folder.';
      });
    } on AuthException catch (e) {
      // Don't expose whether email exists for security
      setState(() => 
        _successMessage = 'If an account exists with this email, you will receive a password reset link.'
      );
      setState(() => _emailSent = true);
    } catch (e) {
      debugPrint('Forgot password error: $e');
      setState(() => _generalError = 'Failed to send reset email. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToLogin() {
    context.push('/login');
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: topPadding + 24,
            bottom: bottomPadding + 30,
            left: 28,
            right: 28,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - topPadding - bottomPadding - 54,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: _navigateToLogin,
                      child: Text(
                        '< Back',
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.textSecondary),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Logo
                  _buildLogo(),
                  
                  const SizedBox(height: 24),
                  
                  // Header
                  _buildHeader(),
                  
                  const SizedBox(height: 32),
                  
                  // Form or Success
                  _emailSent ? _buildSuccessView() : _buildForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(FlickoColors.blurple),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.chat_bubble,
            color: Colors.white,
            size: 28,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Flicko',
          style: GoogleFonts.pacifico(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 30,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'Forgot Password?',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "Enter your email and we'll send you a link to reset your password.",
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textSecondary),
            fontSize: 15,
            height: 1.5,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Error Banner
        if (_generalError != null) _buildErrorBanner(),
        
        // Email Field
        _buildTextField(
          label: 'EMAIL',
          hint: 'Enter your email address',
          controller: _emailController,
          error: _emailError,
          keyboardType: TextInputType.emailAddress,
          onSubmitted: _handleSendReset,
          onChanged: () {
            if (_emailError != null) {
              setState(() => _emailError = null);
            }
          },
        ),
        
        const SizedBox(height: 24),
        
        // Send Reset Button
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleSendReset,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.blurple),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
              disabledBackgroundColor: const Color(FlickoColors.blurple).withOpacity(0.5),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Text(
                    'Send Reset Link',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Back to Login
        GestureDetector(
          onTap: _navigateToLogin,
          child: Text(
            'Back to Login',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.blurple),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(FlickoColors.success).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              const Icon(
                Icons.check_circle,
                color: Color(FlickoColors.success),
                size: 48,
              ),
              const SizedBox(height: 16),
              Text(
                _successMessage!,
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.success),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Check your inbox for the reset link. If you don\'t see it, check your spam folder.',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textSecondary),
                  fontSize: 14,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 24),
        
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: _navigateToLogin,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(FlickoColors.blurple),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            child: Text(
              'Back to Login',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 12),
        
        GestureDetector(
          onTap: () {
            setState(() {
              _emailSent = false;
              _successMessage = null;
              _emailController.clear();
            });
          },
          child: Text(
            'Try different email',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 14,
            ),
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
        color: const Color(FlickoColors.danger).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _generalError!,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.danger),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? error,
    TextInputType? keyboardType,
    VoidCallback? onChanged,
    VoidCallback? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textSecondary),
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: (_) => onChanged?.call(),
          onSubmitted: (_) => onSubmitted?.call(),
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 16,
            ),
            filled: true,
            fillColor: const Color(FlickoColors.bgSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(color: Color(FlickoColors.blurple)),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(3),
              borderSide: const BorderSide(color: Color(FlickoColors.danger)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            errorText: error,
          ),
        ),
      ],
    );
  }
}
