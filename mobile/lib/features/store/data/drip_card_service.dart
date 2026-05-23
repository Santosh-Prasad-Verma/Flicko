import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/equipment_service.dart';

class DripCardDefinition {
  final String id;
  final String name;
  final String slug;
  final Color primaryColor;
  final Color secondaryColor;
  final double borderWidth;
  final bool isAnimated;

  const DripCardDefinition({
    required this.id,
    required this.name,
    required this.slug,
    required this.primaryColor,
    required this.secondaryColor,
    this.borderWidth = 2.0,
    this.isAnimated = true,
  });
}

class BuiltInDripCards {
  static const toxicHazard = DripCardDefinition(
    id: 'toxic-hazard-card',
    name: 'Toxic Hazard Card',
    slug: 'toxic-hazard-card',
    primaryColor: Color(0xFF00FF66),
    secondaryColor: Color(0xFFFAA61A),
    borderWidth: 2.0,
  );

  static const cyberGlitch = DripCardDefinition(
    id: 'cyber-glitch-card',
    name: 'Cyber Glitch Card',
    slug: 'cyber-glitch-card',
    primaryColor: Color(0xFFFF007F),
    secondaryColor: Color(0xFF00E5FF),
    borderWidth: 2.5,
  );

  static const specularGold = DripCardDefinition(
    id: 'specular-gold-card',
    name: 'Gold Metal Card',
    slug: 'specular-gold-card',
    primaryColor: Color(0xFFFFD700),
    secondaryColor: Color(0xFFFFA500),
    borderWidth: 3.0,
  );

  static const all = [toxicHazard, cyberGlitch, specularGold];

  static DripCardDefinition? getById(String id) {
    try {
      return all.firstWhere((d) => d.id == id);
    } catch (_) {
      return null;
    }
  }
}

final equippedDripCardProvider = FutureProvider<DripCardDefinition?>((ref) async {
  final equippedAsync = ref.watch(equippedItemsProvider);

  return equippedAsync.when(
    data: (equipped) {
      final item = equipped['DRIP_CARD'] ?? equipped['drip_card'] ?? equipped['DripCard'];
      if (item != null) {
        return BuiltInDripCards.getById(item.productId);
      }
      return null;
    },
    loading: () => null,
    error: (_, __) => null,
  );
});
