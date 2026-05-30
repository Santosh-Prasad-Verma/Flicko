import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../services/ludo_notifier.dart';
import '../../services/ludo_sound_service.dart';
import 'ludo_colors.dart';

/// Full-screen victory dialog with trophy + fireworks Lottie.
class WinnerModal extends ConsumerWidget {
  const WinnerModal({super.key, required this.winner, required this.onExit});

  final int winner;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F0C29),
                  Color(0xFF302B63),
                  Color(0xFF24243E),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFD4AF37), width: 2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: colorForPlayer(winner),
                    shape: BoxShape.circle,
                    border:
                        Border.all(color: const Color(0xFFD4AF37), width: 3),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.emoji_events,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(height: 12),
                Text(
                  'Player $winner Wins!',
                  style: const TextStyle(
                    color: LudoColors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 160,
                  child: Lottie.asset(
                    'assets/ludo/animations/trophy.json',
                    repeat: false,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.emoji_events,
                      color: Color(0xFFD4AF37),
                      size: 100,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _btn('NEW GAME', () {
                  ref.read(ludoNotifierProvider.notifier).resetGame();
                  LudoSoundService.instance.play('game_start');
                }),
                const SizedBox(height: 10),
                _btn('EXIT', onExit),
              ],
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: Lottie.asset(
                'assets/ludo/animations/firework.json',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFC0392B), Color(0xFF8B5CF6)],
          ),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: LudoColors.white,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}
