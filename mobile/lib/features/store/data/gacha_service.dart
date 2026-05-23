import 'dart:math' as math;
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/equipment_service.dart';
import 'dart:developer' as dev;

class GachaState {
  final List<UserPurchase> ownedCrates;
  final String status; // idle, unboxing, success, error
  final StoreProduct? reward;
  final bool isDuplicate;
  final String? errorMessage;

  const GachaState({
    this.ownedCrates = const [],
    this.status = 'idle',
    this.reward,
    this.isDuplicate = false,
    this.errorMessage,
  });

  GachaState copyWith({
    List<UserPurchase>? ownedCrates,
    String? status,
    StoreProduct? reward,
    bool? isDuplicate,
    String? errorMessage,
  }) {
    return GachaState(
      ownedCrates: ownedCrates ?? this.ownedCrates,
      status: status ?? this.status,
      reward: reward ?? this.reward,
      isDuplicate: isDuplicate ?? this.isDuplicate,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final gachaProvider = NotifierProvider<GachaNotifier, GachaState>(GachaNotifier.new);

class GachaNotifier extends Notifier<GachaState> {
  @override
  GachaState build() {
    // Load crates on start
    Future.microtask(() => loadOwnedCrates());
    return const GachaState();
  }

  Future<void> loadOwnedCrates() async {
    try {
      final storeService = ref.read(storeServiceProvider);
      final purchases = await storeService.getUserPurchases();
      final crates = purchases.where((p) => 
        p.productId == 'mystery-crate' || 
        p.productType.toUpperCase() == 'CRATE'
      ).toList();

      state = state.copyWith(ownedCrates: crates);
    } catch (e) {
      dev.log('[GACHA_LOAD] Error loading owned crates: $e');
    }
  }

  Future<void> executeUnboxing() async {
    if (state.ownedCrates.isEmpty || state.status == 'unboxing') return;

    final consumedCrate = state.ownedCrates.first;
    state = state.copyWith(status: 'unboxing', errorMessage: null, isDuplicate: false);

    try {
      final storeService = ref.read(storeServiceProvider);

      // Check duplicates BEFORE adding the reward
      final inventory = await ref.read(inventoryProvider.future);
      final ownedProductIds = inventory.map((p) => p.productId).toSet();

      // Draw random reward product
      final rewardProduct = storeService.getRandomGachaReward();
      final isDuplicate = ownedProductIds.contains(rewardProduct.id);

      // 1. Consume crate from SharedPreferences locally
      final prefs = await SharedPreferences.getInstance();
      final localData = prefs.getString('local_user_purchases');
      if (localData != null) {
        final list = jsonDecode(localData) as List;
        
        // Remove exactly the first consumed crate item by local purchase ID
        bool removed = false;
        final updatedList = list.where((item) {
          final itemId = item['id'] as String;
          if (!removed && itemId == consumedCrate.id) {
            removed = true;
            return false;
          }
          return true;
        }).toList();

        // 2. Add reward purchase locally
        final rewardPurchase = {
          'id': 'gacha_${rewardProduct.id}_${DateTime.now().millisecondsSinceEpoch}',
          'productId': rewardProduct.id,
          'productName': rewardProduct.name,
          'productType': rewardProduct.type,
          'purchasedAt': DateTime.now().toIso8601String(),
          'price': rewardProduct.price,
          'imageUrl': rewardProduct.imageUrl,
        };
        updatedList.add(rewardPurchase);
        await prefs.setString('local_user_purchases', jsonEncode(updatedList));
      }

      // 3. Sync with Supabase if logged in
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user != null) {
        try {
          // Delete one owned crate item
          // Since there's no unique local purchase ID column in DB, we select one record and delete by id
          final crateRecord = await client
              .from('user_cosmetics')
              .select('id')
              .eq('user_id', user.id)
              .eq('cosmetic_id', consumedCrate.productId)
              .limit(1)
              .maybeSingle();

          if (crateRecord != null) {
            final recordId = crateRecord['id'];
            await client.from('user_cosmetics').delete().eq('id', recordId);
          }

          // Insert reward cosmetic
          await client.from('user_cosmetics').insert({
            'user_id': user.id,
            'cosmetic_id': rewardProduct.id,
            'unlocked_at': DateTime.now().toIso8601String(),
            'is_equipped': false,
          });
        } catch (e) {
          dev.log('[GACHA_SYNC] DB Sync error: $e');
        }
      }

      // Delay to let unboxing turntable spin animation run fully (we'll coordinate with UI screen)
      await Future.delayed(const Duration(milliseconds: 2500));

      // Reload owned crates list
      final updatedPurchases = await storeService.getUserPurchases();
      final updatedCrates = updatedPurchases.where((p) => 
        p.productId == 'mystery-crate' || 
        p.productType.toUpperCase() == 'CRATE'
      ).toList();

      state = state.copyWith(
        status: 'success',
        reward: rewardProduct,
        isDuplicate: isDuplicate,
        ownedCrates: updatedCrates,
      );

      // Force Riverpod inventory and equipment sync
      ref.invalidate(inventoryProvider);
      ref.invalidate(userPurchasesProvider);
      ref.invalidate(equippedItemsProvider);

    } catch (e) {
      state = state.copyWith(
        status: 'error',
        errorMessage: 'TURNTABLE_CRITICAL: ${e.toString().toUpperCase()}',
      );
    }
  }

  void reset() {
    if (state.status == 'unboxing') return;
    state = state.copyWith(status: 'idle', reward: null, isDuplicate: false, errorMessage: null);
    loadOwnedCrates();
  }
}
