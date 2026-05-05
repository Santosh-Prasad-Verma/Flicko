import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/brutalist_widgets.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String? email;
  final String? phone;
  final bool isPhone;

  const OtpVerificationScreen({
    super.key,
    this.email,
    this.phone,
    this.isPhone = false,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  final _otpFocusNode = FocusNode();
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  String? _otpError;
  String? _generalError;
  bool _isLoading = false;

  // Design Tokens (Matching Login/Register)
  static const kBackgroundColor = Color(0xFF050505);
  static const kSurfaceColor = Color(0xFF0C0C0E);
  static const kAccentColor = Color(0xFFC0F500); // Neon Lime
  static const kMutedColor = Color(0xFF71717A);
  static const kPrimaryTextColor = Color(0xFFFBF9FA);
  static const kErrorColor = Color(0xFFFF4B4B);

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
    _otpController.addListener(_clearErrors);
    _otpFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _otpController.dispose();
    _otpFocusNode.dispose();
    super.dispose();
  }

  void _clearErrors() {
    if (_otpError != null || _generalError != null) {
      setState(() {
        _otpError = null;
        _generalError = null;
      });
    }
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.isEmpty || code.length < 6) {
      setState(() => _otpError = 'ENTER 6-DIGIT CODE');
      return;
    }

    setState(() {
      _isLoading = true;
      _generalError = null;
    });

    try {
      if (widget.isPhone) {
        await ref.read(authNotifierProvider.notifier).verifyPhone(widget.phone!, code);
      } else {
        await ref.read(authNotifierProvider.notifier).verifyEmail(widget.email!, code);
      }
      
      if (mounted) {
        context.go('/home');
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
                      widget.isPhone ? 'VERIFY YOUR\nPHONE.' : 'VERIFY YOUR\nEMAIL.',
                      style: GoogleFonts.epilogue(
                        color: kPrimaryTextColor,
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        height: 0.9,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'WE SENT A 6-DIGIT CODE TO\n${(widget.isPhone ? widget.phone : widget.email)?.toUpperCase()}',
                      style: GoogleFonts.spaceGrotesk(
                        color: kMutedColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
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

                    Text(
                      'VERIFICATION CODE',
                      style: GoogleFonts.spaceGrotesk(
                        color: _otpError != null ? kErrorColor : (_otpFocusNode.hasFocus ? kAccentColor : kMutedColor),
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
                          color: _otpError != null 
                              ? kErrorColor 
                              : (_otpFocusNode.hasFocus ? kAccentColor : Colors.white.withOpacity(0.05)),
                          width: 2,
                        ),
                        boxShadow: _otpFocusNode.hasFocus ? [
                          const BoxShadow(
                            color: kAccentColor,
                            offset: Offset(4, 4),
                          ),
                        ] : null,
                      ),
                      child: TextField(
                        controller: _otpController,
                        focusNode: _otpFocusNode,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6)
                        ],
                        onChanged: (v) => setState(() {}),
                        textAlign: TextAlign.center,
                        style: GoogleFonts.spaceGrotesk(
                          color: kAccentColor,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 16,
                        ),
                        decoration: const InputDecoration(
                          hintText: '000000',
                          hintStyle: TextStyle(color: Color(0xFF1F1F23), letterSpacing: 16),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 24),
                        ),
                      ),
                    ),
                    if (_otpError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _otpError!,
                          style: GoogleFonts.spaceGrotesk(
                            color: kErrorColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                    const SizedBox(height: 32),

                    // Verify Button
                    BrutalistButton(
                      text: 'VERIFY NOW',
                      onTap: _verifyOtp,
                      isLoading: _isLoading,
                      color: kAccentColor,
                      shadowColor: kPrimaryTextColor,
                    ),

                    const SizedBox(height: 24),

                    // Cancel Link
                    Center(
                      child: TextButton(
                        onPressed: () => context.pop(),
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        child: Text(
                          'CANCEL',
                          style: GoogleFonts.spaceGrotesk(
                            color: kMutedColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
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
}

