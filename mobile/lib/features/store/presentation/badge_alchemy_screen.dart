import 'dart:math' as math;
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

class _BadgeAlchemyScreenState extends ConsumerState<BadgeAlchemyScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  late AnimationController _animationController;

  static const Color _bg = Color(0xFF000000);
  static const Color _white = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xFF71717A);
  static const Color _lime = Color(0xFF52B788);
  static const Color _gold = Color(0xFFFFD700);
  static const Color _magenta = Color(0xFFFF007F);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    _animationController.repeat();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alchemyState = ref.watch(badgeAlchemyProvider);
    final inventoryAsync = ref.watch(inventoryProvider);
    final equippedItemsAsync = ref.watch(equippedItemsProvider);
    final equippedBadge = ref.watch(equippedBadgeProvider).value;

    // Listen for state changes to handle dialogs or errors
    ref.listen(badgeAlchemyProvider, (prev, next) {
      if (next.status == 'success' && next.reward != null) {
        FlickoHaptics.heavy();
        _showTransmutationDialog(context, next.reward!);
      } else if (next.status == 'error' && next.errorMessage != null) {
        FlickoHaptics.medium();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.errorMessage!.toUpperCase()),
            backgroundColor: _magenta,
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _white),
          onPressed: () {
            ref.read(badgeAlchemyProvider.notifier).clearCrucible();
            context.pop();
          },
        ),
        title: Text(
          'BADGE_ALCHEMY',
          style: GoogleFonts.spaceGrotesk(
            color: _white,
            fontWeight: FontWeight.w900,
            fontSize: 18,
            letterSpacing: 2,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: _gold,
          unselectedLabelColor: _muted,
          indicatorColor: _gold,
          dividerColor: const Color(0xFF141416),
          labelStyle: GoogleFonts.spaceMono(fontWeight: FontWeight.bold, fontSize: 12),
          tabs: const [
            Tab(text: 'ALCHEMICAL_CRUCIBLE'),
            Tab(text: 'ACHIEVEMENTS_LOG'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Upper telemetry banner
          _buildAlertTicker(alchemyState),
          
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Crucible
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProfileHeader(equippedBadge),
                      const SizedBox(height: 24),
                      _buildAlchemicalCircle(alchemyState),
                      const SizedBox(height: 24),
                      _buildSlotsRow(alchemyState),
                      const SizedBox(height: 16),
                      _buildCrucibleActions(alchemyState),
                      const SizedBox(height: 24),
                      Text(
                        '[AVAILABLE_BADGES]',
                        style: GoogleFonts.spaceMono(
                          color: _lime,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
                      inventoryAsync.when(
                        data: (inv) => equippedItemsAsync.when(
                          data: (equipped) => _buildInventoryGrid(inv, alchemyState, equipped),
                          loading: () => const Center(child: CircularProgressIndicator(color: _gold)),
                          error: (e, _) => Center(child: Text('ERROR: $e', style: const TextStyle(color: Colors.red))),
                        ),
                        loading: () => const Center(child: CircularProgressIndicator(color: _gold)),
                        error: (e, _) => Center(child: Text('ERROR: $e', style: const TextStyle(color: Colors.red))),
                      ),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
                
                // Tab 2: Achievements
                SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '[ACHIEVEMENTS_CHECKLIST]',
                        style: GoogleFonts.spaceMono(
                          color: _gold,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 12),
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
        ],
      ),
    );
  }

  Widget _buildAlertTicker(BadgeAlchemyState state) {
    Color barColor = _gold;
    String text = 'ALCHEMY_CHAMBER_ONLINE: READY TO TRANSMUTE';

    if (state.status == 'synthesizing') {
      barColor = _magenta;
      text = 'ALCHEMY_ENGAGED: FUSING BADGE ELEMENTS...';
    } else if (state.status == 'success') {
      barColor = _lime;
      text = 'TRANSMUTATION_COMPLETE: REWARD GRANTED!';
    } else if (state.errorMessage != null) {
      barColor = Colors.red;
      text = state.errorMessage!.toUpperCase();
    }

    return Container(
      width: double.infinity,
      color: barColor,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        text,
        style: GoogleFonts.spaceMono(
          color: Colors.black,
          fontWeight: FontWeight.w900,
          fontSize: 10,
          letterSpacing: 1.0,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildProfileHeader(BadgeDefinition? equippedBadge) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C0C0E),
        border: Border.all(color: _muted.withValues(alpha: 0.15), width: 1.5),
      ),
      child: Row(
        children: [
          const UserAvatar(
            size: 64,
            name: 'ALCHEMIST',
            showStatus: false,
            showBadge: true,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ACTIVE_EQUIPPED_DECK',
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
                  style: GoogleFonts.spaceGrotesk(
                    color: _white,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  equippedBadge != null
                      ? 'GLOW & ANIMATIONS ACTIVE FOR "${equippedBadge.slug.toUpperCase()}"'
                      : 'TAP ANY OWNED BADGE TO EQUIP IT DIRECTLY.',
                  style: GoogleFonts.spaceMono(
                    color: _muted,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlchemicalCircle(BadgeAlchemyState state) {
    return Center(
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF070707),
          border: Border.all(color: _gold, width: 2),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _gold.withValues(alpha: 0.15),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            double rot = _animationController.value * 2 * math.pi;
            if (state.status == 'synthesizing') {
              rot = rot * 4;
            }
            final double pulse = 0.5 + 0.5 * math.sin(_animationController.value * 2 * math.pi);

            return CustomPaint(
              painter: AlchemicalCirclePainter(
                rotation: rot,
                pulse: pulse,
                isSynthesizing: state.status == 'synthesizing',
              ),
              child: child,
            );
          },
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.auto_awesome, color: _gold, size: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlotsRow(BadgeAlchemyState state) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(3, (idx) {
        final hasBadge = state.selectedBadges.length > idx;
        final UserPurchase? purchase = hasBadge ? state.selectedBadges[idx] : null;
        final BadgeDefinition? badgeDef = purchase != null ? BuiltInBadges.getById(purchase.productId) : null;

        return GestureDetector(
          onTap: () {
            if (purchase != null) {
              FlickoHaptics.light();
              ref.read(badgeAlchemyProvider.notifier).selectBadge(purchase);
            }
          },
          child: Column(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(
                    color: purchase != null 
                        ? (badgeDef?.primaryColor ?? _lime) 
                        : _muted.withValues(alpha: 0.3),
                    width: purchase != null ? 2.5 : 1.5,
                  ),
                  boxShadow: purchase != null
                      ? [
                          BoxShadow(
                            color: (badgeDef?.primaryColor ?? _lime).withValues(alpha: 0.4),
                            offset: const Offset(3, 3),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: purchase != null
                      ? Icon(
                          badgeDef?.icon ?? Icons.verified,
                          color: badgeDef?.primaryColor ?? _white,
                          size: 32,
                        )
                      : Text(
                          '${idx + 1}',
                          style: GoogleFonts.spaceMono(
                            color: _muted.withValues(alpha: 0.5),
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 80,
                child: Text(
                  purchase != null ? purchase.productName.toUpperCase() : 'EMPTY',
                  style: GoogleFonts.spaceMono(
                    color: purchase != null ? _white : _muted,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildCrucibleActions(BadgeAlchemyState state) {
    final bool canFuse = state.selectedBadges.length == 3;
    final bool isSynthesizing = state.status == 'synthesizing';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: (canFuse && !isSynthesizing)
                      ? () {
                          FlickoHaptics.heavy();
                          ref.read(badgeAlchemyProvider.notifier).executeSynthesis();
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: (canFuse && !isSynthesizing) ? _gold : Colors.black,
                      border: Border.all(
                        color: (canFuse && !isSynthesizing) ? Colors.black : _muted,
                        width: 2.5,
                      ),
                      boxShadow: (canFuse && !isSynthesizing)
                          ? const [
                              BoxShadow(
                                color: _gold,
                                offset: Offset(4, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        isSynthesizing ? 'TRANSMUTING_CORE...' : 'ACTIVATE_ALCHEMY',
                        style: GoogleFonts.spaceMono(
                          color: (canFuse && !isSynthesizing) ? Colors.black : _muted,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          letterSpacing: 2.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              if (state.selectedBadges.isNotEmpty && !isSynthesizing) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    FlickoHaptics.medium();
                    ref.read(badgeAlchemyProvider.notifier).clearCrucible();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      border: Border.all(color: _muted, width: 2.5),
                    ),
                    child: const Icon(Icons.refresh, color: _white, size: 20),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryGrid(List<UserPurchase> inventory, BadgeAlchemyState state, Map<String, EquippedItem> equipped) {
    final badges = inventory.where((p) => p.productType.toUpperCase() == 'BADGE').toList();

    if (badges.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.badge_outlined, color: _muted, size: 48),
              const SizedBox(height: 16),
              Text(
                'NO BADGES OWNED',
                style: GoogleFonts.spaceMono(color: _white, fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Text(
                'CLAIM MILESTONES OR TRANSMUTE COSMETICS TO OBTAIN BASE BADGES.',
                style: GoogleFonts.spaceMono(color: _muted, fontSize: 9, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.85,
      ),
      itemCount: badges.length,
      itemBuilder: (ctx, idx) {
        final badge = badges[idx];
        final badgeDef = BuiltInBadges.getById(badge.productId);
        final isSelected = state.selectedBadges.any((x) => x.id == badge.id);
        final isEquipped = equipped.values.any((e) => e.productId == badge.productId);

        return GestureDetector(
          onTap: () {
            FlickoHaptics.light();
            _showBadgeOptions(badge, equipped);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? _gold.withValues(alpha: 0.1) : Colors.black,
              border: Border.all(
                color: isSelected
                    ? _gold
                    : isEquipped
                        ? _lime
                        : (badgeDef?.primaryColor ?? _muted.withValues(alpha: 0.3)),
                width: isSelected || isEquipped ? 2.5 : 1.5,
              ),
              boxShadow: isSelected || isEquipped
                  ? [
                      BoxShadow(
                        color: isSelected ? _gold.withValues(alpha: 0.4) : _lime.withValues(alpha: 0.4),
                        offset: const Offset(3, 3),
                      )
                    ]
                  : null,
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
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        badge.productName.toUpperCase(),
                        style: GoogleFonts.spaceMono(
                          color: _white,
                          fontSize: 8,
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
                        fontSize: 6,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                if (isEquipped)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      color: _lime,
                      child: Text(
                        'EQUIPPED',
                        style: GoogleFonts.spaceMono(
                          color: Colors.black,
                          fontSize: 6,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (isSelected)
                  Positioned(
                    top: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      color: _gold,
                      child: const Icon(Icons.check, size: 8, color: Colors.black),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showBadgeOptions(UserPurchase badge, Map<String, EquippedItem> equipped) {
    final badgeDef = BuiltInBadges.getById(badge.productId);
    final isEquipped = equipped.values.any((e) => e.productId == badge.productId);
    final isSelected = ref.read(badgeAlchemyProvider).selectedBadges.any((x) => x.id == badge.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(height: 4, width: 40, color: _gold),
              const SizedBox(height: 20),
              Text(
                badge.productName.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(
                  color: _white,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                badgeDef?.slug.toUpperCase() ?? 'BADGE',
                style: GoogleFonts.spaceMono(
                  color: badgeDef?.primaryColor ?? _muted,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  color: isEquipped ? _lime.withValues(alpha: 0.15) : _muted.withValues(alpha: 0.1),
                  child: Icon(
                    isEquipped ? Icons.check_circle : Icons.power_settings_new,
                    color: isEquipped ? _lime : _white,
                  ),
                ),
                title: Text(
                  isEquipped ? 'UNEQUIP_BADGE' : 'EQUIP_BADGE',
                  style: GoogleFonts.spaceMono(color: _white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isEquipped ? 'Currently displayed on your profile' : 'Set as your active showcase badge',
                  style: GoogleFonts.spaceMono(color: _muted, fontSize: 9),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  FlickoHaptics.medium();
                  if (isEquipped) {
                    await ref.read(equipmentServiceProvider).equipItem('', 'badge');
                  } else {
                    await ref.read(equipmentServiceProvider).equipItem(badge.productId, 'badge');
                  }
                  ref.invalidate(equippedItemsProvider);
                  ref.invalidate(equippedBadgeProvider);
                },
              ),
              const Divider(color: Color(0xFF141416)),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  color: isSelected ? _gold.withValues(alpha: 0.15) : _muted.withValues(alpha: 0.1),
                  child: Icon(
                    isSelected ? Icons.remove_circle_outline : Icons.auto_awesome,
                    color: isSelected ? _magenta : _gold,
                  ),
                ),
                title: Text(
                  isSelected ? 'REMOVE_FROM_CRUCIBLE' : 'LOAD_INTO_CRUCIBLE',
                  style: GoogleFonts.spaceMono(color: _white, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  isSelected ? 'Remove slot allocation' : 'Queue badge for alchemical fusion synthesis',
                  style: GoogleFonts.spaceMono(color: _muted, fontSize: 9),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  FlickoHaptics.light();
                  ref.read(badgeAlchemyProvider.notifier).selectBadge(badge);
                },
              ),
            ],
          ),
        ),
      ),
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
        color: Colors.black,
        border: Border.all(
          color: isClaimed
              ? _muted.withValues(alpha: 0.3)
              : isCompleted
                  ? _lime
                  : _muted.withValues(alpha: 0.5),
          width: isCompleted && !isClaimed ? 2.5 : 1.5,
        ),
        boxShadow: isCompleted && !isClaimed
            ? const [BoxShadow(color: _lime, offset: Offset(3, 3))]
            : null,
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
                      style: GoogleFonts.spaceGrotesk(
                        color: isClaimed ? _muted : _white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      achievement.description.toUpperCase(),
                      style: GoogleFonts.spaceMono(
                        color: _muted,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
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
                    color: rewardBadge.primaryColor.withValues(alpha: 0.15),
                    border: Border.all(color: rewardBadge.primaryColor, width: 1.5),
                  ),
                  child: Tooltip(
                    message: rewardBadge.name,
                    child: Icon(
                      rewardBadge.icon,
                      color: rewardBadge.primaryColor,
                      size: 20,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.zero,
                  child: LinearProgressIndicator(
                    value: (currentCount / achievement.targetCount).clamp(0.0, 1.0),
                    backgroundColor: const Color(0xFF141416),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isClaimed
                          ? _muted
                          : isCompleted
                              ? _lime
                              : _gold,
                    ),
                    minHeight: 8,
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
              color: Colors.black,
              child: Center(
                child: Text(
                  'REWARD_CLAIMED',
                  style: GoogleFonts.spaceMono(
                    color: _muted,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
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
                        'REWARD_UNLOCKED: ${achievement.title.toUpperCase()} BADGE ADDED TO INVENTORY!',
                        style: GoogleFonts.spaceMono(fontWeight: FontWeight.bold),
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
                  border: Border.all(color: Colors.black, width: 1.5),
                  boxShadow: const [BoxShadow(color: Colors.black, offset: Offset(2, 2))],
                ),
                child: Center(
                  child: Text(
                    'CLAIM_ACHIEVEMENT_REWARD',
                    style: GoogleFonts.spaceMono(
                      color: Colors.black,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: _muted.withValues(alpha: 0.3), width: 1.5),
              ),
              child: Center(
                child: Text(
                  'IN_PROGRESS',
                  style: GoogleFonts.spaceMono(
                    color: _muted,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showTransmutationDialog(BuildContext context, BadgeDefinition reward) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            border: Border.all(color: _gold, width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                color: _gold,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                width: double.infinity,
                child: Text(
                  'TRANSMUTATION_SUCCESS',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [reward.primaryColor, reward.secondaryColor],
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: _white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: reward.primaryColor.withValues(alpha: 0.6),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: Icon(reward.icon, color: _white, size: 54),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      reward.name.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                        color: _white,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'A HIGH-FIDELITY COSMETIC FORGED BY ALCHEMICAL SYNTHESIS.',
                      style: GoogleFonts.spaceMono(
                        color: _muted,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: () {
                        FlickoHaptics.light();
                        Navigator.pop(ctx);
                        ref.read(badgeAlchemyProvider.notifier).clearCrucible();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _gold,
                          border: Border.all(color: Colors.black, width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            'CONFIRM_TRANSMUTATION',
                            style: GoogleFonts.spaceMono(
                              color: Colors.black,
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AlchemicalCirclePainter extends CustomPainter {
  final double rotation;
  final double pulse;
  final bool isSynthesizing;

  AlchemicalCirclePainter({
    required this.rotation,
    required this.pulse,
    required this.isSynthesizing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2;

    const Color gold = Color(0xFFFFD700);
    const Color magenta = Color(0xFFFF007F);
    const Color lime = Color(0xFF52B788);

    final paintOuter = Paint()
      ..color = gold.withValues(alpha: 0.5 + 0.3 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final paintInner = Paint()
      ..color = magenta.withValues(alpha: 0.4 + 0.2 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final paintLines = Paint()
      ..color = lime.withValues(alpha: 0.3 + 0.2 * pulse)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Draw outer circle
    canvas.drawCircle(center, maxRadius * 0.9, paintOuter);

    // Draw runic ticks or dashes
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    for (int i = 0; i < 24; i++) {
      canvas.drawLine(
        Offset(0, -maxRadius * 0.9),
        Offset(0, -maxRadius * 0.82),
        paintOuter,
      );
      canvas.rotate(2 * math.pi / 24);
    }
    canvas.restore();

    // Draw middle circle
    canvas.drawCircle(center, maxRadius * 0.7, paintInner);

    // Draw rotating triangle inside middle circle
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-rotation * 1.5);
    final path = Path();
    for (int i = 0; i < 3; i++) {
      final double angle = i * 2 * math.pi / 3 - math.pi / 2;
      final x = maxRadius * 0.7 * math.cos(angle);
      final y = maxRadius * 0.7 * math.sin(angle);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    canvas.drawPath(path, paintLines);
    canvas.restore();

    // Inner core circle
    canvas.drawCircle(center, maxRadius * 0.3, paintInner);
  }

  @override
  bool shouldRepaint(covariant AlchemicalCirclePainter oldDelegate) {
    return oldDelegate.rotation != rotation ||
        oldDelegate.pulse != pulse ||
        oldDelegate.isSynthesizing != isSynthesizing;
  }
}
