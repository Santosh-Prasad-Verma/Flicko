import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/ludo_state.dart';
import '../../services/ludo_sound_service.dart';
import '../widgets/ludo_colors.dart';

/// Lobby for the Ludo feature. Lets the user pick mode: local pass-and-play,
/// vs bots, online random match, or invite friends.
class LudoHomeScreen extends ConsumerStatefulWidget {
  const LudoHomeScreen({super.key});

  @override
  ConsumerState<LudoHomeScreen> createState() => _LudoHomeScreenState();
}

class _LudoHomeScreenState extends ConsumerState<LudoHomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      LudoSoundService.instance.play('home');
    });
  }

  @override
  void dispose() {
    LudoSoundService.instance.stopBgm();
    super.dispose();
  }

  void _start(LudoMode mode, List<SeatConfig> seats, {String? gameId}) {
    Navigator.of(context).pop();
    context.push(
      Uri(
        path: '/ludo/play',
        queryParameters: {
          'mode': mode.name,
          if (gameId != null) 'gameId': gameId,
        },
      ).toString(),
      extra: seats,
    );
  }

  /// Generates a private match id, copies the deep link, opens the share
  /// sheet, and routes the host into the board. Joiners follow the same
  /// `/ludo/play?gameId=<id>` route via GoRouter.
  Future<void> _inviteFriends() async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    final gameId =
        List.generate(8, (_) => chars[rng.nextInt(chars.length)]).join();
    final link = 'https://flicko.app/ludo/play?gameId=$gameId';

    await Clipboard.setData(ClipboardData(text: link));

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2D0E0E),
        content: Text('Invite link copied — game id $gameId',
            style: GoogleFonts.inter(color: Colors.white)),
        duration: const Duration(seconds: 2),
      ),
    );

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Join me on Flicko Ludo: $link',
          subject: 'Flicko Ludo invite',
        ),
      );
    } catch (_) {
      // Sharing is best-effort; the link is already on the clipboard.
    }

    if (!mounted) return;
    _start(
      LudoMode.onlineFriends,
      const [
        SeatConfig(kind: SeatKind.human, displayName: 'You'),
        SeatConfig(kind: SeatKind.remote, displayName: 'Friend 1'),
        SeatConfig(kind: SeatKind.remote, displayName: 'Friend 2'),
        SeatConfig(kind: SeatKind.remote, displayName: 'Friend 3'),
      ],
      gameId: gameId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A0A0A),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: -100,
              right: -80,
              child: _ambient(280, const Color(0xFFC0392B), 0.18),
            ),
            Positioned(
              bottom: -60,
              left: -60,
              child: _ambient(220, const Color(0xFF8B5CF6), 0.16),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: Colors.white),
                        onPressed: () => context.canPop()
                            ? context.pop()
                            : Navigator.maybePop(context),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          LudoSoundService.instance.muted
                              ? Icons.volume_off_rounded
                              : Icons.volume_up_rounded,
                          color: Colors.white70,
                        ),
                        tooltip: 'Mute/Unmute',
                        onPressed: () {
                          setState(() {
                            LudoSoundService.instance.setMuted(!LudoSoundService.instance.muted);
                            if (!LudoSoundService.instance.muted) {
                              LudoSoundService.instance.play('home');
                            }
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.leaderboard_rounded,
                            color: Colors.white70),
                        tooltip: 'Leaderboard',
                        onPressed: () => context.push('/ludo/leaderboard'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _logo(),
                  const SizedBox(height: 28),
                  Text(
                    'CHOOSE YOUR\nGAME MODE',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _modeCard(
                          icon: Icons.sports_esports_rounded,
                          title: 'PLAY ONLINE',
                          subtitle:
                              'Random opponents · matchmaking · ranked games',
                          gradient: const [
                            Color(0xFFC0392B),
                            Color(0xFF8B5CF6),
                          ],
                          onTap: () => _showOnlineSheet(),
                        ),
                        const SizedBox(height: 12),
                        _modeCard(
                          icon: Icons.smart_toy_rounded,
                          title: 'VS COMPUTER',
                          subtitle: 'Pick how many bots you face (1-3)',
                          gradient: const [
                            Color(0xFF8B5CF6),
                            Color(0xFF1E5162),
                          ],
                          onTap: () => _showBotSheet(),
                        ),
                        const SizedBox(height: 12),
                        _modeCard(
                          icon: Icons.group_rounded,
                          title: 'PASS & PLAY',
                          subtitle: '2-4 players, one device',
                          gradient: const [
                            Color(0xFF1E5162),
                            Color(0xFF00A049),
                          ],
                          onTap: () => _showLocalSheet(),
                        ),
                        const SizedBox(height: 12),
                        _modeCard(
                          icon: Icons.link_rounded,
                          title: 'INVITE FRIENDS',
                          subtitle: 'Generate a private match link',
                          gradient: const [
                            Color(0xFFF0C040),
                            Color(0xFFC0392B),
                          ],
                          onTap: _inviteFriends,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLocalSheet() => _showSeatPicker(
        title: 'Pass & Play',
        builder: (count) => List.generate(
          4,
          (i) => i < count
              ? SeatConfig(
                  kind: SeatKind.human, displayName: 'Player ${i + 1}')
              : const SeatConfig(kind: SeatKind.bot, displayName: 'CPU'),
        ),
        onPick: (count) => _start(
          LudoMode.localPass,
          List.generate(
            4,
            (i) => i < count
                ? SeatConfig(
                    kind: SeatKind.human, displayName: 'Player ${i + 1}')
                : const SeatConfig(kind: SeatKind.bot, displayName: 'CPU'),
          ),
        ),
      );

  void _showBotSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A0A0A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        var bots = 1;
        var difficulty = BotDifficulty.medium;
        return StatefulBuilder(builder: (ctx, setLocal) {
          Widget chip(String label, bool selected, VoidCallback onTap) =>
              ChoiceChip(
                label: Text(label),
                selected: selected,
                onSelected: (_) => onTap(),
                selectedColor: const Color(0xFFC0392B),
                backgroundColor: const Color(0xFF2D0E0E),
                labelStyle: const TextStyle(color: Colors.white),
              );

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('VS COMPUTER',
                    style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18)),
                const SizedBox(height: 16),
                Text('Bots',
                    style: GoogleFonts.inter(
                        color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(spacing: 10, children: [
                  for (var n = 1; n <= 3; n++)
                    chip('$n', bots == n,
                        () => setLocal(() => bots = n)),
                ]),
                const SizedBox(height: 16),
                Text('Difficulty',
                    style: GoogleFonts.inter(
                        color: Colors.white60, fontSize: 13)),
                const SizedBox(height: 8),
                Wrap(spacing: 10, children: [
                  chip('Easy', difficulty == BotDifficulty.easy,
                      () => setLocal(() => difficulty = BotDifficulty.easy)),
                  chip(
                      'Medium',
                      difficulty == BotDifficulty.medium,
                      () => setLocal(() => difficulty = BotDifficulty.medium)),
                  chip('Hard', difficulty == BotDifficulty.hard,
                      () => setLocal(() => difficulty = BotDifficulty.hard)),
                ]),
                const SizedBox(height: 20),
                _modeCard(
                  icon: Icons.play_arrow_rounded,
                  title: 'START',
                  subtitle:
                      '$bots ${bots == 1 ? 'bot' : 'bots'} · ${difficulty.name}',
                  gradient: const [Color(0xFFC0392B), Color(0xFF8B5CF6)],
                  onTap: () {
                    Navigator.pop(ctx);
                    _start(
                      LudoMode.vsBot,
                      [
                        const SeatConfig(
                            kind: SeatKind.human, displayName: 'You'),
                        for (var i = 1; i <= 3; i++)
                          SeatConfig(
                            kind: SeatKind.bot,
                            displayName: 'CPU $i',
                            difficulty: difficulty,
                          ),
                      ].sublist(0, bots + 1),
                    );
                  },
                ),
              ],
            ),
          );
        });
      },
    );
  }

  void _showOnlineSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A0A0A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PLAY ONLINE',
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Look for a random match. We\'ll fill empty seats with bots after 30s.',
                style: GoogleFonts.inter(color: Colors.white60, fontSize: 13),
              ),
              const SizedBox(height: 20),
              _modeCard(
                icon: Icons.search_rounded,
                title: 'QUICK MATCH (1v1)',
                subtitle: 'First-come matchmaking',
                gradient: const [Color(0xFFC0392B), Color(0xFF8B5CF6)],
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/ludo/matchmaking?players=2');
                },
              ),
              const SizedBox(height: 12),
              _modeCard(
                icon: Icons.groups_rounded,
                title: 'TEAM MATCH (2v2)',
                subtitle: 'Red+Yellow vs Green+Blue',
                gradient: const [Color(0xFF8B5CF6), Color(0xFF1E5162)],
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/ludo/matchmaking?players=4&team=true');
                },
              ),
              const SizedBox(height: 12),
              _modeCard(
                icon: Icons.public_rounded,
                title: 'FREE-FOR-ALL (4P)',
                subtitle: '4-player ranked free-for-all',
                gradient: const [Color(0xFF1E5162), Color(0xFF00A049)],
                onTap: () {
                  Navigator.pop(ctx);
                  context.push('/ludo/matchmaking?players=4');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showSeatPicker({
    required String title,
    required List<SeatConfig> Function(int count) builder,
    required void Function(int count) onPick,
    String opponentLabel = 'players',
  }) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1A0A0A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        int selected = 2;
        return StatefulBuilder(builder: (ctx, setLocal) {
          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.toUpperCase(),
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'How many $opponentLabel?',
                  style:
                      GoogleFonts.inter(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  children: [
                    for (int n = 1; n <= 3; n++)
                      ChoiceChip(
                        label: Text('$n'),
                        selected: selected == n + 1,
                        onSelected: (_) => setLocal(() => selected = n + 1),
                        selectedColor: const Color(0xFFC0392B),
                        backgroundColor: const Color(0xFF2D0E0E),
                        labelStyle:
                            const TextStyle(color: Colors.white),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                _modeCard(
                  icon: Icons.play_arrow_rounded,
                  title: 'START',
                  subtitle: '$selected players',
                  gradient: const [Color(0xFFC0392B), Color(0xFF8B5CF6)],
                  onTap: () {
                    Navigator.pop(ctx);
                    onPick(selected);
                  },
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Widget _modeCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.3),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _logo() {
    return Center(
      child: Image.asset(
        'assets/ludo/images/logo.png',
        height: 110,
        errorBuilder: (_, __, ___) => Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [
                LudoColors.red,
                LudoColors.green,
                LudoColors.yellow,
                LudoColors.blue,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC0392B).withValues(alpha: 0.5),
                blurRadius: 24,
              ),
            ],
          ),
          alignment: Alignment.center,
          child: Text(
            'LUDO',
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  Widget _ambient(double size, Color color, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [color.withValues(alpha: alpha), Colors.transparent],
          ),
        ),
      );
}
