import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/providers/auth_provider.dart';

/// Register Screen — Discord-inspired
///
/// Flicko logo at top, "Create an account" heading, dark form with blurple accent.
/// Mirrors the React Native register.tsx screen.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  String? _emailError;
  String? _usernameError;
  String? _passwordError;
  String? _confirmError;
  String? _generalError;
  String? _successMessage;
  bool _isLoading = false;
  bool _tosAccepted = false;
  String? _tosError;
  bool _checkingUsername = false;
  bool _showResend = false;
  bool _resendLoading = false;
  String? _resendMessage;
  String? _oauthLoading;
  
  Timer? _usernameCheckTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _usernameCheckTimer?.cancel();
    super.dispose();
  }

  bool _validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  bool _validateUsername(String username) {
    final usernameRegex = RegExp(r'^[\w.-]{2,32}$');
    return usernameRegex.hasMatch(username);
  }

  bool _validatePassword(String password) {
    // At least 8 chars, 1 uppercase, 1 lowercase, 1 number, 1 special
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'\d'))) return false;
    if (!password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};:\x22\x27\\|,.<>\/?]'))) return false;
    // No 3+ repeated chars
    if (RegExp(r'(.)\1{2,}').hasMatch(password)) return false;
    return true;
  }

  void _handleUsernameChange(String value) {
    setState(() {
      _usernameError = null;
    });
    
    _usernameCheckTimer?.cancel();
    final trimmed = value.trim();
    if (trimmed.length >= 2 && _validateUsername(trimmed)) {
      _usernameCheckTimer = Timer(const Duration(milliseconds: 500), () {
        _checkUsernameAvailability(trimmed);
      });
    }
  }

  Future<void> _checkUsernameAvailability(String name) async {
    setState(() => _checkingUsername = true);
    
    try {
      final supabase = Supabase.instance.client;
      final data = await supabase
          .from('profiles')
          .select('id')
          .ilike('username', name)
          .limit(1);
          
      if (data != null && data.isNotEmpty) {
        setState(() => _usernameError = 'Username is already taken');
      }
    } catch (e) {
      // Silently ignore network errors during check
    } finally {
      setState(() => _checkingUsername = false);
    }
  }

  bool _validate() {
    setState(() {
      _emailError = null;
      _usernameError = null;
      _passwordError = null;
      _confirmError = null;
      _generalError = null;
      _successMessage = null;
      _tosError = null;
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

    final trimmedUsername = _usernameController.text.trim();
    if (trimmedUsername.isEmpty) {
      setState(() => _usernameError = 'Username is required');
      valid = false;
    } else if (!_validateUsername(trimmedUsername)) {
      setState(() => _usernameError = '2-32 chars: letters, numbers, _ . -');
      valid = false;
    }

    final password = _passwordController.text;
    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      valid = false;
    } else if (!_validatePassword(password)) {
      if (password.length < 8) {
        setState(() { _passwordError = 'Password must be at least 8 characters'; });
      } else if (!password.contains(RegExp(r'[A-Z]'))) {
        setState(() { _passwordError = 'Password needs at least one uppercase letter'; });
      } else if (!password.contains(RegExp(r'[a-z]'))) {
        setState(() { _passwordError = 'Password needs at least one lowercase letter'; });
      } else if (!password.contains(RegExp(r'\d'))) {
        setState(() { _passwordError = 'Password needs at least one number'; });
      } else if (!password.contains(RegExp(r'[!@#$%^&*]'))) {
        setState(() { _passwordError = 'Special character required'; });
      } else if (RegExp(r'(.)\1{2,}').hasMatch(password)) {
        setState(() { _passwordError = 'No 3+ repeated characters'; });
      } else {
        setState(() { _passwordError = 'Password is too simple'; });
      }
      valid = false;
    }

    final confirmPassword = _confirmPasswordController.text;
    if (confirmPassword.isEmpty) {
      setState(() => _confirmError = 'Please confirm your password');
      valid = false;
    } else if (password != confirmPassword) {
      setState(() => _confirmError = 'Passwords do not match');
      valid = false;
    }

    if (!_tosAccepted) {
      setState(() => _tosError = 'You must accept the Terms of Service and Privacy Policy');
      valid = false;
    }

    return valid;
  }

  Future<void> _handleResend() async {
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
        _resendMessage = 'Confirmation email sent! Check your inbox and spam folder.'
      );
    } catch (e) {
      setState(() => _resendMessage = 'Could not resend — try again in a minute.');
    } finally {
      setState(() => _resendLoading = false);
    }
  }

  Future<void> _handleRegister() async {
    if (!_validate()) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
      _successMessage = null;
    });

    try {
      // Final server-side username uniqueness check
      final trimmedUsername = _usernameController.text.trim();
      final supabase = Supabase.instance.client;
      final existing = await supabase
          .from('profiles')
          .select('id')
          .ilike('username', trimmedUsername)
          .limit(1);
          
      if (existing != null && existing.isNotEmpty) {
        setState(() => _usernameError = 'Username is already taken');
        setState(() => _isLoading = false);
        return;
      }

      // HIGH-002: Sanitize and validate inputs
      final sanitizedEmail = _emailController.text.trim().toLowerCase();
      final sanitizedUsername = trimmedUsername.replaceAll(RegExp(r'[^\w.-]'), '');
      final sanitizedDisplayName = trimmedUsername
          .replaceAll(RegExp(r'''[<>"'&]'''), '') // Remove XSS chars
          .substring(0, 32); // Enforce max length

      if (sanitizedUsername != trimmedUsername) {
        setState(() => _usernameError = 'Username contains invalid characters (only letters, numbers, _ . - allowed)');
        setState(() => _isLoading = false);
        return;
      }

      final response = await supabase.auth.signUp(
        email: sanitizedEmail,
        password: _passwordController.text,
        data: {
          'username': sanitizedUsername,
          'display_name': sanitizedDisplayName,
        },
      );

      if (response.user == null) {
        // Supabase returns error when email confirmation is enabled but SMTP isn't configured
        // Try auto sign-in since account may have been created
        try {
          final signInResponse = await supabase.auth.signInWithPassword(
            email: sanitizedEmail,
            password: _passwordController.text,
          );
          
          if (signInResponse.user != null) {
            ref.read(authProvider.notifier).setAuthenticated(true);
            ref.read(authProvider.notifier).setUser(signInResponse.user!);
            if (mounted) {
              context.go('/');
            }
            return;
          }
        } catch (_) {
          // Auto sign-in failed
        }
        
        setState(() {
          _showResend = true;
          _successMessage = 'Account created! A confirmation link has been sent to your email. Check your spam folder too.';
        });
        return;
      }

      // Registration successful
      if (response.session != null) {
        ref.read(authProvider.notifier).setAuthenticated(true);
        ref.read(authProvider.notifier).setUser(response.user!);
        if (mounted) {
          context.go('/');
        }
      } else {
        setState(() {
          _showResend = true;
          _successMessage = 'Account created! A confirmation link has been sent to your email. Check your spam folder too.';
        });
      }
    } on AuthException catch (e) {
      final isEmailDeliveryError = RegExp(r'confirm|email', caseSensitive: false).hasMatch(e.message);
      if (isEmailDeliveryError) {
        setState(() {
          _showResend = true;
          _successMessage = 'Account created! A confirmation link has been sent to your email. Check your spam folder too.';
        });
      } else {
        setState(() => _generalError = e.message);
      }
    } catch (e) {
      debugPrint('Register error: $e');
      setState(() => _generalError = 'An unexpected error occurred');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleOAuth(String provider) async {
    setState(() {
      _oauthLoading = provider;
      _generalError = null;
    });

    try {
      // OAuth implementation would go here
      await Future.delayed(const Duration(seconds: 1));
      setState(() => _generalError = '$provider sign-up coming soon!');
    } catch (e) {
      setState(() => _generalError = 'OAuth sign-up failed. Please try again.');
    } finally {
      setState(() => _oauthLoading = null);
    }
  }

  void _navigateToLogin() {
    context.pop();
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
                  
                  const SizedBox(height: 12),
                  
                  // Logo
                  _buildLogo(),
                  
                  const SizedBox(height: 12),
                  
                  // Header
                  _buildHeader(),
                  
                  const SizedBox(height: 20),
                  
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
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: const Color(FlickoColors.blurple),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.chat_bubble,
            color: Colors.white,
            size: 26,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Flicko',
          style: GoogleFonts.pacifico(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 28,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Text(
      'Create an account',
      style: GoogleFonts.inter(
        color: const Color(FlickoColors.textPrimary),
        fontSize: 25,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Success Banner
        if (_successMessage != null) _buildSuccessBanner(),
        
        // Error Banner
        if (_generalError != null) _buildErrorBanner(),
        
        // Email Field
        _buildTextField(
          label: 'EMAIL',
          hint: 'Enter your email address',
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
        
        // Username Field
        _buildTextField(
          label: 'USERNAME',
          hint: 'Choose a username',
          controller: _usernameController,
          error: _usernameError,
          hintText: _checkingUsername ? 'Checking availability...' : null,
          onChanged: _handleUsernameChange,
        ),
        
        const SizedBox(height: 16),
        
        // Password Field
        _buildTextField(
          label: 'PASSWORD',
          hint: 'Create a password',
          controller: _passwordController,
          error: _passwordError,
          isPassword: true,
          onChanged: () {
            if (_passwordError != null) {
              setState(() => _passwordError = null);
            }
          },
        ),
        
        const SizedBox(height: 16),
        
        // Confirm Password Field
        _buildTextField(
          label: 'CONFIRM PASSWORD',
          hint: 'Confirm your password',
          controller: _confirmPasswordController,
          error: _confirmError,
          isPassword: true,
          onSubmitted: _handleRegister,
          onChanged: () {
            if (_confirmError != null) {
              setState(() => _confirmError = null);
            }
          },
        ),
        
        const SizedBox(height: 16),
        
        // TOS Checkbox
        _buildTOSCheckbox(),
        
        if (_tosError != null) ...[
          const SizedBox(height: 4),
          Text(
            _tosError!,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.danger),
              fontSize: 11,
            ),
          ),
        ],
        
        const SizedBox(height: 20),
        
        // Register Button
        SizedBox(
          width: double.infinity,
          height: 44,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _handleRegister,
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
                    'Continue',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
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
          label: _oauthLoading == 'google' ? 'Signing up...' : 'Continue with Google',
          onTap: () => _handleOAuth('google'),
          loading: _oauthLoading == 'google',
        ),
        
        const SizedBox(height: 10),
        
        _buildOAuthButton(
          icon: Icons.discord,
          label: _oauthLoading == 'discord' ? 'Signing up...' : 'Continue with Discord',
          onTap: () => _handleOAuth('discord'),
          iconColor: const Color(0xFF5865F2),
          loading: _oauthLoading == 'discord',
        ),
        
        const SizedBox(height: 10),
        
        _buildOAuthButton(
          icon: Icons.code,
          label: _oauthLoading == 'github' ? 'Signing up...' : 'Continue with GitHub',
          onTap: () => _handleOAuth('github'),
          loading: _oauthLoading == 'github',
        ),
        
        const SizedBox(height: 16),
        
        // Login Link
        GestureDetector(
          onTap: _navigateToLogin,
          child: Text(
            'Already have an account?',
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

  Widget _buildSuccessBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.success).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            _successMessage!,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.success),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (_showResend) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _resendLoading ? null : _handleResend,
              child: Text(
                _resendLoading ? 'Sending...' : 'Resend confirmation email',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.blurple),
                  fontSize: 13,
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
                  color: const Color(FlickoColors.success),
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
    String? hintText,
    bool isPassword = false,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
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
          onChanged: onChanged,
          onSubmitted: (_) => onSubmitted?.call(),
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 16,
          ),
          decoration: InputDecoration(
            hintText: hint,
            helperText: hintText,
            helperStyle: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
            ),
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

  Widget _buildTOSCheckbox() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _tosAccepted = !_tosAccepted;
          _tosError = null;
        });
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: _tosAccepted 
                  ? const Color(FlickoColors.blurple) 
                  : Colors.transparent,
              border: Border.all(
                color: _tosError != null 
                    ? const Color(FlickoColors.danger)
                    : _tosAccepted 
                        ? const Color(FlickoColors.blurple)
                        : const Color(FlickoColors.textMuted),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(5),
            ),
            child: _tosAccepted
                ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 14,
                  )
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 12,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'I agree to Flicko\'s '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.blurple),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.blurple),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
