import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

class ChangeEmailScreen extends ConsumerStatefulWidget {
  const ChangeEmailScreen({super.key});

  @override
  ConsumerState<ChangeEmailScreen> createState() => _ChangeEmailScreenState();
}

class _ChangeEmailScreenState extends ConsumerState<ChangeEmailScreen> {
  String _newEmail = '';
  bool _isLoading = false;
  final _emailController = TextEditingController();

  static const Color _neonGreen = Color(0xFF52B788);
  static const Color _bgBlack = Color(0xFF050505);
  static const Color _surfaceContainer = Color(0xFF0C0C0E);
  static const Color _textWhite = Color(0xFFFBF9FA);
  static const Color _textMuted = Color(0xFF71717A);

  bool _isValidEmail(String email) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email.trim());
  }

  bool get _canSave {
    return _newEmail.trim().isNotEmpty &&
        _isValidEmail(_newEmail) &&
        _newEmail.trim().toLowerCase() != _currentEmail?.toLowerCase() &&
        !_isLoading;
  }

  String? get _currentEmail {
    return ref.read(authNotifierProvider).maybeWhen(
      authenticated: (user, _) => user.email,
      orElse: () => null,
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final trimmedEmail = _newEmail.trim().toLowerCase();

    if (!_isValidEmail(trimmedEmail)) {
      _showAlert('INVALID EMAIL', 'Please enter a valid email address.');
      return;
    }

    if (trimmedEmail == _currentEmail?.toLowerCase()) {
      _showAlert('NO CHANGE', 'This is already your current email address.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      await ref.read(authNotifierProvider.notifier).changeEmail(trimmedEmail);

      if (mounted) {
        _showAlert(
          'CONFIRMATION SENT',
          'A confirmation link has been sent to both $_currentEmail and $trimmedEmail.\n\nFollow the links in both emails to complete the change.',
          onOk: () => context.pop(),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains('AuthException')) {
          errorMessage = errorMessage.split(':').last.trim();
        }
        _showAlert('ERROR', errorMessage.isNotEmpty ? errorMessage : 'Failed to update email. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAlert(String title, String message, {VoidCallback? onOk}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _surfaceContainer,
        shape: const RoundedRectangleBorder(),
        title: Text(
          title,
          style: GoogleFonts.epilogue(color: _neonGreen, fontWeight: FontWeight.w900, fontStyle: FontStyle.italic),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(color: _textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onOk?.call();
            },
            child: Text(
              'OK',
              style: GoogleFonts.spaceGrotesk(color: _textWhite),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgBlack,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                children: [
                  Text(
                    'CHANGE\nEMAIL',
                    style: GoogleFonts.epilogue(
                      color: _textWhite,
                      fontSize: 48,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -2,
                      height: 0.9,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Current email display
                  _buildSectionHeader('CURRENT EMAIL'),
                  _buildCurrentEmailBox(),
        
                  const SizedBox(height: 24),
        
                  // New email input
                  _buildSectionHeader('NEW EMAIL ADDRESS'),
                  _buildEmailInput(),
        
                  const SizedBox(height: 32),
        
                  // Info notice
                  _buildInfoBox(),
        
                  const SizedBox(height: 40),
        
                  // Submit button
                  _buildSubmitButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: _neonGreen.withValues(alpha: 0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => context.pop(),
            child: Padding(padding: const EdgeInsets.all(8), child: Image.asset('assets/images/back.png', width: 20, height: 20, fit: BoxFit.contain),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('CREDENTIALS',
                  style: GoogleFonts.spaceGrotesk(
                    color: _neonGreen.withValues(alpha: 0.8),
                    fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text('EMAIL UPDATE',
                  style: GoogleFonts.spaceMono(
                    color: _textWhite.withValues(alpha: 0.3),
                    fontSize: 8, letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(width: 36),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
          style: GoogleFonts.epilogue(
            color: _textWhite, fontSize: 18, fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic, letterSpacing: -0.3,
          ),
        ),
        Container(height: 2, color: _neonGreen, margin: const EdgeInsets.only(top: 6, bottom: 16)),
      ],
    );
  }

  Widget _buildCurrentEmailBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _surfaceContainer,
        border: Border.all(color: _textWhite.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.mail_outline, size: 18, color: _textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _currentEmail ?? 'Not set',
              style: GoogleFonts.spaceMono(
                color: _textWhite,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailInput() {
    final hasError = _newEmail.isNotEmpty && !_isValidEmail(_newEmail);

    return Column(
      children: [
        TextField(
          controller: _emailController,
          onChanged: (v) => setState(() => _newEmail = v),
          keyboardType: TextInputType.emailAddress,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          style: GoogleFonts.spaceMono(color: _textWhite, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Enter new email address',
            hintStyle: GoogleFonts.spaceMono(color: _textMuted, fontSize: 12),
            filled: true,
            fillColor: _bgBlack,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: hasError ? Colors.red : _textWhite.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: hasError ? Colors.red : _textWhite.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.zero,
              borderSide: BorderSide(color: hasError ? Colors.red : _neonGreen),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: _newEmail.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, size: 18, color: _textMuted),
                    onPressed: () {
                      _emailController.clear();
                      setState(() => _newEmail = '');
                    },
                  )
                : null,
          ),
        ),
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Please enter a valid email address',
                style: GoogleFonts.spaceMono(color: Colors.red, fontSize: 11),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _neonGreen.withValues(alpha: 0.05),
        border: Border.all(color: _neonGreen.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, size: 18, color: _neonGreen),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'A confirmation link will be sent to both your current and new email addresses. You must confirm both to complete the change.',
              style: GoogleFonts.inter(
                color: _textMuted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSubmitButton() {
    return GestureDetector(
      onTap: _canSave ? _handleSave : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: _canSave ? _neonGreen : _surfaceContainer,
          border: Border.all(color: _canSave ? _neonGreen : _textWhite.withValues(alpha: 0.1)),
        ),
        alignment: Alignment.center,
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : Text(
                'SEND CONFIRMATION',
                style: GoogleFonts.spaceGrotesk(
                  color: _canSave ? Colors.black : _textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                ),
              ),
      ),
    );
  }
}
