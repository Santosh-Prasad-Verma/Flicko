import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

import '../../domain/ludo_state.dart';

/// Matchmaking placeholder. In production this would post to the backend
/// (which already has matchmaking infrastructure under
/// /api/v1/gaming/matchmaking) and listen on a Centrifugo channel for an
/// `opponent_found` event. Until that wire is hooked up here we simulate the
/// flow with a 5–10s timer that falls back to bots.
class LudoMatchmakingScreen extends ConsumerStatefulWidget {
  const LudoMatchmakingScreen({
    super.key,
    required this.players,
    this.team = false,
  });

  final int players;
  final bool team;

  @override
  ConsumerState<LudoMatchmakingScreen> createState() =>
      _LudoMatchmakingScreenState();
}

class _LudoMatchmakingScreenState
    extends ConsumerState<LudoMatchmakingScreen> {
  Timer? _timer;
  int _elapsed = 0;
  bool _connecting = true;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _elapsed += 1);
      if (_elapsed >= 8) {
        t.cancel();
        _onMatchFound();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _onMatchFound() {
    setState(() => _connecting = false);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      // Build seats: first seat is the local player, fill the rest with
      // remote (or bots after timeout). For now we treat the rest as bots.
      // Standard 2v2 pairing: red+yellow (seats 0,2) vs green+blue (seats 1,3).
      LudoTeam? teamFor(int i) {
        if (!widget.team) return null;
        return i.isEven ? LudoTeam.a : LudoTeam.b;
      }

      final seats = <SeatConfig>[
        SeatConfig(
            kind: SeatKind.human, displayName: 'You', team: teamFor(0)),
        for (int i = 1; i < widget.players; i++)
          SeatConfig(
              kind: SeatKind.bot,
              displayName: 'Online ${i + 1}',
              team: teamFor(i)),
      ];
      // 4-player layouts always need 4 seats so the board renders correctly.
      while (seats.length < 4) {
        seats.add(SeatConfig(
          kind: SeatKind.bot,
          displayName: 'CPU',
          team: teamFor(seats.length),
        ));
      }
      context.pushReplacement(
        '/ludo/play?mode=onlineRandom',
        extra: seats,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A0A),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        color: Colors.white),
                    onPressed: () => context.pop(),
                  ),
                  const Spacer(),
                  Text(
                    widget.team
                        ? 'TEAM MATCH'
                        : '${widget.players}P MATCH',
                    style: GoogleFonts.orbitron(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Center(
                child: SizedBox(
                  width: 220,
                  height: 220,
                  child: Lottie.asset(
                    'assets/ludo/animations/diceroll.json',
                    errorBuilder: (_, __, ___) => CircleAvatar(
                      radius: 80,
                      backgroundColor: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                      child: const Icon(Icons.sports_esports_rounded,
                          size: 60, color: Colors.white),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  _connecting ? 'Finding players…' : 'Match Found!',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _connecting
                      ? '$_elapsed seconds'
                      : 'Loading board…',
                  style: GoogleFonts.inter(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
              ),
              const Spacer(),
              if (_connecting)
                Center(
                  child: TextButton(
                    onPressed: () => context.pop(),
                    child: Text(
                      'CANCEL',
                      style: GoogleFonts.orbitron(
                        color: const Color(0xFFC0392B),
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
