import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/features/ludo/domain/plot_data.dart';
import 'package:mobile/features/ludo/services/ludo_notifier.dart';
import 'package:mobile/features/ludo/services/ludo_sound_service.dart';

class _SilentSound extends LudoSoundService {
  _SilentSound() : super.testInstance();
  @override
  Future<void> play(String name) async {}
  @override
  Future<void> stopBgm() async {}
}

LudoNotifier _make({int seed = 1}) {
  return LudoNotifier(sound: _SilentSound(), rng: Random(seed));
}

ProviderContainer _container({int seed = 1}) {
  final notifier = _make(seed: seed);
  return ProviderContainer(overrides: [
    ludoNotifierProvider.overrideWith(() => notifier),
  ]);
}

void main() {
  group('advancePiece', () {
    test('player 1 enters home stretch at turning point 52', () {
      final r = advancePiece(
          playerNo: 1, fromPos: 51, fromTravel: 50, diceNo: 1);
      expect(r.pos, 111);
      expect(r.travelCount, 51);
    });

    test('wraparound from 52 → 1 for player 2', () {
      final r = advancePiece(
          playerNo: 2, fromPos: 51, fromTravel: 38, diceNo: 2);
      // 51 → 52 → 1 (52 is not player 2's turning point, 13 is).
      expect(r.pos, 1);
      expect(r.travelCount, 40);
    });

    test('reaches home in exactly 57 travels', () {
      final r = advancePiece(
          playerNo: 1, fromPos: 114, fromTravel: 56, diceNo: 1);
      expect(r.travelCount, 57);
    });
  });

  group('LudoNotifier', () {
    test('initial state has 4 pieces in pocket per player and player 1 to act',
        () {
      final c = _container();
      addTearDown(c.dispose);
      final s = c.read(ludoNotifierProvider);
      expect(s.player1, hasLength(4));
      expect(s.player1.every((p) => p.pos == 0), isTrue);
      expect(s.chancePlayer, 1);
      expect(s.winner, isNull);
    });

    test('rolling non-6 with all pieces in pocket passes turn', () async {
      final c = _container(seed: 1);
      addTearDown(c.dispose);
      final n = c.read(ludoNotifierProvider.notifier);
      await n.rollDice(forced: 3);
      // Wait for the auto-pass delay (600ms).
      await Future<void>.delayed(const Duration(milliseconds: 700));
      final s = c.read(ludoNotifierProvider);
      expect(s.chancePlayer, 2);
      expect(s.pileSelectionPlayer, -1);
      expect(s.cellSelectionPlayer, -1);
    });

    test('rolling 6 with all pieces in pocket enables pile selection',
        () async {
      final c = _container();
      addTearDown(c.dispose);
      final n = c.read(ludoNotifierProvider.notifier);
      await n.rollDice(forced: 6);
      final s = c.read(ludoNotifierProvider);
      expect(s.diceNo, 6);
      expect(s.pileSelectionPlayer, 1);
      expect(s.chancePlayer, 1);
    });

    test('releaseFromPocket places piece on starting cell', () async {
      final c = _container();
      addTearDown(c.dispose);
      final n = c.read(ludoNotifierProvider.notifier);
      await n.rollDice(forced: 6);
      n.releaseFromPocket(1, 'A1');
      final s = c.read(ludoNotifierProvider);
      final p = s.player1.firstWhere((e) => e.id == 'A1');
      expect(p.pos, startingPoints[0]); // 1
      expect(p.travelCount, 1);
      expect(s.pileSelectionPlayer, -1);
    });

    test('handleForward advances piece by dice and ends turn (non-6)',
        () async {
      final c = _container();
      addTearDown(c.dispose);
      final n = c.read(ludoNotifierProvider.notifier);
      // Bootstrap: release a piece.
      await n.rollDice(forced: 6);
      n.releaseFromPocket(1, 'A1');
      // Roll a 3 and move it.
      await n.rollDice(forced: 3);
      // After enabling cell selection, move the piece by 3.
      await n.handleForward(playerNo: 1, pieceId: 'A1', targetPos: 4);
      final s = c.read(ludoNotifierProvider);
      final p = s.player1.firstWhere((e) => e.id == 'A1');
      expect(p.pos, 4);
      expect(p.travelCount, 4);
      expect(s.chancePlayer, 2);
    });

    test('handleForward keeps the same player\'s turn when dice == 6',
        () async {
      final c = _container();
      addTearDown(c.dispose);
      final n = c.read(ludoNotifierProvider.notifier);
      await n.rollDice(forced: 6);
      n.releaseFromPocket(1, 'A1');
      await n.rollDice(forced: 6);
      await n.handleForward(playerNo: 1, pieceId: 'A1', targetPos: 7);
      final s = c.read(ludoNotifierProvider);
      expect(s.chancePlayer, 1);
    });
  });
}
