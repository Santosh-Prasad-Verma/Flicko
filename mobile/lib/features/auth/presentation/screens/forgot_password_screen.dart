import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

/// Forgot Password Screen — Premium Discord-inspired with Supabase
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
      
      await ref.read(authNotifierProvider.notifier).resetPassword(sanitizedEmail);

      setState(() {
        _emailSent = true;
        _successMessage = 'Check your email! We\'ve sent a link to reset your password.';
      });
    } catch (e) {
      debugPrint('Forgot password error: $e');
      setState(() => _generalError = 'Failed to send reset email. Please try again.');
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
          
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
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

                        // Card
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Container(
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Forgot password?',
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Enter your email to receive a password reset link.",
                                    style: GoogleFonts.inter(color: const Color(0xFFB9BBBE), fontSize: 14),
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

                                  if (_emailSent) ...[
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF23A559).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: const Color(0xFF23A559).withValues(alpha: 0.3)),
                                      ),
                                      child: Column(
                                        children: [
                                          const Icon(Icons.check_circle_outline, color: Color(0xFF23A559), size: 40),
                                          const SizedBox(height: 12),
                                          Text(
                                            _successMessage!,
                                            style: GoogleFonts.inter(color: const Color(0xFF23A559), fontSize: 15, fontWeight: FontWeight.w600),
                                            textAlign: TextAlign.center,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: () => context.pop(),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF5865F2),
                                          foregroundColor: Colors.white,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        ),
                                        child: Text('Done', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                  ] else ...[
                                    _buildInput(
                                      label: 'EMAIL',
                                      placeholder: 'name@example.com',
                                      controller: _emailController,
                                      focusNode: _emailFocusNode,
                                      error: _emailError,
                                      keyboardType: TextInputType.emailAddress,
                                      icon: Icons.alternate_email,
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      height: 52,
                                      child: ElevatedButton(
                                        onPressed: _isLoading ? null : _handleSendReset,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: const Color(0xFF5865F2),
                                          foregroundColor: Colors.white,
                                          disabledBackgroundColor: const Color(0xFF5865F2).withValues(alpha: 0.5),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                          elevation: 0,
                                        ),
                                        child: _isLoading
                                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
                                            : Text('Send Link', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w700)),
                                      ),
                                    ),
                                  ],

                                  const SizedBox(height: 24),

                                  Center(
                                    child: TextButton(
                                      onPressed: () => context.pop(),
                                      child: Text(
                                        'Back to Login',
                                        style: GoogleFonts.inter(color: const Color(0xFF5865F2), fontSize: 14, fontWeight: FontWeight.w700),
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
    String? error,
    TextInputType? keyboardType,
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
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: error != null 
                  ? const Color(0xFFDA373C).withValues(alpha: 0.5) 
                  : focusNode.hasFocus 
                      ? const Color(0xFF5865F2).withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.05),
              width: 1.5,
            ),
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            onChanged: (v) => setState(() {}),
            onTap: () => setState(() {}),
            style: GoogleFonts.inter(color: Colors.white, fontSize: 15),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: GoogleFonts.inter(color: const Color(0xFF72767D), fontSize: 15),
              prefixIcon: icon != null ? Icon(icon, color: focusNode.hasFocus ? const Color(0xFF5865F2) : const Color(0xFF72767D), size: 20) : null,
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
}
