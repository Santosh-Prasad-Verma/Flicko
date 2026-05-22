import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';

class ChangeUsernameScreen extends ConsumerStatefulWidget {
  const ChangeUsernameScreen({super.key});

  @override
  ConsumerState<ChangeUsernameScreen> createState() => _ChangeUsernameScreenState();
}

enum _ValidationState { idle, checking, available, taken, invalid }

class _ChangeUsernameScreenState extends ConsumerState<ChangeUsernameScreen> {
  String _username = '';
  _ValidationState _validation = _ValidationState.idle;
  bool _isLoading = false;
  Timer? _checkTimeout;
  final _usernameController = TextEditingController();
  final _usernameRegex = RegExp(r'^[a-zA-Z0-9_]{3,32}$');

  static const Color _neonGreen = Color(0xFF52B788);
  static const Color _bgBlack = Color(0xFF050505);
  static const Color _surfaceContainer = Color(0xFF0C0C0E);
  static const Color _textWhite = Color(0xFFFBF9FA);
  static const Color _textMuted = Color(0xFF71717A);

  bool get _canSave {
    return _validation == _ValidationState.available &&
        _usernameRegex.hasMatch(_username) &&
        _username.toLowerCase() != _currentUsername?.toLowerCase() &&
        !_isLoading;
  }

  String? get _currentUsername {
    return ref.read(authNotifierProvider).maybeWhen(
      authenticated: (_, profile) => profile?.username,
      orElse: () => null,
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _checkTimeout?.cancel();
    super.dispose();
  }

  void _handleUsernameChange(String value) {
    // Keep only alphanumeric and underscore
    final cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    _username = cleaned;

    _checkTimeout?.cancel();

    if (cleaned.isEmpty) {
      setState(() => _validation = _ValidationState.idle);
      return;
    }

    if (!_usernameRegex.hasMatch(cleaned)) {
      setState(() => _validation = _ValidationState.invalid);
      return;
    }

    if (cleaned.toLowerCase() == _currentUsername?.toLowerCase()) {
      setState(() => _validation = _ValidationState.idle);
      return;
    }

    setState(() => _validation = _ValidationState.checking);

    _checkTimeout = Timer(const Duration(milliseconds: 500), () async {
      try {
        final response = await Supabase.instance.client
            .from('profiles')
            .select('id')
            .ilike('username', cleaned)
            .limit(1);

        if (mounted) {
          setState(() => _validation = (response as List).isNotEmpty
              ? _ValidationState.taken
              : _ValidationState.available);
        }
      } catch (_) {
        if (mounted) {
          setState(() => _validation = _ValidationState.idle);
        }
      }
    });
  }

  Future<void> _handleSave() async {
    if (!_canSave) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authNotifierProvider.notifier).changeUsername(_username);

      if (mounted) {
        _showAlert(
          'USERNAME UPDATED',
          'Your username has been changed to @$_username.',
          onOk: () => context.pop(),
        );
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('unique') || e.toString().contains('23505')) {
          setState(() => _validation = _ValidationState.taken);
          _showAlert('USERNAME TAKEN', 'That username is already in use. Please choose another.');
        } else {
          _showAlert('ERROR', e.toString());
        }
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

  Widget? _validationIcon() {
    switch (_validation) {
      case _ValidationState.checking:
        return const Padding(
          padding: EdgeInsets.all(12),
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: _textMuted),
          ),
        );
      case _ValidationState.available:
        return const Icon(Icons.check_circle, size: 20, color: _neonGreen);
      case _ValidationState.taken:
        return const Icon(Icons.cancel, size: 20, color: Colors.red);
      case _ValidationState.invalid:
        return const Icon(Icons.warning, size: 20, color: Colors.orange);
      default:
        return _usernameController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close, size: 18, color: _textMuted),
                onPressed: () {
                  _usernameController.clear();
                  setState(() {
                    _username = '';
                    _validation = _ValidationState.idle;
                  });
                },
              )
            : null;
    }
  }

  ({String text, Color color})? _validationMessage() {
    switch (_validation) {
      case _ValidationState.checking:
        return (text: 'Checking availability…', color: _textMuted);
      case _ValidationState.available:
        return (text: '@$_username is available!', color: _neonGreen);
      case _ValidationState.taken:
        return (text: 'That username is already taken.', color: Colors.red);
      case _ValidationState.invalid:
        return (
          text: 'Must be 3–32 characters: letters, numbers, or underscores only.',
          color: Colors.orange,
        );
      default:
        return null;
    }
  }

  Color _borderColor() {
    switch (_validation) {
      case _ValidationState.taken:
      case _ValidationState.invalid:
        return Colors.red;
      case _ValidationState.available:
        return _neonGreen;
      default:
        return _textWhite.withValues(alpha: 0.1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final msg = _validationMessage();

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
                    'CHANGE\nUSERNAME',
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

                  // Current username display
                  _buildSectionHeader('CURRENT USERNAME'),
                  _buildCurrentUsernameBox(),

                  const SizedBox(height: 24),

                  // New username input
                  _buildSectionHeader('NEW @USERNAME'),
                  _buildUsernameInput(),

                  if (msg != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          msg.text,
                          style: GoogleFonts.spaceMono(color: msg.color, fontSize: 11),
                        ),
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Rules info box
                  _buildRulesBox(),

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
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.arrow_back, color: _textWhite, size: 20),
            ),
          ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'CREDENTIALS',
                  style: GoogleFonts.spaceGrotesk(
                    color: _neonGreen.withValues(alpha: 0.8),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 2.0,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  'USERNAME UPDATE',
                  style: GoogleFonts.spaceMono(
                    color: _textWhite.withValues(alpha: 0.3),
                    fontSize: 8,
                    letterSpacing: 1.0,
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
        Text(
          title,
          style: GoogleFonts.epilogue(
            color: _textWhite,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.3,
          ),
        ),
        Container(height: 2, color: _neonGreen, margin: const EdgeInsets.only(top: 6, bottom: 16)),
      ],
    );
  }

  Widget _buildCurrentUsernameBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _surfaceContainer,
        border: Border.all(color: _textWhite.withValues(alpha: 0.05)),
      ),
      child: Row(
        children: [
          const Icon(Icons.alternate_email, size: 18, color: _textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _currentUsername ?? 'Not set',
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

  Widget _buildUsernameInput() {
    return TextField(
      controller: _usernameController,
      onChanged: _handleUsernameChange,
      textCapitalization: TextCapitalization.none,
      autocorrect: false,
      style: GoogleFonts.spaceMono(color: _textWhite, fontSize: 14),
      decoration: InputDecoration(
        hintText: 'Enter new username',
        hintStyle: GoogleFonts.spaceMono(color: _textMuted, fontSize: 12),
        filled: true,
        fillColor: _bgBlack,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: _borderColor()),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: _borderColor()),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
          borderSide: BorderSide(color: _borderColor(), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixIcon: const Icon(Icons.alternate_email, size: 18, color: _neonGreen),
        suffixIcon: _validationIcon(),
      ),
    );
  }

  Widget _buildRulesBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _neonGreen.withValues(alpha: 0.05),
        border: Border.all(color: _neonGreen.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.security, size: 18, color: _neonGreen),
              const SizedBox(width: 12),
              Text(
                'USERNAME REQUIREMENTS',
                style: GoogleFonts.spaceGrotesk(
                  color: _neonGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '• 3–32 characters long\n• Letters (a–z), numbers (0–9), and underscores (_) only\n• Must be unique — no two accounts can share one',
            style: GoogleFonts.inter(
              color: _textMuted,
              fontSize: 13,
              height: 1.6,
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
                'SAVE USERNAME',
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
