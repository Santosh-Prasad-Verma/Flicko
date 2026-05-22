import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:mobile/features/store/data/store_service.dart';

/// Service for managing user's wishlist
final wishlistServiceProvider = Provider<WishlistService>((ref) {
  return WishlistService();
});

/// Provider for wishlist items
final wishlistProvider = NotifierProvider<WishlistNotifier, List<String>>(WishlistNotifier.new);

class WishlistService {
  static const _key = 'store_wishlist';

  Future<List<String>> loadWishlist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString(_key);
      if (data == null) return [];
      return List<String>.from(jsonDecode(data));
    } catch (e) {
      return [];
    }
  }

  Future<void> saveWishlist(List<String> productIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode(productIds));
    } catch (e) {
      // Ignore save errors
    }
  }
}

class WishlistNotifier extends Notifier<List<String>> {
  late WishlistService _service;

  @override
  List<String> build() {
    _service = ref.watch(wishlistServiceProvider);
    Future.microtask(() => _load());
    return [];
  }

  Future<void> _load() async {
    state = await _service.loadWishlist();
  }

  Future<void> add(String productId) async {
    if (!state.contains(productId)) {
      state = [...state, productId];
      await _service.saveWishlist(state);
    }
  }

  Future<void> remove(String productId) async {
    state = state.where((id) => id != productId).toList();
    await _service.saveWishlist(state);
  }

  Future<void> toggle(String productId) async {
    if (state.contains(productId)) {
      await remove(productId);
    } else {
      await add(productId);
    }
  }

  bool contains(String productId) => state.contains(productId);

  int get count => state.length;
}

/// Provider for wishlist products (full product data)
final wishlistProductsProvider = FutureProvider<List<StoreProduct>>((ref) async {
  final wishlistIds = ref.watch(wishlistProvider);
  if (wishlistIds.isEmpty) return [];

  final storeService = ref.watch(storeServiceProvider);
  final allProducts = await storeService.getProducts();

  return allProducts.where((p) => wishlistIds.contains(p.id)).toList();
});
