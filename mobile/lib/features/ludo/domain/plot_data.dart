// Board layout constants — ported verbatim from
// react-native-ludo-game/src/helpers/PlotData.ts
//
// The board is a 15×15 grid composed of 4 corner pockets, 4 paths, and a
// centre 4-triangle. Cells along the perimeter are numbered 1..52, the home
// stretches use 111..115, 221..225, 331..335, 441..445, and `0` represents
// the in-pocket (un-released) state.

const List<int> plot1Data = [
  13, 14, 15, 16, 17, 18, 12, 221, 222, 223, 224, 224, 11, 10, 9, 8, 7, 6,
];

const List<int> plot2Data = [
  24, 25, 26, 23, 331, 27, 22, 332, 28, 21, 333, 29, 20, 334, 30, 19, 335, 31,
];

const List<int> plot3Data = [
  32, 33, 34, 35, 36, 37, 445, 444, 443, 442, 441, 38, 44, 43, 42, 41, 40, 39,
];

const List<int> plot4Data = [
  5, 115, 45, 4, 114, 46, 3, 113, 47, 2, 112, 48, 1, 111, 49, 52, 51, 50,
];

/// Cells on which a piece cannot be captured.
const Set<int> safeSpots = {
  111, 112, 113, 114, 115,
  221, 222, 223, 224, 225,
  331, 332, 333, 334, 335,
  441, 442, 443, 444, 445,
  1, 14, 27, 40,
};

/// Cells decorated with a star icon (also safe).
const Set<int> starSpots = {9, 22, 35, 48};

/// Cells decorated with a directional arrow.
const Set<int> arrowSpots = {12, 51, 38, 25};

/// First track cell each player enters when leaving their pocket.
/// 1-indexed by player number (player 1 → startingPoints[0]).
const List<int> startingPoints = [1, 14, 27, 40];

/// Cell at which each player turns into their home stretch.
const List<int> turningPoints = [52, 13, 26, 39];

/// First cell of each player's home stretch.
const List<int> victoryStart = [111, 221, 331, 441];

/// Number of moves required to reach home from the pocket exit.
/// (52 perimeter cells skipped after the player's start + 5 home-stretch cells.)
const int travelToHome = 57;

/// Pure helper: advance a piece by [diceNo] steps and return the resulting
/// position + travel count, applying the same turning-point and 53→1
/// wrap-around rules the engine uses internally.
///
/// Used by the engine in [LudoNotifier.handleForward] and the bot in
/// [LudoBotBrain] so they cannot drift apart.
({int pos, int travelCount}) advancePiece({
  required int playerNo,
  required int fromPos,
  required int fromTravel,
  required int diceNo,
}) {
  var pos = fromPos;
  var travel = fromTravel;
  for (var i = 0; i < diceNo; i++) {
    pos += 1;
    travel += 1;
    if (pos == turningPoints[playerNo - 1]) {
      pos = victoryStart[playerNo - 1];
    }
    if (pos == 53) pos = 1;
    if (travel >= travelToHome) break;
  }
  return (pos: pos, travelCount: travel);
}
