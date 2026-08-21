import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/services/oauth_service.dart';
import 'package:mobile/features/shared/presentation/widgets/keyboard_dismiss_on_tap.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Login Screen — Discord-inspired
///
/// Flicko logo at top, "Welcome back!" heading, dark form with blurple accent.
/// Mirrors the React Native login.tsx screen.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _oauthService = AppOAuthService();
  
  String? _emailError;
  String? _passwordError;
  String? _generalError;
  bool _isLoading = false;
  bool _showEmailNotConfirmed = false;
  bool _resendLoading = false;
  String? _resendMessage;
  String? _oauthLoading;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }


  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  bool _validate() {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;
    });

    var valid = true;
    final trimmedEmail = _emailController.text.trim();
    
    if (trimmedEmail.isEmpty) {
      setState(() => _emailError = 'Email is required');
      valid = false;
    } else if (!_validateEmail(trimmedEmail)) {
      setState(() => _emailError = 'Enter a valid email address');
      valid = false;
    }

    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      valid = false;
    } else if (_passwordController.text.length < 6) {
      setState(() => _passwordError = 'Password must be at least 6 characters');
      valid = false;
    }

    return valid;
  }

  Future<void> _handleLogin() async {
    if (!_validate()) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
      _showEmailNotConfirmed = false;
      _resendMessage = null;
    });

    try {
      // CRIT-008: Sanitize inputs
      final sanitizedEmail = _emailController.text.trim().toLowerCase();
      final sanitizedPassword = _passwordController.text.trim();

      // CRIT-008: Additional validation
      if (sanitizedEmail.length > 254) {
        setState(() => _generalError = 'Email address too long');
        return;
      }

      if (sanitizedPassword.length > 128) {
        setState(() => _generalError = 'Password too long');
        return;
      }

      // CRIT-008: Check for null bytes (potential injection)
      if (sanitizedEmail.contains('\x00') || sanitizedPassword.contains('\x00')) {
        setState(() => _generalError = 'Invalid characters in credentials');
        return;
      }

      final supabase = Supabase.instance.client;
      final response = await supabase.auth.signInWithPassword(
        email: sanitizedEmail,
        password: sanitizedPassword,
      );

      if (response.user == null) {
        setState(() => _generalError = 'Login failed. Please try again.');
        return;
      }

      // Auth state automatically updated via authNotifierProvider listener

      if (mounted) {
        context.go('/');
      }
    } on AuthException catch (e) {
      // CRIT-008: Don't expose detailed error messages
      final isEmailNotConfirmed = 
          RegExp(r'email.*not.*confirm|not.*confirm.*email|confirm.*email', caseSensitive: false)
              .hasMatch(e.message);
      
      if (isEmailNotConfirmed) {
        setState(() {
          _showEmailNotConfirmed = true;
          _generalError = 'Your email address has not been verified yet. Please check your inbox (and spam folder) for the verification link.';
        });
      } else if (e.message.contains('Invalid login credentials')) {
        setState(() => _generalError = 'Invalid email or password');
      } else {
        setState(() => _generalError = 'Login failed. Please try again.');
      }
    } catch (e) {
      debugPrint('Login error: $e');
      setState(() => _generalError = 'An unexpected error occurred. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResendVerification() async {
    if (_emailController.text.isEmpty) return;
    
    setState(() {
      _resendLoading = true;
      _resendMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      await supabase.auth.resend(
        type: OtpType.signup,
        email: _emailController.text.trim().toLowerCase(),
      );
      
      setState(() => 
        _resendMessage = 'Verification email sent! Check your inbox and spam folder.'
      );
    } catch (e) {
      setState(() => _resendMessage = 'Could not resend — try again in a minute.');
    } finally {
      setState(() => _resendLoading = false);
    }
  }


  Future<void> _handleOAuth(String provider) async {
    setState(() {
      _oauthLoading = provider;
      _generalError = null;
    });

    try {
      AppOAuthResponse response;
      
      switch (provider.toLowerCase()) {
        case 'google':
          response = await _oauthService.signInWithGoogle();
          break;
        case 'apple':
          response = await _oauthService.signInWithApple();
          break;
        case 'github':
          response = await _oauthService.signInWithGitHub();
          break;
        case 'discord':
          response = await _oauthService.signInWithDiscord();
          break;
        default:
          response = AppOAuthResponse(success: false, error: 'Unknown provider');
      }

      if (!response.success) {
        setState(() => _generalError = response.error ?? 'OAuth sign-in failed');
        return;
      }

      // Browser-redirect flows (Google/GitHub/Discord) return pending=true.
      // The auth notifier listens for the deep-link callback; UI just
      // closes the loader and stays on the login screen until the session
      // arrives.
      if (response.pending) return;

      if (response.user == null) {
        setState(() => _generalError = response.error ?? 'OAuth sign-in failed');
        return;
      }

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      setState(() => _generalError = 'OAuth sign-in failed. Please try again.');
    } finally {
      setState(() => _oauthLoading = null);
    }
  }

  void _navigateToRegister() {
    context.push('/register');
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
                  
                  const SizedBox(height: 40),
                  
                  // Header
                  _buildHeader(),
                  
                  const SizedBox(height: 48),
                  
                  // Form
                  _buildForm(),
                  
                  const SizedBox(height: 40),
                  
                  // Footer
                  Center(
                    child: GestureDetector(
                      onTap: _navigateToRegister,
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.inter(
                            color: const Color(FlickoColors.textMuted),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                          children: [
                            const TextSpan(text: 'NEW TO FLICKO? '),
                            TextSpan(
                              text: 'JOIN THE CLUB',
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
          'WELCOME\nBACK.',
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
          "LET'S GET YOU LOGGED IN",
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
        
        // Identifier Field
        _buildTextField(
          label: 'EMAIL',
          hint: 'YOUR@EMAIL.COM',
          controller: _emailController,
          error: _emailError,
          onChanged: () {
            if (_emailError != null) {
              setState(() => _emailError = null);
            }
          },
        ),
        
        const SizedBox(height: 24),
        
        // Password Field
        _buildTextField(
          label: 'PASSWORD',
          hint: '••••••••',
          controller: _passwordController,
          error: _passwordError,
          isPassword: true,
          onSubmitted: _handleLogin,
          onChanged: () {
            if (_passwordError != null) {
              setState(() => _passwordError = null);
            }
          },
        ),
        
        const SizedBox(height: 12),
        
        // Forgot Password
        Align(
          alignment: Alignment.centerRight,
          child: GestureDetector(
            onTap: () => context.push('/forgot-password'),
            child: Text(
              'FORGOT PASSWORD?',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
        
        const SizedBox(height: 8),
        
        // Login Button with Shadow effect
        _buildStyledButton(
          label: 'LOG IN',
          onPressed: _isLoading ? null : _handleLogin,
          isLoading: _isLoading,
          color: const Color(FlickoColors.brandLime),
          textColor: Colors.black,
        ),
        
        const SizedBox(height: 16),
        
        // Social Buttons
        Row(
          children: [
            Expanded(
              child: _buildSocialButton(
                label: 'GOOGLE',
                iconPath: 'assets/icons/google.svg',
                onTap: () => _handleOAuth('google'),
                loading: _oauthLoading == 'google',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildSocialButton(
                label: 'GITHUB',
                iconPath: 'assets/icons/github.svg',
                onTap: () => _handleOAuth('github'),
                loading: _oauthLoading == 'github',
              ),
            ),
          ],
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

  Widget _buildSocialButton({
    required String label,
    required String iconPath,
    required VoidCallback onTap,
    bool loading = false,
  }) {
    return Stack(
      children: [
        // Lime Shadow
        Container(
          width: double.infinity,
          height: 50,
          margin: const EdgeInsets.only(top: 4, left: 4),
          decoration: BoxDecoration(
            color: const Color(FlickoColors.brandLime),
          ),
        ),
        // Button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: loading ? null : onTap,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white, width: 1.5),
              shape: const RoundedRectangleBorder(),
              padding: EdgeInsets.zero,
            ),
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.asset(
                        iconPath,
                        width: 20,
                        height: 20,
                        placeholderBuilder: (context) => const Icon(Icons.login, size: 20, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
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
      child: Column(
        children: [
          Text(
            _generalError!,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.danger),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (_showEmailNotConfirmed) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _resendLoading ? null : _handleResendVerification,
              child: Text(
                _resendLoading ? 'Sending...' : 'Resend verification email',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.blurple),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            if (_resendMessage != null) ...[
              const SizedBox(height: 6),
              Text(
                _resendMessage!,
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textSecondary),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    String? error,
    bool isPassword = false,
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
          obscureText: isPassword,
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
            suffixIcon: isPassword 
              ? const Icon(Icons.visibility_outlined, color: Color(0xFF333333), size: 22)
              : null,
          ),
        ),
      ],
    );
  }

}
