import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/ludo_notifier.dart';
import '../../services/ludo_sound_service.dart';
import 'ludo_colors.dart';

/// In-game pause menu. Resume / mute / new game / exit.
class MenuModal extends ConsumerStatefulWidget {
  const MenuModal({super.key, required this.onClose});
  final VoidCallback onClose;

  @override
  ConsumerState<MenuModal> createState() => _MenuModalState();
}

class _MenuModalState extends ConsumerState<MenuModal> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD4AF37), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn(context, 'RESUME', widget.onClose),
            const SizedBox(height: 12),
            _btn(
              context,
              LudoSoundService.instance.muted ? 'UNMUTE SOUND' : 'MUTE SOUND',
              () {
                setState(() {
                  LudoSoundService.instance.setMuted(!LudoSoundService.instance.muted);
                  if (!LudoSoundService.instance.muted) {
                    LudoSoundService.instance.play('game_start');
                  }
                });
              },
            ),
            const SizedBox(height: 12),
            _btn(context, 'NEW GAME', () {
              ref.read(ludoNotifierProvider.notifier).resetGame();
              LudoSoundService.instance.play('game_start');
              widget.onClose();
            }),
            const SizedBox(height: 12),
            _btn(context, 'EXIT', () {
              widget.onClose();
              Navigator.of(context).maybePop();
            }),
          ],
        ),
      ),
    );
  }

  Widget _btn(BuildContext ctx, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFC0392B), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC0392B).withValues(alpha: 0.4),
              blurRadius: 16,
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: LudoColors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}
