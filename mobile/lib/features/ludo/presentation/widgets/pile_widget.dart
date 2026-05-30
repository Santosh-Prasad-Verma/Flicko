import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ludo_state.dart';
import '../../services/ludo_notifier.dart';
import 'ludo_colors.dart';

/// A single player token. Shows a rotating dashed selector when this token
/// can be moved (either out of the pocket or forward on the board).
class PileWidget extends ConsumerStatefulWidget {
  const PileWidget({
    super.key,
    required this.playerNo,
    required this.pieceId,
    required this.cellMode,
    required this.onPress,
    this.size = 32,
  });

  /// 1..4 — owning player.
  final int playerNo;

  /// Piece identifier (e.g. "A1").
  final String pieceId;

  /// True when on a board cell, false in the pocket.
  final bool cellMode;
  final VoidCallback onPress;
  final double size;

  @override
  ConsumerState<PileWidget> createState() => _PileWidgetState();
}

class _PileWidgetState extends ConsumerState<PileWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat();

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ludoNotifierProvider);
    final isPileEnabled = state.pileSelectionPlayer == widget.playerNo;
    final isCellEnabled = state.cellSelectionPlayer == widget.playerNo;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Find the live piece state. If it can't be found (transient desync after
    // a capture animation, etc.), render nothing rather than silently
    // surfacing a different piece's selection state.
    final pieces = state.piecesFor(widget.playerNo);
    final pieceIdx = pieces.indexWhere((p) => p.id == widget.pieceId);
    if (pieceIdx == -1) return const SizedBox.shrink();
    final piece = pieces[pieceIdx];

    final isForwardable = piece.travelCount + state.diceNo <= 57;

    final selectable = widget.cellMode
        ? (isCellEnabled && isForwardable && piece.pos != 0)
        : isPileEnabled;

    final semanticLabel = _semanticLabel(piece, selectable);

    return Semantics(
      label: semanticLabel,
      button: selectable,
      enabled: selectable,
      onTap: selectable ? widget.onPress : null,
      child: GestureDetector(
        onTap: selectable ? widget.onPress : null,
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (selectable && !reduceMotion)
                AnimatedBuilder(
                  animation: _spin,
                  builder: (_, __) => Transform.rotate(
                    angle: _spin.value * 6.283185,
                    child: CustomPaint(
                      size: Size(widget.size * 0.75, widget.size * 0.75),
                      painter: _DashedRingPainter(
                        color: colorForPlayer(widget.playerNo),
                      ),
                    ),
                  ),
                ),
              if (selectable && reduceMotion)
                CustomPaint(
                  size: Size(widget.size * 0.75, widget.size * 0.75),
                  painter: _DashedRingPainter(
                    color: colorForPlayer(widget.playerNo),
                  ),
                ),
              Image.asset(
                pileAssetForPlayer(widget.playerNo),
                width: widget.size,
                height: widget.size,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    color: colorForPlayer(widget.playerNo),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _semanticLabel(PlayerPiece piece, bool selectable) {
    final colorName = switch (widget.playerNo) {
      1 => 'Red',
      2 => 'Green',
      3 => 'Yellow',
      _ => 'Blue',
    };
    String location;
    if (piece.pos == 0) {
      location = 'in pocket';
    } else if (piece.travelCount >= 57) {
      location = 'finished';
    } else {
      location = 'on cell ${piece.pos}, travelled ${piece.travelCount} of 57';
    }
    final action = selectable ? '. Double tap to move.' : '';
    return '$colorName token ${widget.pieceId}, $location$action';
  }
}

class _DashedRingPainter extends CustomPainter {
  _DashedRingPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.white;
    const dashCount = 12;
    const dashAngle = 6.283185 / (dashCount * 2); // half dash, half gap
    final radius = size.width / 2 - 1;
    final centre = Offset(size.width / 2, size.height / 2);
    for (int i = 0; i < dashCount; i++) {
      final start = (i * 2) * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: radius),
        start,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRingPainter old) => false;
}
