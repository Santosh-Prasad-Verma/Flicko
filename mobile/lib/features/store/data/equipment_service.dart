import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'dart:developer' as dev;

/// Represents an equipped item
class EquippedItem {
  final String id;
  final String productId;
  final String productName;
  final String productType;
  final String? imageUrl;
  final DateTime equippedAt;

  EquippedItem({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productType,
    this.imageUrl,
    required this.equippedAt,
  });

  factory EquippedItem.fromJson(Map<String, dynamic> json) {
    return EquippedItem(
      id: json['id'] as String,
      productId: json['cosmetic_id'] as String,
      productName: json['cosmetic']?['name'] as String? ?? 'Unknown',
      productType: json['cosmetic']?['cosmetic_type'] as String? ?? 'theme',
      imageUrl: json['cosmetic']?['asset_url'] as String?,
      equippedAt: DateTime.parse(json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
    );
  }
}

/// Service for managing equipped items
final equipmentServiceProvider = Provider<EquipmentService>((ref) {
  return EquipmentService(Supabase.instance.client);
});

/// Provider for currently equipped items
final equippedItemsProvider = FutureProvider<Map<String, EquippedItem>>((ref) async {
  final service = ref.watch(equipmentServiceProvider);
  return service.getEquippedItems();
});

/// Provider for user's inventory (all owned items)
final inventoryProvider = FutureProvider<List<UserPurchase>>((ref) async {
  final service = ref.watch(equipmentServiceProvider);
  return service.getInventory();
});

class EquipmentService {
  final SupabaseClient _client;

  EquipmentService(this._client);

  /// Get all equipped items grouped by type
  Future<Map<String, EquippedItem>> getEquippedItems() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return {};

      final response = await _client
          .from('user_cosmetics')
          .select('''
            id,
            cosmetic_id,
            is_equipped,
            updated_at,
            cosmetic:cosmetic_catalog (
              id,
              name,
              cosmetic_type,
              asset_url
            )
          ''')
          .eq('user_id', user.id)
          .eq('is_equipped', true);

      final items = <String, EquippedItem>{};
      for (final json in response as List) {
        final item = EquippedItem.fromJson(json);
        items[item.productType] = item;
      }

      return items;
    } catch (e) {
      dev.log('[EQUIPMENT] Error getting equipped items: $e');
      return {};
    }
  }

  /// Get user's full inventory
  Future<List<UserPurchase>> getInventory() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final response = await _client
          .from('user_cosmetics')
          .select('''
            id,
            cosmetic_id,
            unlocked_at,
            source,
            is_equipped,
            cosmetic:cosmetic_catalog (
              id,
              name,
              cosmetic_type,
              asset_url
            )
          ''')
          .eq('user_id', user.id)
          .order('unlocked_at', ascending: false);

      return (response as List).map((j) => UserPurchase.fromJson(j)).toList();
    } catch (e) {
      dev.log('[EQUIPMENT] Error getting inventory: $e');
      return [];
    }
  }

  /// Equip an item
  Future<bool> equipItem(String productId, String productType) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      // First unequip any existing item of the same type
      await _client
          .from('user_cosmetics')
          .update({'is_equipped': false})
          .eq('user_id', user.id)
          .eq('is_equipped', true);

      // Then equip the new item
      await _client
          .from('user_cosmetics')
          .update({'is_equipped': true})
          .eq('user_id', user.id)
          .eq('cosmetic_id', productId);

      return true;
    } catch (e) {
      dev.log('[EQUIPMENT] Error equipping item: $e');
      return false;
    }
  }

  /// Unequip an item
  Future<bool> unequipItem(String productId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      await _client
          .from('user_cosmetics')
          .update({'is_equipped': false})
          .eq('user_id', user.id)
          .eq('cosmetic_id', productId);

      return true;
    } catch (e) {
      dev.log('[EQUIPMENT] Error unequipping item: $e');
      return false;
    }
  }

  /// Check if a specific item is equipped
  Future<bool> isItemEquipped(String productId) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      final response = await _client
          .from('user_cosmetics')
          .select('is_equipped')
          .eq('user_id', user.id)
          .eq('cosmetic_id', productId)
          .maybeSingle();

      return response?['is_equipped'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get equipped theme ID
  String? getEquippedThemeId(Map<String, EquippedItem> equipped) {
    return equipped['avatar_decoration']?.productId ??
           equipped['theme']?.productId;
  }

  /// Get equipped badge ID
  String? getEquippedBadgeId(Map<String, EquippedItem> equipped) {
    return equipped['nameplate']?.productId ??
           equipped['badge']?.productId;
  }

  /// Get equipped sound pack ID
  String? getEquippedSoundId(Map<String, EquippedItem> equipped) {
    return equipped['sounds']?.productId ??
           equipped['sound_pack']?.productId;
  }

  /// Get equipped sticker pack ID
  String? getEquippedStickerId(Map<String, EquippedItem> equipped) {
    return equipped['stickers']?.productId ??
           equipped['sticker_pack']?.productId;
  }
}
