import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/auth/presentation/screens/otp_verification_screen.dart';
import 'package:fl_country_code_picker/fl_country_code_picker.dart';
import 'package:mobile/features/shared/presentation/widgets/brutalist_widgets.dart';
import 'package:mobile/data/repositories/auth_repository.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // Design Tokens
  static const kBackgroundColor = Color(0xFF050505);
  static const kSurfaceColor = Color(0xFF0C0C0E);
  static const kAccentColor = Color(0xFFCBEF17); // Neon Lime
  static const kErrorColor = Color(0xFFFF3366);
  static const kPrimaryTextColor = Colors.white;
  static const kMutedColor = Color(0xFF666666);

  final _emailFocusNode = FocusNode();
  final _usernameFocusNode = FocusNode();
  final _phoneFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmFocusNode = FocusNode();

  String? _emailError;
  String? _usernameError;
  String? _passwordError;
  String? _confirmError;
  String? _phoneError;
  String? _tosError;
  String? _generalError;
  bool _isLoading = false;
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;
  bool _tosAccepted = false;
  CountryCode? _selectedCountry;
  Timer? _usernameCheckTimer;
  
  late final FlCountryCodePicker _countryPicker;

  @override
  void initState() {
    super.initState();
    _countryPicker = FlCountryCodePicker(
      searchBarDecoration: InputDecoration(
        hintText: 'SEARCH COUNTRY',
        hintStyle: GoogleFonts.spaceGrotesk(color: kMutedColor),
        filled: true,
        fillColor: kBackgroundColor,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kMutedColor.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: kMutedColor.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kAccentColor),
        ),
      ),
      searchBarTextStyle: GoogleFonts.spaceGrotesk(color: kPrimaryTextColor),
      countryTextStyle: GoogleFonts.spaceGrotesk(color: kPrimaryTextColor),
      dialCodeTextStyle: GoogleFonts.spaceGrotesk(color: kPrimaryTextColor, fontWeight: FontWeight.bold),
    );
    _emailFocusNode.addListener(() => setState(() {}));
    _usernameFocusNode.addListener(() => setState(() {}));
    _phoneFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
    _confirmFocusNode.addListener(() => setState(() {}));
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
    return password.length >= 8;
  }

  void _handleUsernameChange(String value) {
    setState(() => _usernameError = null);
    
    _usernameCheckTimer?.cancel();
    final trimmed = value.trim();
    if (trimmed.length >= 2) {
      _usernameCheckTimer = Timer(const Duration(milliseconds: 500), () async {
        if (!mounted) return;
        final exists = await ref.read(authRepositoryProvider).checkUsernameExists(trimmed);
        if (exists && mounted) {
          setState(() {
            _usernameError = 'USERNAME ALREADY EXISTS';
          });
        }
      });
    }
  }

  Future<void> _handleSocialLogin(String provider) async {
    try {
      await ref.read(authNotifierProvider.notifier).signInWithOAuth(provider);
    } catch (e) {
      if (mounted) {
        setState(() => _generalError = 'FAILED TO SIGN IN WITH ${provider.toUpperCase()}.');
      }
    }
  }

  void _handlePhoneChange(String value) {
    if (value.startsWith('+')) {
      final countryCodes = const FlCountryCodePicker().countryCodes.toList();
      countryCodes.sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));

      for (final code in countryCodes) {
        if (value.startsWith(code.dialCode)) {
          if (_selectedCountry?.dialCode != code.dialCode) {
            setState(() {
              _selectedCountry = code;
              _phoneController.text = value.substring(code.dialCode.length).trimLeft();
              _phoneController.selection = TextSelection.fromPosition(TextPosition(offset: _phoneController.text.length));
            });
          }
          break;
        }
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
      setState(() => _emailError = 'EMAIL IS REQUIRED');
      valid = false;
    } else if (!_validateEmail(trimmedEmail)) {
      setState(() => _emailError = 'INVALID EMAIL FORMAT');
      valid = false;
    }

    final trimmedUsername = _usernameController.text.trim();
    if (trimmedUsername.isEmpty) {
      setState(() => _usernameError = 'USERNAME IS REQUIRED');
      valid = false;
    } else if (!_validateUsername(trimmedUsername)) {
      setState(() => _usernameError = '2-32 CHARS: LETTERS, NUMBERS, _ . -');
      valid = false;
    }

    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if (password.isEmpty) {
      setState(() => _passwordError = 'PASSWORD IS REQUIRED');
      valid = false;
    } else if (!_validatePassword(password)) {
      setState(() => _passwordError = 'MINIMUM 8 CHARACTERS');
      valid = false;
    }

    if (password != confirmPassword) {
      setState(() => _confirmError = 'PASSWORDS DO NOT MATCH');
      valid = false;
    }

    if (!_tosAccepted) {
      setState(() => _tosError = 'PLEASE ACCEPT TERMS');
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
      final username = _usernameController.text.trim();
      final usernameExists = await ref.read(authRepositoryProvider).checkUsernameExists(username);
      if (usernameExists) {
        if (mounted) {
          setState(() {
            _usernameError = 'USERNAME ALREADY EXISTS';
            _isLoading = false;
          });
        }
        return;
      }

      final phone = '${_selectedCountry?.dialCode ?? '+1'}${_phoneController.text.trim().replaceAll(RegExp(r'^\+'), '')}';
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();
      
      await ref.read(authNotifierProvider.notifier).signUp(
        email,
        password,
        _confirmPasswordController.text.trim(),
        username,
        phone: phone,
      );

      if (mounted) {
        final authState = ref.read(authNotifierProvider);
        authState.maybeWhen(
          needsVerification: (email, phone, isPhone) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => OtpVerificationScreen(
                  email: email,
                  phone: phone,
                  isPhone: isPhone,
                ),
              ),
            );
          },
          authenticated: (user, profile) {
            context.go('/home');
          },
          orElse: () {},
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generalError = e.toString().replaceAll('Exception: ', '').toUpperCase());
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
      backgroundColor: kBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Brand Logo
                Hero(
                  tag: 'app_logo',
                  child: Image.asset(
                    'assets/branding/Flicko-for-black-background.png',
                    width: 48,
                    height: 48,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.flash_on,
                      color: kAccentColor,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                  Text(
                      'JOIN THE\nFUTURE.',
                      style: GoogleFonts.epilogue(
                        color: kPrimaryTextColor,
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        height: 0.9,
                        letterSpacing: -2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'CREATE YOUR FLICKO ACCOUNT',
                      style: GoogleFonts.spaceGrotesk(
                        color: kMutedColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 40),

                    if (_generalError != null) ...[
                      BrutalistCard(
                        backgroundColor: kBackgroundColor,
                        borderColor: kErrorColor,
                        shadowColor: kErrorColor,
                        shadowOffset: const Offset(4, 4),
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: kErrorColor, size: 20),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _generalError!,
                                style: GoogleFonts.spaceGrotesk(
                                  color: kErrorColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],

                    _buildInput(
                      label: 'EMAIL ADDRESS',
                      placeholder: 'ENTER YOUR EMAIL',
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      error: _emailError,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 16),
                    
                    _buildInput(
                      label: 'USERNAME',
                      placeholder: 'CHOOSE A USERNAME',
                      controller: _usernameController,
                      focusNode: _usernameFocusNode,
                      error: _usernameError,
                      onChanged: _handleUsernameChange,
                    ),
                    const SizedBox(height: 16),

                    _buildInput(
                      label: 'PHONE NUMBER',
                      placeholder: '000 000 0000',
                      controller: _phoneController,
                      focusNode: _phoneFocusNode,
                      error: _phoneError,
                      keyboardType: TextInputType.phone,
                      onChanged: _handlePhoneChange,
                      prefix: GestureDetector(
                        onTap: () async {
                          final code = await _countryPicker.showPicker(
                            context: context,
                            backgroundColor: kSurfaceColor,
                          );
                          if (code != null) {
                            setState(() => _selectedCountry = code);
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          color: Colors.transparent,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _selectedCountry?.dialCode ?? '+1',
                                style: GoogleFonts.spaceGrotesk(
                                  color: kPrimaryTextColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const Icon(Icons.arrow_drop_down, color: kMutedColor, size: 20),
                              const SizedBox(width: 8),
                              Container(
                                height: 20,
                                width: 1,
                                color: kMutedColor.withOpacity(0.3),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    _buildInput(
                      label: 'PASSWORD',
                      placeholder: '••••••••',
                      controller: _passwordController,
                      focusNode: _passwordFocusNode,
                      error: _passwordError,
                      isPassword: true,
                      isVisible: _passwordVisible,
                      onToggleVisibility: () => setState(() => _passwordVisible = !_passwordVisible),
                    ),
                    const SizedBox(height: 16),

                    _buildInput(
                      label: 'CONFIRM PASSWORD',
                      placeholder: '••••••••',
                      controller: _confirmPasswordController,
                      focusNode: _confirmFocusNode,
                      error: _confirmError,
                      isPassword: true,
                      isVisible: _confirmPasswordVisible,
                      onToggleVisibility: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
                    ),
                    const SizedBox(height: 24),

                    // TOS Checkbox
                    GestureDetector(
                      onTap: () => setState(() => _tosAccepted = !_tosAccepted),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: _tosAccepted ? kAccentColor : kSurfaceColor,
                                border: Border.all(
                                  color: _tosError != null ? kErrorColor : (_tosAccepted ? kAccentColor : kMutedColor.withOpacity(0.3)),
                                  width: 2,
                                ),
                                boxShadow: [
                                  if (_tosAccepted)
                                    const BoxShadow(color: kPrimaryTextColor, offset: Offset(3, 3)),
                                ],
                              ),
                              child: _tosAccepted 
                                  ? const Icon(Icons.check, color: kBackgroundColor, size: 16, fontWeight: FontWeight.bold) 
                                  : null,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Text(
                                'I AGREE TO TERMS & PRIVACY POLICY',
                                style: GoogleFonts.spaceGrotesk(
                                  color: _tosError != null ? kErrorColor : (_tosAccepted ? kPrimaryTextColor : kMutedColor),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Register Button
                    BrutalistButton(
                      text: 'CREATE ACCOUNT',
                      onTap: _handleRegister,
                      isLoading: _isLoading,
                      color: kAccentColor,
                      shadowColor: kPrimaryTextColor,
                    ),

                    const SizedBox(height: 32),

                  // Social Auth
                  Row(
                    children: [
                      Expanded(
                        child: BrutalistButton(
                          icon: Image.network(
                            'https://cdn-icons-png.flaticon.com/512/2991/2991148.png',
                            width: 20,
                            height: 20,
                            color: kPrimaryTextColor,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: kPrimaryTextColor, size: 24),
                          ),
                          text: 'GOOGLE',
                          onTap: () => _handleSocialLogin('google'),
                          color: kBackgroundColor,
                          textColor: kPrimaryTextColor,
                          shadowColor: kAccentColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BrutalistButton(
                          icon: Image.network(
                            'https://cdn-icons-png.flaticon.com/512/25/25231.png',
                            width: 20,
                            height: 20,
                            color: kPrimaryTextColor,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.code, color: kPrimaryTextColor, size: 20),
                          ),
                          text: 'GITHUB',
                          onTap: () => _handleSocialLogin('github'),
                          color: kBackgroundColor,
                          textColor: kPrimaryTextColor,
                          shadowColor: kAccentColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),

                    // Login Link
                    Center(
                      child: TextButton(
                        onPressed: () => context.pop(),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.spaceGrotesk(color: kMutedColor, fontSize: 13),
                            children: [
                              const TextSpan(text: 'ALREADY HAVE AN ACCOUNT? '),
                              TextSpan(
                                text: 'LOG IN',
                                style: GoogleFonts.spaceGrotesk(
                                  color: kAccentColor,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                  const SizedBox(height: 48),
                  const BrutalistLegalFooter(),
                ].animate(interval: 50.ms).fade(duration: 400.ms, curve: Curves.easeOut).slideY(begin: 0.1, curve: Curves.easeOut),
              ),
            ),
          ),
        ),
    );
  }

  Widget _buildInput({
    required String label,
    required String placeholder,
    required TextEditingController controller,
    required FocusNode focusNode,
    Widget? prefix,
    String? error,
    bool isPassword = false,
    bool isVisible = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
    void Function(String)? onChanged,
  }) {
    final bool isFocused = focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: error != null ? kErrorColor : (isFocused ? kAccentColor : kMutedColor),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: kSurfaceColor,
            border: Border.all(
              color: error != null 
                  ? kErrorColor 
                  : (isFocused ? kAccentColor : kMutedColor.withOpacity(0.3)),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: error != null 
                    ? kErrorColor.withOpacity(0.2) 
                    : (isFocused ? kAccentColor.withOpacity(0.2) : Colors.transparent),
                offset: const Offset(4, 4),
              ),
            ],
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
            style: GoogleFonts.spaceGrotesk(
              color: kPrimaryTextColor,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: GoogleFonts.spaceGrotesk(
                color: kMutedColor.withOpacity(0.3),
                fontSize: 14,
              ),
              prefixIcon: prefix,
              suffixIcon: isPassword ? IconButton(
                icon: Icon(
                  isVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: isFocused ? kAccentColor : kMutedColor,
                  size: 20,
                ),
                onPressed: onToggleVisibility,
              ) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              error,
              style: GoogleFonts.spaceGrotesk(
                color: kErrorColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }
}


