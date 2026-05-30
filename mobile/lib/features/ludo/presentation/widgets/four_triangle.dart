import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../../domain/ludo_state.dart';
import '../../services/ludo_notifier.dart';
import 'ludo_colors.dart';
import 'pile_widget.dart';

/// Centre 3×3 of the board: four coloured triangles forming the home, plus
/// finished tokens stacked on each triangle. Plays a fireworks Lottie when
/// any token reaches the centre.
class FourTriangle extends ConsumerStatefulWidget {
  const FourTriangle({super.key});

  @override
  ConsumerState<FourTriangle> createState() => _FourTriangleState();
}

class _FourTriangleState extends ConsumerState<FourTriangle> {
  bool _showFirework = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ludoNotifierProvider);

    ref.listen<LudoState>(ludoNotifierProvider, (prev, next) {
      if (next.fireworks && !(prev?.fireworks ?? false)) {
        setState(() => _showFirework = true);
        Future.delayed(const Duration(seconds: 4), () {
          if (!mounted) return;
          setState(() => _showFirework = false);
          ref.read(ludoNotifierProvider.notifier).clearFireworks();
        });
      }
    });

    return AspectRatio(
      aspectRatio: 1,
      child: ClipRect(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: LudoColors.white,
            border: Border.all(color: LudoColors.border, width: 0.8),
          ),
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _TrianglePainter())),
              ..._finishedPieces(state),
              if (_showFirework && !MediaQuery.disableAnimationsOf(context))
                Positioned.fill(
                  child: IgnorePointer(
                    child: Lottie.asset(
                      'assets/ludo/animations/firework.json',
                      fit: BoxFit.cover,
                      repeat: false,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _finishedPieces(LudoState s) {
    Widget stack(List<PlayerPiece> pieces, int playerNo, Alignment align) {
      final finished = pieces.where((p) => p.travelCount >= 57).toList();
      return Align(
        alignment: align,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final p in finished)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: PileWidget(
                    playerNo: playerNo,
                    pieceId: p.id,
                    cellMode: true,
                    onPress: () {},
                    size: 14,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return [
      stack(s.player1, 1, Alignment.bottomLeft),
      stack(s.player2, 2, Alignment.topLeft),
      stack(s.player3, 3, Alignment.topRight),
      stack(s.player4, 4, Alignment.bottomRight),
    ];
  }
}

class _TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final centre = Offset(w / 2, h / 2);

    void tri(List<Offset> pts, Color c) {
      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy)
        ..close();
      canvas.drawPath(path, Paint()..color = c);
    }

    tri([Offset.zero, Offset(w, 0), centre], LudoColors.green);
    tri([Offset(w, 0), Offset(w, h), centre], LudoColors.yellow);
    tri([Offset(w, h), Offset(0, h), centre], LudoColors.blue);
    tri([Offset(0, h), Offset.zero, centre], LudoColors.red);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter oldDelegate) => false;
}
