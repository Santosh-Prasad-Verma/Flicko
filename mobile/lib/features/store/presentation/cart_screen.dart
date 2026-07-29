import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/store_payment_service.dart';
import 'package:mobile/features/settings/application/payment_methods_provider.dart';
import 'package:mobile/features/shared/presentation/widgets/user_avatar.dart';

// Discord Mobile Shop Theme Palette
const _bgDark = Color(0xFF111214);
const _cardBg = Color(0xFF1E1F22);
const _cardBgLight = Color(0xFF2B2D31);
const _blurple = Color(0xFF5865F2);
const _greenAccent = Color(0xFF23A55A);
const _dangerRed = Color(0xFFDA373C);
const _textMuted = Color(0xFF949BA4);

Color _getRarityColor(String rarity) {
  switch (rarity.toLowerCase()) {
    case 'legendary':
      return const Color(0xFFFEE75C);
    case 'epic':
      return const Color(0xFFEB459E);
    case 'rare':
      return const Color(0xFF57F287);
    default:
      return _textMuted;
  }
}

IconData _iconForType(String type) {
  switch (type.toUpperCase()) {
    case 'THEME':
      return Icons.palette_rounded;
    case 'STICKERS':
      return Icons.emoji_emotions_rounded;
    case 'SOUNDS':
      return Icons.music_note_rounded;
    case 'BADGE':
    case 'NAMEPLATE':
      return Icons.verified_rounded;
    default:
      return Icons.storefront_rounded;
  }
}

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final total = ref.read(cartProvider.notifier).total;

    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 24),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Text(
              'Cart',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
            if (cart.isNotEmpty) ...[
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _blurple,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${cart.length}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
        actions: [
          if (cart.isNotEmpty)
            TextButton(
              onPressed: () => ref.read(cartProvider.notifier).clear(),
              child: Text(
                'CLEAR ALL',
                style: GoogleFonts.inter(
                  color: _dangerRed,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
      body: cart.isEmpty
          ? _buildEmptyCart(context)
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: cart.length,
                    itemBuilder: (context, index) =>
                        _buildCartItemCard(context, ref, cart[index]),
                  ),
                ),
                _buildCheckoutFooter(context, ref, cart, total),
              ],
            ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: _cardBg,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: const Icon(Icons.shopping_bag_outlined, color: _textMuted, size: 44),
            ),
            const SizedBox(height: 24),
            Text(
              'Your Cart is Empty',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Explore the shop to discover avatar decorations, nameplates, themes & more.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: _textMuted,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.push('/store'),
              icon: const Icon(Icons.storefront_rounded, size: 18),
              label: Text(
                'EXPLORE SHOP',
                style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blurple,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartItemCard(BuildContext context, WidgetRef ref, CartItem item) {
    final rarityColor = _getRarityColor(item.product.rarity);
    final isAvatarDecoration = item.product.type.toUpperCase() == 'AVATAR_DECORATION';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: _cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            // Preview Thumbnail Box
            GestureDetector(
              onTap: () => context.push('/store/product/${item.product.id}'),
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: _cardBgLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: isAvatarDecoration
                      ? UserAvatar(
                          size: 48,
                          decoration: item.product.id,
                          name: item.product.name,
                          showStatus: false,
                          showBadge: false,
                        )
                      : Icon(
                          _iconForType(item.product.type),
                          color: rarityColor,
                          size: 32,
                        ),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Details Column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.product.name,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: rarityColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.product.rarity.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: rarityColor,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.product.type.replaceAll('_', ' ').toUpperCase(),
                    style: GoogleFonts.inter(
                      color: _textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Quantity Controls & Item Subtotal
                  Row(
                    children: [
                      _buildQtyButton(
                        icon: Icons.remove_rounded,
                        onTap: () {
                          ref.read(cartProvider.notifier).updateQuantity(
                            item.product.id,
                            item.quantity - 1,
                          );
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text(
                          '${item.quantity}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      _buildQtyButton(
                        icon: Icons.add_rounded,
                        onTap: () {
                          ref.read(cartProvider.notifier).updateQuantity(
                            item.product.id,
                            item.quantity + 1,
                          );
                        },
                      ),
                      const Spacer(),
                      Text(
                        '₹${(item.product.price * item.quantity).toStringAsFixed(0)}',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // Delete Button
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.delete_outline_rounded, color: _dangerRed, size: 20),
              onPressed: () {
                ref.read(cartProvider.notifier).remove(item.product.id);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQtyButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: _cardBgLight,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildCheckoutFooter(BuildContext context, WidgetRef ref, List<CartItem> cart, double total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF18191C),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL',
                  style: GoogleFonts.inter(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                  ),
                ),
                Text(
                  '₹${total.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: () => _showCheckoutDialog(context, ref, cart),
                icon: const Icon(Icons.lock_rounded, size: 18),
                label: Text(
                  'SECURE CHECKOUT',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    letterSpacing: 0.5,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _greenAccent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '🔒 Encrypted checkout powered by Flicko Pay',
              style: GoogleFonts.inter(
                color: _textMuted,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  void _showCheckoutDialog(BuildContext context, WidgetRef ref, List<CartItem> cart) {
    final total = ref.read(cartProvider.notifier).total;
    final paidItems = cart.where((item) => item.product.price > 0).toList();
    final freeItems = cart.where((item) => item.product.price == 0).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: _bgDark,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: _CheckoutSheet(
            cart: cart,
            total: total,
            paidItems: paidItems,
            freeItems: freeItems,
            scrollController: scrollController,
          ),
        ),
      ),
    );
  }
}

/// Full checkout bottom sheet with payment options
class _CheckoutSheet extends ConsumerStatefulWidget {
  final List<CartItem> cart;
  final double total;
  final List<CartItem> paidItems;
  final List<CartItem> freeItems;
  final ScrollController scrollController;

  const _CheckoutSheet({
    required this.cart,
    required this.total,
    required this.paidItems,
    required this.freeItems,
    required this.scrollController,
  });

  @override
  ConsumerState<_CheckoutSheet> createState() => _CheckoutSheetState();
}

class _CheckoutSheetState extends ConsumerState<_CheckoutSheet> {
  bool _isProcessing = false;
  int _selectedPaymentMethod = 0; // 0 = saved card, 1 = new card, 2 = UPI, 3 = wallet
  final _couponController = TextEditingController();
  String? _couponError;
  // ignore: unused_field
  bool _couponSuccess = false;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  static const Color _kCardBg = Color(0xFF1E1F22);
  static const Color _kCardBgLight = Color(0xFF2B2D31);
  static const Color _kBlurple = Color(0xFF5865F2);
  static const Color _kGreen = Color(0xFF23A55A);
  static const Color _kTextMuted = Color(0xFF949BA4);

  @override
  Widget build(BuildContext context) {
    final paymentMethodsAsync = ref.watch(paymentMethodsProvider);
    final hasSavedCards = paymentMethodsAsync.when(
      data: (methods) => methods.isNotEmpty,
      loading: () => false,
      error: (_, __) => false,
    );

    return Container(
      padding: const EdgeInsets.all(24),
      child: ListView(
        controller: widget.scrollController,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _kCardBgLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.lock_rounded, color: _kBlurple, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SECURE CHECKOUT',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      '256-bit encrypted payment',
                      style: GoogleFonts.inter(
                        color: _kTextMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Order summary
          _buildOrderSummary(),
          const SizedBox(height: 20),
          // Coupon section
          _buildCouponCodeSection(),
          const SizedBox(height: 12),
          // Payment methods
          if (widget.paidItems.isNotEmpty) ...[
            Text(
              'PAYMENT METHOD',
              style: GoogleFonts.inter(
                color: _kTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
            paymentMethodsAsync.when(
              data: (methods) => _buildPaymentMethodsList(methods, hasSavedCards),
              loading: () => const Center(child: CircularProgressIndicator(color: _kBlurple)),
              error: (e, _) => const Text('Error loading payment methods', style: TextStyle(color: Colors.red)),
            ),
            const SizedBox(height: 24),
          ],
          // Total and checkout button
          _buildCheckoutButton(context),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    final activeCoupon = ref.watch(activeCouponProvider);
    final total = widget.total;
    final discount = activeCoupon != null ? total * (activeCoupon.discountPercent / 100) : 0.0;
    final finalTotal = total - discount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items (${widget.cart.length})',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (activeCoupon != null) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DISCOUNT (${activeCoupon.code})',
                  style: GoogleFonts.inter(
                    color: _kGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '-₹${discount.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    color: _kGreen,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: GoogleFonts.inter(
                  color: _kGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              Text(
                '₹${finalTotal.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCodeSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROMO CODE',
            style: GoogleFonts.inter(
              color: _kTextMuted,
              fontWeight: FontWeight.bold,
              fontSize: 11,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),
          if (activeCoupon != null) ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kGreen.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _kGreen),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded, color: _kGreen, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${activeCoupon.code} APPLIED (${activeCoupon.discountPercent.toInt()}% OFF)',
                            style: GoogleFonts.inter(
                              color: _kGreen,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.redAccent),
                  onPressed: () {
                    ref.read(activeCouponProvider.notifier).state = null;
                    _couponController.clear();
                    setState(() {
                      _couponSuccess = false;
                      _couponError = null;
                    });
                  },
                ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: _kCardBgLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _couponError != null ? Colors.redAccent : Colors.transparent,
                      ),
                    ),
                    child: TextField(
                      controller: _couponController,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'ENTER PROMO CODE',
                        hintStyle: GoogleFonts.inter(color: _kTextMuted, fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _applyCoupon,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    decoration: BoxDecoration(
                      color: _kBlurple,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        'APPLY',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_couponError != null) ...[
              const SizedBox(height: 8),
              Text(
                _couponError!,
                style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _applyCoupon() {
    final code = _couponController.text.trim().toUpperCase();
    if (code.isEmpty) return;

    if (code == 'SONICDRIP' || code == 'SONIC50') {
      ref.read(activeCouponProvider.notifier).state = const CouponInfo(
        code: 'SONICDRIP',
        discountPercent: 50,
        description: 'Turntable Promo - 50% discount on all cosmetics!',
      );
      setState(() {
        _couponSuccess = true;
        _couponError = null;
      });
    } else if (code == 'FREEBADGE' || code == 'FREE') {
      ref.read(activeCouponProvider.notifier).state = const CouponInfo(
        code: 'FREEBADGE',
        discountPercent: 100,
        description: 'Vegas Promo - 100% off!',
      );
      setState(() {
        _couponSuccess = true;
        _couponError = null;
      });
    } else {
      setState(() {
        _couponError = 'INVALID CODE (TRY "SONIC50" OR "FREE")';
        _couponSuccess = false;
      });
    }
  }

  Widget _buildPaymentMethodsList(List<dynamic> methods, bool hasSavedCards) {
    return Column(
      children: [
        if (hasSavedCards) ...[
          ...methods.take(2).map((method) => _buildPaymentOption(
            index: methods.indexOf(method),
            icon: Icons.credit_card_rounded,
            title: '${method.cardType} •••• ${method.cardNumberLastFour}',
            subtitle: 'Expires ${method.expiryMonth}/${method.expiryYear}',
            isSelected: _selectedPaymentMethod == methods.indexOf(method),
            onTap: () => setState(() => _selectedPaymentMethod = methods.indexOf(method)),
          )),
        ],
        _buildPaymentOption(
          index: 10,
          icon: Icons.add_card_rounded,
          title: 'Add New Card',
          subtitle: 'Credit or debit card',
          isSelected: _selectedPaymentMethod == 10,
          onTap: () async {
            await context.push('/profile/settings/add-card');
            ref.invalidate(paymentMethodsProvider);
          },
        ),
        _buildPaymentOption(
          index: 11,
          icon: Icons.account_balance_wallet_rounded,
          title: 'UPI / Wallet',
          subtitle: 'Google Pay, PhonePe, Paytm, BHIM',
          isSelected: _selectedPaymentMethod == 11,
          onTap: () => setState(() => _selectedPaymentMethod = 11),
        ),
      ],
    );
  }

  Widget _buildPaymentOption({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? _kBlurple : Colors.white.withValues(alpha: 0.06),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 34,
              decoration: BoxDecoration(
                color: _kCardBgLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: isSelected ? _kBlurple : Colors.white70, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: _kTextMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? _kBlurple : Colors.white38,
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckoutButton(BuildContext context) {
    final activeCoupon = ref.watch(activeCouponProvider);
    final finalTotal = activeCoupon != null ? widget.total * (1 - activeCoupon.discountPercent / 100) : widget.total;
    final isFree = finalTotal == 0;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: _isProcessing ? null : () => _processPayment(context),
            icon: _isProcessing
                ? const SizedBox.shrink()
                : Icon(
                    isFree ? Icons.card_giftcard_rounded : Icons.lock_rounded,
                    size: 18,
                  ),
            label: _isProcessing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : Text(
                    isFree ? 'CLAIM FREE ITEMS' : 'PAY ₹${finalTotal.toStringAsFixed(0)}',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      letterSpacing: 0.5,
                    ),
                  ),
            style: ElevatedButton.styleFrom(
              backgroundColor: isFree ? _kGreen : _kBlurple,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.shield_rounded, color: _kTextMuted, size: 14),
            const SizedBox(width: 6),
            Text(
              'Protected by Flicko 256-Bit Encrypted Pay',
              style: GoogleFonts.inter(
                color: _kTextMuted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _processPayment(BuildContext context) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final authState = ref.read(authNotifierProvider);
      final user = authState.maybeWhen(
        authenticated: (user, profile) => user,
        orElse: () => null,
      );

      final profile = authState.maybeWhen(
        authenticated: (_, profile) => profile,
        orElse: () => null,
      );

      final activeCoupon = ref.read(activeCouponProvider);
      final rawAmount = widget.paidItems.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity));
      final finalAmount = activeCoupon != null ? rawAmount * (1 - activeCoupon.discountPercent / 100) : rawAmount;

      // Guest / Offline checkouts save to local SharedPreferences bypass
      if (user == null) {
        final storeService = ref.read(storeServiceProvider);
        for (final item in widget.cart) {
          await storeService.purchaseProduct(item.product);
        }
      } else {
        // Process free items first
        if (widget.freeItems.isNotEmpty) {
          final storeService = ref.read(storeServiceProvider);
          for (final item in widget.freeItems) {
            await storeService.purchaseProduct(item.product);
          }
        }

        // Process paid items
        if (widget.paidItems.isNotEmpty && finalAmount > 0) {
          final bool hasLiveGateway = AppConfig.hasApiBaseUrl && AppConfig.razorpayKeyId.isNotEmpty;
          bool useSandbox = !hasLiveGateway;

          // The sandbox path grants paid items for free, so it is confined to
          // debug builds. It used to be offered in every build whenever the
          // gateway failed, which turned any payment outage into free
          // cosmetics for real users.
          if (hasLiveGateway) {
            final paymentService = ref.read(storePaymentServiceProvider);
            final result = await paymentService.processPayment(
              amount: finalAmount,
              userEmail: user.email ?? '',
              userPhone: profile?.phone ?? '',
              description: 'Flicko Store Purchase - ${widget.paidItems.length} item(s)',
              items: widget.paidItems,
            );

            if (!result.success) {
              if (!mounted) return;
              if (!AppConfig.isDebug) {
                _showError(result.error ?? 'Payment failed');
                return;
              }
              final confirmed = await _showSandboxConfirmationDialog(finalAmount);
              if (confirmed == true) {
                useSandbox = true;
              } else {
                _showError(result.error ?? 'Payment failed');
                return;
              }
            }
          } else {
            if (!mounted) return;
            if (!AppConfig.isDebug) {
              _showError('Payments are not available right now.');
              return;
            }
            final confirmed = await _showSandboxConfirmationDialog(finalAmount);
            if (confirmed == true) {
              useSandbox = true;
            } else {
              _showError('Payment cancelled: Live gateway not configured.');
              return;
            }
          }

          if (useSandbox) {
            final paymentService = ref.read(storePaymentServiceProvider);
            final granted = await paymentService
                .grantWithoutPaymentForDebug(widget.paidItems);
            if (!granted.success) {
              if (!mounted) return;
              _showError(granted.error ?? 'Sandbox checkout failed');
              return;
            }
          }
        } else if (widget.paidItems.isNotEmpty && finalAmount == 0) {
          // If discounted to 100% free, claim it as free
          final storeService = ref.read(storeServiceProvider);
          for (final item in widget.paidItems) {
            await storeService.purchaseProduct(item.product);
          }
        }
      }

      // Clear cart, coupon, and show success
      ref.read(cartProvider.notifier).clear();
      ref.read(activeCouponProvider.notifier).state = null;
      ref.invalidate(userPurchasesProvider);

      if (!context.mounted) return;
      Navigator.pop(context);
      _showSuccessDialog(context);
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<bool?> _showSandboxConfirmationDialog(double amount) async {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: const Border(
          top: BorderSide(color: _kNeon, width: 4),
          left: BorderSide(color: _kNeon, width: 2),
          right: BorderSide(color: _kNeon, width: 2),
          bottom: BorderSide(color: _kNeon, width: 2),
        ),
        title: Row(
          children: [
            const Icon(Icons.terminal, color: _kNeon, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'SANDBOX_OVERRIDE',
                style: GoogleFonts.spaceGrotesk(
                  color: _kWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                border: Border.all(color: Colors.red.withValues(alpha: 0.5), width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.red, size: 14),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'LIVE_GATEWAY: NOT_CONFIGURED',
                      style: GoogleFonts.robotoMono(
                        color: Colors.red,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'PROCESS STORE PURCHASE OF ₹${amount.toStringAsFixed(0)} IN TEST MODE?\n\n'
              'THIS WILL GRANT COSMETICS WITHOUT PROCESSING A REAL PAYMENT.',
              style: GoogleFonts.robotoMono(
                color: _kWhite.withValues(alpha: 0.8),
                fontSize: 12,
                height: 1.6,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              'ABORT',
              style: GoogleFonts.robotoMono(
                color: _kWhite.withValues(alpha: 0.5),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: _kNeon,
                border: Border.all(color: Colors.black, width: 2),
                boxShadow: const [
                  BoxShadow(color: Colors.white, offset: Offset(3, 3)),
                ],
              ),
              child: Text(
                'OVERRIDE_&_PURCHASE',
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: const Border(
          top: BorderSide(color: _kLime, width: 4),
          left: BorderSide(color: _kLime, width: 2),
          right: BorderSide(color: _kLime, width: 2),
          bottom: BorderSide(color: _kLime, width: 2),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: _kLime, width: 1),
              ),
              child: const Icon(Icons.check_circle, color: _kLime, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              'PURCHASE SUCCESSFUL!',
              style: GoogleFonts.inter(
                color: _kWhite,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your items are now available in My Items.',
              style: GoogleFonts.inter(color: _kMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                context.pop();
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                margin: const EdgeInsets.only(right: 4, bottom: 4),
                decoration: BoxDecoration(
                  color: _kLime,
                  border: Border.all(color: Colors.black, width: 2),
                  boxShadow:  [
                    BoxShadow(color: Colors.white.withValues(alpha: 0.25),
                      blurRadius: 14, offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'VIEW MY ITEMS',
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
