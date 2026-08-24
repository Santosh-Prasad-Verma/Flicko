import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import 'package:mobile/data/repositories/auth_repository.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/shared/presentation/widgets/keyboard_dismiss_on_tap.dart';

/// Verify Email Screen — Discord-inspired OTP Verification
///
/// Prompts the user to enter the 6-digit OTP code sent to their email.
/// On successful verification, logs them into the app and transitions to Home.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  final String initialEmail;

  const VerifyEmailScreen({super.key, this.initialEmail = ''});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  late final TextEditingController _emailController;
  final List<TextEditingController> _codeControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading = false;
  bool _isResending = false;
  bool _isPasting = false;
  late bool _isEditingEmail;
  String? _errorMessage;
  String? _successMessage;
  int _resendCooldown = 60;
  Timer? _cooldownTimer;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialEmail.trim();
    _emailController = TextEditingController(text: initial);
    _isEditingEmail = initial.isEmpty;
    _startCooldownTimer();

    // Auto-focus the first OTP field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _focusNodes.isNotEmpty) {
        if (!_isEditingEmail) {
          _focusNodes[0].requestFocus();
        }
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    for (final c in _codeControllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown > 0) {
        setState(() => _resendCooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _otpCode => _codeControllers.map((c) => c.text.trim()).join();

  void _onDigitChanged(int index, String value) {
    if (_isPasting) return;

    if (value.length > 1) {
      // Handle pasting multi-digit OTP without duplicate callback execution
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.isNotEmpty) {
        _isPasting = true;
        for (var i = 0; i < 6; i++) {
          if (i < digits.length) {
            _codeControllers[i].text = digits[i];
          }
        }
        _isPasting = false;
        final nextFocus = digits.length < 6 ? digits.length : 5;
        _focusNodes[nextFocus].requestFocus();

        if (digits.length >= 6 && !_isLoading) {
          _handleVerify();
        }
      }
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_otpCode.length == 6 && !_isLoading) {
          _handleVerify();
        }
      }
    }
  }

  void _onKeyDown(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _codeControllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
  }

  Future<void> _handleVerify() async {
    final email = _emailController.text.trim().toLowerCase();
    final code = _otpCode;

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address');
      return;
    }

    if (code.length != 6) {
      setState(() => _errorMessage = 'Please enter the full 6-digit code');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).verifyEmail(email, code);

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      debugPrint('Verification error: $e');
      final raw = e.toString();
      String userMessage = 'Invalid or expired verification code. Please check your code or request a new one.';
      if (raw.contains('invalid or expired')) {
        userMessage = 'Invalid or expired verification code.';
      } else if (raw.contains('400') || raw.contains('401')) {
        userMessage = 'Invalid code. Please double-check the 6-digit code sent to your email.';
      }
      if (mounted) {
        setState(() => _errorMessage = userMessage);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleResend() async {
    final email = _emailController.text.trim().toLowerCase();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address');
      return;
    }

    if (_resendCooldown > 0) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).resendVerification(email);
      if (mounted) {
        setState(() {
          _successMessage = 'A new 6-digit verification code was sent to your email!';
          _startCooldownTimer();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to resend verification code. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = _emailController.text.trim();
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: const Color(FlickoColors.black),
      body: KeyboardDismissOnTap(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            top: topPadding + 40,
            bottom: bottomPadding + 32,
            left: 24,
            right: 24,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon Header
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF52B788).withOpacity(0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF52B788).withOpacity(0.3),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF52B788).withOpacity(0.15),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mark_email_unread_outlined,
                      size: 36,
                      color: Color(0xFF52B788),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Heading
                  Text(
                    'Verify Your Email',
                    style: GoogleFonts.inter(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 10),

                  // Subtitle & Email
                  Text(
                    'Enter the 6-digit verification code sent to your email',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: const Color(0xFF949BA4),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  if (!_isEditingEmail && email.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1F22),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFF2B2D31)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            email,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF52B788),
                            ),
                          ),
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              setState(() => _isEditingEmail = true);
                            },
                            child: const Icon(
                              Icons.edit_outlined,
                              size: 14,
                              color: Color(0xFF949BA4),
                            ),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1F22),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF2B2D31)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.email_outlined, size: 18, color: Color(0xFF949BA4)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Enter your email',
                                hintStyle: TextStyle(color: Color(0xFF5F6368)),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                          ),
                          if (email.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                setState(() => _isEditingEmail = false);
                                if (_focusNodes.isNotEmpty) {
                                  _focusNodes[0].requestFocus();
                                }
                              },
                              child: Text(
                                'Done',
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF52B788),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // Feedback Messages
                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDA373C).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDA373C).withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFDA373C), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFFF2D3D4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  if (_successMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF52B788).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFF52B788).withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_outline, color: Color(0xFF52B788), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _successMessage!,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFFD0F0E0),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // 6-digit OTP Box Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(6, (index) {
                      return SizedBox(
                        width: 48,
                        height: 56,
                        child: RawKeyboardListener(
                          focusNode: FocusNode(),
                          onKey: (event) => _onKeyDown(index, event),
                          child: TextFormField(
                            controller: _codeControllers[index],
                            focusNode: _focusNodes[index],
                            textAlign: TextAlign.center,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(6),
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            style: GoogleFonts.firaCode(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                            decoration: InputDecoration(
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                              filled: true,
                              fillColor: const Color(0xFF1E1F22),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF35373C), width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10),
                                borderSide: const BorderSide(color: Color(0xFF52B788), width: 2),
                              ),
                            ),
                            onChanged: (value) => _onDigitChanged(index, value),
                          ),
                        ),
                      );
                    }),
                  ),

                  const SizedBox(height: 28),

                  // Verify Button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _handleVerify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF52B788),
                        foregroundColor: Colors.black,
                        disabledBackgroundColor: const Color(0xFF52B788).withOpacity(0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 0,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : Text(
                              'Verify Email',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Resend Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Didn't receive the code? ",
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF949BA4),
                        ),
                      ),
                      if (_resendCooldown > 0)
                        Text(
                          'Resend in ${_resendCooldown}s',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF80848E),
                          ),
                        )
                      else
                        GestureDetector(
                          onTap: _isResending ? null : _handleResend,
                          child: _isResending
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF52B788),
                                  ),
                                )
                              : Text(
                                  'Resend Code',
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF52B788),
                                  ),
                                ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Back to Login / Change Email
                  TextButton.icon(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/login');
                      }
                    },
                    icon: const Icon(Icons.arrow_back, size: 16, color: Color(0xFF949BA4)),
                    label: Text(
                      'Back to Login',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF949BA4),
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
}
