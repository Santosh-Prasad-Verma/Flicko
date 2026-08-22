import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/data/clients/api_client.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/services/oauth_service.dart';
import 'package:mobile/features/shared/presentation/widgets/keyboard_dismiss_on_tap.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:mobile/core/services/username_availability_service.dart';

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
  bool _showResend = false;
  bool _resendLoading = false;
  String? _oauthLoading;
  bool _isVerificationEmailSent = false;
  
  bool _isCheckingUsername = false;
  bool? _isUsernameAvailable;
  Timer? _usernameCheckTimer;
  List<String> _usernameSuggestions = [];

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
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[A-Z]'))) return false;
    if (!password.contains(RegExp(r'[a-z]'))) return false;
    if (!password.contains(RegExp(r'\d'))) return false;
    if (!password.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};:\x22\x27\\|,.<>\/?]'))) return false;
    if (RegExp(r'(.)\1{2,}').hasMatch(password)) return false;
    return true;
  }

  String _sanitizeErrorMessage(String raw) {
    if (raw.contains('502') || raw.contains('unexpected_failure') || raw.contains('hook')) {
      return 'Registration service is currently busy. Please try again or use Google/GitHub sign in.';
    }
    if (raw.contains('already registered') || raw.contains('User already registered')) {
      return 'This email address is already registered. Try logging in instead.';
    }
    if (raw.contains('Username is already taken') || raw.contains('username_taken')) {
      return 'Username is already taken. Please choose a different username.';
    }
    if (raw.contains('Password should be at least')) {
      return 'Password should be at least 8 characters long.';
    }
    if (raw.startsWith('{') && raw.contains('"message"')) {
      final match = RegExp(r'"message"\s*:\s*"([^"]+)"').firstMatch(raw);
      if (match != null) {
        final innerMsg = match.group(1)!;
        if (innerMsg.contains('502')) {
          return 'Registration server connection issue. Please try again.';
        }
        return innerMsg;
      }
    }
    return raw.replaceAll(RegExp(r'^AuthException:\s*'), '').trim();
  }

  void _handleUsernameChange(String value) {
    setState(() {
      _usernameError = null;
      _isUsernameAvailable = null;
      _isCheckingUsername = false;
      _usernameSuggestions = [];
    });

    _usernameCheckTimer?.cancel();
    final trimmed = value.trim();
    if (trimmed.length >= 2) {
      setState(() => _isCheckingUsername = true);
      _usernameCheckTimer = Timer(const Duration(milliseconds: 300), () {
        _checkUsernameAvailability(trimmed);
      });
    }
  }

  Future<void> _checkUsernameAvailability(String name) async {
    try {
      final service = ref.read(usernameAvailabilityServiceProvider);
      final result = await service.checkAvailability(name);

      if (!mounted) return;
      setState(() {
        _isCheckingUsername = false;
        _isUsernameAvailable = result.isAvailable;
        _usernameError = result.error;
        _usernameSuggestions = result.suggestions;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isCheckingUsername = false;
          _isUsernameAvailable = true;
          _usernameError = null;
        });
      }
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
      _successMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).resendVerification(
        _emailController.text.trim().toLowerCase(),
      );
      
      setState(() => 
        _successMessage = 'Confirmation email sent! Check your inbox and spam folder.'
      );
    } catch (e) {
      setState(() => _generalError = 'Could not resend — try again in a minute.');
    } finally {
      if (mounted) {
        setState(() => _resendLoading = false);
      }
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
      // HIGH-002: Sanitize and validate inputs
      final sanitizedEmail = _emailController.text.trim().toLowerCase();
      final trimmedUsername = _usernameController.text.trim();
      final sanitizedUsername = trimmedUsername.replaceAll(RegExp(r'[^\w.-]'), '');

      if (sanitizedUsername != trimmedUsername) {
        setState(() => _usernameError = 'Username contains invalid characters (only letters, numbers, _ . - allowed)');
        setState(() => _isLoading = false);
        return;
      }

      await ref.read(authNotifierProvider.notifier).signUp(
        sanitizedEmail,
        _passwordController.text,
        sanitizedUsername,
      );

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      debugPrint('Register error: $e');
      setState(() => _generalError = _sanitizeErrorMessage(e.toString()));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  final _oauthService = AppOAuthService();

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

      if (response.pending) return;

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      setState(() => _generalError = 'OAuth sign-up failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _oauthLoading = null);
      }
    }
  }

  void _navigateToLogin() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
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
                  
                  const SizedBox(height: 40),
                  
                  if (_isVerificationEmailSent)
                    _buildCheckEmailView()
                  else ...[
                    // Header
                    _buildHeader(),
                    
                    const SizedBox(height: 48),
                    
                    // Form
                    _buildForm(),
                    
                    const SizedBox(height: 40),
                    
                    // Footer
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
                              const TextSpan(text: 'ALREADY HAVE AN ACCOUNT? '),
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
          'CREATE\nACCOUNT.',
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
          "JOIN THE FLICKO COMMUNITY",
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
        // Success Banner
        if (_successMessage != null) _buildSuccessBanner(),
        
        // Error Banner
        if (_generalError != null) _buildErrorBanner(),
        
        // Email Field
        _buildTextField(
          label: 'EMAIL',
          hint: 'YOUR@EMAIL.COM',
          controller: _emailController,
          error: _emailError,
          keyboardType: TextInputType.emailAddress,
          onChanged: (val) {
            if (_emailError != null) {
              setState(() => _emailError = null);
            }
          },
        ),
        
        const SizedBox(height: 24),
        
        // Username Field
        _buildTextField(
          label: 'USERNAME',
          hint: 'CHOOSE_A_NAME',
          controller: _usernameController,
          error: _usernameError,
          onChanged: _handleUsernameChange,
        ),
        _buildUsernameAvailabilityIndicator(),
        
        const SizedBox(height: 24),
        
        // Password Field
        _buildTextField(
          label: 'PASSWORD',
          hint: '••••••••',
          controller: _passwordController,
          error: _passwordError,
          isPassword: true,
          onChanged: (val) {
            if (_passwordError != null) {
              setState(() => _passwordError = null);
            }
            setState(() {});
          },
        ),
        _buildPasswordStrengthCard(),
        
        const SizedBox(height: 24),
        
        // Confirm Password Field
        _buildTextField(
          label: 'CONFIRM PASSWORD',
          hint: '••••••••',
          controller: _confirmPasswordController,
          error: _confirmError,
          isPassword: true,
          onSubmitted: _handleRegister,
          onChanged: (val) {
            if (_confirmError != null) {
              setState(() => _confirmError = null);
            }
          },
        ),
        
        const SizedBox(height: 24),
        
        // TOS Checkbox
        _buildTOSCheckbox(),
        
        if (_tosError != null) ...[
          const SizedBox(height: 8),
          Text(
            _tosError!,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.danger),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        
        const SizedBox(height: 16),
        
        // Register Button
        _buildStyledButton(
          label: 'CREATE ACCOUNT',
          onPressed: _isLoading ? null : _handleRegister,
          isLoading: _isLoading,
          color: const Color(FlickoColors.brandLime),
          textColor: Colors.black,
        ),
        
        const SizedBox(height: 16),
        
        // OAuth Divider
        _buildOAuthDivider(),
        
        const SizedBox(height: 16),
        
        // OAuth Buttons
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

  Widget _buildSuccessBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.success).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            _successMessage!,
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.success),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          if (_showResend) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: _resendLoading ? null : _handleResend,
              child: Text(
                _resendLoading ? 'SENDING...' : 'RESEND VERIFICATION',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.brandLime),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.danger).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(FlickoColors.danger).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(FlickoColors.danger),
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _generalError!,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.danger),
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameAvailabilityIndicator() {
    final trimmed = _usernameController.text.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    if (_isCheckingUsername) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(Color(FlickoColors.textMuted)),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Checking username availability...',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textMuted),
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }

    if (_isUsernameAvailable == true) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Color(FlickoColors.brandLime), size: 14),
            const SizedBox(width: 6),
            Text(
              'Username is available',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.brandLime),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    if (_isUsernameAvailable == false) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cancel_rounded, color: Color(FlickoColors.danger), size: 14),
                const SizedBox(width: 6),
                Text(
                  _usernameError ?? 'Username is already taken',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.danger),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            if (_usernameSuggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'SUGGESTIONS:',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _usernameSuggestions.map((suggestion) {
                  return InkWell(
                    onTap: () {
                      _usernameController.text = suggestion;
                      _handleUsernameChange(suggestion);
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(FlickoColors.brandLime).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(FlickoColors.brandLime).withValues(alpha: 0.4),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        suggestion,
                        style: GoogleFonts.inter(
                          color: const Color(FlickoColors.brandLime),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildPasswordStrengthCard() {
    final pwd = _passwordController.text;
    if (pwd.isEmpty) return const SizedBox.shrink();

    final hasMinLength = pwd.length >= 8;
    final hasUpper = pwd.contains(RegExp(r'[A-Z]'));
    final hasLower = pwd.contains(RegExp(r'[a-z]'));
    final hasDigit = pwd.contains(RegExp(r'\d'));
    final hasSpecial = pwd.contains(RegExp(r'[!@#$%^&*()_+\-=\[\]{};:\x22\x27\\|,.<>\/?]'));

    int metCount = 0;
    if (hasMinLength) metCount++;
    if (hasUpper) metCount++;
    if (hasLower) metCount++;
    if (hasDigit) metCount++;
    if (hasSpecial) metCount++;

    Color strengthColor = Colors.redAccent;
    String strengthLabel = 'Weak';
    if (metCount >= 4) {
      strengthColor = const Color(FlickoColors.brandLime);
      strengthLabel = 'Strong';
    } else if (metCount >= 2) {
      strengthColor = Colors.orangeAccent;
      strengthLabel = 'Medium';
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PASSWORD STRENGTH',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              Text(
                strengthLabel.toUpperCase(),
                style: GoogleFonts.inter(
                  color: strengthColor,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(5, (index) {
              final active = index < metCount;
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index < 4 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: active ? strengthColor : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          _buildRequirementItem('At least 8 characters', hasMinLength),
          _buildRequirementItem('One uppercase letter (A-Z)', hasUpper),
          _buildRequirementItem('One lowercase letter (a-z)', hasLower),
          _buildRequirementItem('One number (0-9)', hasDigit),
          _buildRequirementItem('One special character (!@#\$%^&*)', hasSpecial),
        ],
      ),
    );
  }

  Widget _buildRequirementItem(String text, bool isMet) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            isMet ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            color: isMet ? const Color(FlickoColors.brandLime) : const Color(FlickoColors.textMuted),
            size: 13,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: GoogleFonts.inter(
              color: isMet ? Colors.white : const Color(FlickoColors.textMuted),
              fontSize: 11,
              fontWeight: isMet ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
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
            fontWeight: FontWeight.w900,
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          obscureText: isPassword,
          keyboardType: keyboardType,
          onChanged: onChanged,
          onSubmitted: (_) => onSubmitted?.call(),
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          cursorColor: const Color(FlickoColors.brandLime),
          decoration: InputDecoration(
            hintText: hint,
            helperText: hintText,
            helperStyle: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
            ),
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

  Widget _buildOAuthDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1,
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
        ),
      ],
    );
  }

  Widget _buildCheckEmailView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        
        // Mail icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: const Color(FlickoColors.brandLime).withValues(alpha: 0.08),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(FlickoColors.brandLime).withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: const Icon(
            Icons.mark_email_read_rounded,
            color: Color(FlickoColors.brandLime),
            size: 48,
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Title
        Text(
          'CHECK YOUR\nEMAIL.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 42,
            fontWeight: FontWeight.w900,
            height: 0.9,
            letterSpacing: -1.5,
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Subtitle
        Text(
          "WE'VE SENT A VERIFICATION LINK",
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textMuted),
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Email address display
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFF0F0F0F),
            border: Border.all(
              color: const Color(FlickoColors.brandLime).withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.email_outlined,
                color: const Color(FlickoColors.brandLime),
                size: 18,
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  _emailController.text.trim().toLowerCase(),
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Instructions
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0A),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.06),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              _buildStepItem(1, 'Open your email inbox (check spam too)'),
              const SizedBox(height: 14),
              _buildStepItem(2, 'Click the verification link in the email'),
              const SizedBox(height: 14),
              _buildStepItem(3, 'Come back and log in with your credentials'),
            ],
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Resend section
        if (_successMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _successMessage!,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.success),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        
        if (_generalError != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              _generalError!,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.danger),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        
        // Resend button
        GestureDetector(
          onTap: _resendLoading ? null : _handleResend,
          child: Text(
            _resendLoading ? 'SENDING...' : "DIDN'T RECEIVE IT? RESEND",
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.brandLime),
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
              decoration: TextDecoration.underline,
              decorationColor: const Color(FlickoColors.brandLime),
            ),
          ),
        ),
        
        const SizedBox(height: 32),
        
        // Go to Login button
        _buildStyledButton(
          label: 'GO TO LOGIN',
          onPressed: () => context.pop(),
          color: const Color(FlickoColors.brandLime),
          textColor: Colors.black,
        ),
      ],
    );
  }

  Widget _buildStepItem(int step, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: const Color(FlickoColors.brandLime).withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(FlickoColors.brandLime).withValues(alpha: 0.25),
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              '$step',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.brandLime),
                fontSize: 13,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: _tosAccepted 
                  ? const Color(FlickoColors.brandLime) 
                  : Colors.transparent,
              border: Border.all(
                color: _tosError != null 
                    ? const Color(FlickoColors.danger)
                    : _tosAccepted 
                        ? const Color(FlickoColors.brandLime)
                        : Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
              borderRadius: BorderRadius.zero,
            ),
            child: _tosAccepted
                ? const Icon(
                    Icons.check,
                    color: Colors.black,
                    size: 16,
                    weight: 900,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                children: [
                  const TextSpan(text: 'I AGREE TO THE '),
                  TextSpan(
                    text: 'TERMS OF SERVICE',
                    style: TextStyle(color: const Color(FlickoColors.brandLime)),
                  ),
                  const TextSpan(text: ' AND '),
                  TextSpan(
                    text: 'PRIVACY POLICY',
                    style: TextStyle(color: const Color(FlickoColors.brandLime)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
