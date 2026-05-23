import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'dart:developer' as dev;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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

  Future<Map<String, EquippedItem>> _loadLocalEquipped() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('local_equipped_items');
      if (data == null) return {};
      final map = jsonDecode(data) as Map<String, dynamic>;
      return map.map((key, value) => MapEntry(
        key,
        EquippedItem(
          id: value['id'] as String,
          productId: value['productId'] as String,
          productName: value['productName'] as String,
          productType: value['productType'] as String,
          imageUrl: value['imageUrl'] as String?,
          equippedAt: DateTime.parse(value['equippedAt'] as String),
        ),
      ));
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveLocalEquipped(Map<String, EquippedItem> equipped) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final map = equipped.map((key, val) => MapEntry(
        key,
        {
          'id': val.id,
          'productId': val.productId,
          'productName': val.productName,
          'productType': val.productType,
          'imageUrl': val.imageUrl,
          'equippedAt': val.equippedAt.toIso8601String(),
        },
      ));
      await prefs.setString('local_equipped_items', jsonEncode(map));
    } catch (_) {}
  }

  Future<List<UserPurchase>> _loadLocalPurchases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('local_user_purchases');
      if (data == null) {
        return [
          UserPurchase(
            id: 'local_midnight_purchase',
            productId: 'midnight',
            productName: 'Midnight',
            productType: 'THEME',
            purchasedAt: DateTime.now(),
            price: 0,
          ),
          UserPurchase(
            id: 'local_sounds_purchase',
            productId: 'myinstants-trending',
            productName: 'Trending Sounds',
            productType: 'SOUNDS',
            purchasedAt: DateTime.now(),
            price: 0,
          )
        ];
      }
      final list = jsonDecode(data) as List;
      return list.map((item) => UserPurchase(
        id: item['id'] as String,
        productId: item['productId'] as String,
        productName: item['productName'] as String,
        productType: item['productType'] as String,
        purchasedAt: DateTime.parse(item['purchasedAt'] as String),
        price: (item['price'] as num).toDouble(),
        imageUrl: item['imageUrl'] as String?,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  /// Get all equipped items grouped by type
  Future<Map<String, EquippedItem>> getEquippedItems() async {
    Map<String, EquippedItem> localEquipped = {};
    try {
      localEquipped = await _loadLocalEquipped();
    } catch (_) {}

    try {
      final user = _client.auth.currentUser;
      if (user == null) return localEquipped;

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

      // Merge with local equipped items (local takes priority in guest/offline)
      for (final key in localEquipped.keys) {
        items[key] = localEquipped[key]!;
      }

      return items;
    } catch (e) {
      dev.log('[EQUIPMENT] Error getting equipped items: $e');
      return localEquipped;
    }
  }

  /// Get user's full inventory
  Future<List<UserPurchase>> getInventory() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        return _loadLocalPurchases();
      }

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

      final supabaseInv = (response as List).map((j) => UserPurchase.fromJson(j)).toList();
      
      // Merge with local purchases
      final localInv = await _loadLocalPurchases();
      final merged = <String, UserPurchase>{};
      for (final p in localInv) {
        merged[p.productId] = p;
      }
      for (final p in supabaseInv) {
        merged[p.productId] = p;
      }
      return merged.values.toList();
    } catch (e) {
      dev.log('[EQUIPMENT] Error getting inventory: $e');
      return _loadLocalPurchases();
    }
  }

  /// Equip an item
  Future<bool> equipItem(String productId, String productType) async {
    final typeKey = productType.toLowerCase();
    
    try {
      final localEquipped = await _loadLocalEquipped();
      final inventory = await _loadLocalPurchases();
      final product = inventory.firstWhere(
        (p) => p.productId == productId,
        orElse: () => UserPurchase(
          id: 'local_$productId',
          productId: productId,
          productName: productId.replaceAll('-', ' ').toUpperCase(),
          productType: productType,
          purchasedAt: DateTime.now(),
          price: 0,
        ),
      );
      
      localEquipped[typeKey] = EquippedItem(
        id: 'local_equipped_$productId',
        productId: productId,
        productName: product.productName,
        productType: typeKey,
        imageUrl: product.imageUrl,
        equippedAt: DateTime.now(),
      );
      await _saveLocalEquipped(localEquipped);
    } catch (_) {}

    try {
      final user = _client.auth.currentUser;
      if (user == null) return true;

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
      return true;
    }
  }

  /// Unequip an item
  Future<bool> unequipItem(String productId) async {
    try {
      final localEquipped = await _loadLocalEquipped();
      localEquipped.removeWhere((key, value) => value.productId == productId);
      await _saveLocalEquipped(localEquipped);
    } catch (_) {}

    try {
      final user = _client.auth.currentUser;
      if (user == null) return true;

      await _client
          .from('user_cosmetics')
          .update({'is_equipped': false})
          .eq('user_id', user.id)
          .eq('cosmetic_id', productId);

      return true;
    } catch (e) {
      dev.log('[EQUIPMENT] Error unequipping item: $e');
      return true;
    }
  }

  /// Check if a specific item is equipped
  Future<bool> isItemEquipped(String productId) async {
    try {
      final local = await _loadLocalEquipped();
      if (local.values.any((item) => item.productId == productId)) {
        return true;
      }
    } catch (_) {}

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
