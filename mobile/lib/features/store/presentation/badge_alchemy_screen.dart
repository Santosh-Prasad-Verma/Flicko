import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/equipment_service.dart';
import 'package:mobile/features/store/data/badge_service.dart' hide AnimatedBuilder;
import 'package:mobile/features/store/data/badge_alchemy_service.dart';
import 'package:mobile/core/services/flicko_haptics.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';

class BadgeAlchemyScreen extends ConsumerStatefulWidget {
  const BadgeAlchemyScreen({super.key});

  @override
  ConsumerState<BadgeAlchemyScreen> createState() => _BadgeAlchemyScreenState();
}

class _BadgeAlchemyScreenState extends ConsumerState<BadgeAlchemyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const Color _bg = Color(0xFF050505);
  static const Color _cardBg = Color(0xFF0F0F12);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xFF71717A);
  static const Color _lime = Color(0xFF52B788);
  static const Color _gold = Color(0xFFFFD700);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alchemyState = ref.watch(badgeAlchemyProvider);
    final inventoryAsync = ref.watch(inventoryProvider);
    final equippedItemsAsync = ref.watch(equippedItemsProvider);
    final equippedBadge = ref.watch(equippedBadgeProvider).value;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _white),
          onPressed: () {
            context.pop();
          },
        ),
        title: Text(
          'MY BADGES',
          style: GoogleFonts.spaceGrotesk(
            color: _white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 2,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: _lime,
          unselectedLabelColor: _muted,
          indicatorColor: _lime,
          dividerColor: const Color(0xFF141416),
          labelStyle: GoogleFonts.spaceMono(fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 1),
          tabs: const [
            Tab(text: 'SHOWCASE'),
            Tab(text: 'ACHIEVEMENTS'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            // Tab 1: Showcase
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(equippedBadge),
                  const SizedBox(height: 32),
                  Text(
                    'OWNED BADGES',
                    style: GoogleFonts.spaceMono(
                      color: _lime,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  inventoryAsync.when(
                    data: (inv) => equippedItemsAsync.when(
                      data: (equipped) => _buildInventoryGrid(inv, equipped),
                      loading: () => const Center(child: CircularProgressIndicator(color: _lime)),
                      error: (e, _) => Center(child: Text('ERROR: $e', style: const TextStyle(color: Colors.red))),
                    ),
                    loading: () => const Center(child: CircularProgressIndicator(color: _lime)),
                    error: (e, _) => Center(child: Text('ERROR: $e', style: const TextStyle(color: Colors.red))),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
            
            // Tab 2: Achievements
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ACHIEVEMENTS LOG',
                    style: GoogleFonts.spaceMono(
                      color: _lime,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...BadgeAlchemyNotifier.achievements.map(
                    (a) => _buildAchievementItem(a, alchemyState),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(BadgeDefinition? equippedBadge) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(color: Colors.white.withValues(alpha: 0.04), width: 1.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          const UserAvatar(
            size: 60,
            name: 'MEMBER',
            showStatus: false,
            showBadge: true,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EQUIPPED BADGE',
                  style: GoogleFonts.spaceMono(
                    color: _lime,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  equippedBadge != null ? equippedBadge.name.toUpperCase() : 'NO BADGE EQUIPPED',
                  style: GoogleFonts.outfit(
                    color: _white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  equippedBadge != null
                      ? 'This badge is displayed on your system profile.'
                      : 'Tap any owned badge to equip it directly.',
                  style: GoogleFonts.inter(
                    color: _muted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryGrid(List<UserPurchase> inventory, Map<String, EquippedItem> equipped) {
    final badges = inventory.where((p) => p.productType.toUpperCase() == 'BADGE').toList();

    if (badges.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.badge_outlined, color: _muted, size: 40),
            const SizedBox(height: 16),
            Text(
              'NO BADGES OWNED',
              style: GoogleFonts.spaceMono(color: _white, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Text(
              'Complete achievements or check the store to acquire badges.',
              style: GoogleFonts.inter(color: _muted, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.85,
      ),
      itemCount: badges.length,
      itemBuilder: (ctx, idx) {
        final badge = badges[idx];
        final badgeDef = BuiltInBadges.getById(badge.productId);
        final isEquipped = equipped.values.any((e) => e.productId == badge.productId);

        return GestureDetector(
          onTap: () async {
            FlickoHaptics.medium();
            if (isEquipped) {
              await ref.read(equipmentServiceProvider).equipItem('', 'badge');
            } else {
              await ref.read(equipmentServiceProvider).equipItem(badge.productId, 'badge');
            }
            ref.invalidate(equippedItemsProvider);
            ref.invalidate(equippedBadgeProvider);
          },
          child: Container(
            decoration: BoxDecoration(
              color: _cardBg,
              border: Border.all(
                color: isEquipped
                    ? _lime
                    : Colors.white.withValues(alpha: 0.04),
                width: isEquipped ? 2.0 : 1.2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: Icon(
                        badgeDef?.icon ?? Icons.verified,
                        color: badgeDef?.primaryColor ?? _white,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        badge.productName.toUpperCase(),
                        style: GoogleFonts.outfit(
                          color: _white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      badgeDef?.slug.toUpperCase() ?? 'BADGE',
                      style: GoogleFonts.spaceMono(
                        color: _muted,
                        fontSize: 7,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (isEquipped)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: _lime,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAchievementItem(BadgeAchievement achievement, BadgeAlchemyState state) {
    final isClaimed = state.claimedAchievements.contains(achievement.id);
    
    int currentCount = 0;
    switch (achievement.statistic) {
      case 'messages':
        currentCount = state.messagesSent;
        break;
      case 'sounds':
        currentCount = state.soundsPlayed;
        break;
      case 'fusions':
        currentCount = state.cosmeticsFused;
        break;
      case 'crates':
        currentCount = state.cratesOpened;
        break;
      case 'syntheses':
        currentCount = state.badgeSyntheses;
        break;
    }

    final isCompleted = currentCount >= achievement.targetCount;
    final rewardBadge = BuiltInBadges.getById(achievement.badgeId);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardBg,
        border: Border.all(
          color: isClaimed
              ? Colors.white.withValues(alpha: 0.02)
              : isCompleted
                  ? _lime
                  : Colors.white.withValues(alpha: 0.04),
          width: isCompleted && !isClaimed ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      achievement.title.toUpperCase(),
                      style: GoogleFonts.outfit(
                        color: isClaimed ? _muted : _white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement.description,
                      style: GoogleFonts.inter(
                        color: _muted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (rewardBadge != null)
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: rewardBadge.primaryColor.withValues(alpha: 0.05),
                    border: Border.all(color: rewardBadge.primaryColor.withValues(alpha: 0.2), width: 1.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    rewardBadge.icon,
                    color: rewardBadge.primaryColor,
                    size: 18,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (currentCount / achievement.targetCount).clamp(0.0, 1.0),
                    backgroundColor: Colors.black,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isClaimed
                          ? _muted
                          : isCompleted
                              ? _lime
                              : _gold,
                    ),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$currentCount/${achievement.targetCount}',
                style: GoogleFonts.spaceMono(
                  color: isCompleted ? _lime : _gold,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isClaimed)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: Text(
                'CLAIMED',
                style: GoogleFonts.spaceMono(
                  color: _muted,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else if (isCompleted)
            GestureDetector(
              onTap: () async {
                FlickoHaptics.heavy();
                final success = await ref
                    .read(badgeAlchemyProvider.notifier)
                    .claimAchievement(achievement.id);
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'REWARD UNLOCKED: ${achievement.title.toUpperCase()} BADGE ADDED TO INVENTORY!',
                        style: GoogleFonts.spaceMono(fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                      backgroundColor: _lime,
                    ),
                  );
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _lime,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'CLAIM REWARD',
                    style: GoogleFonts.outfit(
                      color: Colors.black,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              child: Text(
                'IN PROGRESS',
                style: GoogleFonts.spaceMono(
                  color: _muted,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
