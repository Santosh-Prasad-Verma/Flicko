import 'package:flutter/material.dart';

/// Ludo player palette. Same hex values as the RN port (`COLORS`).
abstract class LudoColors {
  static const red = Color(0xFFD5151D); // player 1
  static const green = Color(0xFF00A049); // player 2
  static const yellow = Color(0xFFFFDE17); // player 3
  static const blue = Color(0xFF28AEFF); // player 4
  static const white = Color(0xFFFFFFFF);
  static const grey = Color(0xFF808080);
  static const border = Color(0xFFEEEEEE);
  static const transparent = Color(0x00000000);
}

/// Returns the player's primary colour for [playerNo] (1..4).
Color colorForPlayer(int playerNo) => switch (playerNo) {
      1 => LudoColors.red,
      2 => LudoColors.green,
      3 => LudoColors.yellow,
      _ => LudoColors.blue,
    };

/// Returns the player number (1..4) given a piece id like "A1".
int playerForPieceId(String id) => switch (id[0]) {
      'A' => 1,
      'B' => 2,
      'C' => 3,
      _ => 4,
    };

String pileAssetForPlayer(int playerNo) => switch (playerNo) {
      1 => 'assets/ludo/images/piles/red.png',
      2 => 'assets/ludo/images/piles/green.png',
      3 => 'assets/ludo/images/piles/yellow.png',
      _ => 'assets/ludo/images/piles/blue.png',
    };

String diceAsset(int n) => 'assets/ludo/images/dice/$n.png';
