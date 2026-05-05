import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/core/services/biometrics_service.dart';
import 'package:mobile/data/services/oauth_service.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';

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
  final _biometricsService = BiometricsService();
  final _oauthService = OAuthService();
  
  String? _emailError;
  String? _passwordError;
  String? _generalError;
  bool _isLoading = false;
  bool _showEmailNotConfirmed = false;
  bool _resendLoading = false;
  String? _resendMessage;
  String? _oauthLoading;
  bool _isBiometricAvailable = false;
  bool _isBiometricEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    final isAvailable = await _biometricsService.isBiometricAvailable();
    final isEnabled = await _biometricsService.isBiometricsEnabled();
    
    if (mounted) {
      setState(() {
        _isBiometricAvailable = isAvailable;
        _isBiometricEnabled = isEnabled;
      });
    }
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
      if (sanitizedEmail.contains('\0') || sanitizedPassword.contains('\0')) {
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

      // Update auth state
      ref.read(authProvider.notifier).setAuthenticated(true);
      ref.read(authProvider.notifier).setUser(response.user!);

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

  Future<void> _handleBiometricLogin() async {
    if (!_isBiometricAvailable || !_isBiometricEnabled) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      final biometricType = await _biometricsService.getPrimaryBiometricType();
      final authenticated = await _biometricsService.authenticate(
        localizedReason: 'Use $biometricType to access your Flicko account',
      );

      if (!authenticated) {
        setState(() => _isLoading = false);
        return;
      }

      final credentials = await _biometricsService.getCredentials();
      if (credentials == null) {
        setState(() {
          _isLoading = false;
          _generalError = 'No saved credentials found. Please login with password first.';
        });
        return;
      }

      _emailController.text = credentials['email']!;
      _passwordController.text = credentials['password']!;

      await _handleLogin();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _generalError = 'Biometric authentication failed. Please try again.';
      });
    }
  }

  Future<void> _enableBiometrics() async {
    if (!_isBiometricAvailable) return;

    try {
      final authenticated = await _biometricsService.authenticate(
        localizedReason: 'Enable biometric login for quick access',
      );

      if (!authenticated) return;

      await _biometricsService.enableBiometrics();
      await _biometricsService.storeCredentials(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text.trim(),
      );

      setState(() => _isBiometricEnabled = true);
    } catch (e) {
      setState(() => _generalError = 'Failed to enable biometrics. Please try again.');
    }
  }

  Future<void> _handleOAuth(String provider) async {
    setState(() {
      _oauthLoading = provider;
      _generalError = null;
    });

    try {
      OAuthResponse response;
      
      switch (provider.toLowerCase()) {
        case 'google':
          response = await _oauthService.signInWithGoogle();
          break;
        case 'apple':
          response = await _oauthService.signInWithApple();
          break;
        case 'discord':
          response = await _oauthService.signInWithDiscord();
          break;
        default:
          response = OAuthResponse(success: false, error: 'Unknown provider');
      }

      if (!response.success || response.user == null) {
        setState(() => _generalError = response.error ?? 'OAuth sign-in failed');
        return;
      }

      // Update auth state
      ref.read(authProvider.notifier).setAuthenticated(true);
      ref.read(authProvider.notifier).setUser(response.user!);

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
      backgroundColor: const Color(FlickoColors.bgPrimary),
      body: KeyboardDismissOnTap(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: topPadding + 40,
            bottom: bottomPadding + 40,
            left: 28,
            right: 28,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height - topPadding - bottomPadding - 80,
            ),
            child: IntrinsicHeight(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo
                  _buildLogo(),
                  
                  const SizedBox(height: 24),
                  
                  // Header
                  _buildHeader(),
                  
                  const SizedBox(height: 24),
                  
                  // Form
                  _buildForm(),
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
          'Welcome back!',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 25,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          "We're so excited to see you again!",
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
          hint: 'Email or Phone Number',
          controller: _emailController,
          error: _emailError,
          keyboardType: TextInputType.emailAddress,
          onChanged: () {
            if (_emailError != null) {
              setState(() => _emailError = null);
            }
          },
        ),
        
        const SizedBox(height: 16),
        
        // Password Field
        _buildTextField(
          label: 'PASSWORD',
          hint: 'Password',
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
        
        const SizedBox(height: 8),
        
        // Forgot Password
        GestureDetector(
          onTap: () {
            // TODO: Navigate to forgot password
          },
          child: Text(
            'Forgot your password?',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.blurple),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Login Button
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
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
                    'Log In',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Biometric Login Button
        if (_isBiometricAvailable && _isBiometricEnabled)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _handleBiometricLogin,
              icon: const Icon(Icons.fingerprint, size: 20),
              label: Text(
                'Login with Biometrics',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(FlickoColors.textPrimary),
                side: const BorderSide(color: Color(FlickoColors.bgTertiary)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        
        if (_isBiometricAvailable && !_isBiometricEnabled)
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: _isLoading ? null : _enableBiometrics,
              icon: const Icon(Icons.fingerprint, size: 20),
              label: Text(
                'Enable Biometric Login',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(FlickoColors.textPrimary),
                side: const BorderSide(color: Color(FlickoColors.bgTertiary)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        
        const SizedBox(height: 20),
        
        // OAuth Divider
        _buildOAuthDivider(),
        
        const SizedBox(height: 20),
        
        // OAuth Buttons
        _buildOAuthButton(
          icon: Icons.g_mobiledata,
          label: _oauthLoading == 'google' ? 'Signing in...' : 'Continue with Google',
          onTap: () => _handleOAuth('google'),
          loading: _oauthLoading == 'google',
        ),
        
        const SizedBox(height: 10),
        
        _buildOAuthButton(
          icon: Icons.discord,
          label: _oauthLoading == 'discord' ? 'Signing in...' : 'Continue with Discord',
          onTap: () => _handleOAuth('discord'),
          iconColor: const Color(0xFF5865F2),
          loading: _oauthLoading == 'discord',
        ),
        
        const SizedBox(height: 10),
        
        _buildOAuthButton(
          icon: Icons.code,
          label: _oauthLoading == 'github' ? 'Signing in...' : 'Continue with GitHub',
          onTap: () => _handleOAuth('github'),
          loading: _oauthLoading == 'github',
        ),
        
        const SizedBox(height: 20),
        
        // Register Link
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Need an account? ',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 14,
              ),
            ),
            GestureDetector(
              onTap: _navigateToRegister,
              child: Text(
                'Register',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.blurple),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
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
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
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

  Widget _buildOAuthDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: const Color(FlickoColors.bgTertiary),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: const Color(FlickoColors.bgTertiary),
          ),
        ),
      ],
    );
  }

  Widget _buildOAuthButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? iconColor,
    bool loading = false,
  }) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgSecondary),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: iconColor ?? const Color(FlickoColors.textPrimary),
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper widget to dismiss keyboard on tap
class KeyboardDismissOnTap extends StatelessWidget {
  final Widget child;
  
  const KeyboardDismissOnTap({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      behavior: HitTestBehavior.translucent,
      child: child,
    );
  }
}
