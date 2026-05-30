import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../domain/ludo_state.dart';
import '../../services/ludo_notifier.dart';
import 'ludo_colors.dart';

/// Per-player dice + pile-icon strip. The dice is interactive only when this
/// is the current player's turn; long-press forces a 6 (developer aid).
class DiceWidget extends ConsumerStatefulWidget {
  const DiceWidget({
    super.key,
    required this.playerNo,
    required this.color,
    required this.pieces,
    this.mirror = false,
  });

  final int playerNo;
  final Color color;
  final List<PlayerPiece> pieces;

  /// When true, the row is mirrored horizontally (for top-right / bottom-right
  /// dice mirroring the layout from the RN port).
  final bool mirror;

  @override
  ConsumerState<DiceWidget> createState() => _DiceWidgetState();
}

class _DiceWidgetState extends ConsumerState<DiceWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..repeat(reverse: true);

  bool _rolling = false;

  @override
  void dispose() {
    _arrow.dispose();
    super.dispose();
  }

  Future<void> _onPress({bool forceSix = false}) async {
    if (_rolling) return;
    final notifier = ref.read(ludoNotifierProvider.notifier);
    setState(() => _rolling = true);
    await notifier.rollDice(forced: forceSix ? 6 : null);
    if (mounted) setState(() => _rolling = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ludoNotifierProvider);
    final isMyTurn = state.chancePlayer == widget.playerNo &&
        state.winner == null &&
        !state.touchDiceBlock;
    final canShowArrow = isMyTurn && !state.isDiceRolled;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    final row = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0052BE), Color(0xFF5F9FCB), Color(0xFF97C6C9)],
            ),
            border: Border.all(color: const Color(0xFFF0CE2C), width: 3),
          ),
          child: Image.asset(
            pileAssetForPlayer(widget.playerNo),
            width: 26,
            height: 26,
            errorBuilder: (_, __, ___) => Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: widget.color,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFFAAC8AB),
            border: Border.all(color: const Color(0xFFAAC8AB), width: 3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Semantics(
            label: 'Player ${widget.playerNo} dice',
            value: 'rolled ${state.diceNo}',
            button: isMyTurn,
            enabled: isMyTurn,
            onTap: isMyTurn ? () => _onPress() : null,
            child: GestureDetector(
              onTap: isMyTurn ? () => _onPress() : null,
              onLongPress: isMyTurn ? () => _onPress(forceSix: true) : null,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8C0C1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.black26),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isMyTurn && !_rolling)
                      Image.asset(
                        diceAsset(state.diceNo),
                        width: 38,
                        height: 38,
                        errorBuilder: (_, __, ___) => Center(
                          child: Text('${state.diceNo}',
                              style: const TextStyle(
                                  fontSize: 26, fontWeight: FontWeight.w900)),
                        ),
                      ),
                    if (_rolling && !reduceMotion)
                      Lottie.asset(
                        'assets/ludo/animations/diceroll.json',
                        width: 70,
                        height: 70,
                        repeat: false,
                        errorBuilder: (_, __, ___) =>
                            const CircularProgressIndicator(strokeWidth: 2),
                      ),
                    if (_rolling && reduceMotion)
                      const CircularProgressIndicator(strokeWidth: 2),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (canShowArrow && !reduceMotion) ...[
          const SizedBox(width: 6),
          AnimatedBuilder(
            animation: _arrow,
            builder: (_, __) => Transform.translate(
              offset: Offset(_arrow.value * 10 - 5, 0),
              child: Image.asset(
                'assets/ludo/images/arrow.png',
                width: 36,
                height: 18,
                errorBuilder: (_, __, ___) => Icon(
                  Icons.east_rounded,
                  size: 28,
                  color: widget.color,
                ),
              ),
            ),
          ),
        ],
        if (canShowArrow && reduceMotion) ...[
          const SizedBox(width: 6),
          Icon(Icons.east_rounded, size: 28, color: widget.color),
        ],
      ],
    );

    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..scaleByDouble(widget.mirror ? -1.0 : 1.0, 1.0, 1.0, 1.0),
      child: row,
    );
  }
}
