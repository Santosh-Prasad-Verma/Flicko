import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile/features/store/data/store_service.dart';
import 'package:mobile/features/store/data/store_payment_service.dart';
import 'package:mobile/features/auth/application/auth_notifier.dart';
import 'package:mobile/features/settings/application/payment_methods_provider.dart';

// Shared colors
const _kBg = Color(0xFF050505);
const _kSurface = Color(0xFF0C0C0E);
const _kNeon = Color(0xFF9B84EE);
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final total = ref.read(cartProvider.notifier).total;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kSurface,
        elevation: 0,
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
                  style: GoogleFonts.spaceGrotesk(
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
                style: GoogleFonts.spaceGrotesk(
                  color: Colors.red,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
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
                    itemBuilder: (context, index) => _buildCartItem(context, ref, cart[index]),
                  ),
                ),
                _buildCheckoutSection(context, ref, cart, total),
              ],
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
              decoration: BoxDecoration(
                color: _kNeon,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'BROWSE STORE',
                style: GoogleFonts.spaceGrotesk(
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

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: rarityColor.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Product image/icon
            GestureDetector(
              onTap: () => context.push('/store/product/${item.product.id}'),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      rarityColor.withValues(alpha: 0.3),
                      rarityColor.withValues(alpha: 0.1),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
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
            const SizedBox(width: 16),
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
                          style: GoogleFonts.spaceGrotesk(
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
                          style: GoogleFonts.spaceMono(
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
                    style: GoogleFonts.spaceMono(
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
                      Container(
                        width: 40,
                        alignment: Alignment.center,
                        child: Text(
                          '${item.quantity}',
                          style: GoogleFonts.spaceGrotesk(
                            color: _kWhite,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
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
                        '\$${(item.product.price * item.quantity).toStringAsFixed(2)}',
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
    );
  }

  Widget _buildQuantityButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: _kNeon.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, color: _kNeon, size: 16),
      ),
    );
  }

  Widget _buildCheckoutSection(BuildContext context, WidgetRef ref, List<CartItem> cart, double total) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _kSurface,
        border: Border(top: BorderSide(color: _kWhite.withValues(alpha: 0.1))),
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
                  style: GoogleFonts.spaceGrotesk(
                    color: _kMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '\$${total.toStringAsFixed(2)}',
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
                padding: const EdgeInsets.symmetric(vertical: 18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_kNeon, Color(0xFF00E5FF)]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock, color: Colors.black, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'CHECKOUT',
                        style: GoogleFonts.spaceGrotesk(
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
            const SizedBox(height: 8),
            Text(
              'Secure checkout powered by Flicko Pay',
              style: GoogleFonts.spaceMono(
                color: _kMuted,
                fontSize: 10,
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
    final hasFreeItems = cart.any((item) => item.product.price == 0);
    final paidItems = cart.where((item) => item.product.price > 0).toList();
    final freeItems = cart.where((item) => item.product.price == 0).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollController) => _CheckoutSheet(
          cart: cart,
          total: total,
          paidItems: paidItems,
          freeItems: freeItems,
          scrollController: scrollController,
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

  static const Color _kBg = Color(0xFF050505);
  static const Color _kSurface = Color(0xFF0C0C0E);
  static const Color _kNeon = Color(0xFF9B84EE);
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
              decoration: BoxDecoration(
                color: _kWhite.withValues(alpha: 0.2),
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
                  color: _kNeon.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
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
                      style: GoogleFonts.spaceGrotesk(
                        color: _kWhite,
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      '256-bit encrypted payment',
                      style: GoogleFonts.spaceGrotesk(
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
          // Payment methods
          if (widget.paidItems.isNotEmpty) ...[
            Text(
              'PAYMENT METHOD',
              style: GoogleFonts.spaceGrotesk(
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kWhite.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Items (${widget.cart.length})',
                style: GoogleFonts.spaceGrotesk(color: _kMuted),
              ),
              Text(
                '\$${widget.total.toStringAsFixed(2)}',
                style: GoogleFonts.spaceGrotesk(color: _kWhite),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(color: Color(0xFF1A1A1A)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL',
                style: GoogleFonts.spaceGrotesk(
                  color: _kWhite,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              Text(
                '\$${widget.total.toStringAsFixed(2)}',
                style: GoogleFonts.epilogue(
                  color: _kLime,
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
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? _kNeon : _kWhite.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 32,
              decoration: BoxDecoration(
                color: _kSurface,
                borderRadius: BorderRadius.circular(6),
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
                    style: GoogleFonts.spaceGrotesk(
                      color: _kWhite,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.spaceGrotesk(
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
    final isFree = widget.total == 0;

    return Column(
      children: [
        GestureDetector(
          onTap: _isProcessing ? null : () => _processPayment(context),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
              gradient: isFree
                  ? const LinearGradient(colors: [_kLime, Color(0xFF38EF7D)])
                  : const LinearGradient(colors: [_kNeon, Color(0xFF00E5FF)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: (isFree ? _kLime : _kNeon).withValues(alpha: 0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
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
                          isFree ? 'CLAIM FREE ITEMS' : 'PAY \$${widget.total.toStringAsFixed(2)}',
                          style: GoogleFonts.spaceGrotesk(
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
              style: GoogleFonts.spaceMono(
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

      if (user == null) {
        _showError('Please log in to continue');
        return;
      }

      final profile = authState.maybeWhen(
        authenticated: (_, profile) => profile,
        orElse: () => null,
      );

      // Process free items first
      if (widget.freeItems.isNotEmpty) {
        final storeService = ref.read(storeServiceProvider);
        for (final item in widget.freeItems) {
          await storeService.purchaseProduct(item.product);
        }
      }

      // Process paid items
      if (widget.paidItems.isNotEmpty) {
        final paymentService = ref.read(storePaymentServiceProvider);
        final result = await paymentService.processPayment(
          amount: widget.paidItems.fold(0.0, (sum, item) => sum + (item.product.price * item.quantity)),
          userEmail: user.email ?? '',
          userPhone: profile?.phone ?? '',
          description: 'Flicko Store Purchase - ${widget.paidItems.length} item(s)',
          items: widget.paidItems,
        );

        if (!result.success) {
          _showError(result.error ?? 'Payment failed');
          return;
        }
      }

      // Clear cart and show success
      ref.read(cartProvider.notifier).clear();
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

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kLime.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: _kLime, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              'PURCHASE SUCCESSFUL!',
              style: GoogleFonts.spaceGrotesk(
                color: _kWhite,
                fontWeight: FontWeight.w900,
                fontSize: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your items are now available in My Items.',
              style: GoogleFonts.spaceGrotesk(color: _kMuted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () {
                Navigator.pop(ctx);
                context.pop();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                decoration: BoxDecoration(
                  color: _kLime,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'VIEW MY ITEMS',
                  style: GoogleFonts.spaceGrotesk(
                    color: Colors.black,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRarityColor(String rarity) {
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

  IconData _iconForType(String type) {
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
}
