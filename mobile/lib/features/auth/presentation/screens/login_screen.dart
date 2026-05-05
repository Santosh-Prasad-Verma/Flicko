import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/brutalist_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  
  String? _emailError;
  String? _passwordError;
  String? _generalError;
  bool _isLoading = false;
  bool _passwordVisible = false;

  // Design Tokens
  static const kBackgroundColor = Color(0xFF050505);
  static const kSurfaceColor = Color(0xFF0C0C0E);
  static const kAccentColor = Color(0xFFC0F500); // Neon Lime
  static const kMutedColor = Color(0xFF71717A);
  static const kPrimaryTextColor = Color(0xFFFBF9FA);
  static const kErrorColor = Color(0xFFFF4B4B);

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() => setState(() {}));
    _passwordFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
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
      setState(() => _emailError = 'IDENTIFIER IS REQUIRED');
      valid = false;
    }

    if (_passwordController.text.isEmpty) {
      setState(() => _passwordError = 'PASSWORD IS REQUIRED');
      valid = false;
    }

    return valid;
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

  Future<void> _handleLogin() async {
    if (!_validate()) return;

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generalError = e.toString().replaceAll('Exception: ', '').toUpperCase());
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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
                      'WELCOME\nBACK.',
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
                      "LET'S GET YOU LOGGED IN",
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
                        backgroundColor: kErrorColor.withOpacity(0.1),
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
                      label: 'IDENTIFIER',
                      placeholder: 'EMAIL OR USERNAME',
                      controller: _emailController,
                      focusNode: _emailFocusNode,
                      error: _emailError,
                      keyboardType: TextInputType.emailAddress,
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

                    const SizedBox(height: 8),

                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.push('/forgot-password'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          'FORGOT PASSWORD?',
                          style: GoogleFonts.spaceGrotesk(
                            color: kMutedColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),

                    // Login Button
                    BrutalistButton(
                      text: 'LOG IN',
                      onTap: _handleLogin,
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
                          icon: const FaIcon(FontAwesomeIcons.google, color: kPrimaryTextColor, size: 20),
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
                          icon: const FaIcon(FontAwesomeIcons.github, color: kPrimaryTextColor, size: 20),
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

                    // Register Link
                    Center(
                      child: TextButton(
                        onPressed: () => context.push('/register'),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: RichText(
                          text: TextSpan(
                            style: GoogleFonts.spaceGrotesk(color: kMutedColor, fontSize: 13),
                            children: [
                              const TextSpan(text: "NEW TO FLICKO? "),
                              TextSpan(
                                text: 'JOIN THE CLUB',
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

