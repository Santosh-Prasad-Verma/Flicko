import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ludo_state.dart';
import '../../domain/plot_data.dart';
import '../../services/ludo_notifier.dart';
import 'ludo_colors.dart';
import 'pile_widget.dart';

/// One cell on the path. Renders the cell background, optional star/arrow,
/// and any pieces currently on this cell.
class CellWidget extends ConsumerWidget {
  const CellWidget({
    super.key,
    required this.id,
    required this.color,
  });

  final int id;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(ludoNotifierProvider);
    final isSafe = safeSpots.contains(id);
    final isStar = starSpots.contains(id);
    final isArrow = arrowSpots.contains(id);

    final piecesHere = state.currentPosition.where((p) => p.pos == id).toList();

    final bg = isSafe ? color : LudoColors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: LudoColors.grey, width: 0.4),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isStar)
            const Icon(Icons.star_border_rounded,
                size: 14, color: LudoColors.grey),
          if (isArrow)
            Transform.rotate(
              angle: _arrowAngle(id),
              child:
                  const Icon(Icons.east, size: 12, color: LudoColors.grey),
            ),
          ..._renderPieces(ref, piecesHere),
        ],
      ),
    );
  }

  static double _arrowAngle(int id) {
    return switch (id) {
      12 => 0,
      25 => 1.5708, // 90°
      38 => 3.14159, // 180°
      _ => -1.5708, // -90°
    };
  }

  List<Widget> _renderPieces(WidgetRef ref, List<PlottedPiece> here) {
    final notifier = ref.read(ludoNotifierProvider.notifier);
    return [
      for (int i = 0; i < here.length; i++)
        Builder(builder: (context) {
          final piece = here[i];
          final pNo = playerForPieceId(piece.id);
          final scale = here.length == 1 ? 1.0 : 0.7;
          final dx = here.length == 1 ? 0.0 : (i.isEven ? -6.0 : 6.0);
          final dy = here.length == 1 ? 0.0 : (i < 2 ? -6.0 : 6.0);
          return Transform.translate(
            offset: Offset(dx, dy),
            child: Transform.scale(
              scale: scale,
              child: PileWidget(
                playerNo: pNo,
                pieceId: piece.id,
                cellMode: true,
                onPress: () => notifier.handleForward(
                  playerNo: pNo,
                  pieceId: piece.id,
                  targetPos: id,
                ),
                size: 22,
              ),
            ),
          );
        }),
    ];
  }
}
