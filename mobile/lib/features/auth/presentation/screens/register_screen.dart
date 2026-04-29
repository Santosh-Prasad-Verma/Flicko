import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:mobile/data/services/clerk_auth_service.dart';
import 'package:clerk_auth/clerk_auth.dart' as clerk_auth_api;
import 'package:fl_country_code_picker/fl_country_code_picker.dart';


/// Register Screen — Premium Discord-inspired with Clerk Authentication
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  final _emailFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _emailError;
  String? _usernameError;
  String? _phoneError;
  String? _passwordError;
  String? _confirmError;
  String? _generalError;
  String? _successMessage;
  bool _isLoading = false;
  bool _tosAccepted = false;
  String? _tosError;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  CountryCode _selectedCountry = const CountryCode(name: 'United States', code: 'US', dialCode: '+1');
  final _countryPicker = const FlCountryCodePicker(
    showDialCode: true,
    showSearchBar: true,
  );
  
  Timer? _usernameCheckTimer;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _usernameFocusNode.dispose();
    _phoneFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmFocusNode.dispose();
    _animationController.dispose();
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
    return true; // Simplified for UX, real validation on server
  }

  void _handleUsernameChange(String value) {
    setState(() => _usernameError = null);
  }

  Future<void> _handleSocialLogin(String strategy) async {
    try {
      await ref.read(authNotifierProvider.notifier).signInWithOAuth(strategy);
    } catch (e) {
      if (mounted) {
        setState(() => _generalError = 'Failed to sign in with social provider.');
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

    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    debugPrint('Validation check:');
    debugPrint('Password length: ${password.length}');
    debugPrint('Confirm length: ${confirmPassword.length}');
    debugPrint('Passwords match exactly: ${password == confirmPassword}');

    if (password.isEmpty) {
      setState(() => _passwordError = 'Password is required');
      valid = false;
    } else if (!_validatePassword(password)) {
      setState(() => _passwordError = 'Password must be at least 8 characters');
      valid = false;
    }

    if (password != confirmPassword) {
      setState(() => _confirmError = 'Passwords do not match');
      valid = false;
    }

    if (!_tosAccepted) {
      setState(() => _tosError = 'Please accept the Terms of Service');
      valid = false;
    }

    return valid;
  }

  Future<void> _handleRegister() async {
    if (!_validate()) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      final phone = '${_selectedCountry.dialCode}${_phoneController.text.trim().replaceAll(RegExp(r'^\+'), '')}';
      
      final password = _passwordController.text.trim();
      
      await ref.read(authNotifierProvider.notifier).signUp(
        _emailController.text.trim().toLowerCase(),
        password,
        _confirmPasswordController.text.trim(),
        _usernameController.text.trim(),
        phone: phone,
      );

      if (mounted) {
        final clerk = ClerkAuthService.currentAuthState;
        final signUp = clerk?.client.signUp;
        final needsPhone = signUp?.unverifiedFields.contains(clerk_auth_api.Field.phoneNumber) ?? false;
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpVerificationScreen(
              email: _emailController.text.trim().toLowerCase(),
              phone: phone,
              isPhone: needsPhone,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Register error: $e');
      if (mounted) {
        setState(() => _generalError = e.toString().replaceAll('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E1F22),
                  Color(0xFF2B2D31),
                  Color(0xFF1E1F22),
                ],
              ),
            ),
          ),
          
          // Background Decorative Elements
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF5865F2).withValues(alpha: 0.04),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Logo & Brand
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Hero(
                              tag: 'app_logo',
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.asset(
                                  'assets/images/Flicko-con-without-background.png',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF5865F2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(Icons.flash_on, color: Colors.white, size: 30),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              'Flicko',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),

                        // Register Card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(24),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Create an account',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  if (_generalError != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDA373C).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFFDA373C).withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        _generalError!,
                                        style: GoogleFonts.inter(color: const Color(0xFFDA373C), fontSize: 13),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  if (_successMessage != null) ...[
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF23A559).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF23A559).withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        _successMessage!,
                                        style: GoogleFonts.inter(color: const Color(0xFF23A559), fontSize: 13, fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  _buildInput(
                                    label: 'EMAIL',
                                    placeholder: 'name@example.com',
                                    controller: _emailController,
                                    focusNode: _emailFocusNode,
                                    error: _emailError,
                                    keyboardType: TextInputType.emailAddress,
                                    icon: Icons.alternate_email,
                                  ),
                                  
                                  _buildInput(
                                    label: 'USERNAME',
                                    placeholder: 'flicko_user',
                                    controller: _usernameController,
                                    focusNode: _usernameFocusNode,
                                    error: _usernameError,
                                    icon: Icons.person_outline,
                                    onChanged: _handleUsernameChange,
                                  ),

                                      GestureDetector(
                                        onTap: () async {
                                          final code = await _countryPicker.showPicker(context: context);
                                          if (code != null) {
                                            setState(() {
                                              _selectedCountry = code;
                                            });
                                          }
                                        },
                                        child: _buildInput(
                                          label: 'PHONE NUMBER',
                                          placeholder: '234 567 8900',
                                          controller: _phoneController,
                                          focusNode: _phoneFocusNode,
                                          error: _phoneError,
                                          keyboardType: TextInputType.phone,
                                          icon: Icons.phone_outlined,
                                          onChanged: (value) {
                                            // Auto-detect country code as user types
                                            String digits = value.replaceAll(RegExp(r'[^0-9]'), '');
                                            if (value.startsWith('+') || digits.isNotEmpty) {
                                              // Look for matches in the picker's common country code list
                                              final searchStr = value.startsWith('+') ? value : '+$value';
                                              final match = _countryPicker.countryCodes.where((c) => searchStr.startsWith(c.dialCode)).toList();
                                              
                                              if (match.isNotEmpty) {
                                                // Sort by length descending to get the most specific match (e.g. +1 vs +1246)
                                                match.sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
                                                final bestMatch = match.first;
                                                
                                                if (_selectedCountry.dialCode != bestMatch.dialCode) {
                                                  setState(() {
                                                    _selectedCountry = bestMatch;
                                                  });
                                                }
                                              }
                                            }
                                          },
                                          prefix: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ClipRRect(borderRadius: BorderRadius.circular(2), child: _selectedCountry.flagImage(width: 24)),
                                                const SizedBox(width: 4),
                                                Text(
                                                  _selectedCountry.dialCode,
                                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                                                ),
                                                const Icon(Icons.arrow_drop_down, color: Color(0xFF72767D), size: 20),
                                                Container(
                                                  height: 24,
                                                  width: 1,
                                                  color: Colors.white.withValues(alpha: 0.1),
                                                  margin: const EdgeInsets.symmetric(horizontal: 8),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                  
                                  _buildInput(
                                    label: 'PASSWORD',
                                    placeholder: '••••••••',
                                    controller: _passwordController,
                                    focusNode: _passwordFocusNode,
                                    error: _passwordError,
                                    isPassword: true,
                                    icon: Icons.lock_outline,
                                    isVisible: _passwordVisible,
                                    onToggleVisibility: () => setState(() => _passwordVisible = !_passwordVisible),
                                    onChanged: (_) {
                                      if (_passwordError != null || _confirmError != null) {
                                        setState(() {
                                          _passwordError = null;
                                          _confirmError = null;
                                        });
                                      }
                                    },
                                  ),

                                  _buildInput(
                                    label: 'CONFIRM PASSWORD',
                                    placeholder: '••••••••',
                                    controller: _confirmPasswordController,
                                    focusNode: _confirmFocusNode,
                                    error: _confirmError,
                                    isPassword: true,
                                    icon: Icons.lock_reset_outlined,
                                    isVisible: _confirmPasswordVisible,
                                    onToggleVisibility: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
                                    onChanged: (_) {
                                      if (_confirmError != null) {
                                        setState(() {
                                          _confirmError = null;
                                        });
                                      }
                                    },
                                  ),

                                  // TOS Checkbox
                                  GestureDetector(
                                    onTap: () => setState(() => _tosAccepted = !_tosAccepted),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 22,
                                          height: 22,
                                          decoration: BoxDecoration(
                                            color: _tosAccepted ? const Color(0xFF5865F2) : Colors.black.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(
                                              color: _tosError != null 
                                                  ? const Color(0xFFDA373C)
                                                  : _tosAccepted 
                                                      ? const Color(0xFF5865F2)
                                                      : Colors.white.withValues(alpha: 0.1),
                                              width: 1.5,
                                            ),
                                          ),
                                          child: _tosAccepted ? const Icon(Icons.check, color: Colors.white, size: 16) : null,
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            'I agree to the Terms & Privacy Policy',
                                            style: GoogleFonts.inter(color: const Color(0xFFB9BBBE), fontSize: 13),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // Register Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _handleRegister,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFF5865F2),
                                        foregroundColor: Colors.white,
                                        disabledBackgroundColor: const Color(0xFF5865F2).withValues(alpha: 0.5),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        elevation: 0,
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                          : Text('Register', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                                    ),
                                  ),

                                  const SizedBox(height: 24),

                                  // Divider
                                  Row(
                                    children: [
                                      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        child: Text(
                                          'OR',
                                          style: GoogleFonts.inter(
                                            color: const Color(0xFF72767D),
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.1))),
                                    ],
                                  ),

                                  const SizedBox(height: 24),

                                  // Social Auth Buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildSocialButton(
                                          iconPath: 'assets/images/google_icon.png',
                                          label: 'Google',
                                          onPressed: () => _handleSocialLogin('oauth_google'),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: _buildSocialButton(
                                          iconPath: 'assets/images/github_icon.png',
                                          label: 'GitHub',
                                          onPressed: () => _handleSocialLogin('oauth_github'),
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 24),

                                  // Login Link
                                  Center(
                                    child: GestureDetector(
                                      onTap: () => context.pop(),
                                      child: RichText(
                                        text: TextSpan(
                                          style: GoogleFonts.inter(color: const Color(0xFF72767D), fontSize: 14),
                                          children: [
                                            const TextSpan(text: 'Already have an account? '),
                                            TextSpan(
                                              text: 'Log In',
                                              style: GoogleFonts.inter(color: const Color(0xFF5865F2), fontWeight: FontWeight.w700),
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
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required String label,
    required String placeholder,
    required TextEditingController controller,
    required FocusNode focusNode,
    IconData? icon,
    Widget? prefix,
    String? error,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: error != null ? const Color(0xFFDA373C) : const Color(0xFFB9BBBE).withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: isPassword && !isVisible,
            keyboardType: keyboardType,
            onChanged: (v) {
              onChanged?.call(v);
              setState(() {});
            },
            onTap: () => setState(() {}),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: GoogleFonts.inter(color: const Color(0xFF72767D), fontSize: 15),
              prefixIcon: prefix ?? (icon != null ? Icon(icon, color: focusNode.hasFocus ? const Color(0xFF5865F2) : const Color(0xFF72767D), size: 20) : null),
              suffixIcon: isPassword ? IconButton(
                icon: Icon(isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: const Color(0xFFB9BBBE), size: 20),
                onPressed: onToggleVisibility,
              ) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              error,
              style: GoogleFonts.inter(
                color: const Color(0xFFDA373C),
                fontSize: 11,
                fontWeight: FontWeight.w400,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSocialButton({
    required String label,
    required String iconPath,
    required VoidCallback onPressed,
  }) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (label == 'GitHub')
                Image.network(
                  'https://cdn-icons-png.flaticon.com/512/25/25231.png',
                  width: 24,
                  height: 24,
                  color: Colors.white,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.code,
                    color: Colors.white,
                    size: 24,
                  ),
                )
              else
                Image.network(
                  'https://cdn-icons-png.flaticon.com/512/2991/2991148.png',
                  width: 24,
                  height: 24,
                  color: Colors.white,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.g_mobiledata,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              const SizedBox(width: 12),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
