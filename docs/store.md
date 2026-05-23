# Flicko Store Module

## Overview
The Flicko Store is an integrated marketplace allowing users to discover, collect, and equip digital cosmetics, features, and profile enhancements. Designed with a distinct brutalist, retro-futuristic aesthetic ("Sonic Drip"), the store gamifies the collection process with an XP-based rank system (e.g., "Novice Dripper" to "Legendary Cosmic DJ").

## Architecture & State Management
- **State Management**: Built primarily with Riverpod (`flutter_riverpod`). State like user cart (`cartProvider`), wishlist (`wishlistProvider`), user inventory (`userPurchasesProvider`), and active equipment (`equipmentProvider`) are managed in centralized providers inside `/lib/features/store/data/`.
- **Navigation**: Uses `go_router` for seamless navigation through nested screens (e.g., `/store`, `/store/cart`, `/store/themes`, etc.).

## Screens and Flow
1. **Store Hub (`store_screen.dart`)**
   - The central marketplace with tabs for 'Discover' and 'My Collection'.
   - Displays a dynamic Collector XP Bar that tracks purchases and assigns a rank.
   - Showcases products separated by categories: Themes, Decorations, Nameplates, Voice Skins, Warp Drips, Sounds, and Badges.
2. **Cart & Checkout (`cart_screen.dart`)**
   - Accumulates items to purchase.
3. **Cosmetic Modifiers**
   - **Theme Picker (`theme_picker_screen.dart`)**: Lets users swap the app's visual theme (e.g., Cyberpunk, Retro, Midnight).
   - **Cosmetic Fusion (`cosmetic_fusion_screen.dart`)**: A crafting interface to merge lower-tier items into higher-tier loot.
   - **Gacha Unboxing (`gacha_unboxing_screen.dart`)**: A randomized drop system with flashy animations to unlock rare cosmetics.
4. **Specialized Stores**
   - Avatar Decorations, Nameplates, Voice Skins, Warp Drips, and Badge Alchemy each have dedicated sub-screens to preview and acquire items.

## Design Aesthetic
- **Color Palette**: Heavy use of Pure Black (`#000000`), Deep Black-Gray (`#0C0C0E`), and Lime Green / Sonic Drip Green (`#52B788`) as accent colors.
- **Typography**: Employs `GoogleFonts.spaceGrotesk` and `GoogleFonts.spaceMono` for a tech-heavy, monospaced, brutalist feel.
- **UI Elements**: Elements have sharp edges (no rounding), thick borders, offset shadows, and neon highlights.

## Future Projections & Roadmap
- **Cross-Platform Syncing**: Tying store purchases to the Supabase/Appwrite backend to ensure users retain purchases across devices.
- **Creator Economy Integration**: Allowing approved creators to design and list custom cosmetics (themes, sounds, nameplates) on the store for profit.
- **Dynamic Previews**: Implement live 3D rendering for avatar items and audio visualization for voice skins before purchase.
- **Seasonal Events & Drops**: Time-gated, exclusive cosmetic lines tied to platform-wide events (e.g., Halloween, Anniversaries).
