import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/brutalist_widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _emailFocusNode = FocusNode();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _emailError;
  String? _generalError;
  String? _successMessage;
  bool _isLoading = false;
  bool _emailSent = false;

  // Design Tokens
  static const kBackgroundColor = Color(0xFF050505);
  static const kSurfaceColor = Color(0xFF0C0C0E);
  static const kAccentColor = Color(0xFFC0F500); // Neon Lime
  static const kMutedColor = Color(0xFF71717A);
  static const kPrimaryTextColor = Color(0xFFFBF9FA);
  static const kErrorColor = Color(0xFFFF4B4B);
  static const kSuccessColor = Color(0xFF23A559);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    _animationController.forward();

    _emailFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    _animationController.dispose();
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
      setState(() => _emailError = 'EMAIL IS REQUIRED');
      return false;
    } else if (!_validateEmail(trimmedEmail)) {
      setState(() => _emailError = 'INVALID EMAIL FORMAT');
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
      await ref.read(authNotifierProvider.notifier).resetPassword(sanitizedEmail);

      setState(() {
        _emailSent = true;
        _successMessage = 'CHECK YOUR EMAIL! WE\'VE SENT A LINK TO RESET YOUR PASSWORD.';
      });
    } catch (e) {
      setState(() => _generalError = 'FAILED TO SEND RESET EMAIL. PLEASE TRY AGAIN.');
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
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
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
                      'FORGOT\nPASSWORD?',
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
                      "ENTER YOUR EMAIL TO RECEIVE A RESET LINK",
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
                                _generalError!.toUpperCase(),
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

                    if (_emailSent) ...[
                      BrutalistCard(
                        backgroundColor: kSuccessColor.withOpacity(0.1),
                        borderColor: kSuccessColor,
                        shadowColor: kSuccessColor,
                        shadowOffset: const Offset(4, 4),
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.check_circle_outline, color: kSuccessColor, size: 48),
                            const SizedBox(height: 16),
                            Text(
                              _successMessage!,
                              style: GoogleFonts.spaceGrotesk(
                                color: kSuccessColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      BrutalistButton(
                        text: 'DONE',
                        onTap: () => context.pop(),
                        color: kAccentColor,
                        shadowColor: kPrimaryTextColor,
                      ),
                    ] else ...[
                      _buildInput(
                        label: 'EMAIL ADDRESS',
                        placeholder: 'NAME@EXAMPLE.COM',
                        controller: _emailController,
                        focusNode: _emailFocusNode,
                        error: _emailError,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 24),
                      BrutalistButton(
                        text: 'SEND RESET LINK',
                        onTap: _handleSendReset,
                        isLoading: _isLoading,
                        color: kAccentColor,
                        shadowColor: kPrimaryTextColor,
                      ),
                    ],

                    const SizedBox(height: 32),

                    Center(
                      child: TextButton(
                        onPressed: () => context.pop(),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: Text(
                          'BACK TO LOGIN',
                          style: GoogleFonts.spaceGrotesk(
                            color: kMutedColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const BrutalistLegalFooter(),
                  ],
                ),
              ),
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
    String? error,
    TextInputType? keyboardType,
  }) {
    final hasFocus = focusNode.hasFocus;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.spaceGrotesk(
            color: error != null ? kErrorColor : (hasFocus ? kAccentColor : kMutedColor),
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: kSurfaceColor,
            border: Border.all(
              color: error != null 
                  ? kErrorColor 
                  : (hasFocus ? kAccentColor : Colors.white.withOpacity(0.05)),
              width: 2,
            ),
            boxShadow: hasFocus ? [
              const BoxShadow(
                color: kAccentColor,
                offset: Offset(4, 4),
              ),
            ] : null,
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            onChanged: (v) => setState(() {}),
            style: GoogleFonts.spaceGrotesk(
              color: kPrimaryTextColor,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: GoogleFonts.spaceGrotesk(
                color: kMutedColor.withOpacity(0.5),
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              error,
              style: GoogleFonts.spaceGrotesk(
                color: kErrorColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
      ],
    );
  }
}
