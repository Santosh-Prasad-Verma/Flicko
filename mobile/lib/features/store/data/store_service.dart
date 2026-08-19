import 'package:mobile/data/clients/supabase_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
  List<StoreProduct>? _cachedProducts;

  StoreService(this._client);

  Future<List<StoreProduct>> getProducts({String? type, String? search}) async {
    List<StoreProduct> products;
    if (_cachedProducts != null) {
      products = _cachedProducts!;
    } else {
      try {
        var query = _client
            .from('cosmetic_catalog')
            .select()
            .eq('is_active', true);

        final response = await query.order('created_at', ascending: false);
        products = (response as List).map((j) => StoreProduct.fromJson(j)).toList();

        // Always merge local sample products (like themes & new stickers) that are not present in the DB catalog
        final sampleProducts = getSampleProducts();
        final dbProductSlugs = products.map((p) => p.slug.toLowerCase()).toSet();
        
        products = List<StoreProduct>.from(products);
        for (final sample in sampleProducts) {
          if (!dbProductSlugs.contains(sample.slug.toLowerCase())) {
            products.add(sample);
          }
        }

        // Auto-convert any remote DB products with low prices (USD) to our beautiful custom INR values
        final samplePriceMap = {for (var p in sampleProducts) p.id: p.price};
        for (var i = 0; i < products.length; i++) {
          final p = products[i];
          if (p.price > 0 && p.price <= 25.0) {
            final samplePrice = samplePriceMap[p.id];
            final newPrice = samplePrice ?? (p.price * 80).roundToDouble();
            products[i] = StoreProduct(
              id: p.id,
              slug: p.slug,
              name: p.name,
              type: p.type,
              description: p.description,
              price: newPrice,
              imageUrl: p.imageUrl,
              previewUrl: p.previewUrl,
              rarity: p.rarity,
              isHot: p.isHot,
              isActive: p.isActive,
            );
          }
        }

        _cachedProducts = products;
      } catch (e) {
        products = getSampleProducts();
        _cachedProducts = products;
      }
    }

    var filtered = products;

    if (type != null && type != 'ALL') {
      final typeLower = type.toLowerCase();
      filtered = filtered.where((p) {
        final pType = p.type.toLowerCase();
        if (typeLower == 'themes' || typeLower == 'theme') {
          return pType == 'theme' || pType == 'profile_theme' || pType == 'gradient';
        } else if (typeLower == 'decorations' || typeLower == 'decoration' || typeLower == 'avatar_decoration') {
          return pType == 'avatar_decoration' || pType == 'decoration';
        } else if (typeLower == 'banners' || typeLower == 'banner' || typeLower == 'profile_banner') {
          return pType == 'profile_banner' || pType == 'banner';
        } else if (typeLower == 'effects' || typeLower == 'effect' || typeLower == 'profile_effect') {
          return pType == 'profile_effect' || pType == 'effect';
        } else if (typeLower == 'badges' || typeLower == 'badge') {
          return pType == 'badge';
        } else if (typeLower == 'nameplates' || typeLower == 'nameplate') {
          return pType == 'nameplate';
        } else if (typeLower == 'voice_skins' || typeLower == 'voice_skin') {
          return pType == 'voice_skin';
        } else if (typeLower == 'warp_drips' || typeLower == 'warp_drip' || typeLower == 'entrance_warp' || typeLower == 'drip_card') {
          return pType == 'entrance_warp' || pType == 'drip_card';
        } else if (typeLower == 'sounds' || typeLower == 'sound') {
          return pType == 'sounds' || pType == 'sound';
        } else if (typeLower == 'stickers' || typeLower == 'sticker') {
          return pType == 'stickers' || pType == 'sticker';
        }
        return pType == typeLower;
      }).toList();
    }

    if (search != null && search.isNotEmpty) {
      filtered = filtered.where((p) =>
          p.name.toLowerCase().contains(search.toLowerCase())).toList();
    }

    return filtered;
  }

  List<StoreProduct> getSampleProducts({String? type, String? search}) {
    final allProducts = [
      // 1. AVATAR DECORATIONS (Profile Picture Frames & Rings)
      StoreProduct(id: 'neon-cyber-frame', slug: 'neon-cyber-frame', name: 'Neon Cyber Ring', type: 'AVATAR_DECORATION', price: 299.0, rarity: 'epic', isHot: true, description: 'Radioactive green & cyan sweep gradient revolving dynamically around your avatar.'),
      StoreProduct(id: 'sakura-aura', slug: 'sakura-aura', name: 'Sakura Blossom Aura', type: 'AVATAR_DECORATION', price: 349.0, rarity: 'epic', isHot: true, description: 'Soft pink sakura petals and glowing floral shimmer encircling your profile avatar.'),
      StoreProduct(id: 'dragon-fire-frame', slug: 'dragon-fire-frame', name: 'Dragon Flame Burst', type: 'AVATAR_DECORATION', price: 399.0, rarity: 'legendary', isHot: true, description: 'Combustive orange and red heat embers pulsing vigorously with fire energy.'),
      StoreProduct(id: 'cyberpunk-visor', slug: 'cyberpunk-visor', name: 'Cyber Visor & HUD', type: 'AVATAR_DECORATION', price: 449.0, rarity: 'legendary', isHot: true, description: 'Futuristic cyan HUD visor with digital target reticles scanning your avatar.'),
      StoreProduct(id: 'golden-crown', slug: 'golden-crown', name: 'Imperial Gold Crown', type: 'AVATAR_DECORATION', price: 499.0, rarity: 'legendary', isHot: true, description: 'Majestic golden crown floating with shimmering specular sparkles over your profile.'),
      StoreProduct(id: 'glitch-matrix-frame', slug: 'glitch-matrix-frame', name: 'Glitch Matrix Frame', type: 'AVATAR_DECORATION', price: 499.0, rarity: 'legendary', isHot: true, description: 'Flickering matrix code stream wrapping your profile in erratic chromatic visual offsets.'),
      StoreProduct(id: 'cosmic-orbit-frame', slug: 'cosmic-orbit-frame', name: 'Cosmic Orbit Frame', type: 'AVATAR_DECORATION', price: 399.0, rarity: 'legendary', description: 'Revolving tiny orbital spheres rotating on double-ring coordinates around your avatar.'),
      StoreProduct(id: 'pixel-glitch', slug: 'pixel-glitch', name: 'Chromatic Pixel Glitch', type: 'AVATAR_DECORATION', price: 299.0, rarity: 'rare', description: 'Retro 8-bit pixel shifts and color channel split jitter around your avatar.'),
      StoreProduct(id: 'anime-sparkles', slug: 'anime-sparkles', name: 'Kawaii Star Sparkles', type: 'AVATAR_DECORATION', price: 249.0, rarity: 'rare', description: 'Cute sparkling anime stars and twinkling glimmers shining around your avatar.'),
      StoreProduct(id: 'void-vortex', slug: 'void-vortex', name: 'Void Gravity Well', type: 'AVATAR_DECORATION', price: 549.0, rarity: 'legendary', isHot: true, description: 'Deep cosmic singularity pulling purple event-horizon particle trails inward.'),
      StoreProduct(id: 'rainbow-pulse-frame', slug: 'rainbow-pulse-frame', name: 'Rainbow Spectrum Wave', type: 'AVATAR_DECORATION', price: 279.0, rarity: 'epic', description: 'Looping hue-spectrum gradient color sweep that flows in a continuous spectrum wave.'),

      // 2. PROFILE BANNERS (Header Backgrounds)
      StoreProduct(id: 'banner-nebula', slug: 'banner-nebula', name: 'Cosmic Pink Nebula', type: 'PROFILE_BANNER', price: 249.0, rarity: 'epic', isHot: true, description: 'Deep purple space filled with vibrant magenta star clusters and glowing celestial gas.'),
      StoreProduct(id: 'banner-synthwave', slug: 'banner-synthwave', name: 'Retrowave Grid Sunset', type: 'PROFILE_BANNER', price: 299.0, rarity: 'epic', isHot: true, description: 'Neon wireframe 3D grid stretching towards a blazing 80s synthwave vector sun.'),
      StoreProduct(id: 'banner-cybercity', slug: 'banner-cybercity', name: 'Neo-Tokyo Cyber Rain', type: 'PROFILE_BANNER', price: 349.0, rarity: 'legendary', isHot: true, description: 'Rain-soaked futuristic cyberpunk city glowing with neon Japanese billboard reflections.'),
      StoreProduct(id: 'banner-deep-sea', slug: 'banner-deep-sea', name: 'Bioluminescent Abyss', type: 'PROFILE_BANNER', price: 199.0, rarity: 'rare', description: 'Mystical deep ocean waters shimmering with cyan bioluminescent jellyfish currents.'),
      StoreProduct(id: 'banner-pixel-dungeon', slug: 'banner-pixel-dungeon', name: '16-Bit Pixel Dungeon', type: 'PROFILE_BANNER', price: 299.0, rarity: 'epic', description: 'Detailed retro pixel art castle with torchlights and dramatic moonlit clouds.'),
      StoreProduct(id: 'banner-liquid-gold', slug: 'banner-liquid-gold', name: 'Molten Liquid Gold', type: 'PROFILE_BANNER', price: 399.0, rarity: 'legendary', isHot: true, description: 'Lustrous molten golden waves flowing smoothly with high-contrast metallic speculars.'),
      StoreProduct(id: 'banner-sakura-night', slug: 'banner-sakura-night', name: 'Midnight Cherry Blossom', type: 'PROFILE_BANNER', price: 249.0, rarity: 'rare', description: 'Full moon casting silver moonlight over dark cherry blossom trees in full bloom.'),

      // 3. PROFILE EFFECTS & INTROS (Special Particle Overlay Animations)
      StoreProduct(id: 'effect-cherry-blossoms', slug: 'effect-cherry-blossoms', name: 'Falling Sakura Petals', type: 'PROFILE_EFFECT', price: 299.0, rarity: 'epic', isHot: true, description: 'Gentle breeze drifting pink cherry blossom petals continuously across your profile card.'),
      StoreProduct(id: 'effect-matrix-code', slug: 'effect-matrix-code', name: 'Matrix Binary Code Rain', type: 'PROFILE_EFFECT', price: 399.0, rarity: 'legendary', isHot: true, description: 'Cascading digital green binary glyphs falling smoothly from the top of your profile.'),
      StoreProduct(id: 'effect-electric-sparks', slug: 'effect-electric-sparks', name: 'High-Voltage Lightning Arcs', type: 'PROFILE_EFFECT', price: 349.0, rarity: 'legendary', description: 'Cyan and violet electrical discharges dancing around your profile banner and card.'),
      StoreProduct(id: 'effect-cosmic-dust', slug: 'effect-cosmic-dust', name: 'Golden Cosmic Star Dust', type: 'PROFILE_EFFECT', price: 299.0, rarity: 'epic', description: 'Floating golden stardust particles rising softly with warm ambient lighting.'),

      // 4. PROFILE THEMES & COLOR GRADIENTS (App Theme & Card Shading)
      StoreProduct(id: 'gradient-midnight-violet', slug: 'gradient-midnight-violet', name: 'Midnight Violet Gradient', type: 'THEME', price: 199.0, rarity: 'rare', isHot: true, description: 'Smooth deep obsidian to electric violet gradient shading for your profile card.'),
      StoreProduct(id: 'gradient-cyber-pink', slug: 'gradient-cyber-pink', name: 'Cyberpunk Magenta-Cyan', type: 'THEME', price: 249.0, rarity: 'epic', isHot: true, description: 'High-energy neon pink transitioning into bright cyan blue profile theme.'),
      StoreProduct(id: 'gradient-sunset-blaze', slug: 'gradient-sunset-blaze', name: 'Sunset Amber Blaze', type: 'THEME', price: 249.0, rarity: 'epic', description: 'Rich fiery crimson melting into warm golden amber sunset gradients.'),
      StoreProduct(id: 'gradient-emerald-matrix', slug: 'gradient-emerald-matrix', name: 'Emerald Matrix Green', type: 'THEME', price: 199.0, rarity: 'rare', description: 'Deep dark forest green blending with vibrant lime matrix accents.'),
      StoreProduct(id: 'gradient-platinum-lux', slug: 'gradient-platinum-lux', name: 'Platinum Pearl Glow', type: 'THEME', price: 349.0, rarity: 'legendary', description: 'Sleek metallic silver and pearl white luxurious profile gradient.'),
      StoreProduct(id: 'sonic-drip', slug: 'sonic-drip', name: 'Sonic Drip Theme', type: 'THEME', price: 399.0, rarity: 'legendary', isHot: true, description: 'The official Sonic Drip brutalist theme. Bold forest-green outlines on a solid black canvas.'),
      StoreProduct(id: 'amoled-cord', slug: 'amoled-cord', name: 'AMOLED Cord Theme', type: 'THEME', price: 249.0, rarity: 'epic', isHot: true, description: 'Ultra-dark AMOLED true-black theme with soft purple accents.'),
      StoreProduct(id: 'dark-discord', slug: 'dark-discord', name: 'Dark Discord Theme', type: 'THEME', price: 149.0, rarity: 'rare', description: 'Official Discord blurple on ultra-dark base with green accent highlights.'),
      StoreProduct(id: 'pm-theme', slug: 'pm-theme', name: 'PM Amber Theme', type: 'THEME', price: 199.0, rarity: 'epic', description: 'Warm orange-amber tones on a rich dark brown base.'),
      StoreProduct(id: 'neon-pulse', slug: 'neon-pulse', name: 'Neon Pulse Theme', type: 'THEME', price: 399.0, rarity: 'epic', description: 'Vibrant neon colors that pulse with energy.'),
      StoreProduct(id: 'aurora-borealis', slug: 'aurora-borealis', name: 'Aurora Borealis Theme', type: 'THEME', price: 549.0, rarity: 'legendary', isHot: true, description: 'Stunning northern lights theme with emerald and violet glows.'),
      StoreProduct(id: 'synthwave', slug: 'synthwave', name: 'Synthwave Theme', type: 'THEME', price: 399.0, rarity: 'epic', description: '80s inspired synthwave theme.'),
      StoreProduct(id: 'midnight', slug: 'midnight', name: 'Midnight Default', type: 'THEME', price: 0, rarity: 'common', description: 'Dark and elegant default theme.'),

      // 5. NAMEPLATES (Kinetic Username Styling)
      StoreProduct(id: 'glitch-matrix-tag', slug: 'glitch-matrix-tag', name: 'Glitch Matrix Nameplate', type: 'NAMEPLATE', price: 499.0, rarity: 'legendary', isHot: true, description: 'Erratic green-magenta pixel shifts and digital glitch effect on your name tag.'),
      StoreProduct(id: 'neon-cyber-tag', slug: 'neon-cyber-tag', name: 'Neon Cyber Nameplate', type: 'NAMEPLATE', price: 299.0, rarity: 'epic', isHot: true, description: 'Radioactive neon outline with breathing glow around your username text.'),
      StoreProduct(id: 'fire-pulse-tag', slug: 'fire-pulse-tag', name: 'Fire Aura Nameplate', type: 'NAMEPLATE', price: 249.0, rarity: 'rare', description: 'Flaming orange embers pulsing dynamically behind your username lettering.'),
      StoreProduct(id: 'gold-spark-tag', slug: 'gold-spark-tag', name: 'Gold Specular Nameplate', type: 'NAMEPLATE', price: 399.0, rarity: 'legendary', description: 'Reflective gold metallic sheen sweeping continuously across your nameplate.'),
      StoreProduct(id: 'rainbow-drip-tag', slug: 'rainbow-drip-tag', name: 'Rainbow Wave Nameplate', type: 'NAMEPLATE', price: 279.0, rarity: 'epic', description: 'Looping hue-spectrum color wave flowing across your name tag.'),
      StoreProduct(id: 'vampire-goth-tag', slug: 'vampire-goth-tag', name: 'Goth Crimson Nameplate', type: 'NAMEPLATE', price: 349.0, rarity: 'epic', description: 'Dark blood-red gothic outline with subtle mist animations.'),

      // 6. BADGES (Equippable Profile Badges)
      StoreProduct(id: 'og-badge', slug: 'og-badge', name: 'OG Master Badge', type: 'BADGE', price: 799.0, rarity: 'legendary', isHot: true, description: 'Original early supporter master badge with purple glowing border.'),
      StoreProduct(id: 'verified-plus', slug: 'verified-plus', name: 'Verified+ Badge', type: 'BADGE', price: 1199.0, rarity: 'legendary', description: 'Official verified creator checkmark with diamond glow.'),
      StoreProduct(id: 'premium-star', slug: 'premium-star', name: 'Premium Star Badge', type: 'BADGE', price: 249.0, rarity: 'epic', description: 'Sparkling green star badge for active community supporters.'),
      StoreProduct(id: 'bolt-master', slug: 'bolt-master', name: 'Lightning Bolt Badge', type: 'BADGE', price: 299.0, rarity: 'rare', description: 'Electrical yellow bolt badge for energetic chatters.'),
      StoreProduct(id: 'diamond-elite', slug: 'diamond-elite', name: 'Diamond Elite Badge', type: 'BADGE', price: 499.0, rarity: 'epic', description: 'Sleek royal purple diamond badge for elite members.'),
      StoreProduct(id: 'cosmic-overlord-badge', slug: 'cosmic-overlord-badge', name: 'Cosmic Overlord Badge', type: 'BADGE', price: 899.0, rarity: 'legendary', description: 'Mythic galaxy emblem forged in cosmic starfire.'),
      StoreProduct(id: 'alchemist-badge', slug: 'alchemist-badge', name: 'Badge Alchemist', type: 'BADGE', price: 599.0, rarity: 'legendary', description: 'Mystical shifting alchemy emblem awarded to master creators.'),

      // 7. STICKERS & SOUNDBOARDS
      StoreProduct(id: 'sticker-chaimal', slug: 'sticker-chaimal', name: 'Indian Classic Memes', type: 'STICKERS', price: 149.0, rarity: 'rare', isHot: true, description: 'Classic Indian meme stickers including Chapal Marunga, chal chal baap ko mat sikha, and Mujhe Maaro.', imageUrl: 'assets/images/emojis/emojis/static/cheekh_ke_scheme_btade.png'),
      StoreProduct(id: 'sticker-anime-dance', slug: 'sticker-anime-dance', name: 'Animated Anime Dance', type: 'STICKERS', price: 249.0, rarity: 'epic', isHot: true, description: 'Smooth looping retro and anime animated stickers including JotaroDance and kurukuru.', imageUrl: 'assets/images/emojis/emojis/animated/JotaroDance.gif'),
      StoreProduct(id: 'sticker-pepe-galactic', slug: 'sticker-pepe-galactic', name: 'Pepe Galactic Pack', type: 'STICKERS', price: 199.0, rarity: 'epic', description: 'The absolute premium cosmic Pepe collection.', imageUrl: 'assets/images/emojis/emojis/static/PepeGalaxy.png'),
      StoreProduct(id: 'handy-emoji-panel', slug: 'handy-emoji-panel', name: 'Handy Emoji Panel (246 Stickers)', type: 'STICKERS', price: 249.0, rarity: 'epic', isHot: true, description: '246 premium stickers — cute, expressive, and animated. Perfect for every conversation.'),

      // 8. SOUNDS & CRATES
      StoreProduct(id: 'classic-memes', slug: 'classic-memes', name: 'Classic Memes Soundboard', type: 'SOUNDS', price: 79.0, rarity: 'rare', isHot: true, description: 'Vine Boom, Bruh, Oof, Airhorn — essential meme soundboard classics.'),
      StoreProduct(id: 'mystery-crate', slug: 'mystery-crate', name: 'Mystery Cosmetic Crate', type: 'CRATE', price: 149.0, rarity: 'epic', isHot: true, description: 'Gacha spin unlocking one premium Rare, Epic, or Legendary cosmetic item!'),
      StoreProduct(id: 'sonic-cyber-bundle', slug: 'sonic-cyber-bundle', name: 'Sonic Cyber Ultimate Bundle', type: 'BUNDLE', price: 599.0, rarity: 'legendary', isHot: true, description: 'Includes Sonic Drip Theme, OG Badge, Neon Ring Decoration, and Classic Memes. Save 55%!'),
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
        final p = StoreProduct.fromJson(response);
        // Auto-convert price to matching sample price or to rounded INR
        if (p.price > 0 && p.price <= 25.0) {
          final sampleProducts = getSampleProducts();
          final samplePriceMap = {for (var s in sampleProducts) s.id: s.price};
          final samplePrice = samplePriceMap[p.id];
          final newPrice = samplePrice ?? (p.price * 80).roundToDouble();
          return StoreProduct(
            id: p.id,
            slug: p.slug,
            name: p.name,
            type: p.type,
            description: p.description,
            price: newPrice,
            imageUrl: p.imageUrl,
            previewUrl: p.previewUrl,
            rarity: p.rarity,
            isHot: p.isHot,
            isActive: p.isActive,
          );
        }
        return p;
      }
      // Return from sample products
      return getSampleProducts().firstWhere((p) => p.id == productId);
    } catch (e) {
      try {
        return getSampleProducts().firstWhere((p) => p.id == productId);
      } catch (_) {
        return null;
      }
    }
  }

  Future<List<UserPurchase>> _loadLocalPurchases() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = prefs.getString('local_user_purchases');
      if (data == null) {
        // Pre-populate with free items (Midnight theme, Trending sounds)
        final freeMidnight = UserPurchase(
          id: 'local_midnight_purchase',
          productId: 'midnight',
          productName: 'Midnight',
          productType: 'THEME',
          purchasedAt: DateTime.now(),
          price: 0,
        );
        final freeSounds = UserPurchase(
          id: 'local_sounds_purchase',
          productId: 'myinstants-trending',
          productName: 'Trending Sounds',
          productType: 'SOUNDS',
          purchasedAt: DateTime.now(),
          price: 0,
        );
        final initial = [freeMidnight, freeSounds];
        await _saveLocalPurchases(initial);
        return initial;
      }
      final list = jsonDecode(data) as List;
      return list.map((item) => UserPurchase(
        id: item['id'] as String,
        productId: item['productId'] as String,
        productName: item['productName'] as String,
        productType: item['productType'] as String,
        purchasedAt: DateTime.parse(item['purchasedAt'] as String),
        price: (item['price'] as num).toDouble(),
        imageUrl: item['imageUrl'] as String?,
      )).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _saveLocalPurchases(List<UserPurchase> purchases) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = purchases.map((p) => {
        'id': p.id,
        'productId': p.productId,
        'productName': p.productName,
        'productType': p.productType,
        'purchasedAt': p.purchasedAt.toIso8601String(),
        'price': p.price,
        'imageUrl': p.imageUrl,
      }).toList();
      await prefs.setString('local_user_purchases', jsonEncode(list));
    } catch (_) {}
  }

  Future<List<UserPurchase>> getUserPurchases() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        return _loadLocalPurchases();
      }

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

      final supabasePurchases = (response as List).map((j) => UserPurchase.fromJson(j)).toList();
      
      // Merge with local purchases so offline test items show up as well
      final localPurchases = await _loadLocalPurchases();
      final merged = <String, UserPurchase>{};
      for (final p in localPurchases) {
        merged[p.productId] = p;
      }
      for (final p in supabasePurchases) {
        merged[p.productId] = p;
      }
      return merged.values.toList();
    } catch (e) {
      return _loadLocalPurchases();
    }
  }

  Future<bool> purchaseProduct(StoreProduct product) async {
    if (product.id == 'sonic-cyber-bundle') {
      try {
        final themeProd = getSampleProducts().firstWhere((p) => p.id == 'sonic-drip');
        final badgeProd = getSampleProducts().firstWhere((p) => p.id == 'og-badge');
        final soundsProd = getSampleProducts().firstWhere((p) => p.id == 'classic-memes');
        await purchaseProduct(themeProd);
        await purchaseProduct(badgeProd);
        await purchaseProduct(soundsProd);
      } catch (_) {}
    }

    try {
      final local = await _loadLocalPurchases();
      if (!local.any((p) => p.productId == product.id)) {
        final newPurchase = UserPurchase(
          id: 'local_${product.id}_${DateTime.now().millisecondsSinceEpoch}',
          productId: product.id,
          productName: product.name,
          productType: product.type,
          purchasedAt: DateTime.now(),
          price: product.price,
          imageUrl: product.imageUrl,
        );
        await _saveLocalPurchases([...local, newPurchase]);
      }
    } catch (_) {}

    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        await _client.from('user_cosmetics').insert({
          'user_id': user.id,
          'cosmetic_id': product.id,
          'source': 'purchase',
        });
      }
      return true;
    } catch (e) {
      // If offline/error, local succeeded so return true
      return true;
    }
  }

  Future<bool> giftProduct(StoreProduct product, String recipientId, String recipientName) async {
    try {
      final local = await _loadLocalPurchases();
      final newPurchase = UserPurchase(
        id: 'gift_${product.id}_${recipientId}_${DateTime.now().millisecondsSinceEpoch}',
        productId: product.id,
        productName: '${product.name} (Gift to $recipientName)',
        productType: product.type,
        purchasedAt: DateTime.now(),
        price: product.price,
        imageUrl: product.imageUrl,
      );
      await _saveLocalPurchases([...local, newPurchase]);
    } catch (_) {}

    try {
      final user = _client.auth.currentUser;
      if (user != null) {
        await _client.from('user_cosmetics').insert({
          'user_id': recipientId,
          'cosmetic_id': product.id,
          'source': 'gift',
          'metadata': {
            'gifted_by': user.id,
          },
        });
      }
      return true;
    } catch (e) {
      return true;
    }
  }

  StoreProduct getRandomGachaReward() {
    final pool = getSampleProducts().where((p) =>
      p.id != 'mystery-crate' &&
      p.id != 'sonic-cyber-bundle' &&
      p.price > 0
    ).toList();
    
    if (pool.isEmpty) {
      return StoreProduct(
        id: 'classic-memes',
        slug: 'classic-memes',
        name: 'Classic Memes',
        type: 'SOUNDS',
        price: 0.99,
        rarity: 'rare',
        description: 'Classic memes soundboard',
      );
    }
    
    final rand = DateTime.now().millisecondsSinceEpoch % 100;
    String targetRarity = 'rare';
    if (rand < 15) {
      targetRarity = 'legendary';
    } else if (rand < 50) {
      targetRarity = 'epic';
    }
    
    final matching = pool.where((p) => p.rarity.toLowerCase() == targetRarity).toList();
    if (matching.isNotEmpty) {
      return matching[DateTime.now().millisecondsSinceEpoch % matching.length];
    }
    return pool[DateTime.now().millisecondsSinceEpoch % pool.length];
  }
}

class CouponInfo {
  final String code;
  final double discountPercent;
  final String description;

  const CouponInfo({
    required this.code,
    required this.discountPercent,
    required this.description,
  });
}

// Providers
final activeCouponProvider = StateProvider<CouponInfo?>((ref) => null);

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
