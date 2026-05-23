import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/equipment_service.dart';

class AvatarDecorationDefinition {
  final String id;
  final String name;
  final String slug;
  final Color primaryColor;
  final Color secondaryColor;
  final bool isAnimated;

  const AvatarDecorationDefinition({
    required this.id,
    required this.name,
    required this.slug,
    required this.primaryColor,
    required this.secondaryColor,
    this.isAnimated = true,
  });
}

class BuiltInDecorations {
  static const neonCyber = AvatarDecorationDefinition(
    id: 'neon-cyber-frame',
    name: 'Neon Cyber Frame',
    slug: 'neon-cyber-frame',
    primaryColor: Color(0xFF52B788),
    secondaryColor: Color(0xFF00E5FF),
    isAnimated: true,
  );

  static const glitchMatrix = AvatarDecorationDefinition(
    id: 'glitch-matrix-frame',
    name: 'Glitch Matrix Frame',
    slug: 'glitch-matrix-frame',
    primaryColor: Color(0xFF00FF66),
    secondaryColor: Color(0xFFFF007F),
    isAnimated: true,
  );

  static const cosmicOrbit = AvatarDecorationDefinition(
    id: 'cosmic-orbit-frame',
    name: 'Cosmic Orbit Frame',
    slug: 'cosmic-orbit-frame',
    primaryColor: Color(0xFF9B84EE),
    secondaryColor: Color(0xFF00E5FF),
    isAnimated: true,
  );

  static const fireRing = AvatarDecorationDefinition(
    id: 'fire-ring-frame',
    name: 'Fire Aura Frame',
    slug: 'fire-ring-frame',
    primaryColor: Color(0xFFFAA61A),
    secondaryColor: Color(0xFFED4245),
    isAnimated: true,
  );

  static const rainbowPulse = AvatarDecorationDefinition(
    id: 'rainbow-pulse-frame',
    name: 'Rainbow Pulse Frame',
    slug: 'rainbow-pulse-frame',
    primaryColor: Color(0xFFFF007F),
    secondaryColor: Color(0xFF00FF66),
    isAnimated: true,
  );

  static const all = [neonCyber, glitchMatrix, cosmicOrbit, fireRing, rainbowPulse];

  static AvatarDecorationDefinition? getById(String id) {
    try {
      return all.firstWhere((d) => d.id == id);
    } catch (_) {
      // Direct string mapping fallback for core/legacy values in UserAvatar
      if (id == 'neon-ring' || id == 'glow-fx') return neonCyber;
      if (id == 'gold-ring') return fireRing;
      if (id == 'purple-ring') return cosmicOrbit;
      return null;
    }
  }
}

final equippedDecorationProvider = FutureProvider<AvatarDecorationDefinition?>((ref) async {
  final equippedAsync = ref.watch(equippedItemsProvider);

  return equippedAsync.when(
    data: (equipped) {
      final item = equipped['avatar_decoration'] ?? equipped['decoration'];
      if (item != null) {
        return BuiltInDecorations.getById(item.productId);
      }
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
