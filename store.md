# 🏪 Flicko Store — Technical Documentation

> **The Premium Cosmetics Marketplace — Themes, Badges, Sounds, and Beyond**

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [File Structure](#file-structure)
- [Data Models](#data-models)
- [Core Service — StoreService](#core-service--storeservice)
- [Cart System](#cart-system)
- [Product Categories](#product-categories)
- [Specialized Sub-Stores](#specialized-sub-stores)
- [Gacha System](#gacha-system)
- [Badge Alchemy](#badge-alchemy)
- [Cosmetic Fusion](#cosmetic-fusion)
- [Purchase Flow](#purchase-flow)
- [Main Store Screen](#main-store-screen)
- [Product Detail Screen](#product-detail-screen)
- [Cart Screen](#cart-screen)
- [Inventory Screen](#inventory-screen)
- [Theme Picker](#theme-picker)
- [Supporting Services](#supporting-services)
- [Design Language](#design-language)
- [State Management](#state-management)
- [Routing & Navigation](#routing--navigation)
- [Dependencies](#dependencies)
- [Future Roadmap](#future-roadmap)

---

## Overview

The **Flicko Store** is a full-featured in-app cosmetics marketplace where users can browse, purchase, equip, and collect digital cosmetic items. It provides a **Discord Nitro-like premium experience** with a dark, cybernetic aesthetic.

### Key Features

- **45+ cosmetic products** across 10+ categories
- **Shopping cart** with quantity management and coupon support
- **Gacha/Mystery Crate** system with vinyl turntable spinning animation
- **Badge Alchemy** — forge new badges by combining existing ones
- **Cosmetic Fusion** — fuse multiple cosmetics into higher-rarity items
- **Wishlist** functionality for saving items
- **Inventory** screen for purchased items
- **Gift** system to send items to other users
- **Theme previews** with live switching
- **Sticker picker** with full emoji panel integration
- **Soundboard creator** studio
- **Voice skin** audio filter previews
- **Entrance warp** animations
- **Drip card** message styling
- **Nameplate** kinetic text effects

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                          Flicko Store System                         │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                     Presentation Layer                         │ │
│  │                                                                │ │
│  │  store_screen.dart (85KB)        ← Main marketplace            │ │
│  │  product_detail_screen.dart      ← Product details + preview   │ │
│  │  cart_screen.dart (41KB)         ← Shopping cart + checkout     │ │
│  │  inventory_screen.dart           ← User's purchased items      │ │
│  │  theme_picker_screen.dart        ← Live theme switching        │ │
│  │  gacha_unboxing_screen.dart      ← Mystery crate spinner       │ │
│  │  badge_alchemy_screen.dart       ← Badge forging workshop      │ │
│  │  cosmetic_fusion_screen.dart     ← Cosmetic fusion lab         │ │
│  │  avatar_decoration_store.dart    ← Profile frame store         │ │
│  │  nameplate_store_screen.dart     ← Kinetic nameplate store     │ │
│  │  voice_skin_store_screen.dart    ← Audio filter store          │ │
│  │  warp_drip_store_screen.dart     ← Entrance warp + drip cards  │ │
│  │  soundboard_creator_studio.dart  ← Custom soundboard builder   │ │
│  │                                                                │ │
│  │  widgets/                                                      │ │
│  │    product_preview_widget.dart   ← Animated product preview    │ │
│  │    sticker_picker_widget.dart    ← 246-sticker emoji panel     │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                       Data Layer                               │ │
│  │                                                                │ │
│  │  store_service.dart              ← Product catalog + purchases │ │
│  │  equipment_service.dart          ← Equip/unequip cosmetics     │ │
│  │  store_payment_service.dart      ← Payment processing          │ │
│  │  wishlist_service.dart           ← Wishlist management         │ │
│  │  badge_service.dart              ← Badge catalog + rendering   │ │
│  │  badge_alchemy_service.dart      ← Badge fusion recipes        │ │
│  │  cosmetic_fusion_service.dart    ← Multi-cosmetic fusion       │ │
│  │  gacha_service.dart              ← Gacha reward logic          │ │
│  │  store_theme_service.dart        ← Theme management + preview  │ │
│  │  avatar_decoration_service.dart  ← Avatar frame management     │ │
│  │  nameplate_service.dart          ← Nameplate management        │ │
│  │  drip_card_service.dart          ← Message card styling        │ │
│  │  warp_service.dart               ← Entrance animation mgmt    │ │
│  │  notification_sound_service.dart ← Sound pack management       │ │
│  │  custom_recording_service.dart   ← Soundboard recordings       │ │
│  │  store_audio_preview_service.dart← Sound previews              │ │
│  └────────────────────────────────────────────────────────────────┘ │
│                                                                     │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                    Persistence Layer                            │ │
│  │  Supabase (cosmetic_catalog, user_cosmetics)                   │ │
│  │  SharedPreferences (local purchases, offline cache)            │ │
│  └────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

---

## File Structure

```
mobile/lib/features/store/
├── data/
│   ├── store_service.dart              (27KB)  # Core models + catalog + cart
│   ├── equipment_service.dart          (11KB)  # Equip/unequip management
│   ├── store_payment_service.dart       (6KB)  # Payment processing
│   ├── badge_service.dart              (10KB)  # Badge definitions + rendering
│   ├── badge_alchemy_service.dart      (16KB)  # Badge forging recipes
│   ├── cosmetic_fusion_service.dart     (9KB)  # Multi-item fusion
│   ├── gacha_service.dart               (6KB)  # Mystery crate rewards
│   ├── store_theme_service.dart        (14KB)  # Theme definitions + preview
│   ├── wishlist_service.dart            (2KB)  # Wishlist management
│   ├── avatar_decoration_service.dart   (3KB)  # Profile frame management
│   ├── nameplate_service.dart           (3KB)  # Kinetic nameplate mgmt
│   ├── drip_card_service.dart           (2KB)  # Message card styling
│   ├── warp_service.dart                (2KB)  # Entrance warp management
│   ├── notification_sound_service.dart (11KB)  # Sound pack management
│   ├── custom_recording_service.dart    (2KB)  # Soundboard recordings
│   └── store_audio_preview_service.dart (2KB)  # Sound previews
│
└── presentation/
    ├── store_screen.dart               (85KB)  # Main store UI
    ├── product_detail_screen.dart      (35KB)  # Product detail page
    ├── cart_screen.dart                (41KB)  # Cart + checkout
    ├── inventory_screen.dart           (18KB)  # User's items
    ├── theme_picker_screen.dart        (18KB)  # Theme browser
    ├── gacha_unboxing_screen.dart      (33KB)  # Mystery crate spinner
    ├── badge_alchemy_screen.dart       (40KB)  # Badge forging lab
    ├── cosmetic_fusion_screen.dart     (23KB)  # Fusion reactor
    ├── avatar_decoration_store_screen  (19KB)  # Avatar frames store
    ├── nameplate_store_screen.dart     (19KB)  # Nameplate store
    ├── voice_skin_store_screen.dart    (27KB)  # Voice skin store
    ├── warp_drip_store_screen.dart     (25KB)  # Warp + drip cards store
    ├── soundboard_creator_studio.dart  (16KB)  # Soundboard builder
    └── widgets/
        ├── product_preview_widget.dart (16KB)  # Product preview animations
        └── sticker_picker_widget.dart   (8KB)  # Sticker/emoji panel
```

**Total codebase size**: ~470KB+ of Dart code across 29 files.

---

## Data Models

### `StoreProduct`

The core product model for all cosmetic items.

| Field        | Type     | Description |
|--------------|----------|-------------|
| `id`         | `String` | Unique product ID (e.g., `'sonic-drip'`) |
| `slug`       | `String` | URL-safe slug |
| `name`       | `String` | Display name |
| `type`       | `String` | Category type (THEME, BADGE, SOUNDS, etc.) |
| `description`| `String?`| Detailed product description |
| `price`      | `double` | Price in USD (0 = free) |
| `imageUrl`   | `String?`| Asset image URL |
| `previewUrl` | `String?`| Preview/demo URL |
| `rarity`     | `String` | `'common'` / `'rare'` / `'epic'` / `'legendary'` |
| `isHot`      | `bool`   | Featured/trending flag |
| `isActive`   | `bool`   | Active listing flag |

**Rarity Colors**:
| Rarity | Color |
|--------|-------|
| Common | Grey |
| Rare | Blue |
| Epic | Purple |
| Legendary | Gold / Amber |

### `CartItem`

| Field      | Type           | Description |
|------------|----------------|-------------|
| `product`  | `StoreProduct` | The product in cart |
| `quantity`  | `int`          | Quantity (default: 1) |

### `UserPurchase`

Represents a purchased/owned item.

| Field         | Type       | Description |
|---------------|------------|-------------|
| `id`          | `String`   | Purchase record ID |
| `productId`   | `String`   | Referenced product ID |
| `productName` | `String`   | Product name snapshot |
| `productType` | `String`   | Product type snapshot |
| `purchasedAt` | `DateTime` | Purchase timestamp |
| `price`       | `double`   | Paid price |
| `imageUrl`    | `String?`  | Product image |

### `CouponInfo`

| Field            | Type     | Description |
|------------------|----------|-------------|
| `code`           | `String` | Coupon code |
| `discountPercent`| `double` | Discount percentage |
| `description`    | `String` | Coupon description |

---

## Core Service — StoreService

**Provider**: `storeServiceProvider`
**Backend**: `SupabaseClient` → `cosmetic_catalog` table

### Key Methods

| Method | Description |
|--------|-------------|
| `getProducts({type, search})` | Fetch products with optional type filter and search |
| `getProduct(productId)` | Fetch a single product by ID |
| `getSampleProducts({type, search})` | Return 45+ hardcoded sample products as fallback |
| `getUserPurchases()` | Fetch user's owned items (Supabase + local merged) |
| `purchaseProduct(product)` | Execute purchase (local + Supabase) |
| `giftProduct(product, recipientId, name)` | Gift item to another user |
| `getRandomGachaReward()` | Weighted random reward from product pool |

### Dual Storage Architecture

```
┌──────────────────┐     ┌──────────────────┐
│  SharedPreferences│     │    Supabase      │
│  (Local Offline)  │◄───▶│  (Cloud Sync)   │
│                   │     │                  │
│ local_user_       │     │ cosmetic_catalog │
│ purchases         │     │ user_cosmetics   │
└──────────────────┘     └──────────────────┘
         │                         │
         └────────┬────────────────┘
                  │
         ┌────────▼────────┐
         │  Merged Result   │
         │  (deduplicated   │
         │   by productId)  │
         └─────────────────┘
```

- **Online**: Fetches from Supabase `cosmetic_catalog`, merges with local
- **Offline**: Falls back to `getSampleProducts()` with 45+ hardcoded items
- **Purchases**: Stored locally AND synced to Supabase when authenticated
- **Pre-populated**: Free items (Midnight theme, Trending Sounds) auto-added on first use

---

## Cart System

**Provider**: `cartProvider` (`NotifierProvider<CartNotifier, List<CartItem>>`)

### CartNotifier Methods

| Method | Description |
|--------|-------------|
| `add(product)` | Add to cart (increment if exists) |
| `remove(productId)` | Remove item from cart |
| `updateQuantity(productId, quantity)` | Set specific quantity |
| `clear()` | Empty the cart |
| `total` | Computed total price |
| `itemCount` | Total item count |

### Coupon System

**Provider**: `activeCouponProvider` (`StateProvider<CouponInfo?>`)

Coupons apply a percentage discount to the cart total. Can be entered on the cart screen.

---

## Product Categories

The store offers **10+ distinct cosmetic categories**:

| Category | Type Key | Count | Price Range | Description |
|----------|----------|-------|-------------|-------------|
| **Themes** | `THEME` | 10 | ₹0 – ₹549 | Full app color schemes (Sonic Drip, AMOLED Cord, etc.) |
| **Sticker Packs** | `STICKERS` | 7 | ₹149 – ₹249 | Emoji/sticker collections (Handy Emoji Panel: 246 stickers, Meme & Anime stickers) |
| **Sound Packs** | `SOUNDS` | 9 | ₹0 – ₹199 | Notification sounds, soundboard effects, and premium Flicko Beats backing loops |
| **Badges** | `BADGE` | 9 | ₹0 – ₹1199 | Profile badges (OG, Verified+, Diamond Elite, etc.) |
| **Avatar Decorations** | `AVATAR_DECORATION` | 5 | ₹249 – ₹499 | Animated profile frames (Neon Cyber, Glitch Matrix, etc.) |
| **Nameplates** | `NAMEPLATE` | 5 | ₹249 – ₹499 | Kinetic text effects for username display |
| **Voice Skins** | `VOICE_SKIN` | 4 | ₹149 – ₹499 | Audio filters + visualizers for voice messages |
| **Entrance Warps** | `ENTRANCE_WARP` | 3 | ₹299 – ₹499 | Animated entrances when joining a chat |
| **Drip Cards** | `DRIP_CARD` | 3 | ₹279 – ₹549 | Custom message bubble styling |
| **Mystery Crates** | `CRATE` | 1 | ₹149 | Gacha system with weighted random rewards |
| **Bundles** | `BUNDLE` | 1 | ₹599 | Multi-item value packs (Sonic Cyber Bundle) |

---

## Specialized Sub-Stores

### Avatar Decoration Store (`avatar_decoration_store_screen.dart`)
- Browse and preview animated profile frames
- Live preview of frame effects around user avatar
- Categories: Neon, Glitch, Cosmic, Fire, Rainbow

### Nameplate Store (`nameplate_store_screen.dart`)
- Browse kinetic text effects for display names
- Preview animation on sample username text
- Categories: Glitch, Neon, Fire, Gold, Rainbow

### Voice Skin Store (`voice_skin_store_screen.dart`)
- Browse audio filter + waveform visualizer combos
- Audio preview playback for each skin
- Categories: 8-Bit, Retro Radio, Lofi Tape, Cyber Vocoder

### Warp & Drip Store (`warp_drip_store_screen.dart`)
- Entrance warps: full-screen animations on chat join
- Drip cards: custom message bubble borders and effects
- Split-tab browsing between warps and cards

### Soundboard Creator Studio (`soundboard_creator_studio.dart`)
- Create custom soundboards from purchased sound packs
- Record custom sounds from microphone
- Organize sounds into custom boards

---

## Gacha System

**File**: `gacha_unboxing_screen.dart` (33KB)

### Vinyl Turntable Spinner

The Mystery Crate uses a **decelerating vinyl turntable** animation:

1. User purchases a Mystery Vinyl Crate (₹149)
2. A turntable needle-drop animation spins through possible rewards
3. The spin decelerates with easing physics
4. The needle lands on a random reward with rarity-weighted probability
5. Reward is revealed with particle effects and rarity-colored glow

### Rarity Weights

| Rarity | Probability | Pool |
|--------|-------------|------|
| Legendary | ~15% | All legendary items |
| Epic | ~35% | All epic items |
| Rare | ~50% | All rare items |

**Algorithm**: `DateTime.now().millisecondsSinceEpoch % 100` for weighted selection.

---

## Badge Alchemy

**File**: `badge_alchemy_screen.dart` (40KB)
**Service**: `badge_alchemy_service.dart` (16KB)

### Concept

Users can **combine existing badges** to forge new, unique badges through an alchemical fusion interface.

- **Input**: 2-3 owned badges placed on a fusion pedestal
- **Process**: Animated fusion reaction with particle effects
- **Output**: A new badge with combined properties and higher rarity
- **Recipes**: Pre-defined and discoverable combinations
- **Special rewards**: Unique "Cosmic Overlord" and "Badge Alchemist" badges only obtainable through alchemy

---

## Cosmetic Fusion

**File**: `cosmetic_fusion_screen.dart` (23KB)
**Service**: `cosmetic_fusion_service.dart` (9KB)

### Concept

Fuse **any combination of cosmetics** (not just badges) to create upgraded or transformed items.

- Cross-category fusion (e.g., theme + badge → themed badge)
- Rarity upgrade paths (rare + rare → epic chance)
- Unique fusion-only items

---

## Purchase Flow

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Browse  │───▶│  Detail  │───▶│  Cart    │───▶│ Checkout │
│  Store   │    │  Screen  │    │  Screen  │    │          │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
     │               │               │               │
     │          Add to Cart      Apply Coupon    Process Payment
     │          Add to Wishlist  Update Qty      (Local + Supabase)
     │          Gift to Friend   Remove Item     Add to Inventory
     │                                           Clear Cart
     │
     ├── Direct Purchase (Buy Now)
     ├── Gift Purchase
     └── Gacha Spin
```

### Bundle Handling

The **Sonic Cyber Bundle** (₹599) automatically unlocks all 3 included items individually:
- Sonic Drip Theme
- OG Badge
- Classic Memes Soundboard

---

## Main Store Screen

**File**: `store_screen.dart` (85KB — the largest file in the project)

### Layout Structure

```
┌─────────────────────────────────────┐
│  ← THE DRIP STORE            🛒 📦 │  ← Header + Cart + Inventory
├─────────────────────────────────────┤
│  🔍 Search the drip...             │  ← Search bar
├─────────────────────────────────────┤
│  ALL │ THEMES │ BADGES │ SOUNDS │..│  ← Category filter chips
├─────────────────────────────────────┤
│  ┌─────────────────────────────┐   │
│  │ 🔥 FEATURED                 │   │
│  │ ┌──────────────────────────┐│   │  ← Featured/Hot carousel
│  │ │  Sonic Drip Theme    ₹399││   │
│  │ │  ★★★★★ LEGENDARY  🔥 HOT ││   │
│  │ └──────────────────────────┘│   │
│  └─────────────────────────────┘   │
├─────────────────────────────────────┤
│  ┌──────┐ ┌──────┐ ┌──────┐       │
│  │Theme  │ │Badge  │ │Sound  │       │  ← Product grid
│  │₹249  │ │₹799  │ │ FREE  │       │     (2-column)
│  │EPIC   │ │LEGEND│ │COMMON│       │
│  └──────┘ └──────┘ └──────┘       │
│  ┌──────┐ ┌──────┐ ┌──────┐       │
│  │Warp   │ │Skin   │ │Crate  │       │
│  │₹399  │ │₹299  │ │₹149  │       │
│  │EPIC   │ │EPIC  │ │EPIC   │       │
│  └──────┘ └──────┘ └──────┘       │
└─────────────────────────────────────┘
```

### Features

- **Category filter tabs**: ALL, Themes, Badges, Stickers, Sounds, Decorations, Nameplates, Voice Skins, Warps & Drips
- **Search bar**: Real-time text filtering
- **Featured section**: Hot items highlighted with fire emoji and glow effects
- **Product cards**: Show name, price, rarity badge, hot indicator
- **Rarity-colored borders**: Dynamic coloring based on item rarity
- **Staggered grid layout**: 2-column responsive grid
- **Pull-to-refresh**: Reload product catalog

---

## Product Detail Screen

**File**: `product_detail_screen.dart` (35KB)

### Features

- Full product information display
- Animated preview widget for visual cosmetics
- Rarity badge with appropriate coloring
- Price display with currency formatting
- "Add to Cart" and "Buy Now" buttons
- "Gift to Friend" option with user search
- "Add to Wishlist" toggle
- Related products suggestions

---

## Cart Screen

**File**: `cart_screen.dart` (41KB)

### Features

- Item list with quantity controls (+/-)
- Swipe-to-remove items
- Price breakdown (subtotal, discount, total)
- Coupon code input field
- Checkout button with total
- Empty cart state
- Animated transitions for add/remove

---

## Inventory Screen

**File**: `inventory_screen.dart` (18KB)

### Features

- Grid view of all owned items
- Category tabs for filtering
- Equip/unequip functionality
- Purchase date display
- Item detail navigation

---

## Theme Picker

**File**: `theme_picker_screen.dart` (18KB)

### Features

- Browse all available themes
- Live preview of theme colors on sample UI
- One-tap theme application
- Owned/purchasable state indicators
- Theme comparison view

---

## Supporting Services

### Equipment Service (`equipment_service.dart` — 11KB)
- Equip/unequip cosmetics per category
- Track active equipment per slot (active theme, active badge, etc.)
- Supabase sync for equipped items

### Store Payment Service (`store_payment_service.dart` — 6KB)
- Payment processing abstraction
- Transaction logging
- Coupon validation and application

### Wishlist Service (`wishlist_service.dart` — 2KB)
- Add/remove items from wishlist
- Persistent storage via SharedPreferences
- Wishlist state provider

### Store Theme Service (`store_theme_service.dart` — 14KB)
- Theme definitions with complete color palettes
- Theme preview rendering
- Active theme management
- Custom theme data structures

### Badge Service (`badge_service.dart` — 10KB)
- Badge catalog with 9+ badge definitions
- Badge rendering widgets (star, bolt, diamond shapes)
- Badge equip/display logic

### Notification Sound Service (`notification_sound_service.dart` — 11KB)
- Sound pack management (MyInstants integration)
- Custom notification sound selection
- Audio playback for previews

### Store Audio Preview Service (`store_audio_preview_service.dart` — 2KB)
- Audio preview playback for voice skins and sounds
- Play/pause state management

---

## Design Language

### Color Palette

The store shares Flicko's core cybernetic dark theme:

| Token | Hex | Usage |
|-------|-----|-------|
| Background | `#000000` | Screen base |
| Card Surface | `#0D0D12` / `#111115` | Product cards |
| Card Border | `#1C1C24` / `#222228` | Card edges |
| Accent Pink | `#FF007F` | CTAs, hot items, prices |
| Accent Purple | `#8B00FF` | Epic rarity, secondary |
| Accent Cyan | `#00FFCC` | Code/tech elements |
| Gold | `#FFD700` | Legendary rarity |
| Text Primary | `#FBF9FA` | Main text |
| Text Muted | `#8E8E93` | Metadata, descriptions |

### Rarity Visual System

| Rarity | Border Color | Glow Color | Badge Style |
|--------|-------------|------------|-------------|
| Common | Grey | None | Simple text |
| Rare | Blue | Subtle blue | Rounded pill |
| Epic | Purple | Medium purple | Gradient pill |
| Legendary | Gold | Strong amber | Animated glow |

### Typography

- **Epilogue**: Store title, section headers
- **Space Grotesk**: Product names, prices, buttons
- **Space Mono**: Metadata, tags, rarity labels

### Animations

- **Product cards**: Staggered fade-in on load
- **Featured carousel**: Auto-scroll with parallax
- **Cart items**: Slide-in/out animations
- **Gacha spinner**: Decelerating turntable physics
- **Badge alchemy**: Fusion particle effects
- **Rarity reveals**: Glow + scale burst animation

---

## State Management

### Providers

```dart
// Core service
final storeServiceProvider = Provider<StoreService>(...);

// Product catalog (cached, filtered)
final storeProductsProvider = FutureProvider.family<List<StoreProduct>, ({String? type, String? search})>(...);

// Single product lookup
final productProvider = FutureProvider.family<StoreProduct?, String>(...);

// User's purchases
final userPurchasesProvider = FutureProvider<List<UserPurchase>>(...);

// Shopping cart (in-memory)
final cartProvider = NotifierProvider<CartNotifier, List<CartItem>>(...);

// Active coupon
final activeCouponProvider = StateProvider<CouponInfo?>(...);
```

### Architecture Pattern

- **Service Layer**: `StoreService` handles all Supabase/local data operations
- **Provider Layer**: Riverpod providers expose data reactively to UI
- **UI Layer**: ConsumerStatefulWidgets watch providers for state changes
- **Caching**: `_cachedProducts` in StoreService prevents redundant API calls

---

## Routing & Navigation

| Path | Screen | Access Point |
|------|--------|-------------|
| `/store` | `StoreScreen` | Bottom nav / Settings |
| `/store/product/:id` | `ProductDetailScreen` | Product card tap |
| `/store/cart` | `CartScreen` | Cart icon in header |
| `/store/inventory` | `InventoryScreen` | Inventory icon in header |
| `/store/themes` | `ThemePickerScreen` | Theme category |
| `/store/gacha` | `GachaUnboxingScreen` | Mystery Crate purchase |
| `/store/alchemy` | `BadgeAlchemyScreen` | Badge section |
| `/store/fusion` | `CosmeticFusionScreen` | Fusion lab button |
| `/store/avatars` | `AvatarDecorationStoreScreen` | Decorations category |
| `/store/nameplates` | `NameplateStoreScreen` | Nameplates category |
| `/store/voice-skins` | `VoiceSkinStoreScreen` | Voice skins category |
| `/store/warps` | `WarpDripStoreScreen` | Warps category |
| `/store/soundboard` | `SoundboardCreatorStudio` | Sounds category |

---

## Dependencies

| Package | Purpose |
|---------|---------|
| `supabase_flutter` | Backend database for products and purchases |
| `flutter_riverpod` | State management |
| `shared_preferences` | Local purchase persistence |
| `google_fonts` | Typography (Epilogue, Space Grotesk, Space Mono) |
| `flutter_animate` | Product card and screen animations |
| `go_router` | Navigation between store screens |
| `dio` | HTTP for external asset loading |
| `just_audio` | Sound preview playback |
| `cached_network_image` | Image caching for product thumbnails |

---

## Database Schema

### Supabase Tables

#### `cosmetic_catalog`
```sql
CREATE TABLE cosmetic_catalog (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    slug        TEXT UNIQUE NOT NULL,
    name        TEXT NOT NULL,
    cosmetic_type TEXT NOT NULL,    -- THEME, BADGE, SOUNDS, etc.
    description TEXT,
    price       DECIMAL(10,2) DEFAULT 0,
    asset_url   TEXT,
    preview_url TEXT,
    rarity      TEXT DEFAULT 'common',
    is_hot      BOOLEAN DEFAULT false,
    is_active   BOOLEAN DEFAULT true,
    created_at  TIMESTAMPTZ DEFAULT now()
);
```

#### `user_cosmetics`
```sql
CREATE TABLE user_cosmetics (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    cosmetic_id UUID REFERENCES cosmetic_catalog(id),
    source      TEXT DEFAULT 'purchase',  -- purchase, gift, gacha, alchemy
    unlocked_at TIMESTAMPTZ DEFAULT now(),
    metadata    JSONB,
    UNIQUE(user_id, cosmetic_id)
);
```

---

## Future Roadmap

### Phase 1 — Enhanced Shopping Experience 🛍️

- [ ] **Product reviews & ratings** — 5-star rating system with written reviews
- [ ] **Price history charts** — Show price trends and sale alerts
- [ ] **Seasonal sales events** — Black Friday, Holiday, Anniversary events with automated discounts
- [ ] **Bundle builder** — Let users create custom bundles for discounts
- [ ] **Wishlist notifications** — Alert when wishlisted items go on sale

### Phase 2 — Social Commerce 🤝

- [ ] **Trading system** — Trade cosmetics between users
- [ ] **Marketplace** — User-to-user resale of limited edition items
- [ ] **Gift wrapping** — Animated gift reveal experience for recipients
- [ ] **Gift cards** — Purchasable gift card codes
- [ ] **Group buys** — Discounts when friends purchase together

### Phase 3 — Creator Economy 🎨

- [ ] **User-created themes** — Theme editor for users to design and sell themes
- [ ] **User-created sticker packs** — Upload custom sticker sets
- [ ] **Commission system** — Revenue sharing for user-created content
- [ ] **Featured creators** — Highlight top community designers
- [ ] **Custom badge designer** — Design your own badge artwork

### Phase 4 — Gamification 🎮

- [ ] **Achievement system** — Earn free cosmetics through milestones
- [ ] **Daily login rewards** — Streak-based reward calendar
- [ ] **Seasonal battle pass** — Tiered reward track with free/premium tiers
- [ ] **Limited edition drops** — Time-limited exclusive items
- [ ] **Collection completion bonuses** — Rewards for completing sets

### Phase 5 — Advanced Customization 🔧

- [ ] **Theme color customizer** — Adjust individual colors within themes
- [ ] **Animation speed controls** — Customize animation intensity
- [ ] **Preview in chat** — See how cosmetics look in actual chat bubbles
- [ ] **Cross-device sync** — Seamless equipment sync across all devices
- [ ] **Outfit presets** — Save and switch between cosmetic configurations

### Phase 6 — Payment Infrastructure 💳

- [ ] **Real payment gateway** — Stripe/PayPal integration
- [ ] **Virtual currency (Drip Coins)** — In-app currency system
- [ ] **Subscription tier (Flicko Premium)** — Monthly access to exclusive items
- [ ] **Referral rewards** — Earn credits for inviting friends
- [ ] **Purchase history** — Full transaction log with receipts

---

*Documentation last updated: May 2026*
*Flicko Store v1.0 — The Drip Store*
