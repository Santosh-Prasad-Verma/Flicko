import 'package:flutter/material.dart';

import 'cell_widget.dart';

/// 6 cells × 3 rows for one of the long horizontal arms.
class HorizontalPath extends StatelessWidget {
  const HorizontalPath({
    super.key,
    required this.cells,
    required this.color,
  });

  final List<int> cells;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final groups = <List<int>>[];
    for (var i = 0; i < cells.length; i += 6) {
      groups.add(cells.sublist(i, (i + 6).clamp(0, cells.length)));
    }
    return SizedBox.expand(
      child: Column(
        children: [
          for (final g in groups)
            Expanded(
              child: Row(
                children: [
                  for (final c in g)
                    Expanded(child: CellWidget(id: c, color: color)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// 3 cells × 6 rows for one of the long vertical arms.
class VerticalPath extends StatelessWidget {
  const VerticalPath({
    super.key,
    required this.cells,
    required this.color,
  });

  final List<int> cells;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final groups = <List<int>>[];
    for (var i = 0; i < cells.length; i += 3) {
      groups.add(cells.sublist(i, (i + 3).clamp(0, cells.length)));
    }
    return SizedBox.expand(
      child: Column(
        children: [
          for (final g in groups)
            Expanded(
              child: Row(
                children: [
                  for (final c in g)
                    Expanded(child: CellWidget(id: c, color: color)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
