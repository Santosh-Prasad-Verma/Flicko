import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import '../../providers/chess_game_notifier.dart';

class ChessGameScreen extends ConsumerStatefulWidget {
  final String gameId;

  const ChessGameScreen({
    super.key,
    required this.gameId,
  });

  @override
  ConsumerState<ChessGameScreen> createState() => _ChessGameScreenState();
}

class _ChessGameScreenState extends ConsumerState<ChessGameScreen> {
  String? _selectedSquare;
  List<String> _validMoves = [];
  bool _isFlipped = false;

  // Standard chess starting position FEN
  static const String _initialFEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1';

  @override
  Widget build(BuildContext context) {
    final gameStateAsync = ref.watch(chessGameProvider(widget.gameId));

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: _buildAppBar(),
      body: gameStateAsync.when(
        data: (state) => _buildGameContent(state.fen),
        loading: () => _buildLoadingContent(),
        error: (err, stack) => _buildErrorContent(err),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text(
        'CHESS MATCH',
        style: GoogleFonts.epilogue(
          color: const Color(FlickoColors.textPrimary),
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
      actions: [
        IconButton(
          icon: Icon(
            _isFlipped ? Icons.flip_to_front : Icons.flip_to_back,
            color: const Color(FlickoColors.textSecondary),
          ),
          onPressed: () => setState(() => _isFlipped = !_isFlipped),
          tooltip: 'Flip Board',
        ),
        IconButton(
          icon: const Icon(Icons.flag_outlined, color: Color(FlickoColors.danger)),
          onPressed: _showResignDialog,
          tooltip: 'Resign',
        ),
      ],
    );
  }

  Widget _buildGameContent(String fen) {
    final board = _parseFEN(fen);
    final isWhiteTurn = !fen.contains(' b ');

    return Column(
      children: [
        // Opponent info
        _buildPlayerHeader('Opponent', isBot: true, isTurn: !isWhiteTurn),
        
        // Captured pieces (opponent's captures)
        _buildCapturedPieces(isWhite: true),
        
        // Chess board
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1.0,
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(FlickoColors.bgTertiary),
                    width: 2,
                  ),
                ),
                child: _buildChessBoard(board),
              ),
            ),
          ),
        ),
        
        // Captured pieces (player's captures)
        _buildCapturedPieces(isWhite: false),
        
        // Player info
        _buildPlayerHeader('You', isBot: false, isTurn: isWhiteTurn),
        
        // Move history and controls
        _buildBottomPanel(),
      ],
    );
  }

  Widget _buildPlayerHeader(String name, {required bool isBot, required bool isTurn}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: isTurn ? const Color(FlickoColors.blurple).withValues(alpha: 0.1) : Colors.transparent,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(FlickoColors.bgSecondary),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isTurn ? const Color(FlickoColors.blurple) : const Color(FlickoColors.bgTertiary),
              ),
            ),
            child: Icon(
              isBot ? Icons.smart_toy : Icons.person,
              color: isTurn ? const Color(FlickoColors.blurple) : const Color(FlickoColors.textMuted),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isBot)
                Text(
                  'AI • Medium',
                  style: GoogleFonts.inter(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 11,
                  ),
                ),
            ],
          ),
          const Spacer(),
          if (isTurn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.blurple),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                'YOUR TURN',
                style: GoogleFonts.spaceMono(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCapturedPieces({required bool isWhite}) {
    // Placeholder for captured pieces display
    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Text(
            isWhite ? 'Captured: ' : 'Captured: ',
            style: GoogleFonts.inter(
              color: const Color(FlickoColors.textMuted),
              fontSize: 11,
            ),
          ),
          // Would show captured piece icons here
        ],
      ),
    );
  }

  Widget _buildChessBoard(List<List<String>> board) {
    return Column(
      children: List.generate(8, (rowIndex) {
        final displayRow = _isFlipped ? 7 - rowIndex : rowIndex;
        return Expanded(
          child: Row(
            children: List.generate(8, (colIndex) {
              final displayCol = _isFlipped ? 7 - colIndex : colIndex;
              final square = '${_getFile(displayCol)}${8 - displayRow}';
              final piece = board[displayRow][displayCol];
              final isLight = (displayRow + displayCol) % 2 == 0;
              final isSelected = _selectedSquare == square;
              final isValidMove = _validMoves.contains(square);

              return Expanded(
                child: GestureDetector(
                  onTap: () => _handleSquareTap(square, piece),
                  child: Container(
                    color: isSelected
                        ? const Color(FlickoColors.blurple).withValues(alpha: 0.4)
                        : isValidMove
                            ? const Color(FlickoColors.neonGreen).withValues(alpha: 0.3)
                            : isLight
                                ? const Color(0xFFB7C0D8)
                                : const Color(0xFF7B8B9D),
                    child: Stack(
                      children: [
                        // Coordinate labels
                        if (colIndex == 0)
                          Positioned(
                            left: 2,
                            top: 2,
                            child: Text(
                              '${8 - displayRow}',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isLight ? const Color(0xFF7B8B9D) : const Color(0xFFB7C0D8),
                              ),
                            ),
                          ),
                        if (rowIndex == 7)
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Text(
                              _getFile(displayCol).toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                                color: isLight ? const Color(0xFF7B8B9D) : const Color(0xFFB7C0D8),
                              ),
                            ),
                          ),
                        // Piece
                        Center(
                          child: _buildPiece(piece),
                        ),
                        // Valid move indicator
                        if (isValidMove && piece.isEmpty)
                          Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: const Color(FlickoColors.neonGreen).withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }

  Widget _buildPiece(String piece) {
    if (piece.isEmpty) return const SizedBox.shrink();

    final isWhite = piece.toUpperCase() == piece;
    final color = isWhite ? Colors.white : Colors.black;
    final shadowColor = isWhite ? Colors.black : Colors.white;

    // Unicode chess pieces
    final pieceSymbols = {
      'K': '♔', 'Q': '♕', 'R': '♖', 'B': '♗', 'N': '♘', 'P': '♙',
      'k': '♚', 'q': '♛', 'r': '♜', 'b': '♝', 'n': '♞', 'p': '♟',
    };

    final symbol = pieceSymbols[piece] ?? '';

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.5),
            blurRadius: 1,
            offset: const Offset(1, 1),
          ),
        ],
      ),
      child: Text(
        symbol,
        style: TextStyle(
          fontSize: 32,
          color: color,
          height: 1.1,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildBottomPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        border: Border(
          top: BorderSide(color: const Color(FlickoColors.bgTertiary)),
        ),
      ),
      child: Row(
        children: [
          // Move history
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(FlickoColors.bgPrimary),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'e4 e5 Nf3 Nc6 Bb5',
                style: GoogleFonts.spaceMono(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Action buttons
          IconButton(
            icon: const Icon(Icons.draw_outlined, color: Color(FlickoColors.textSecondary)),
            onPressed: _showDrawDialog,
            tooltip: 'Offer Draw',
          ),
          IconButton(
            icon: const Icon(Icons.history, color: Color(FlickoColors.textSecondary)),
            onPressed: () {},
            tooltip: 'Move History',
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingContent() {
    return const Center(
      child: CircularProgressIndicator(color: Color(FlickoColors.blurple)),
    );
  }

  Widget _buildErrorContent(Object err) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Color(FlickoColors.danger), size: 48),
          const SizedBox(height: 16),
          Text(
            'Failed to load game',
            style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => ref.invalidate(chessGameProvider(widget.gameId)),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  List<List<String>> _parseFEN(String fen) {
    final board = List.generate(8, (_) => List.filled(8, ''));
    final rows = fen.split(' ')[0].split('/');

    for (int row = 0; row < 8; row++) {
      int col = 0;
      for (final char in rows[row].split('')) {
        if (int.tryParse(char) != null) {
          col += int.parse(char);
        } else {
          board[row][col] = char;
          col++;
        }
      }
    }

    return board;
  }

  String _getFile(int col) => String.fromCharCode(97 + col);

  void _handleSquareTap(String square, String piece) {
    if (_selectedSquare == null) {
      // Select a piece
      if (piece.isNotEmpty) {
        setState(() {
          _selectedSquare = square;
          _validMoves = _getValidMoves(square, piece);
        });
      }
    } else {
      // Try to move
      if (_validMoves.contains(square)) {
        _makeMove(_selectedSquare!, square);
      }
      setState(() {
        _selectedSquare = null;
        _validMoves = [];
      });
    }
  }

  List<String> _getValidMoves(String from, String piece) {
    // Simplified valid moves - in production, this would come from backend
    // or a local chess engine
    final moves = <String>[];
    final col = from.codeUnitAt(0) - 97;
    final row = 8 - int.parse(from[1]);

    // Add some example moves based on piece type
    switch (piece.toLowerCase()) {
      case 'p':
        // Pawn moves
        final direction = piece.toUpperCase() == piece ? -1 : 1;
        final newRow = row + direction;
        if (newRow >= 0 && newRow < 8) {
          moves.add('${_getFile(col)}${8 - newRow}');
        }
        break;
      case 'n':
        // Knight moves
        final knightMoves = [
          [-2, -1], [-2, 1], [-1, -2], [-1, 2],
          [1, -2], [1, 2], [2, -1], [2, 1],
        ];
        for (final m in knightMoves) {
          final newCol = col + m[0];
          final newRow = row + m[1];
          if (newCol >= 0 && newCol < 8 && newRow >= 0 && newRow < 8) {
            moves.add('${_getFile(newCol)}${8 - newRow}');
          }
        }
        break;
      case 'k':
        // King moves
        for (int dc = -1; dc <= 1; dc++) {
          for (int dr = -1; dr <= 1; dr++) {
            if (dc == 0 && dr == 0) continue;
            final newCol = col + dc;
            final newRow = row + dr;
            if (newCol >= 0 && newCol < 8 && newRow >= 0 && newRow < 8) {
              moves.add('${_getFile(newCol)}${8 - newRow}');
            }
          }
        }
        break;
      default:
        // For other pieces, show empty list (backend validates)
        break;
    }

    return moves;
  }

  void _makeMove(String from, String to) {
    final moveStr = '$from$to';
    ref.read(chessGameProvider(widget.gameId).notifier).makeOptimisticMove(moveStr);
  }

  void _showResignDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Resign Game?',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
        ),
        content: Text(
          'Are you sure you want to resign? This cannot be undone.',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              'Resign',
              style: GoogleFonts.inter(color: const Color(FlickoColors.danger)),
            ),
          ),
        ],
      ),
    );
  }

  void _showDrawDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Text(
          'Offer Draw?',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
        ),
        content: Text(
          'Send a draw offer to your opponent?',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Draw offer sent'),
                  backgroundColor: Color(FlickoColors.blurple),
                ),
              );
            },
            child: Text(
              'Offer Draw',
              style: GoogleFonts.inter(color: const Color(FlickoColors.blurple)),
            ),
          ),
        ],
      ),
    );
  }
}
