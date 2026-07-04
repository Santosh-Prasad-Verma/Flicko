import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/store_payment_service.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/settings/application/payment_methods_provider.dart';
import 'package:mobile/core/config/app_config.dart';

// Shared colors
const _kBg = Color(0xFF000000);
const _kSurface = Color(0xFF000000);
const _kNeon = Color(0xFF52B788);
const _kWhite = Color(0xFFFFFFFF);
const _kMuted = Color(0xFF71717A);
const _kLime = Color(0xFF52B788);
const _kGold = Color(0xFFFFD700);

// Helper functions for cart items
Color getRarityColor(String rarity) {
  switch (rarity.toLowerCase()) {
    case 'legendary':
      return _kGold;
    case 'epic':
      return _kNeon;
    case 'rare':
      return const Color(0xFF00E5FF);
    default:
      return _kMuted;
  }
}

IconData iconForType(String type) {
  switch (type.toUpperCase()) {
    case 'THEME':
      return Icons.palette_rounded;
    case 'STICKERS':
      return Icons.emoji_emotions_rounded;
    case 'SOUNDS':
      return Icons.music_note_rounded;
    case 'BADGE':
      return Icons.verified_rounded;
    default:
      return Icons.store_rounded;
  }
}

class CartScreen extends ConsumerWidget {
  const CartScreen({super.key});

  Widget _buildLiquidGlassBackground({required Widget child}) {
    return Stack(
      children: [
        // Pure black base
        Container(color: const Color(0xFF000000)),
        // Ambient glow 1 (Emerald Green)
        Positioned(
          top: -100,
          left: -80,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF10B981).withValues(alpha: 0.18),
            ),
          ),
        ),
        // Ambient glow 2 (Deep Purple)
        Positioned(
          bottom: 200,
          right: -100,
          child: Container(
            width: 380,
            height: 380,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF9B84EE).withValues(alpha: 0.15),
            ),
          ),
        ),
        // Backdrop blur overlay
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
            child: Container(color: Colors.transparent),
          ),
        ),
        child,
      ],
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final total = ref.read(cartProvider.notifier).total;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              color: Colors.black.withValues(alpha: 0.25),
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _kWhite),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Text(
              'Cart',
              style: GoogleFonts.epilogue(
                color: _kWhite,
                fontWeight: FontWeight.w900,
                fontSize: 20,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (cart.isNotEmpty) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _kNeon,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${cart.length}',
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
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
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
        ],
      ),
      body: _buildLiquidGlassBackground(
        child: SafeArea(
          bottom: false,
          child: cart.isEmpty
              ? _buildEmptyCart(context)
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: cart.length,
                        itemBuilder: (context, index) => _buildCartItem(context, ref, cart[index]),
                      ),
                    ),
                    _buildCheckoutSection(context, ref, cart, total),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyCart(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: _kSurface,
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(Icons.shopping_bag_outlined, color: _kMuted, size: 48),
          ),
          const SizedBox(height: 24),
          Text(
            'YOUR CART IS EMPTY',
            style: GoogleFonts.epilogue(
              color: _kWhite,
              fontSize: 22,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Looks like you haven\'t added anything yet.',
            style: GoogleFonts.inter(color: _kMuted, fontSize: 14),
          ),
          const SizedBox(height: 32),
          GestureDetector(
            onTap: () => context.push('/store'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              margin: const EdgeInsets.only(right: 4, bottom: 4),
              decoration: BoxDecoration(
                color: _kNeon,
                border: Border.all(color: Colors.black, width: 2),
                boxShadow:  [
                  BoxShadow(color: Colors.white.withValues(alpha: 0.25),
                    blurRadius: 14, offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Text(
                'BROWSE STORE',
                style: GoogleFonts.inter(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(BuildContext context, WidgetRef ref, CartItem item) {
    final rarityColor = getRarityColor(item.product.rarity);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: rarityColor.withValues(alpha: 0.35), width: 1.2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withValues(alpha: 0.04),
                  Colors.white.withValues(alpha: 0.01),
                ],
              ),
            ),
            child: Row(
          children: [
            // Product image/icon
            GestureDetector(
              onTap: () => context.push('/store/product/${item.product.id}'),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: rarityColor, width: 1.5),
                ),
                child: Center(
                  child: Icon(
                    iconForType(item.product.type),
                    color: rarityColor,
                    size: 32,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Product details
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
                            color: _kWhite,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: rarityColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.product.rarity.toUpperCase(),
                          style: GoogleFonts.inter(
                            color: rarityColor,
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.product.type.toUpperCase(),
                    style: GoogleFonts.inter(
                      color: _kMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Quantity controls
                  Row(
                    children: [
                      _buildQuantityButton(
                        icon: Icons.remove,
                        onTap: () {
                          ref.read(cartProvider.notifier).updateQuantity(
                            item.product.id,
                            item.quantity - 1,
                          );
                        },
                      ),
                      SizedBox(
                        width: 32,
                        child: Center(
                          child: Text(
                            '${item.quantity}',
                            style: GoogleFonts.inter(
                              color: _kWhite,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                      _buildQuantityButton(
                        icon: Icons.add,
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
                        style: GoogleFonts.epilogue(
                          color: _kWhite,
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Remove button
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
              onPressed: () {
                ref.read(cartProvider.notifier).remove(item.product.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${item.product.name} removed from cart'),
                    backgroundColor: Colors.red,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildQuantityButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(color: _kNeon.withValues(alpha: 0.4), width: 1.0),
        ),
        child: Icon(icon, color: _kNeon, size: 16),
      ),
    );
  }

  Widget _buildCheckoutSection(BuildContext context, WidgetRef ref, List<CartItem> cart, double total) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.4),
            border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08), width: 1.0)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TOTAL',
                      style: GoogleFonts.inter(
                        color: _kMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '₹${total.toStringAsFixed(0)}',
                      style: GoogleFonts.epilogue(
                        color: _kWhite,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _showCheckoutDialog(context, ref, cart),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      color: _kNeon,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _kNeon.withValues(alpha: 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.lock, color: Colors.black, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'SECURE CHECKOUT',
                            style: GoogleFonts.inter(
                              color: Colors.black,
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Secure checkout powered by Flicko Pay',
                  style: GoogleFonts.inter(
                    color: _kMuted,
                    fontSize: 9,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCheckoutDialog(BuildContext context, WidgetRef ref, List<CartItem> cart) {
    final total = ref.read(cartProvider.notifier).total;
    final hasFreeItems = cart.any((item) => item.product.price == 0);
    final paidItems = cart.where((item) => item.product.price > 0).toList();
    final freeItems = cart.where((item) => item.product.price == 0).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.85),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
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
  bool _couponSuccess = false;

  @override
  void dispose() {
    _couponController.dispose();
    super.dispose();
  }

  static const Color _kBg = Color(0xFF000000);
  static const Color _kSurface = Color(0xFF000000);
  static const Color _kNeon = Color(0xFF52B788);
  static const Color _kWhite = Color(0xFFFFFFFF);
  static const Color _kMuted = Color(0xFF71717A);
  static const Color _kLime = Color(0xFF52B788);

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
              decoration: const BoxDecoration(
                color: _kNeon,
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
                  color: Colors.black,
                  border: Border.all(color: _kNeon, width: 1.5),
                ),
                child: const Icon(Icons.lock, color: _kNeon, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SECURE CHECKOUT',
                      style: GoogleFonts.inter(
                        color: _kWhite,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      '256-bit encrypted payment',
                      style: GoogleFonts.inter(
                        color: _kMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Order summary
          _buildOrderSummary(),
          const SizedBox(height: 24),
          // Coupon section
          _buildCouponCodeSection(),
          const SizedBox(height: 12),
          // Payment methods
          if (widget.paidItems.isNotEmpty) ...[
            Text(
              'PAYMENT METHOD',
              style: GoogleFonts.inter(
                color: _kMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(height: 12),
            paymentMethodsAsync.when(
              data: (methods) => _buildPaymentMethodsList(methods, hasSavedCards),
              loading: () => const Center(child: CircularProgressIndicator(color: _kNeon)),
              error: (e, _) => Text('Error loading payment methods', style: TextStyle(color: Colors.red)),
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
        color: Colors.black,
        border: Border.all(color: _kNeon, width: 2),
        boxShadow:  [
          BoxShadow(color: _kNeon.withValues(alpha: 0.25),
            blurRadius: 14, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items (${widget.cart.length})',
                style: GoogleFonts.inter(
                  color: _kWhite,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '₹${total.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  color: _kWhite,
                  fontWeight: FontWeight.w900,
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
                    color: _kLime,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '-₹${discount.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    color: _kLime,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          const Divider(color: _kNeon, thickness: 1.5),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: GoogleFonts.inter(
                  color: _kNeon,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
              Text(
                '₹${finalTotal.toStringAsFixed(0)}',
                style: GoogleFonts.epilogue(
                  color: _kWhite,
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCouponCodeSection() {
    final activeCoupon = ref.watch(activeCouponProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 24, right: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: _kNeon, width: 2),
        boxShadow:  [
          BoxShadow(color: Colors.white.withValues(alpha: 0.25),
            blurRadius: 14, offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PROMO CODE',
            style: GoogleFonts.inter(
              color: _kWhite,
              fontWeight: FontWeight.w900,
              fontSize: 11,
              letterSpacing: 1,
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
                      color: Colors.black,
                      border: Border.all(color: _kNeon, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle, color: _kNeon, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${activeCoupon.code} APPLIED (${activeCoupon.discountPercent.toInt()}% OFF)',
                            style: GoogleFonts.inter(
                              color: _kNeon,
                              fontWeight: FontWeight.w900,
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
                  icon: const Icon(Icons.clear, color: Colors.red),
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
                      color: Colors.black,
                      border: Border.all(color: _couponError != null ? Colors.red : _kNeon, width: 1.5),
                    ),
                    child: TextField(
                      controller: _couponController,
                      style: GoogleFonts.inter(color: _kWhite, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'ENTER CODE',
                        hintStyle: GoogleFonts.inter(color: _kMuted, fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _applyCoupon,
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: _kNeon,
                      border: Border.all(color: Colors.black, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        'APPLY',
                        style: GoogleFonts.inter(
                          color: Colors.black,
                          fontWeight: FontWeight.w900,
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
                style: GoogleFonts.inter(color: Colors.red, fontSize: 10),
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
        // Saved cards
        if (hasSavedCards) ...[
          ...methods.take(2).map((method) => _buildPaymentOption(
            index: methods.indexOf(method),
            icon: Icons.credit_card,
            title: '${method.cardType} •••• ${method.cardNumberLastFour}',
            subtitle: 'Expires ${method.expiryMonth}/${method.expiryYear}',
            isSelected: _selectedPaymentMethod == methods.indexOf(method),
            onTap: () => setState(() => _selectedPaymentMethod = methods.indexOf(method)),
          )),
        ],
        // Add new card
        _buildPaymentOption(
          index: 10,
          icon: Icons.add_card,
          title: 'Add New Card',
          subtitle: 'Credit or debit card',
          isSelected: _selectedPaymentMethod == 10,
          onTap: () async {
            await context.push('/profile/settings/add-card');
            ref.invalidate(paymentMethodsProvider);
          },
        ),
        // UPI (for Indian users)
        _buildPaymentOption(
          index: 11,
          icon: Icons.account_balance_wallet,
          title: 'UPI / Wallet',
          subtitle: 'Google Pay, PhonePe, etc.',
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
        margin: const EdgeInsets.only(bottom: 12, right: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(
            color: isSelected ? _kNeon : _kWhite.withValues(alpha: 0.2),
            width: isSelected ? 2.5 : 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(color: _kNeon.withValues(alpha: 0.25),
                    blurRadius: 14, offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: isSelected ? _kNeon : _kMuted, width: 1.5),
              ),
              child: Icon(icon, color: isSelected ? _kNeon : _kMuted, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: _kWhite,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: _kMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Radio<int>(
              value: index,
              groupValue: _selectedPaymentMethod,
              onChanged: (v) => setState(() => _selectedPaymentMethod = v!),
              activeColor: _kNeon,
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
        GestureDetector(
          onTap: _isProcessing ? null : () => _processPayment(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            margin: const EdgeInsets.only(right: 4, bottom: 4),
            decoration: BoxDecoration(
              color: isFree ? _kLime : _kNeon,
              border: Border.all(color: Colors.black, width: 2),
              boxShadow:  [
                BoxShadow(color: Colors.white.withValues(alpha: 0.25),
                  blurRadius: 14, offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isFree ? Icons.card_giftcard : Icons.lock,
                          color: Colors.black,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isFree ? 'CLAIM FREE ITEMS' : 'PAY ₹${finalTotal.toStringAsFixed(0)}',
                          style: GoogleFonts.inter(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shield, color: _kMuted, size: 14),
            const SizedBox(width: 6),
            Text(
              'Protected by Flicko Secure Pay',
              style: GoogleFonts.inter(
                color: _kMuted,
                fontSize: 10,
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
              // Offer sandbox fallback if live payment fails
              final confirmed = await _showSandboxConfirmationDialog(context, finalAmount);
              if (confirmed == true) {
                useSandbox = true;
              } else {
                _showError(result.error ?? 'Payment failed');
                return;
              }
            }
          } else {
            final confirmed = await _showSandboxConfirmationDialog(context, finalAmount);
            if (confirmed == true) {
              useSandbox = true;
            } else {
              _showError('Payment cancelled: Live gateway not configured.');
              return;
            }
          }

          if (useSandbox) {
            final storeService = ref.read(storeServiceProvider);
            for (final item in widget.paidItems) {
              await storeService.purchaseProduct(item.product);
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

      if (mounted) {
        Navigator.pop(context);
        _showSuccessDialog(context);
      }
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

  Future<bool?> _showSandboxConfirmationDialog(BuildContext context, double amount) async {
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
