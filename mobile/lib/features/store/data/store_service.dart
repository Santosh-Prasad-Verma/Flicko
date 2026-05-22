import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Models
class StoreProduct {
  final String id;
  final String slug;
  final String name;
  final String type;
  final String? description;
  final double price;
  final String? imageUrl;
  final String? previewUrl;
  final String rarity;
  final bool isHot;
  final bool isActive;

  StoreProduct({
    required this.id,
    required this.slug,
    required this.name,
    required this.type,
    this.description,
    required this.price,
    this.imageUrl,
    this.previewUrl,
    this.rarity = 'common',
    this.isHot = false,
    this.isActive = true,
  });

  factory StoreProduct.fromJson(Map<String, dynamic> json) {
    return StoreProduct(
      id: json['id'] as String,
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String,
      type: json['cosmetic_type'] as String? ?? json['type'] as String? ?? 'theme',
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['asset_url'] as String? ?? json['image_url'] as String?,
      previewUrl: json['preview_url'] as String?,
      rarity: json['rarity'] as String? ?? 'common',
      isHot: json['is_hot'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'slug': slug,
    'name': name,
    'type': type,
    'description': description,
    'price': price,
    'image_url': imageUrl,
    'preview_url': previewUrl,
    'rarity': rarity,
    'is_hot': isHot,
    'is_active': isActive,
  };
}

class CartItem {
  final StoreProduct product;
  int quantity;

  CartItem({required this.product, this.quantity = 1});
}

class UserPurchase {
  final String id;
  final String productId;
  final String productName;
  final String productType;
  final DateTime purchasedAt;
  final double price;
  final String? imageUrl;

  UserPurchase({
    required this.id,
    required this.productId,
    required this.productName,
    required this.productType,
    required this.purchasedAt,
    required this.price,
    this.imageUrl,
  });

  factory UserPurchase.fromJson(Map<String, dynamic> json) {
    return UserPurchase(
      id: json['id'] as String,
      productId: json['cosmetic_id'] as String? ?? json['product_id'] as String,
      productName: json['cosmetic']?['name'] as String? ?? json['product_name'] as String? ?? 'Unknown',
      productType: json['cosmetic']?['cosmetic_type'] as String? ?? json['product_type'] as String? ?? 'theme',
      purchasedAt: DateTime.parse(json['unlocked_at'] as String? ?? json['purchased_at'] as String? ?? DateTime.now().toIso8601String()),
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['cosmetic']?['asset_url'] as String? ?? json['image_url'] as String?,
    );
  }
}

// Service
final storeServiceProvider = Provider<StoreService>((ref) => StoreService(Supabase.instance.client));

class StoreService {
  final SupabaseClient _client;

  StoreService(this._client);

  Future<List<StoreProduct>> getProducts({String? type, String? search}) async {
    try {
      var query = _client
          .from('cosmetic_catalog')
          .select()
          .eq('is_active', true);

      if (type != null && type != 'ALL') {
        final dbType = type.toLowerCase() == 'themes'
            ? 'avatar_decoration'
            : type.toLowerCase() == 'badges'
                ? 'nameplate'
                : type.toLowerCase();
        query = query.eq('cosmetic_type', dbType);
      }

      final response = await query.order('created_at', ascending: false);

      var products = (response as List).map((j) => StoreProduct.fromJson(j)).toList();

      // If no products in DB, return sample products
      if (products.isEmpty) {
        return _getSampleProducts(type: type, search: search);
      }

      if (search != null && search.isNotEmpty) {
        products = products.where((p) =>
            p.name.toLowerCase().contains(search.toLowerCase())).toList();
      }

      return products;
    } catch (e) {
      // Return sample products on error
      return _getSampleProducts(type: type, search: search);
    }
  }

  List<StoreProduct> _getSampleProducts({String? type, String? search}) {
    final allProducts = [
      StoreProduct(id: '1', slug: 'neon-pulse', name: 'Neon Pulse', type: 'THEME', price: 4.99, rarity: 'epic', isHot: true, description: 'Vibrant neon colors that pulse with energy'),
      StoreProduct(id: '2', slug: 'cyber-glow', name: 'Cyber Glow', type: 'THEME', price: 3.99, rarity: 'rare', description: 'Futuristic cyberpunk aesthetic'),
      StoreProduct(id: '3', slug: 'midnight', name: 'Midnight', type: 'THEME', price: 0, rarity: 'common', description: 'Dark and elegant theme'),
      StoreProduct(id: '4', slug: 'flame-pack', name: 'Flame Pack', type: 'STICKERS', price: 1.99, rarity: 'rare', isHot: true, description: 'Hot flame sticker collection'),
      StoreProduct(id: '5', slug: 'space-vibes', name: 'Space Vibes', type: 'STICKERS', price: 2.49, rarity: 'epic', description: 'Cosmic sticker pack'),
      StoreProduct(id: '6', slug: 'retro-beeps', name: 'Retro Beeps', type: 'SOUNDS', price: 0.99, rarity: 'common', description: 'Retro notification sounds'),
      StoreProduct(id: '7', slug: 'og-badge', name: 'OG Badge', type: 'BADGE', price: 9.99, rarity: 'legendary', isHot: true, description: 'Original gangster badge'),
      StoreProduct(id: '8', slug: 'verified-plus', name: 'Verified+', type: 'BADGE', price: 14.99, rarity: 'legendary', description: 'Premium verified badge'),
      StoreProduct(id: '9', slug: 'aurora-borealis', name: 'Aurora Borealis', type: 'THEME', price: 6.99, rarity: 'legendary', isHot: true, description: 'Stunning northern lights theme'),
      StoreProduct(id: '10', slug: 'pixel-art', name: 'Pixel Art Pack', type: 'STICKERS', price: 2.99, rarity: 'rare', description: 'Retro pixel art stickers'),
      StoreProduct(id: '11', slug: 'synth-wave', name: 'Synthwave', type: 'THEME', price: 4.99, rarity: 'epic', description: '80s inspired synthwave theme'),
      StoreProduct(id: '12', slug: 'chill-beats', name: 'Chill Beats', type: 'SOUNDS', price: 1.49, rarity: 'rare', description: 'Relaxing notification sounds'),
    ];

    var filtered = allProducts;
    
    if (type != null && type != 'ALL') {
      final typeLower = type.toUpperCase();
      filtered = filtered.where((p) => p.type.toUpperCase() == typeLower).toList();
    }

    if (search != null && search.isNotEmpty) {
      filtered = filtered.where((p) =>
          p.name.toLowerCase().contains(search.toLowerCase())).toList();
    }

    return filtered;
  }

  Future<StoreProduct?> getProduct(String productId) async {
    try {
      final response = await _client
          .from('cosmetic_catalog')
          .select()
          .eq('id', productId)
          .maybeSingle();
      
      if (response != null) {
        return StoreProduct.fromJson(response);
      }
      // Return from sample products
      return _getSampleProducts().firstWhere((p) => p.id == productId);
    } catch (e) {
      return _getSampleProducts().firstWhere((p) => p.id == productId);
    }
  }

  Future<List<UserPurchase>> getUserPurchases() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return [];

      final response = await _client
          .from('user_cosmetics')
          .select('''
            id,
            cosmetic_id,
            unlocked_at,
            source,
            cosmetic:cosmetic_catalog (
              id,
              name,
              cosmetic_type,
              asset_url
            )
          ''')
          .eq('user_id', user.id)
          .order('unlocked_at', ascending: false);

      return (response as List).map((j) => UserPurchase.fromJson(j)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> purchaseProduct(StoreProduct product) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return false;

      await _client.from('user_cosmetics').insert({
        'user_id': user.id,
        'cosmetic_id': product.id,
        'source': 'purchase',
      });

      return true;
    } catch (e) {
      return false;
    }
  }
}

// Providers
final storeProductsProvider = FutureProvider.family<List<StoreProduct>, ({String? type, String? search})>((ref, params) async {
  final service = ref.watch(storeServiceProvider);
  return service.getProducts(type: params.type, search: params.search);
});

final userPurchasesProvider = FutureProvider<List<UserPurchase>>((ref) async {
  final service = ref.watch(storeServiceProvider);
  return service.getUserPurchases();
});

final productProvider = FutureProvider.family<StoreProduct?, String>((ref, productId) async {
  final service = ref.watch(storeServiceProvider);
  return service.getProduct(productId);
});

// Cart Provider
final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(CartNotifier.new);

class CartNotifier extends Notifier<List<CartItem>> {
  @override
  List<CartItem> build() => [];

  void add(StoreProduct product) {
    final index = state.indexWhere((item) => item.product.id == product.id);
    if (index >= 0) {
      state[index].quantity++;
      state = [...state];
    } else {
      state = [...state, CartItem(product: product)];
    }
  }

  void remove(String productId) {
    state = state.where((item) => item.product.id != productId).toList();
  }

  void updateQuantity(String productId, int quantity) {
    final index = state.indexWhere((item) => item.product.id == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        remove(productId);
      } else {
        state[index].quantity = quantity;
        state = [...state];
      }
    }
  }

  void clear() {
    state = [];
  }

  double get total => state.fold(0, (sum, item) => sum + (item.product.price * item.quantity));

  int get itemCount => state.fold(0, (sum, item) => sum + item.quantity);
}
