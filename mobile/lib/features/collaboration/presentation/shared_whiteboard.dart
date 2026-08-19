import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
// Local interactive whiteboard engine


class PathData {
  final String id;
  final List<Offset> points;
  final Color color;
  final double strokeWidth;
  final String userId;

  PathData({
    required this.id,
    required this.points,
    required this.color,
    required this.strokeWidth,
    required this.userId,
  });
}

class SharedWhiteboard extends StatefulWidget {
  final String channelId;
  final String currentUserId;
  final VoidCallback? onClose;
  final void Function(List<PathData>)? onExport;

  const SharedWhiteboard({
    super.key,
    required this.channelId,
    required this.currentUserId,
    this.onClose,
    this.onExport,
  });

  @override
  State<SharedWhiteboard> createState() => _SharedWhiteboardState();
}

class _SharedWhiteboardState extends State<SharedWhiteboard> {
  final List<PathData> _paths = [];
  List<Offset> _currentPath = [];
  Color _selectedColor = Colors.white;
  double _brushSize = 4.0;
  String _tool = 'pen'; // 'pen' or 'eraser'
  int _pathIdCounter = 0;
  
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  static const List<Color> _colors = [
    Colors.white,
    Color(0xFFED4245),
    Color(0xFFFEE75C),
    Color(0xFF57F287),
    Color(0xFF5865F2),
    Color(0xFFEB459E),
    Color(0xFFFF7A00),
    Colors.black,
  ];

  static const List<double> _brushSizes = [2.0, 4.0, 8.0, 12.0];

  void _handlePanStart(DragStartDetails details) {
    setState(() {
      _currentPath = [details.localPosition];
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    setState(() {
      _currentPath.add(details.localPosition);
    });
  }

  void _handlePanEnd(DragEndDetails details) {
    if (_currentPath.isNotEmpty) {
      _pathIdCounter++;
      final newPath = PathData(
        id: '${widget.currentUserId}_$_pathIdCounter',
        points: List.from(_currentPath),
        color: _tool == 'eraser' ? const Color(FlickoColors.bgPrimary) : _selectedColor,
        strokeWidth: _tool == 'eraser' ? _brushSize * 3 : _brushSize,
        userId: widget.currentUserId,
      );
      setState(() {
        _paths.add(newPath);
        _currentPath.clear();
      });

      _channel?.sendBroadcastMessage(
        event: 'draw',
        payload: {
          'id': newPath.id,
          'points': newPath.points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
          'color': newPath.color.value,
          'strokeWidth': newPath.strokeWidth,
          'userId': newPath.userId,
        },
      );
    }
  }

  void _handleUndo() {
    setState(() {
      for (int i = _paths.length - 1; i >= 0; i--) {
        if (_paths[i].userId == widget.currentUserId) {
          _paths.removeAt(i);
          break;
        }
      }
    });

    _channel?.sendBroadcastMessage(
      event: 'undo',
      payload: {'userId': widget.currentUserId},
    );
  }

  void _handleClear() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Clear Canvas',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
        ),
        content: Text(
          'This will clear all drawings. Continue?',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted))),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _paths.clear();
              });
              _channel?.sendBroadcastMessage(
                event: 'clear',
                payload: {},
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(FlickoColors.danger)),
            child: Text('Clear', style: GoogleFonts.inter(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleExport() {
    widget.onExport?.call(_paths);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Whiteboard snapshot has been saved.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(FlickoColors.bgPrimary),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: GestureDetector(
              onPanStart: _handlePanStart,
              onPanUpdate: _handlePanUpdate,
              onPanEnd: _handlePanEnd,
              child: ClipRect(
                child: CustomPaint(
                  painter: _WhiteboardPainter(
                    paths: _paths,
                    currentPath: _currentPath,
                    currentColor: _tool == 'eraser' ? const Color(FlickoColors.bgPrimary) : _selectedColor,
                    currentStrokeWidth: _tool == 'eraser' ? _brushSize * 3 : _brushSize,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
          ),
          _buildToolbar(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgPrimary),
        border: Border(bottom: BorderSide(color: Color(0xFF202225), width: 1)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, color: Color(FlickoColors.textMuted)),
            onPressed: widget.onClose,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'Whiteboard',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.undo, color: Color(FlickoColors.textMuted), size: 20),
                onPressed: _handleUndo,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(FlickoColors.textMuted), size: 20),
                onPressed: _handleClear,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                constraints: const BoxConstraints(),
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined, color: Color(FlickoColors.textMuted), size: 20),
                onPressed: _handleExport,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(FlickoColors.bgSecondary),
        border: Border(top: BorderSide(color: Color(0xFF202225), width: 1)),
      ),
      child: Row(
        children: [
          _buildToolBtn(Icons.edit, 'pen'),
          const SizedBox(width: 4),
          _buildToolBtn(Icons.water_drop_outlined, 'eraser'),
          const SizedBox(width: 10),
          Container(width: 1, height: 24, color: const Color(0xFF40444B)),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _colors.map((c) => _buildColorBtn(c)).toList(),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Container(width: 1, height: 24, color: const Color(0xFF40444B)),
          const SizedBox(width: 10),
          Row(
            children: _brushSizes.map((s) => _buildBrushSizeBtn(s)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildToolBtn(IconData icon, String type) {
    final isActive = _tool == type;
    return InkWell(
      onTap: () => setState(() => _tool = type),
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isActive ? const Color(FlickoColors.blurple).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 18,
          color: isActive ? const Color(FlickoColors.blurple) : const Color(FlickoColors.textMuted),
        ),
      ),
    );
  }

  Widget _buildColorBtn(Color color) {
    final isActive = _selectedColor == color && _tool == 'pen';
    return InkWell(
      onTap: () {
        setState(() {
          _selectedColor = color;
          _tool = 'pen';
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isActive ? Border.all(color: const Color(FlickoColors.blurple), width: 2) : null,
        ),
      ),
    );
  }

  Widget _buildBrushSizeBtn(double size) {
    final isActive = _brushSize == size;
    return InkWell(
      onTap: () => setState(() => _brushSize = size),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: isActive ? const Color(FlickoColors.blurple).withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Container(
          width: size + 4,
          height: size + 4,
          decoration: BoxDecoration(
            color: isActive ? const Color(FlickoColors.blurple) : const Color(FlickoColors.textMuted),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _WhiteboardPainter extends CustomPainter {
  final List<PathData> paths;
  final List<Offset> currentPath;
  final Color currentColor;
  final double currentStrokeWidth;

  _WhiteboardPainter({
    required this.paths,
    required this.currentPath,
    required this.currentColor,
    required this.currentStrokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final pathData in paths) {
      if (pathData.points.isEmpty) continue;

      final paint = Paint()
        ..color = pathData.color
        ..strokeWidth = pathData.strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(pathData.points[0].dx, pathData.points[0].dy);
      for (int i = 1; i < pathData.points.length; i++) {
        path.lineTo(pathData.points[i].dx, pathData.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    if (currentPath.isNotEmpty) {
      final paint = Paint()
        ..color = currentColor
        ..strokeWidth = currentStrokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      final path = Path()..moveTo(currentPath[0].dx, currentPath[0].dy);
      for (int i = 1; i < currentPath.length; i++) {
        path.lineTo(currentPath[i].dx, currentPath[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WhiteboardPainter oldDelegate) {
    return true; // We always repaint when points change
  }
}
