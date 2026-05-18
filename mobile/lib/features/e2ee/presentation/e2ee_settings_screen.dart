import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

import '../application/e2ee_session.dart';
import '../data/secure_keystore.dart';

/// Encryption settings — view your fingerprint, refill prekeys, wipe keys.
class E2EESettingsScreen extends ConsumerStatefulWidget {
  const E2EESettingsScreen({super.key});

  @override
  ConsumerState<E2EESettingsScreen> createState() => _E2EESettingsScreenState();
}

class _E2EESettingsScreenState extends ConsumerState<E2EESettingsScreen> {
  String? _fingerprint;
  bool _busy = false;
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _busy = true);
    try {
      final session = ref.read(e2eeSessionProvider);
      await session.ensureBootstrapped();
      final fp = await session.getMyFingerprint();
      if (mounted) setState(() => _fingerprint = fp);
    } catch (e) {
      if (mounted) setState(() => _status = 'Bootstrap failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _refill() async {
    setState(() => _busy = true);
    try {
      await ref.read(e2eeSessionProvider).refillOneTimePrekeys();
      if (mounted) setState(() => _status = 'Prekey pool refilled.');
    } catch (e) {
      if (mounted) setState(() => _status = 'Refill failed: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _wipe() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text('Wipe encryption keys?',
            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w900)),
        content: Text(
          'You will lose access to all previously sent encrypted messages on this device. '
          'New keys will be generated on next launch.',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Wipe', style: GoogleFonts.inter(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _busy = true);
    try {
      await ref.read(secureKeystoreProvider).wipe();
      await _load();
      if (mounted) setState(() => _status = 'Keys wiped. Re-bootstrapped.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.black),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.black),
        title: Text('ENCRYPTION',
            style: GoogleFonts.spaceGrotesk(
                fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.5)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _section(
            title: 'YOUR FINGERPRINT',
            description:
                'Share this with friends out-of-band to verify nobody is intercepting your messages.',
            child: _busy
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : SelectableText(
                    _fingerprint ?? 'not bootstrapped',
                    style: GoogleFonts.robotoMono(
                      color: const Color(FlickoColors.brandLime),
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          _action(
            label: 'REFILL PREKEY POOL',
            description:
                'Generates fresh one-time prekeys so peers can start new conversations.',
            onTap: _busy ? null : _refill,
          ),
          const SizedBox(height: 12),
          _action(
            label: 'WIPE KEYS',
            description:
                'Destroy local private keys. Existing encrypted history will become unreadable.',
            danger: true,
            onTap: _busy ? null : _wipe,
          ),
          if (_status != null) ...[
            const SizedBox(height: 16),
            Text(_status!,
                style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
          ],
        ],
      ),
    );
  }

  Widget _section({
    required String title,
    required String description,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.spaceGrotesk(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1.2)),
          const SizedBox(height: 6),
          Text(description,
              style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _action({
    required String label,
    required String description,
    VoidCallback? onTap,
    bool danger = false,
  }) {
    final color = danger ? Colors.redAccent : const Color(FlickoColors.brandLime);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(FlickoColors.bgSecondary),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: GoogleFonts.spaceGrotesk(
                          color: color,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                          letterSpacing: 1.2)),
                  const SizedBox(height: 4),
                  Text(description,
                      style: GoogleFonts.inter(
                          color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}
