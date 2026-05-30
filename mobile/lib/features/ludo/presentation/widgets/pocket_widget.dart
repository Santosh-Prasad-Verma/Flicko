import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/ludo_state.dart';
import '../../services/ludo_notifier.dart';
import 'ludo_colors.dart';
import 'pile_widget.dart';

/// One of the four corner pockets where un-released pieces sit.
class PocketWidget extends ConsumerWidget {
  const PocketWidget({
    super.key,
    required this.color,
    required this.playerNo,
    required this.pieces,
  });

  final Color color;
  final int playerNo;
  final List<PlayerPiece> pieces;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(ludoNotifierProvider.notifier);

    return Container(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: Colors.black12, width: 0.4),
      ),
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.7,
          heightFactor: 0.7,
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: LudoColors.white,
              border: Border.all(color: LudoColors.border),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _row(context, notifier, [0, 1]),
                _row(context, notifier, [2, 3]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, LudoNotifier notifier, List<int> idx) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final i in idx) _slot(context, notifier, i),
        ],
      ),
    );
  }

  Widget _slot(BuildContext context, LudoNotifier notifier, int i) {
    final piece = i < pieces.length ? pieces[i] : null;
    final inPocket = piece != null && piece.pos == 0;

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Center(
          child: FractionallySizedBox(
            widthFactor: 0.8,
            heightFactor: 0.8,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12, width: 0.5),
              ),
              child: inPocket
                  ? Padding(
                      padding: const EdgeInsets.all(2),
                      child: PileWidget(
                        playerNo: playerNo,
                        pieceId: piece.id,
                        cellMode: false,
                        onPress: () =>
                            notifier.releaseFromPocket(playerNo, piece.id),
                        size: 22,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
