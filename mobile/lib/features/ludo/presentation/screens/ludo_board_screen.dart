import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../auth/application/auth_notifier.dart';
import '../../domain/ludo_state.dart';
import '../../domain/plot_data.dart';
import '../../services/ludo_bot_brain.dart';
import '../../services/ludo_leaderboard_provider.dart';
import '../../services/ludo_notifier.dart';
import '../../services/ludo_online_sync.dart';
import '../../services/ludo_sound_service.dart';
import '../widgets/dice_widget.dart';
import '../widgets/four_triangle.dart';
import '../widgets/ludo_colors.dart';
import '../widgets/menu_modal.dart';
import '../widgets/path_widgets.dart';
import '../widgets/pocket_widget.dart';
import '../widgets/winner_modal.dart';

class LudoBoardScreen extends ConsumerStatefulWidget {
  const LudoBoardScreen({
    super.key,
    this.mode = LudoMode.localPass,
    this.seats,
    this.gameId,
  });

  final LudoMode mode;
  final List<SeatConfig>? seats;
  final String? gameId;

  @override
  ConsumerState<LudoBoardScreen> createState() => _LudoBoardScreenState();
}

class _LudoBoardScreenState extends ConsumerState<LudoBoardScreen>
    with TickerProviderStateMixin {
  late final AnimationController _startBlink = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 500),
  );
  bool _showStartImage = true;
  late final LudoBotBrain _brain;

  @override
  void initState() {
    super.initState();
    _startBlink.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (!mounted) return;
      _startBlink.stop();
      setState(() => _showStartImage = false);
    });

    // Configure the engine after first frame so the listener attaches.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(ludoNotifierProvider.notifier);
      notifier.configure(
        mode: widget.mode,
        seats: widget.seats ??
            const [
              SeatConfig(kind: SeatKind.human, displayName: 'You'),
              SeatConfig(kind: SeatKind.human, displayName: 'Player 2'),
              SeatConfig(kind: SeatKind.human, displayName: 'Player 3'),
              SeatConfig(kind: SeatKind.human, displayName: 'Player 4'),
            ],
        gameId: widget.gameId,
      );
      _brain = LudoBotBrain(notifier);
      notifier.onBotTurn = _brain.takeTurn;
      LudoSoundService.instance.play('game_start');

      // Online modes: subscribe to authoritative game channel.
      final isOnline = widget.mode == LudoMode.onlineRandom ||
          widget.mode == LudoMode.onlineFriends;
      if (isOnline && widget.gameId != null) {
        ref.read(ludoOnlineSyncProvider(widget.gameId));
      }
    });
  }

  @override
  void dispose() {
    _startBlink.dispose();
    _brain.dispose();
    ref.read(ludoNotifierProvider.notifier).onBotTurn = null;
    super.dispose();
  }

  void _openMenu() {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => MenuModal(onClose: () => Navigator.of(context).pop()),
    );
  }

  /// Best-effort score submission. The local game is authoritative for
  /// offline modes; we just report the result so the leaderboard reflects it.
  /// Online modes will be replaced by an authoritative server result later.
  void _onWinAnnounced(LudoState state) {
    final myUserId = ref.read(currentUserIdProvider);
    if (myUserId == null) return;

    // Map seat index → user id (when known). Bot seats produce synthetic ids
    // so the loser list isn't empty; the backend stores them as informational.
    String idForSeat(int seatIdx) {
      final s = state.seats[seatIdx];
      if (s.userId != null) return s.userId!;
      if (seatIdx == 0) return myUserId;
      return 'bot:${state.gameId ?? 'local'}:$seatIdx';
    }

    final winnerSeatIdx = state.winner! - 1;
    final winnerId = idForSeat(winnerSeatIdx);
    final losers = <String>[
      for (int i = 0; i < state.seats.length; i++)
        if (i != winnerSeatIdx) idForSeat(i),
    ];
    final isBotGame =
        state.seats.any((s) => s.kind == SeatKind.bot) &&
            state.mode != LudoMode.onlineRandom &&
            state.mode != LudoMode.onlineFriends;

    submitLudoScore(
      winnerId: winnerId,
      loserIds: losers,
      isBotGame: isBotGame,
      gameId: state.gameId,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(ludoNotifierProvider);
    // Propagate the OS "reduce motion" preference into the engine so per-cell
    // hops and the dice-roll delay are skipped for screen-reader users.
    ref.read(ludoNotifierProvider.notifier).reducedMotion =
        MediaQuery.disableAnimationsOf(context);

    // Winner modal trigger.
    ref.listen<LudoState>(ludoNotifierProvider, (prev, next) {
      if (next.winner != null && (prev?.winner == null)) {
        _onWinAnnounced(next);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            barrierColor: Colors.black87,
            builder: (_) => WinnerModal(
              winner: next.winner!,
              onExit: () {
                Navigator.of(context).pop();
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
            ),
          );
        });
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFF1E5162),
      body: SafeArea(
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
              child: Column(
                children: [
                  _topDiceRow(state),
                  const SizedBox(height: 8),
                  Expanded(child: _board(state)),
                  const SizedBox(height: 8),
                  _bottomDiceRow(state),
                ],
              ),
            ),
            Positioned(
              top: 12,
              left: 16,
              child: IconButton(
                tooltip: 'Menu',
                icon: const Icon(Icons.menu_rounded,
                    color: LudoColors.white, size: 28),
                onPressed: _openMenu,
              ),
            ),
            Positioned(
              top: 12,
              right: 16,
              child: _ScoreBadge(state: state),
            ),
            if (_showStartImage)
              Positioned.fill(
                child: IgnorePointer(
                  child: FadeTransition(
                    opacity: _startBlink,
                    child: Center(
                      child: Image.asset(
                        'assets/ludo/images/start.png',
                        width: MediaQuery.of(context).size.width * 0.55,
                        errorBuilder: (_, __, ___) => Text(
                          'START!',
                          style: GoogleFonts.orbitron(
                            color: const Color(0xFFFFD700),
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _topDiceRow(LudoState state) {
    return IgnorePointer(
      ignoring: state.touchDiceBlock,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            DiceWidget(
              playerNo: 2,
              color: LudoColors.green,
              pieces: state.player2,
            ),
            DiceWidget(
              playerNo: 3,
              color: LudoColors.yellow,
              pieces: state.player3,
              mirror: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomDiceRow(LudoState state) {
    return IgnorePointer(
      ignoring: state.touchDiceBlock,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            DiceWidget(
              playerNo: 1,
              color: LudoColors.red,
              pieces: state.player1,
            ),
            DiceWidget(
              playerNo: 4,
              color: LudoColors.blue,
              pieces: state.player4,
              mirror: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _board(LudoState state) {
    return Center(
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: LudoColors.white,
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top row: green pocket | vertical path 2 | yellow pocket
              Expanded(
                flex: 6,
                child: Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: PocketWidget(
                        color: LudoColors.green,
                        playerNo: 2,
                        pieces: state.player2,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: VerticalPath(
                          cells: plot2Data, color: LudoColors.yellow),
                    ),
                    Expanded(
                      flex: 6,
                      child: PocketWidget(
                        color: LudoColors.yellow,
                        playerNo: 3,
                        pieces: state.player3,
                      ),
                    ),
                  ],
                ),
              ),
              // Middle row: horizontal path 1 | four-triangle | horizontal path 3
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: HorizontalPath(
                          cells: plot1Data, color: LudoColors.green),
                    ),
                    const Expanded(flex: 3, child: FourTriangle()),
                    Expanded(
                      flex: 6,
                      child: HorizontalPath(
                          cells: plot3Data, color: LudoColors.blue),
                    ),
                  ],
                ),
              ),
              // Bottom row: red pocket | vertical path 4 | blue pocket
              Expanded(
                flex: 6,
                child: Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: PocketWidget(
                        color: LudoColors.red,
                        playerNo: 1,
                        pieces: state.player1,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: VerticalPath(
                          cells: plot4Data, color: LudoColors.red),
                    ),
                    Expanded(
                      flex: 6,
                      child: PocketWidget(
                        color: LudoColors.blue,
                        playerNo: 4,
                        pieces: state.player4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact scoreboard chip — finished pieces per player. Groups by team
/// when the seats are configured as 2v2.
class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.state});
  final LudoState state;

  @override
  Widget build(BuildContext context) {
    int finished(List<PlayerPiece> ps) =>
        ps.where((p) => p.travelCount >= travelToHome).length;

    final isTeamMode = state.seats.any((s) => s.team != null);

    if (isTeamMode) {
      int teamScore(LudoTeam team) {
        var total = 0;
        for (var i = 0; i < state.seats.length; i++) {
          if (state.seats[i].team == team) {
            total += finished(state.piecesFor(i + 1));
          }
        }
        return total;
      }

      final activeTeam = state.seats[state.chancePlayer - 1].team;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _teamChip('A', teamScore(LudoTeam.a), const Color(0xFFC0392B),
                activeTeam == LudoTeam.a),
            const SizedBox(width: 10),
            Text('vs',
                style: GoogleFonts.spaceMono(
                    color: Colors.white60, fontSize: 11)),
            const SizedBox(width: 10),
            _teamChip('B', teamScore(LudoTeam.b), const Color(0xFF8B5CF6),
                activeTeam == LudoTeam.b),
          ],
        ),
      );
    }

    final scores = [
      (1, finished(state.player1), LudoColors.red),
      (2, finished(state.player2), LudoColors.green),
      (3, finished(state.player3), LudoColors.yellow),
      (4, finished(state.player4), LudoColors.blue),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in scores) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: s.$3,
                shape: BoxShape.circle,
                border: Border.all(
                  color: state.chancePlayer == s.$1
                      ? LudoColors.white
                      : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              '${s.$2}/4',
              style: GoogleFonts.spaceMono(
                color: LudoColors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _teamChip(String label, int score, Color color, bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.4) : color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Team $label',
              style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Text('$score/8',
              style: GoogleFonts.spaceMono(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
