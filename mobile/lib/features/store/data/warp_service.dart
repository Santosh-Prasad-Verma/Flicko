import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/equipment_service.dart';

class WarpDefinition {
  final String id;
  final String name;
  final String slug;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isAnimated;

  const WarpDefinition({
    required this.id,
    required this.name,
    required this.slug,
    required this.primaryColor,
    required this.secondaryColor,
    this.isAnimated = true,
  });
}

class BuiltInWarps {
  static const cyberMatrix = WarpDefinition(
    id: 'cyber-matrix-warp',
    name: 'Cyber Matrix Warp',
    slug: 'cyber-matrix-warp',
    primaryColor: Color(0xFF00FF66),
    secondaryColor: Color(0xFF003311),
  );

  static const gridExplosion = WarpDefinition(
    id: 'grid-explosion-warp',
    name: 'Grid Expansion Warp',
    slug: 'grid-explosion-warp',
    primaryColor: Color(0xFF00E5FF),
    secondaryColor: Color(0xFFFF007F),
  );

  static const neonRift = WarpDefinition(
    id: 'neon-rift-warp',
    name: 'Neon Rift Warp',
    slug: 'neon-rift-warp',
    primaryColor: Color(0xFFFF007F),
    secondaryColor: Color(0xFF00FF66),
  );

  static const all = [cyberMatrix, gridExplosion, neonRift];

  static WarpDefinition? getById(String id) {
    try {
      return all.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }
}

final equippedWarpProvider = FutureProvider<WarpDefinition?>((ref) async {
  final equippedAsync = ref.watch(equippedItemsProvider);

  return equippedAsync.when(
    data: (equipped) {
      final item = equipped['ENTRANCE_WARP'] ?? equipped['entrance_warp'] ?? equipped['EntranceWarp'];
      if (item != null) {
        return BuiltInWarps.getById(item.productId);
      }
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
