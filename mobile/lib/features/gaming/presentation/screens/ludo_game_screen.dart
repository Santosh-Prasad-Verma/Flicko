import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';

class LudoGameScreen extends ConsumerStatefulWidget {
  final String gameId;

  const LudoGameScreen({
    super.key,
    required this.gameId,
  });

  @override
  ConsumerState<LudoGameScreen> createState() => _LudoGameScreenState();
}

class _LudoGameScreenState extends ConsumerState<LudoGameScreen>
    with SingleTickerProviderStateMixin {
  int _currentDiceValue = 0;
  bool _isRolling = false;
  int _currentPlayerIndex = 0;
  String? _selectedToken;

  // Player colors
  static const List<Color> _playerColors = [
    Color(0xFFE53935), // Red
    Color(0xFF43A047), // Green
    Color(0xFFFFB300), // Yellow
    Color(0xFF1E88E5), // Blue
  ];

  static const List<String> _playerNames = ['Red', 'Green', 'Yellow', 'Blue'];

  // Token positions (progression index: -1 = base, 0-50 = perimeter, 51-56 = home run, 57 = finished)
  final List<List<int>> _tokenPositions = [
    [-1, -1, -1, -1], // Red tokens
    [-1, -1, -1, -1], // Green tokens
    [-1, -1, -1, -1], // Yellow tokens
    [-1, -1, -1, -1], // Blue tokens
  ];

  // Entry offsets for each color
  static const List<int> _entryOffsets = [0, 13, 26, 39];

  // Safe squares on the board
  static const Set<int> _safeSquares = {0, 8, 13, 21, 26, 34, 39, 47};

  late AnimationController _diceAnimController;
  late Animation<double> _diceRotation;

  @override
  void initState() {
    super.initState();
    _diceAnimController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _diceRotation = Tween<double>(begin: 0, end: 2 * 3.14159).animate(
      CurvedAnimation(parent: _diceAnimController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _diceAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Player info bar
          _buildPlayerInfoBar(),
          
          // Game board
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 1.0,
                child: Container(
                  margin: const EdgeInsets.all(16),
                  child: _buildLudoBoard(),
                ),
              ),
            ),
          ),
          
          // Dice and controls
          _buildDicePanel(),
        ],
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
        'LUDO MATCH',
        style: GoogleFonts.epilogue(
          color: const Color(FlickoColors.textPrimary),
          fontSize: 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.0,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.info_outline, color: Color(FlickoColors.textSecondary)),
          onPressed: _showRules,
        ),
      ],
    );
  }

  Widget _buildPlayerInfoBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        border: Border(
          bottom: BorderSide(color: const Color(FlickoColors.bgTertiary)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(4, (index) {
          final isCurrentPlayer = index == _currentPlayerIndex;
          final tokensHome = _tokenPositions[index].where((p) => p >= 57).length;
          
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: isCurrentPlayer
                  ? _playerColors[index].withValues(alpha: 0.2)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isCurrentPlayer ? _playerColors[index] : Colors.transparent,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _playerColors[index],
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _playerNames[index],
                  style: GoogleFonts.inter(
                    color: isCurrentPlayer
                        ? _playerColors[index]
                        : const Color(FlickoColors.textMuted),
                    fontSize: 12,
                    fontWeight: isCurrentPlayer ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '$tokensHome/4',
                  style: GoogleFonts.spaceMono(
                    color: const Color(FlickoColors.textMuted),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildLudoBoard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        border: Border.all(color: const Color(FlickoColors.bgTertiary), width: 2),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final cellSize = constraints.maxWidth / 15;
          return Stack(
            children: [
              // Draw the board grid
              ..._buildBoardCells(cellSize),
              // Draw tokens on the board
              ..._buildTokens(cellSize),
              // Draw home bases
              ..._buildHomeBases(cellSize),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildBoardCells(double cellSize) {
    final cells = <Widget>[];

    // The Ludo board is 15x15
    for (int row = 0; row < 15; row++) {
      for (int col = 0; col < 15; col++) {
        final position = _getBoardPosition(row, col);
        Color? cellColor;

        if (position != null) {
          // Determine cell color based on position type
          if (position >= 0 && position < 52) {
            // Main track - check for safe squares
            if (_safeSquares.contains(position)) {
              cellColor = const Color(0xFFFFFFFF).withValues(alpha: 0.1);
            }
          } else if (position >= 100 && position < 200) {
            // Home run for specific color
            final colorIndex = (position - 100) ~/ 10;
            cellColor = _playerColors[colorIndex].withValues(alpha: 0.3);
          }
        }

        // Color zones (home bases)
        if (row < 6 && col < 6) {
          cellColor = _playerColors[0].withValues(alpha: 0.15); // Red
        } else if (row < 6 && col > 8) {
          cellColor = _playerColors[1].withValues(alpha: 0.15); // Green
        } else if (row > 8 && col < 6) {
          cellColor = _playerColors[2].withValues(alpha: 0.15); // Yellow
        } else if (row > 8 && col > 8) {
          cellColor = _playerColors[3].withValues(alpha: 0.15); // Blue
        }

        cells.add(
          Positioned(
            left: col * cellSize,
            top: row * cellSize,
            width: cellSize,
            height: cellSize,
            child: Container(
              decoration: BoxDecoration(
                color: cellColor ?? Colors.transparent,
                border: Border.all(
                  color: const Color(FlickoColors.bgTertiary).withValues(alpha: 0.3),
                  width: 0.5,
                ),
              ),
            ),
          ),
        );
      }
    }

    // Draw colored paths to home
    cells.addAll(_buildHomePaths(cellSize));

    return cells;
  }

  List<Widget> _buildHomePaths(double cellSize) {
    final paths = <Widget>[];

    // Red home path (row 7, cols 1-5)
    for (int i = 0; i < 5; i++) {
      paths.add(_buildHomePathCell(7, 1 + i, cellSize, _playerColors[0]));
    }
    // Green home path (col 7, rows 1-5)
    for (int i = 0; i < 5; i++) {
      paths.add(_buildHomePathCell(1 + i, 7, cellSize, _playerColors[1]));
    }
    // Yellow home path (row 7, cols 13-9)
    for (int i = 0; i < 5; i++) {
      paths.add(_buildHomePathCell(7, 13 - i, cellSize, _playerColors[2]));
    }
    // Blue home path (col 7, rows 13-9)
    for (int i = 0; i < 5; i++) {
      paths.add(_buildHomePathCell(13 - i, 7, cellSize, _playerColors[3]));
    }

    return paths;
  }

  Widget _buildHomePathCell(int row, int col, double cellSize, Color color) {
    return Positioned(
      left: col * cellSize,
      top: row * cellSize,
      width: cellSize,
      height: cellSize,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.4),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
      ),
    );
  }

  int? _getBoardPosition(int row, int col) {
    // Simplified position mapping
    // Returns null for non-track cells
    // Returns position index (0-51) for main track
    // Returns 100+ for home run positions

    // Main track positions would be mapped here
    // This is a simplified version
    return null;
  }

  List<Widget> _buildTokens(double cellSize) {
    final tokens = <Widget>[];

    for (int playerIndex = 0; playerIndex < 4; playerIndex++) {
      for (int tokenIndex = 0; tokenIndex < 4; tokenIndex++) {
        final position = _tokenPositions[playerIndex][tokenIndex];
        Offset? offset;

        if (position == -1) {
          // In base - position in the home area
          offset = _getBasePosition(playerIndex, tokenIndex, cellSize);
        } else if (position >= 0 && position < 52) {
          // On main track
          offset = _getTrackPosition(playerIndex, position, cellSize);
        } else if (position >= 51 && position < 57) {
          // In home run
          offset = _getHomeRunPosition(playerIndex, position, cellSize);
        }

        if (offset != null) {
          tokens.add(
            Positioned(
              left: offset.dx,
              top: offset.dy,
              child: _buildToken(
                playerIndex,
                tokenIndex,
                cellSize,
                position >= 57, // is finished
              ),
            ),
          );
        }
      }
    }

    return tokens;
  }

  Offset _getBasePosition(int playerIndex, int tokenIndex, double cellSize) {
    // Calculate position within the 6x6 home base
    double baseRow, baseCol;

    switch (playerIndex) {
      case 0: // Red (top-left)
        baseRow = 1 + (tokenIndex ~/ 2) * 2;
        baseCol = 1 + (tokenIndex % 2) * 2;
        break;
      case 1: // Green (top-right)
        baseRow = 1 + (tokenIndex ~/ 2) * 2;
        baseCol = 9 + (tokenIndex % 2) * 2;
        break;
      case 2: // Yellow (bottom-left)
        baseRow = 9 + (tokenIndex ~/ 2) * 2;
        baseCol = 1 + (tokenIndex % 2) * 2;
        break;
      case 3: // Blue (bottom-right)
      default:
        baseRow = 9 + (tokenIndex ~/ 2) * 2;
        baseCol = 9 + (tokenIndex % 2) * 2;
        break;
    }

    return Offset(baseCol * cellSize + cellSize * 0.15, baseRow * cellSize + cellSize * 0.15);
  }

  Offset _getTrackPosition(int playerIndex, int progressionIndex, double cellSize) {
    // Calculate physical position on the track
    // Uses 1D coordinate system: physicalPos = (entryOffset + progressionIndex) % 52
    final physicalPos = (_entryOffsets[playerIndex] + progressionIndex) % 52;

    // Map physical position to (row, col) on the 15x15 grid
    final trackCoords = _getTrackCoordinates(physicalPos);
    return Offset(
      trackCoords.$2 * cellSize + cellSize * 0.25,
      trackCoords.$1 * cellSize + cellSize * 0.25,
    );
  }

  (int, int) _getTrackCoordinates(int physicalPos) {
    // Map the 52-square perimeter to grid coordinates
    // This is a simplified mapping
    if (physicalPos < 6) {
      return (6, physicalPos + 6);
    } else if (physicalPos < 12) {
      return (6 - (physicalPos - 6), 8);
    } else if (physicalPos < 13) {
      return (0, 8 - (physicalPos - 11));
    }
    // ... continue for all 52 positions
    return (7, 7); // center as fallback
  }

  Offset _getHomeRunPosition(int playerIndex, int homeRunIndex, double cellSize) {
    // Position in the final stretch to home
    final homeRunPos = homeRunIndex - 51; // 0-5 range

    switch (playerIndex) {
      case 0: // Red - horizontal from left
        return Offset((1 + homeRunPos) * cellSize + cellSize * 0.25, 7 * cellSize + cellSize * 0.25);
      case 1: // Green - vertical from top
        return Offset(7 * cellSize + cellSize * 0.25, (1 + homeRunPos) * cellSize + cellSize * 0.25);
      case 2: // Yellow - horizontal from right
        return Offset((13 - homeRunPos) * cellSize + cellSize * 0.25, 7 * cellSize + cellSize * 0.25);
      case 3: // Blue - vertical from bottom
      default:
        return Offset(7 * cellSize + cellSize * 0.25, (13 - homeRunPos) * cellSize + cellSize * 0.25);
    }
  }

  Widget _buildToken(int playerIndex, int tokenIndex, double cellSize, bool isFinished) {
    final isSelected = _selectedToken == '$playerIndex-$tokenIndex';
    final isCurrentPlayer = playerIndex == _currentPlayerIndex;
    final canMove = isCurrentPlayer && _currentDiceValue > 0 && !isFinished;

    return GestureDetector(
      onTap: canMove ? () => _selectToken(playerIndex, tokenIndex) : null,
      child: Container(
        width: cellSize * 0.5,
        height: cellSize * 0.5,
        decoration: BoxDecoration(
          color: _playerColors[playerIndex],
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? const Color(FlickoColors.neonGreen)
                : Colors.white.withValues(alpha: 0.8),
            width: isSelected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: isFinished
            ? const Icon(Icons.star, color: Colors.white, size: 16)
            : Center(
                child: Text(
                  '${tokenIndex + 1}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }

  List<Widget> _buildHomeBases(double cellSize) {
    return [
      // Center home (finish area)
      Positioned(
        left: 6 * cellSize,
        top: 6 * cellSize,
        width: 3 * cellSize,
        height: 3 * cellSize,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _playerColors[0],
                _playerColors[1],
                _playerColors[2],
                _playerColors[3],
              ],
            ),
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.home, color: Colors.white, size: 20),
                Text(
                  'HOME',
                  style: GoogleFonts.spaceMono(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ];
  }

  Widget _buildDicePanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(FlickoColors.bgSecondary),
        border: Border(
          top: BorderSide(color: const Color(FlickoColors.bgTertiary)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dice
          GestureDetector(
            onTap: _canRollDice() ? _rollDice : null,
            child: AnimatedBuilder(
              animation: _diceAnimController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _diceRotation.value,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _isRolling
                        ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(FlickoColors.blurple),
                              strokeWidth: 3,
                            ),
                          )
                        : _buildDiceFace(_currentDiceValue),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 24),
          // Roll button / Status
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _currentDiceValue > 0
                    ? 'Rolled: $_currentDiceValue'
                    : 'Tap to roll',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textPrimary),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _getTurnHint(),
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDiceFace(int value) {
    final dots = _getDiceDots(value);
    return Padding(
      padding: const EdgeInsets.all(12),
      child: GridView.count(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        children: List.generate(9, (index) {
          return Container(
            decoration: BoxDecoration(
              color: dots.contains(index) ? const Color(FlickoColors.bgPrimary) : Colors.transparent,
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }

  List<int> _getDiceDots(int value) {
    switch (value) {
      case 1:
        return [4];
      case 2:
        return [0, 8];
      case 3:
        return [0, 4, 8];
      case 4:
        return [0, 2, 6, 8];
      case 5:
        return [0, 2, 4, 6, 8];
      case 6:
        return [0, 2, 3, 5, 6, 8];
      default:
        return [];
    }
  }

  bool _canRollDice() {
    return !_isRolling && _currentDiceValue == 0;
  }

  String _getTurnHint() {
    if (_isRolling) return 'Rolling...';
    if (_currentDiceValue == 0) return '${_playerNames[_currentPlayerIndex]}\'s turn';
    if (_selectedToken != null) return 'Tap destination or cancel';
    return 'Select a token to move';
  }

  void _rollDice() {
    if (!_canRollDice()) return;

    setState(() => _isRolling = true);
    _diceAnimController.forward(from: 0);

    // Simulate dice roll (in production, this comes from backend via crypto/rand)
    Future.delayed(const Duration(milliseconds: 500), () {
      final roll = DateTime.now().millisecondsSinceEpoch % 6 + 1;
      setState(() {
        _currentDiceValue = roll;
        _isRolling = false;
      });
    });
  }

  void _selectToken(int playerIndex, int tokenIndex) {
    if (playerIndex != _currentPlayerIndex || _currentDiceValue == 0) return;

    setState(() {
      _selectedToken = '$playerIndex-$tokenIndex';
    });

    // Attempt move
    _attemptMove(playerIndex, tokenIndex);
  }

  void _attemptMove(int playerIndex, int tokenIndex) {
    final currentPos = _tokenPositions[playerIndex][tokenIndex];
    int newPos;

    if (currentPos == -1) {
      // In base - need 6 to exit
      if (_currentDiceValue == 6) {
        newPos = 0;
      } else {
        _showInvalidMoveSnackbar('Need a 6 to exit base!');
        setState(() => _selectedToken = null);
        return;
      }
    } else {
      newPos = currentPos + _currentDiceValue;
      if (newPos > 57) {
        _showInvalidMoveSnackbar('Move exceeds home limit!');
        setState(() => _selectedToken = null);
        return;
      }
    }

    // Apply move
    setState(() {
      _tokenPositions[playerIndex][tokenIndex] = newPos;
      _selectedToken = null;
      _currentDiceValue = 0;
    });

    // Check for win
    if (_tokenPositions[playerIndex].every((p) => p >= 57)) {
      _showWinDialog(playerIndex);
    } else {
      // Next turn (or same player if rolled 6)
      if (_currentDiceValue != 6) {
        setState(() {
          _currentPlayerIndex = (_currentPlayerIndex + 1) % 4;
        });
      }
    }
  }

  void _showInvalidMoveSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(FlickoColors.danger),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showWinDialog(int playerIndex) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(FlickoColors.bgSecondary),
        title: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _playerColors[playerIndex],
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '${_playerNames[playerIndex]} Wins!',
              style: GoogleFonts.inter(
                color: _playerColors[playerIndex],
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        content: Text(
          'All tokens reached home. Congratulations!',
          style: GoogleFonts.inter(color: const Color(FlickoColors.textSecondary)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(
              'Exit',
              style: GoogleFonts.inter(color: const Color(FlickoColors.blurple)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _resetGame();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _playerColors[playerIndex],
            ),
            child: const Text('Play Again'),
          ),
        ],
      ),
    );
  }

  void _resetGame() {
    setState(() {
      for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
          _tokenPositions[i][j] = -1;
        }
      }
      _currentPlayerIndex = 0;
      _currentDiceValue = 0;
      _selectedToken = null;
    });
  }

  void _showRules() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(FlickoColors.bgSecondary),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LUDO RULES',
              style: GoogleFonts.epilogue(
                color: const Color(FlickoColors.textPrimary),
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            _buildRuleItem('Roll a 6 to move a token out of base'),
            _buildRuleItem('Rolling a 6 grants another turn'),
            _buildRuleItem('Land on an opponent to send them back to base'),
            _buildRuleItem('Safe squares (stars) protect from capture'),
            _buildRuleItem('First player to get all 4 tokens home wins'),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Color(FlickoColors.neonGreen), size: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: const Color(FlickoColors.textSecondary),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
