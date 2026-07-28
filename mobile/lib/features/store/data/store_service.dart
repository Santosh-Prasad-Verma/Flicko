import 'package:supabase_flutter/supabase_flutter.dart';
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
        if (typeLower == 'themes') {
          return pType == 'theme';
        } else if (typeLower == 'decorations' || typeLower == 'decoration' || typeLower == 'avatar_decoration') {
          return pType == 'avatar_decoration' || pType == 'decoration';
        } else if (typeLower == 'badges') {
          return pType == 'badge';
        } else if (typeLower == 'nameplates' || typeLower == 'nameplate') {
          return pType == 'nameplate';
        } else if (typeLower == 'voice_skins' || typeLower == 'voice_skin') {
          return pType == 'voice_skin';
        } else if (typeLower == 'warp_drips' || typeLower == 'warp_drip' || typeLower == 'entrance_warp' || typeLower == 'drip_card') {
          return pType == 'entrance_warp' || pType == 'drip_card';
        } else if (typeLower == 'sounds') {
          return pType == 'sounds' || pType == 'sound';
        } else if (typeLower == 'stickers') {
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
      // Premium Themes from cloned repos
      StoreProduct(id: 'sonic-drip', slug: 'sonic-drip', name: 'Sonic Drip', type: 'THEME', price: 399.0, rarity: 'legendary', isHot: true, description: 'The official Sonic Drip brutalist theme. Bold forest-green outlines on a solid black turntable canvas.'),
      StoreProduct(id: 'amoled-cord', slug: 'amoled-cord', name: 'AMOLED Cord', type: 'THEME', price: 249.0, rarity: 'epic', isHot: true, description: 'Ultra-dark AMOLED true-black theme with soft purple accents. Pure black saves battery on OLED screens.'),
      StoreProduct(id: 'dark-discord', slug: 'dark-discord', name: 'Dark Discord', type: 'THEME', price: 149.0, rarity: 'rare', isHot: true, description: 'Official Discord blurple on ultra-dark base. The darkest Discord experience with green accent highlights.'),
      StoreProduct(id: 'pm-theme', slug: 'pm-theme', name: 'PM Theme', type: 'THEME', price: 199.0, rarity: 'epic', description: 'Warm orange-amber tones on a rich dark brown base. Cozy and premium feel for late-night chatting.'),
      // Built-in themes
      StoreProduct(id: 'neon-pulse', slug: 'neon-pulse', name: 'Neon Pulse', type: 'THEME', price: 399.0, rarity: 'epic', isHot: true, description: 'Vibrant neon colors that pulse with energy'),
      StoreProduct(id: 'cyber-glow', slug: 'cyber-glow', name: 'Cyber Glow', type: 'THEME', price: 299.0, rarity: 'rare', description: 'Futuristic cyberpunk aesthetic'),
      StoreProduct(id: 'midnight', slug: 'midnight', name: 'Midnight', type: 'THEME', price: 0, rarity: 'common', description: 'Dark and elegant free theme'),
      StoreProduct(id: 'aurora-borealis', slug: 'aurora-borealis', name: 'Aurora Borealis', type: 'THEME', price: 549.0, rarity: 'legendary', isHot: true, description: 'Stunning northern lights theme'),
      StoreProduct(id: 'synthwave', slug: 'synthwave', name: 'Synthwave', type: 'THEME', price: 399.0, rarity: 'epic', description: '80s inspired synthwave theme'),
      StoreProduct(id: 'fire', slug: 'fire', name: 'Fire', type: 'THEME', price: 299.0, rarity: 'rare', description: 'Hot flames and warm embers'),

      // Sticker Packs — Emojis & Animated Stickers from assets
      StoreProduct(id: 'sticker-chaimal', slug: 'sticker-chaimal', name: 'Indian Classic Memes', type: 'STICKERS', price: 149.0, rarity: 'rare', isHot: true, description: 'Classic Indian meme stickers including Chapal Marunga, chal chal baap ko mat sikha, Mujhe Maaro, and cheekh ke scheme btade.', imageUrl: 'assets/images/emojis/emojis/static/cheekh_ke_scheme_btade.png'),
      StoreProduct(id: 'sticker-anime-dance', slug: 'sticker-anime-dance', name: 'Animated Anime Dance', type: 'STICKERS', price: 249.0, rarity: 'epic', isHot: true, description: 'Smooth looping retro and anime animated stickers including JotaroDance, kurukuru, ChikaBrow, and nachoo.', imageUrl: 'assets/images/emojis/emojis/animated/JotaroDance.gif'),
      StoreProduct(id: 'sticker-pepe-galactic', slug: 'sticker-pepe-galactic', name: 'Pepe Galactic Pack', type: 'STICKERS', price: 199.0, rarity: 'epic', description: 'The absolute premium cosmic Pepe collection: Pepe Galactic, Pepe Gaming, Pepe Anger, and monkas.', imageUrl: 'assets/images/emojis/emojis/static/PepeGalaxy.png'),
      StoreProduct(id: 'handy-emoji-panel', slug: 'handy-emoji-panel', name: 'Handy Emoji Panel', type: 'STICKERS', price: 249.0, rarity: 'epic', isHot: true, description: '246 premium stickers — cute, expressive, and animated. Perfect for every conversation.'),
      StoreProduct(id: 'flame-pack', slug: 'flame-pack', name: 'Flame Pack', type: 'STICKERS', price: 149.0, rarity: 'rare', description: 'Hot flame sticker collection'),
      StoreProduct(id: 'space-vibes', slug: 'space-vibes', name: 'Space Vibes', type: 'STICKERS', price: 199.0, rarity: 'epic', description: 'Cosmic sticker pack'),
      StoreProduct(id: 'pixel-art', slug: 'pixel-art', name: 'Pixel Art Pack', type: 'STICKERS', price: 249.0, rarity: 'rare', description: 'Retro pixel art stickers'),

      // Built-in sounds
      StoreProduct(id: 'myinstants-trending', slug: 'myinstants-trending', name: 'Trending Sounds', type: 'SOUNDS', price: 0, rarity: 'common', description: 'Free trending sound effects from MyInstants. Updated daily with the hottest sounds.'),
      StoreProduct(id: 'classic-memes', slug: 'classic-memes', name: 'Classic Memes', type: 'SOUNDS', price: 79.0, rarity: 'rare', isHot: true, description: 'Vine Boom, Bruh, Oof, Airhorn — the essential meme soundboard classics.'),
      StoreProduct(id: 'retro-beeps', slug: 'retro-beeps', name: 'Retro Beeps', type: 'SOUNDS', price: 79.0, rarity: 'common', description: 'Retro notification and game sounds'),

      // Badges
      StoreProduct(id: 'og-badge', slug: 'og-badge', name: 'OG Badge', type: 'BADGE', price: 799.0, rarity: 'legendary', isHot: true, description: 'Original gangster badge'),
      StoreProduct(id: 'verified-plus', slug: 'verified-plus', name: 'Verified+', type: 'BADGE', price: 1199.0, rarity: 'legendary', description: 'Premium verified badge'),
      StoreProduct(id: 'premium-star', slug: 'premium-star', name: 'Premium Star', type: 'BADGE', price: 249.0, rarity: 'epic', description: 'A sparkling green star badge for premium users.'),
      StoreProduct(id: 'bolt-master', slug: 'bolt-master', name: 'Bolt Master', type: 'BADGE', price: 299.0, rarity: 'rare', description: 'An electrical yellow bolt badge for energetic chatters.'),
      StoreProduct(id: 'diamond-elite', slug: 'diamond-elite', name: 'Diamond Elite', type: 'BADGE', price: 499.0, rarity: 'epic', description: 'A sleek purple diamond badge for elite members.'),
      StoreProduct(id: 'cosmic-overlord-badge', slug: 'cosmic-overlord-badge', name: 'Cosmic Overlord', type: 'BADGE', price: 0.0, rarity: 'legendary', description: 'An elite mythic badge forged in the alchemical fusion core.'),
      StoreProduct(id: 'alchemist-badge', slug: 'alchemist-badge', name: 'Badge Alchemist', type: 'BADGE', price: 0.0, rarity: 'legendary', description: 'A mystical shifting badge awarded to master alchemists.'),
      StoreProduct(id: 'soundboard-dj', slug: 'soundboard-dj', name: 'Soundboard DJ', type: 'BADGE', price: 0.0, rarity: 'rare', description: 'Awarded for playing a massive amount of soundboard effects.'),
      StoreProduct(id: 'chat-veteran-badge', slug: 'chat-veteran-badge', name: 'Chat Veteran', type: 'BADGE', price: 0.0, rarity: 'epic', description: 'Awarded for sending a massive amount of chat messages.'),

      // Special Gacha & Styling Bundles
      StoreProduct(id: 'mystery-crate', slug: 'mystery-crate', name: 'Mystery Vinyl Crate', type: 'CRATE', price: 149.0, rarity: 'epic', isHot: true, description: 'Decelerating turntable needle-drop gacha spin. Unlocks one premium Rare, Epic, or Legendary cosmetic item!'),
      StoreProduct(id: 'sonic-cyber-bundle', slug: 'sonic-cyber-bundle', name: 'Sonic Cyber Bundle', type: 'BUNDLE', price: 599.0, rarity: 'legendary', isHot: true, description: 'Includes Sonic Drip Theme, OG Badge, and Classic Memes Soundboard. Save 55% over individual purchases!'),

      // Animated Avatar Decorations / Profile Frames
      StoreProduct(id: 'neon-cyber-frame', slug: 'neon-cyber-frame', name: 'Neon Cyber Frame', type: 'AVATAR_DECORATION', price: 299.0, rarity: 'epic', isHot: true, description: 'Radioactive sweep gradient revolving around your avatar container in a fluid neon pulse.'),
      StoreProduct(id: 'glitch-matrix-frame', slug: 'glitch-matrix-frame', name: 'Glitch Matrix Frame', type: 'AVATAR_DECORATION', price: 499.0, rarity: 'legendary', isHot: true, description: 'Flickering matrix code stream wrapping your profile in erratic chromatic visual offsets.'),
      StoreProduct(id: 'cosmic-orbit-frame', slug: 'cosmic-orbit-frame', name: 'Cosmic Orbit Frame', type: 'AVATAR_DECORATION', price: 399.0, rarity: 'legendary', description: 'Revolving tiny orbital spheres rotating on double-ring coordinates around your avatar.'),
      StoreProduct(id: 'fire-ring-frame', slug: 'fire-ring-frame', name: 'Fire Aura Frame', type: 'AVATAR_DECORATION', price: 249.0, rarity: 'rare', description: 'Dynamic glowing orange heat aura that pulses and expands outwards with fire ember elements.'),
      StoreProduct(id: 'rainbow-pulse-frame', slug: 'rainbow-pulse-frame', name: 'Rainbow Pulse Frame', type: 'AVATAR_DECORATION', price: 279.0, rarity: 'epic', description: 'Looping hue-spectrum gradient color sweep that flows in a continuous spectrum wave.'),

      // Kinetic Nameplates / Text Drips
      StoreProduct(id: 'glitch-matrix-tag', slug: 'glitch-matrix-tag', name: 'Glitch Matrix Tag', type: 'NAMEPLATE', price: 499.0, rarity: 'legendary', isHot: true, description: 'Chaoitc, erratically flickering green-magenta pixel-shifts formatting your name tag.'),
      StoreProduct(id: 'neon-cyber-tag', slug: 'neon-cyber-tag', name: 'Neon Cyber Tag', type: 'NAMEPLATE', price: 299.0, rarity: 'epic', isHot: true, description: 'A vibrant radioactive neon tag outlining your name text with high contrast breathing glows.'),
      StoreProduct(id: 'fire-pulse-tag', slug: 'fire-pulse-tag', name: 'Fire Aura Tag', type: 'NAMEPLATE', price: 249.0, rarity: 'rare', description: 'Combustive orange flaming embers pulsing dynamically behind your user name text.'),
      StoreProduct(id: 'gold-spark-tag', slug: 'gold-spark-tag', name: 'Gold Specular Tag', type: 'NAMEPLATE', price: 399.0, rarity: 'legendary', description: 'Shining specular golden beams sweeping continuously across your uppercase lettering.'),
      StoreProduct(id: 'rainbow-drip-tag', slug: 'rainbow-drip-tag', name: 'Rainbow Drip Tag', type: 'NAMEPLATE', price: 279.0, rarity: 'epic', description: 'Continuous looping hue-spectrum color wave flowing beautifully across your tag.'),

      // Premium Voice Skins / Audio Filters & Waveforms
      StoreProduct(id: '8bit-arcade-skin', slug: '8bit-arcade-skin', name: '8-Bit Arcade Skin', type: 'VOICE_SKIN', price: 299.0, rarity: 'epic', isHot: true, description: 'Adds retro bitcrushed chiptune texture and bounces a sharp neon grid visualizer on your voice clips.'),
      StoreProduct(id: 'retro-radio-skin', slug: 'retro-radio-skin', name: 'Retro Radio Skin', type: 'VOICE_SKIN', price: 149.0, rarity: 'rare', description: 'Filters your voice with narrow AM radio warmth and record scratches, paired with an oscilloscope wave visualizer.'),
      StoreProduct(id: 'lofi-tape-skin', slug: 'lofi-tape-skin', name: 'Lofi Tape Skin', type: 'VOICE_SKIN', price: 249.0, rarity: 'epic', isHot: true, description: 'Injects pitch wow-and-flutter wiggles and warm tape saturation, complete with a flowing orange ember waveform.'),
      StoreProduct(id: 'cyber-vocoder-skin', slug: 'cyber-vocoder-skin', name: 'Cyber Vocoder Skin', type: 'VOICE_SKIN', price: 499.0, rarity: 'legendary', isHot: true, description: 'Synthesizes your voice note with robotic vocoder chimes, rendering falling matrix binary codes on bounce.'),

      // Premium Entrance Warps
      StoreProduct(id: 'cyber-matrix-warp', slug: 'cyber-matrix-warp', name: 'Cyber Matrix Warp', type: 'ENTRANCE_WARP', price: 399.0, rarity: 'epic', isHot: true, description: 'Green cascading matrix rain columns dissolving beautifully across the entire chat layout when you enter.'),
      StoreProduct(id: 'grid-explosion-warp', slug: 'grid-explosion-warp', name: 'Grid Expansion Warp', type: 'ENTRANCE_WARP', price: 299.0, rarity: 'epic', description: 'Synthwave wobbly wireframe vector grid expanding and exploding outwards in 3D scale upon entering chat.'),
      StoreProduct(id: 'neon-rift-warp', slug: 'neon-rift-warp', name: 'Neon Rift Warp', type: 'ENTRANCE_WARP', price: 499.0, rarity: 'legendary', isHot: true, description: 'Screen splits open from the center with cyan-magenta electric lightning sparks and bolts on entering.'),

      // Premium Message Drip Cards
      StoreProduct(id: 'toxic-hazard-card', slug: 'toxic-hazard-card', name: 'Toxic Hazard Card', type: 'DRIP_CARD', price: 279.0, rarity: 'epic', description: 'Dresses your message text bubble in a radioactive lime dashed border with custom corner hazard stripe blocks.'),
      StoreProduct(id: 'cyber-glitch-card', slug: 'cyber-glitch-card', name: 'Cyber Glitch Card', type: 'DRIP_CARD', price: 399.0, rarity: 'epic', isHot: true, description: 'Surrounds your message cards with overlapping cyan-magenta double borders that glitch and jitter periodically.'),
      StoreProduct(id: 'specular-gold-card', slug: 'specular-gold-card', name: 'Gold Metal Card', type: 'DRIP_CARD', price: 549.0, rarity: 'legendary', isHot: true, description: 'Forges a solid reflective gold border around your messages with an automated looping metallic specular glint sweep.'),
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
