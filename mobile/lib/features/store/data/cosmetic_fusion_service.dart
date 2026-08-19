import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/equipment_service.dart';
import 'dart:developer' as dev;
import 'package:mobile/features/store/data/badge_alchemy_service.dart';

class CosmeticFusionState {
  final List<UserPurchase> selectedItems;
  final String status; // idle, fusing, success, error
  final StoreProduct? reward;
  final String? errorMessage;

  const CosmeticFusionState({
    this.selectedItems = const [],
    this.status = 'idle',
    this.reward,
    this.errorMessage,
  });

  CosmeticFusionState copyWith({
    List<UserPurchase>? selectedItems,
    String? status,
    StoreProduct? reward,
    String? errorMessage,
  }) {
    return CosmeticFusionState(
      selectedItems: selectedItems ?? this.selectedItems,
      status: status ?? this.status,
      reward: reward ?? this.reward,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final cosmeticFusionProvider = NotifierProvider<CosmeticFusionNotifier, CosmeticFusionState>(CosmeticFusionNotifier.new);

class CosmeticFusionNotifier extends Notifier<CosmeticFusionState> {
  @override
  CosmeticFusionState build() => const CosmeticFusionState();

  Future<void> selectItem(UserPurchase item) async {
    if (state.status == 'fusing') return;

    final isSelected = state.selectedItems.any((x) => x.id == item.id);
    if (isSelected) {
      // Remove it
      state = state.copyWith(
        selectedItems: state.selectedItems.where((x) => x.id != item.id).toList(),
        status: 'idle',
        errorMessage: null,
      );
      return;
    }

    if (state.selectedItems.length >= 3) {
      state = state.copyWith(errorMessage: 'REACTOR_CAPACITY_REACHED: ONLY 3 SLOTS AVAILABLE!');
      return;
    }

    // Check if equipped (protected)
    final equippedMap = await ref.read(equippedItemsProvider.future);
    final isEquipped = equippedMap.values.any((e) => e.productId == item.productId);
    if (isEquipped) {
      state = state.copyWith(errorMessage: 'REACTOR_ERROR: EQUIPPED ITEM IS PROTECTED!');
      return;
    }

    // Load full catalog to inspect rarities
    final storeService = ref.read(storeServiceProvider);
    final allProducts = await storeService.getProducts();

    final itemProduct = _findProduct(allProducts, item.productId);
    if (itemProduct == null) {
      state = state.copyWith(errorMessage: 'REACTOR_ERROR: COULD NOT FIND COSMETIC METADATA!');
      return;
    }

    if (state.selectedItems.isNotEmpty) {
      // Check if new item matches the rarity of first item
      final firstItem = state.selectedItems.first;
      final firstProduct = _findProduct(allProducts, firstItem.productId);
      
      if (firstProduct != null && firstProduct.rarity.toLowerCase() != itemProduct.rarity.toLowerCase()) {
        state = state.copyWith(errorMessage: 'REACTOR_ERROR: ALL ITEMS MUST SHARE THE SAME RARITY!');
        return;
      }
    }

    state = state.copyWith(
      selectedItems: [...state.selectedItems, item],
      status: 'idle',
      errorMessage: null,
    );
  }

  void clearReactor() {
    if (state.status == 'fusing') return;
    state = const CosmeticFusionState();
  }

  bool get canFuse => state.selectedItems.length == 3;

  Future<void> executeFusion() async {
    if (!canFuse || state.status == 'fusing') return;

    state = state.copyWith(status: 'fusing', errorMessage: null);

    try {
      final storeService = ref.read(storeServiceProvider);
      final allProducts = await storeService.getProducts();

      // Determine Rarity & Upgrade tier
      final firstProduct = _findProduct(allProducts, state.selectedItems.first.productId);
      if (firstProduct == null) throw Exception('Reactor failed to resolve loaded item rarity.');

      final currentRarity = firstProduct.rarity.toLowerCase();
      String upgradeRarity;
      if (currentRarity == 'common') {
        upgradeRarity = 'rare';
      } else if (currentRarity == 'rare') {
        upgradeRarity = 'epic';
      } else if (currentRarity == 'epic') {
        upgradeRarity = 'legendary';
      } else {
        // Legendary fusion yields the ultra exclusive Cosmic Overlord Badge!
        upgradeRarity = 'legendary';
      }

      StoreProduct rewardProduct;

      if (currentRarity == 'legendary') {
        // Yield special Cosmic Overlord Badge
        rewardProduct = StoreProduct(
          id: 'cosmic-overlord-badge',
          slug: 'cosmic-overlord-badge',
          name: 'Cosmic Overlord Badge',
          type: 'BADGE',
          price: 99.99,
          rarity: 'legendary',
          imageUrl: null,
          description: 'An elite mythic badge forged inside the Cosmic Fusion Chamber. Emitted only to Legendary Masters.',
        );
      } else {
        // Select random candidate of upgraded rarity
        final candidates = allProducts.where((p) => p.rarity.toLowerCase() == upgradeRarity.toLowerCase()).toList();
        if (candidates.isEmpty) throw Exception('No products found matching upgrade tier $upgradeRarity.');

        // Select one the user doesn't already own, if possible
        final inventory = await ref.read(inventoryProvider.future);
        final ownedIds = inventory.map((p) => p.productId).toSet();
        var unowned = candidates.where((p) => !ownedIds.contains(p.id)).toList();
        if (unowned.isEmpty) {
          unowned = candidates; // Fallback if they own all
        }

        final random = math.Random();
        rewardProduct = unowned[random.nextInt(unowned.length)];
      }

      // Deduct fused items & Add reward item locally
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('local_user_purchases');
      if (data != null) {
        final list = jsonDecode(data) as List;
        final selectedIds = state.selectedItems.map((x) => x.id).toSet();
        final selectedProductIds = state.selectedItems.map((x) => x.productId).toList();

        // 1. Remove exactly the 3 fused items by local ID
        final updatedList = list.where((item) {
          final itemId = item['id'] as String;
          return !selectedIds.contains(itemId);
        }).toList();

        // 2. Add reward purchase
        final rewardPurchase = {
          'id': 'fusion_${rewardProduct.id}_${DateTime.now().millisecondsSinceEpoch}',
          'productId': rewardProduct.id,
          'productName': rewardProduct.name,
          'productType': rewardProduct.type,
          'purchasedAt': DateTime.now().toIso8601String(),
          'price': rewardProduct.price,
          'imageUrl': rewardProduct.imageUrl,
        };
        updatedList.add(rewardPurchase);
        await prefs.setString('local_user_purchases', jsonEncode(updatedList));

        // Sync with Supabase if logged in
        final client = Supabase.instance.client;
        final user = client.auth.currentUser;
        if (user != null) {
          try {
            // Delete fused cosmetics
            await client
                .from('user_cosmetics')
                .delete()
                .eq('user_id', user.id)
                .inFilter('cosmetic_id', selectedProductIds);

            // Insert reward cosmetic
            await client.from('user_cosmetics').insert({
              'user_id': user.id,
              'cosmetic_id': rewardProduct.id,
              'unlocked_at': DateTime.now().toIso8601String(),
              'is_equipped': false,
            });
          } catch (e) {
            dev.log('[FUSION_SYNC] Error syncing fusion with DB: $e');
          }
        }
      }

      // Wait a moment for dynamic animation simulation
      await Future.delayed(const Duration(milliseconds: 1800));

      state = state.copyWith(
        status: 'success',
        reward: rewardProduct,
      );

      // Increment alchemy stat
      ref.read(badgeAlchemyProvider.notifier).incrementCosmeticsFused();

      // Invalidate providers to force UI refresh
      ref.invalidate(inventoryProvider);
      ref.invalidate(userPurchasesProvider);
      ref.invalidate(equippedItemsProvider);

    } catch (e) {
      state = state.copyWith(
        status: 'error',
        errorMessage: 'REACTOR_CRITICAL: ${e.toString().toUpperCase()}',
      );
    }
  }

  StoreProduct? _findProduct(List<StoreProduct> products, String productId) {
    try {
      return products.firstWhere((p) => p.id == productId);
    } catch (_) {
      return null;
    }
  }
}
