import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/constants/flicko_colors.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/data/models/user_model.dart';

/// Change Username Screen
///
/// Allows the authenticated user to change their @username.
/// Validates format, checks uniqueness in the profiles table, then writes the update.
/// Route: /profile/settings/change-username
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
    final cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '').substring(0, value.length.clamp(0, 32));
    setState(() => _username = cleaned);

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

        setState(() => _validation = (response as List).isNotEmpty ? _ValidationState.taken : _ValidationState.available);
      } catch (_) {
        setState(() => _validation = _ValidationState.idle);
      }
    });
  }

  Future<void> _handleSave() async {
    if (!_canSave) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authNotifierProvider).maybeWhen(
        authenticated: (user, _) => user,
        orElse: () => null,
      );

      if (user == null) return;

      final error = await Supabase.instance.client
          .from('profiles')
          .update({
            'username': _username,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id);

      if (error != null) throw error;

      _showAlert(
        'Username Updated',
        'Your username has been changed to @$_username.',
        onOk: () => context.pop(),
      );
    } catch (e) {
      if (e.toString().contains('unique') || e.toString().contains('23505')) {
        setState(() => _validation = _ValidationState.taken);
        _showAlert('Username Taken', 'That username is already in use. Please choose another.');
      } else {
        _showAlert('Error', e.toString() ?? 'Failed to update username. Please try again.');
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAlert(String title, String message, {VoidCallback? onOk}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          title,
          style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
        ),
        content: Text(
          message,
          style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onOk?.call();
            },
            child: Text(
              'OK',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _validationIcon() {
    switch (_validation) {
      case _ValidationState.checking:
        return const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Color(FlickoColors.textMuted)));
      case _ValidationState.available:
        return const Icon(Icons.check_circle, size: 20, color: Color(FlickoColors.success));
      case _ValidationState.taken:
        return const Icon(Icons.cancel, size: 20, color: Color(FlickoColors.red));
      case _ValidationState.invalid:
        return const Icon(Icons.warning, size: 20, color: Color(FlickoColors.warning));
      default:
        return null;
    }
  }

  ({String text, Color color})? _validationMessage() {
    switch (_validation) {
      case _ValidationState.checking:
        return (text: 'Checking availability…', color: const Color(FlickoColors.textMuted));
      case _ValidationState.available:
        return (text: '@$_username is available!', color: const Color(FlickoColors.success));
      case _ValidationState.taken:
        return (text: 'That username is already taken.', color: const Color(FlickoColors.red));
      case _ValidationState.invalid:
        return (
          text: 'Username must be 3–32 characters: letters, numbers, or underscores only.',
          color: const Color(FlickoColors.warning),
        );
      default:
        return null;
    }
  }

  Color _borderColor() {
    switch (_validation) {
      case _ValidationState.taken:
      case _ValidationState.invalid:
        return const Color(FlickoColors.red);
      case _ValidationState.available:
        return const Color(FlickoColors.success);
      default:
        return const Color(0xFF232428);
    }
  }

  @override
  Widget build(BuildContext context) {
    final msg = _validationMessage();

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Change Username',
          style: GoogleFonts.inter(
            color: const Color(FlickoColors.textPrimary),
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _canSave ? _handleSave : null,
            child: _isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Color(FlickoColors.blurple)))
                : Text(
                    'Save',
                    style: GoogleFonts.inter(
                      color: _canSave ? const Color(FlickoColors.blurple) : const Color(FlickoColors.textMuted),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Current username display
          _buildSectionHeader('CURRENT USERNAME'),
          _buildCurrentBox(),

          const SizedBox(height: 16),

          // New username input
          _buildSectionHeader('NEW USERNAME'),
          _buildUsernameInput(),

          if (msg != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Text(
                msg.text,
                style: GoogleFonts.inter(color: msg.color, fontSize: 12),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Rules info box
          _buildRulesBox(),

          const SizedBox(height: 24),

          // Submit button
          ElevatedButton(
            onPressed: _canSave ? _handleSave : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: _canSave ? const Color(FlickoColors.blurple) : const Color(FlickoColors.bgTertiary),
              foregroundColor: _canSave ? Colors.white : const Color(FlickoColors.textMuted),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(
                    'Update Username',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title,
        style: GoogleFonts.inter(
          color: const Color(FlickoColors.textMuted),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildCurrentBox() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(
            '@',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              _currentUsername ?? 'Not set',
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUsernameInput() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: _borderColor()),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _usernameController,
          onChanged: _handleUsernameChange,
          textCapitalization: TextCapitalization.none,
          autocorrect: false,
          style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
          decoration: InputDecoration(
            hintText: _currentUsername ?? 'new_username',
            hintStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            filled: true,
            fillColor: Colors.transparent,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            prefixIcon: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '@',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            suffixIcon: _validationIcon(),
          ),
        ),
      ),
    );
  }

  Widget _buildRulesBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        border: Border.all(color: const Color(FlickoColors.blurple), left: BorderSide.none),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Username rules',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textPrimary),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '• 3–32 characters long',
            style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 13, height: 1.5),
          ),
          Text(
            '• Letters (a–z), numbers (0–9), and underscores _ only',
            style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 13, height: 1.5),
          ),
          Text(
            '• Must be unique — no two accounts can share one',
            style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary), fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }
}
