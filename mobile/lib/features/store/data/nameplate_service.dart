import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/equipment_service.dart';

class NameplateDefinition {
  final String id;
  final String name;
  final String slug;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isAnimated;

  const NameplateDefinition({
    required this.id,
    required this.name,
    required this.slug,
    required this.primaryColor,
    required this.secondaryColor,
    this.isAnimated = true,
  });
}

class BuiltInNameplates {
  static const glitchMatrix = NameplateDefinition(
    id: 'glitch-matrix-tag',
    name: 'Glitch Matrix Tag',
    slug: 'glitch-matrix-tag',
    primaryColor: Color(0xFF00FF66),
    secondaryColor: Color(0xFFFF007F),
    isAnimated: true,
  );

  static const neonCyber = NameplateDefinition(
    id: 'neon-cyber-tag',
    name: 'Neon Cyber Tag',
    slug: 'neon-cyber-tag',
    primaryColor: Color(0xFF52B788),
    secondaryColor: Color(0xFF00E5FF),
    isAnimated: true,
  );

  static const firePulse = NameplateDefinition(
    id: 'fire-pulse-tag',
    name: 'Fire Aura Tag',
    slug: 'fire-pulse-tag',
    primaryColor: Color(0xFFFAA61A),
    secondaryColor: Color(0xFFED4245),
    isAnimated: true,
  );

  static const goldSpark = NameplateDefinition(
    id: 'gold-spark-tag',
    name: 'Gold Specular Tag',
    slug: 'gold-spark-tag',
    primaryColor: Color(0xFFFFD700),
    secondaryColor: Color(0xFFFFA500),
    isAnimated: true,
  );

  static const rainbowDrip = NameplateDefinition(
    id: 'rainbow-drip-tag',
    name: 'Rainbow Drip Tag',
    slug: 'rainbow-drip-tag',
    primaryColor: Color(0xFFFF007F),
    secondaryColor: Color(0xFF00FF66),
    isAnimated: true,
  );

  static const all = [glitchMatrix, neonCyber, firePulse, goldSpark, rainbowDrip];

  static NameplateDefinition? getById(String id) {
    try {
      return all.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }
}

final equippedNameplateProvider = FutureProvider<NameplateDefinition?>((ref) async {
  final equippedAsync = ref.watch(equippedItemsProvider);

  return equippedAsync.when(
    data: (equipped) {
      // Check both case variations for robust type safety
      final item = equipped['NAMEPLATE'] ?? equipped['nameplate'] ?? equipped['Nameplate'];
      if (item != null) {
        return BuiltInNameplates.getById(item.productId);
      }
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
