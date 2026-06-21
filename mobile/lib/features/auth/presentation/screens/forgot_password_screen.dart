import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/shared/presentation/widgets/keyboard_dismiss_on_tap.dart';

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

      if (sanitizedEmail.contains('\x00')) {
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
    } on AuthException catch (_) {
      // Don't expose whether email exists for security
      setState(() {
        _emailSent = true;
        _successMessage = 'If an account exists with this email, you will receive a password reset link.';
      });
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
                  // Back Button
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_back_ios_new, color: Color(FlickoColors.textMuted), size: 14),
                          const SizedBox(width: 8),
                          Text(
                            'BACK',
                            style: GoogleFonts.inter(
                              color: const Color(FlickoColors.textMuted),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Logo
                  _buildLogo(),
                  
                  const SizedBox(height: 24),
                  
                  // Header
                  _buildHeader(),
                  
                  const SizedBox(height: 48),
                  
                  // Form or Success
                  _emailSent ? _buildSuccessView() : _buildForm(),
                  
                  if (!_emailSent) ...[
                    const SizedBox(height: 40),
                    Center(
                      child: GestureDetector(
                        onTap: _navigateToLogin,
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.inter(
                              color: const Color(FlickoColors.textMuted),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                            children: [
                              const TextSpan(text: 'REMEMBERED IT? '),
                              TextSpan(
                                text: 'LOG IN',
                                style: TextStyle(
                                  color: const Color(FlickoColors.brandLime),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
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
          'FORGOT\nPASSWORD?',
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
          "WE'LL SEND YOU A RESET LINK",
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
        // Error Banner
        if (_generalError != null) _buildErrorBanner(),
        
        // Email Field
        _buildTextField(
          label: 'EMAIL ADDRESS',
          hint: 'YOUR@EMAIL.COM',
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
        
        const SizedBox(height: 16),
        
        // Send Reset Button
        _buildStyledButton(
          label: 'SEND RESET LINK',
          onPressed: _isLoading ? null : _handleSendReset,
          isLoading: _isLoading,
          color: const Color(FlickoColors.brandLime),
          textColor: Colors.black,
        ),
      ],
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            // Shadow Box
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 4, left: 4),
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(
                color: Colors.white,
              ),
              child: const Opacity(opacity: 0, child: Text('placeholder')),
            ),
            // Main Success Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0F0F),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.mark_email_read,
                    color: Color(FlickoColors.brandLime),
                    size: 48,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'EMAIL SENT!',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _successMessage ?? 'Check your inbox for the reset link.',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.textMuted),
                      fontSize: 14,
                      height: 1.5,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 32),
        
        GestureDetector(
          onTap: () {
            setState(() {
              _emailSent = false;
              _successMessage = null;
              _emailController.clear();
            });
          },
          child: Center(
            child: Text(
              'TRY DIFFERENT EMAIL',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 24),
        
        _buildStyledButton(
          label: 'RETURN TO LOGIN',
          onPressed: _navigateToLogin,
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
        // Shadow Box
        Container(
          width: double.infinity,
          height: 56,
          margin: const EdgeInsets.only(top: 4, left: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        // Main Button
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
              padding: EdgeInsets.zero,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                    ),
                  )
                : Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
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
        color: const Color(FlickoColors.danger).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        _generalError!,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.danger),
          fontSize: 14,
          fontWeight: FontWeight.w600,
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
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          onChanged: (_) => onChanged?.call(),
          onSubmitted: (_) => onSubmitted?.call(),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          cursorColor: const Color(FlickoColors.brandLime),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.inter(
              color: const Color(0xFF333333),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
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
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 18,
            ),
            errorText: error,
          ),
        ),
      ],
    );
  }
}
