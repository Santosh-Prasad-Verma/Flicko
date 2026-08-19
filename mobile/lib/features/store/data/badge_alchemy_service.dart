import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile/data/clients/supabase_client.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/equipment_service.dart';
import 'package:mobile/features/store/data/badge_service.dart';
import 'dart:developer' as dev;

class BadgeAchievement {
  final String id;
  final String title;
  final String description;
  final String badgeId;
  final int targetCount;
  final String statistic; // 'messages', 'sounds', 'fusions', 'crates', 'syntheses'

  const BadgeAchievement({
    required this.id,
    required this.title,
    required this.description,
    required this.badgeId,
    required this.targetCount,
    required this.statistic,
  });
}

class BadgeAlchemyState {
  final int messagesSent;
  final int soundsPlayed;
  final int cosmeticsFused;
  final int cratesOpened;
  final int badgeSyntheses;
  final Set<String> claimedAchievements;
  final List<UserPurchase> selectedBadges;
  final String status; // 'idle', 'synthesizing', 'success', 'error'
  final BadgeDefinition? reward;
  final String? errorMessage;

  const BadgeAlchemyState({
    this.messagesSent = 0,
    this.soundsPlayed = 0,
    this.cosmeticsFused = 0,
    this.cratesOpened = 0,
    this.badgeSyntheses = 0,
    this.claimedAchievements = const {},
    this.selectedBadges = const [],
    this.status = 'idle',
    this.reward,
    this.errorMessage,
  });

  BadgeAlchemyState copyWith({
    int? messagesSent,
    int? soundsPlayed,
    int? cosmeticsFused,
    int? cratesOpened,
    int? badgeSyntheses,
    Set<String>? claimedAchievements,
    List<UserPurchase>? selectedBadges,
    String? status,
    BadgeDefinition? reward,
    String? errorMessage,
  }) {
    return BadgeAlchemyState(
      messagesSent: messagesSent ?? this.messagesSent,
      soundsPlayed: soundsPlayed ?? this.soundsPlayed,
      cosmeticsFused: cosmeticsFused ?? this.cosmeticsFused,
      cratesOpened: cratesOpened ?? this.cratesOpened,
      badgeSyntheses: badgeSyntheses ?? this.badgeSyntheses,
      claimedAchievements: claimedAchievements ?? this.claimedAchievements,
      selectedBadges: selectedBadges ?? this.selectedBadges,
      status: status ?? this.status,
      reward: reward ?? this.reward,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final badgeAlchemyProvider = NotifierProvider<BadgeAlchemyNotifier, BadgeAlchemyState>(BadgeAlchemyNotifier.new);

class BadgeAlchemyNotifier extends Notifier<BadgeAlchemyState> {
  static const achievements = [
    BadgeAchievement(
      id: 'chat-veteran',
      title: 'Spam Bot',
      description: 'Send 50 Chat Messages',
      badgeId: 'chat-veteran-badge',
      targetCount: 50,
      statistic: 'messages',
    ),
    BadgeAchievement(
      id: 'soundboard-dj',
      title: 'Frequency DJ',
      description: 'Play 10 Soundboard Effects',
      badgeId: 'soundboard-dj',
      targetCount: 10,
      statistic: 'sounds',
    ),
    BadgeAchievement(
      id: 'reactor-melt',
      title: 'Reactor Melt',
      description: 'Perform 3 Cosmetic Fusions',
      badgeId: 'bolt-master',
      targetCount: 3,
      statistic: 'fusions',
    ),
    BadgeAchievement(
      id: 'gacha-addict',
      title: 'Gacha Addict',
      description: 'Open 5 Mystery Vinyl Crates',
      badgeId: 'diamond-elite',
      targetCount: 5,
      statistic: 'crates',
    ),
    BadgeAchievement(
      id: 'gold-transmutation',
      title: 'Gold Transmutation',
      description: 'Perform 1 Badge Alchemy Synthesis',
      badgeId: 'alchemist-badge',
      targetCount: 1,
      statistic: 'syntheses',
    ),
  ];

  @override
  BadgeAlchemyState build() {
    _loadState();
    return const BadgeAlchemyState();
  }

  Future<void> _loadState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final messages = prefs.getInt('alchemy_stat_messages') ?? 0;
      final sounds = prefs.getInt('alchemy_stat_sounds') ?? 0;
      final fusions = prefs.getInt('alchemy_stat_fusions') ?? 0;
      final crates = prefs.getInt('alchemy_stat_crates') ?? 0;
      final syntheses = prefs.getInt('alchemy_stat_syntheses') ?? 0;
      final claimedList = prefs.getStringList('alchemy_claimed_achievements') ?? [];

      state = state.copyWith(
        messagesSent: messages,
        soundsPlayed: sounds,
        cosmeticsFused: fusions,
        cratesOpened: crates,
        badgeSyntheses: syntheses,
        claimedAchievements: claimedList.toSet(),
      );
    } catch (_) {}
  }

  Future<void> _saveStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('alchemy_stat_messages', state.messagesSent);
      await prefs.setInt('alchemy_stat_sounds', state.soundsPlayed);
      await prefs.setInt('alchemy_stat_fusions', state.cosmeticsFused);
      await prefs.setInt('alchemy_stat_crates', state.cratesOpened);
      await prefs.setInt('alchemy_stat_syntheses', state.badgeSyntheses);
      await prefs.setStringList('alchemy_claimed_achievements', state.claimedAchievements.toList());
    } catch (_) {}
  }

  // Increment statistics
  void incrementMessagesSent() {
    state = state.copyWith(messagesSent: state.messagesSent + 1);
    _saveStats();
  }

  void incrementSoundsPlayed() {
    state = state.copyWith(soundsPlayed: state.soundsPlayed + 1);
    _saveStats();
  }

  void incrementCosmeticsFused() {
    state = state.copyWith(cosmeticsFused: state.cosmeticsFused + 1);
    _saveStats();
  }

  void incrementCratesOpened() {
    state = state.copyWith(cratesOpened: state.cratesOpened + 1);
    _saveStats();
  }

  void incrementBadgeSyntheses() {
    state = state.copyWith(badgeSyntheses: state.badgeSyntheses + 1);
    _saveStats();
  }

  // Claim achievement reward badge
  Future<bool> claimAchievement(String id) async {
    if (state.claimedAchievements.contains(id)) return false;

    final achievement = achievements.firstWhere((x) => x.id == id);
    final count = _getStatForStatistic(achievement.statistic);

    if (count < achievement.targetCount) return false;

    // Load badge details
    final badge = BuiltInBadges.getById(achievement.badgeId);
    if (badge == null) return false;

    // Grant badge to local purchases
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('local_user_purchases');
    final purchases = data != null ? jsonDecode(data) as List : [];
    
    // Check if they already own it
    final ownsBadge = purchases.any((x) => x['productId'] == badge.id);
    if (!ownsBadge) {
      final reward = {
        'id': 'achievement_${badge.id}_${DateTime.now().millisecondsSinceEpoch}',
        'productId': badge.id,
        'productName': badge.name,
        'productType': 'BADGE',
        'purchasedAt': DateTime.now().toIso8601String(),
        'price': 0.0,
      };
      purchases.add(reward);
      await prefs.setString('local_user_purchases', jsonEncode(purchases));
    }

    // Sync to Supabase
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user != null) {
      try {
        await client.from('user_cosmetics').insert({
          'user_id': user.id,
          'cosmetic_id': badge.id,
          'source': 'achievement',
          'unlocked_at': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        dev.log('[ALCH_ACH] Supabase sync error: $e');
      }
    }

    // Mark as claimed
    final updatedClaimed = {...state.claimedAchievements, id};
    state = state.copyWith(claimedAchievements: updatedClaimed);
    await _saveStats();

    // Invalidate inventory providers
    ref.invalidate(inventoryProvider);
    ref.invalidate(userPurchasesProvider);

    return true;
  }

  int _getStatForStatistic(String stat) {
    switch (stat) {
      case 'messages':
        return state.messagesSent;
      case 'sounds':
        return state.soundsPlayed;
      case 'fusions':
        return state.cosmeticsFused;
      case 'crates':
        return state.cratesOpened;
      case 'syntheses':
        return state.badgeSyntheses;
      default:
        return 0;
    }
  }

  // Crucible selection logic
  Future<void> selectBadge(UserPurchase badge) async {
    if (state.status == 'synthesizing') return;

    final isSelected = state.selectedBadges.any((x) => x.id == badge.id);
    if (isSelected) {
      state = state.copyWith(
        selectedBadges: state.selectedBadges.where((x) => x.id != badge.id).toList(),
        status: 'idle',
        errorMessage: null,
      );
      return;
    }

    if (state.selectedBadges.length >= 3) {
      state = state.copyWith(errorMessage: 'CRUCIBLE_FULL: CAN ONLY LOAD 3 BADGES!');
      return;
    }

    // Protected equipped check
    final equippedMap = await ref.read(equippedItemsProvider.future);
    final isEquipped = equippedMap.values.any((e) => e.productId == badge.productId);
    if (isEquipped) {
      state = state.copyWith(errorMessage: 'PROTECTION_ACTIVE: EQUIPPED BADGE CANNOT BE RECYCLED!');
      return;
    }

    // Check matching rarity logic
    final catalog = ref.read(storeServiceProvider);
    final allProducts = await catalog.getProducts();
    final badgeProduct = allProducts.firstWhere((p) => p.id == badge.productId, orElse: () => getFallbackBadgeProduct(badge));

    if (state.selectedBadges.isNotEmpty) {
      final first = state.selectedBadges.first;
      final firstProduct = allProducts.firstWhere((p) => p.id == first.productId, orElse: () => getFallbackBadgeProduct(first));
      if (firstProduct.rarity.toLowerCase() != badgeProduct.rarity.toLowerCase()) {
        state = state.copyWith(errorMessage: 'CRUCIBLE_ERROR: BADGES MUST BE OF THE SAME RARITY!');
        return;
      }
    }

    state = state.copyWith(
      selectedBadges: [...state.selectedBadges, badge],
      status: 'idle',
      errorMessage: null,
    );
  }

  void clearCrucible() {
    if (state.status == 'synthesizing') return;
    state = state.copyWith(
      selectedBadges: [],
      status: 'idle',
      reward: null,
      errorMessage: null,
    );
  }

  StoreProduct getFallbackBadgeProduct(UserPurchase purchase) {
    String rarity = 'rare';
    if (purchase.productId == 'og-badge' || purchase.productId == 'verified-plus' || purchase.productId == 'cosmic-overlord-badge' || purchase.productId == 'alchemist-badge') {
      rarity = 'legendary';
    } else if (purchase.productId == 'premium-star' || purchase.productId == 'chat-veteran-badge') {
      rarity = 'epic';
    }
    return StoreProduct(
      id: purchase.productId,
      slug: purchase.productId,
      name: purchase.productName,
      type: 'BADGE',
      price: 0,
      rarity: rarity,
    );
  }

  // Execute Alchemy Synthesis
  Future<void> executeSynthesis() async {
    if (state.selectedBadges.length != 3 || state.status == 'synthesizing') return;

    state = state.copyWith(status: 'synthesizing', errorMessage: null);

    try {
      final catalog = ref.read(storeServiceProvider);
      final allProducts = await catalog.getProducts();

      // Find the loaded badge items
      final firstProduct = allProducts.firstWhere(
        (p) => p.id == state.selectedBadges.first.productId,
        orElse: () => getFallbackBadgeProduct(state.selectedBadges.first),
      );

      final currentRarity = firstProduct.rarity.toLowerCase();
      String nextRarity = 'epic';

      if (currentRarity == 'common' || currentRarity == 'rare') {
        nextRarity = 'epic';
      } else if (currentRarity == 'epic') {
        nextRarity = 'legendary';
      } else {
        // Legendary alchemy yields the legendary alchemist or cosmic overlord badge!
        nextRarity = 'legendary';
      }

      // Gather candidate badges of next rarity tier
      final allBadges = BuiltInBadges.all;
      var candidateBadges = allBadges.where((b) {
        final prod = allProducts.firstWhere((p) => p.id == b.id, orElse: () => StoreProduct(id: b.id, slug: b.id, name: b.name, type: 'BADGE', price: 0, rarity: 'rare'));
        return prod.rarity.toLowerCase() == nextRarity.toLowerCase();
      }).toList();

      if (candidateBadges.isEmpty) {
        candidateBadges = [BuiltInBadges.alchemistBadge, BuiltInBadges.cosmicOverlord];
      }

      // Yield one candidate randomly
      final random = math.Random();
      BadgeDefinition rewardBadge;
      
      if (currentRarity == 'legendary') {
        // Legendary Crucible guaranteed to give alchemist-badge or cosmic-overlord-badge
        final special = [BuiltInBadges.alchemistBadge, BuiltInBadges.cosmicOverlord];
        rewardBadge = special[random.nextInt(special.length)];
      } else {
        rewardBadge = candidateBadges[random.nextInt(candidateBadges.length)];
      }

      // Deduct fused badges from local purchases
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('local_user_purchases');
      if (data != null) {
        final list = jsonDecode(data) as List;
        final selectedIds = state.selectedBadges.map((x) => x.id).toSet();
        final selectedProductIds = state.selectedBadges.map((x) => x.productId).toList();

        // 1. Remove exactly the 3 fused badges by local ID
        final updatedList = list.where((item) {
          final itemId = item['id'] as String;
          return !selectedIds.contains(itemId);
        }).toList();

        // 2. Add reward badge
        final rewardPurchase = {
          'id': 'alchemy_${rewardBadge.id}_${DateTime.now().millisecondsSinceEpoch}',
          'productId': rewardBadge.id,
          'productName': rewardBadge.name,
          'productType': 'BADGE',
          'purchasedAt': DateTime.now().toIso8601String(),
          'price': 0.0,
        };
        updatedList.add(rewardPurchase);
        await prefs.setString('local_user_purchases', jsonEncode(updatedList));

        // Sync with Supabase
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
              'cosmetic_id': rewardBadge.id,
              'unlocked_at': DateTime.now().toIso8601String(),
              'is_equipped': false,
            });
          } catch (e) {
            dev.log('[ALCH_SYNC] Supabase sync error: $e');
          }
        }
      }

      // 1.8 seconds delay for alchemical rune rotation visual effect
      await Future.delayed(const Duration(milliseconds: 1800));

      state = state.copyWith(
        status: 'success',
        reward: rewardBadge,
        badgeSyntheses: state.badgeSyntheses + 1,
      );

      _saveStats();

      // Force refresh of collections & inventory
      ref.invalidate(inventoryProvider);
      ref.invalidate(userPurchasesProvider);
      ref.invalidate(equippedItemsProvider);

    } catch (e) {
      state = state.copyWith(
        status: 'error',
        errorMessage: 'TRANSMUTATION_CRITICAL: ${e.toString().toUpperCase()}',
      );
    }
  }
}
