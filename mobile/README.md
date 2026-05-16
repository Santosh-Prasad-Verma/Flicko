# Flicko Mobile

[![Flutter](https://img.shields.io/badge/Flutter-v3.22+-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Architecture](https://img.shields.io/badge/Architecture-Modular_Feature--First-blue)](https://docs.flutter.dev/perf/rendering/best-practices)
[![Status](https://img.shields.io/badge/Status-Advanced_Maturity-orange)](MOBILE_STATUS.md)

Flicko is a premium, high-performance mobile communication platform inspired by Discord, built from the ground up with **Flutter**. It offers a feature-rich experience for servers, direct messaging, and real-time voice/video collaboration.

## 🚀 Key Features

### 💬 Messaging & Real-time
- **Rich Text Chat**: Markdown support, image/GIF attachments, and interactive reactions.
- **Advanced Grouping**: Smart message grouping with persistent status indicators.
- **Real-time Presence**: WebSocket-driven online/idle/dnd status tracking via Supabase.

### 🔊 Voice & Video Collaboration
- **LiveKit Integration**: Low-latency voice and video channels with background support.
- **Interactive Tools**: Built-in soundboard, collaborative whiteboard, and screen sharing.
- **Voice HUD**: Non-intrusive floating control bar for active calls.

### 🛡️ Moderation & Server Management
- **Granular Permissions**: 23+ individual role-based permissions and hierarchical roles.
- **Moderation Hub**: Native support for timeouts, bans, and keyword-based AutoMod.
- **Audit Logs**: Comprehensive history of all administrative actions.

### 💎 Premium Ecosystem
- **Flicko Plus**: Tiered subscription system integrated with **Stripe**.
- **Bot Marketplace**: Native configuration for popular automation tools (Tickets, Polls, Music).

## 🛠 Tech Stack

- **Framework**: [Flutter v3.22+](https://flutter.dev)
- **State Management**: [Riverpod Generator](https://riverpod.dev)
- **Navigation**: [GoRouter](https://pub.dev/packages/go_router)
- **Database & Auth**: [Supabase Flutter](https://supabase.com)
- **Real-time**: [LiveKit Client](https://livekit.io)
- **Media Storage**: [Appwrite Flutter SDK](https://appwrite.io)
- **Payments**: [Flutter Stripe](https://stripe.com)
- **Local Storage**: [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)

## 🏗 Architecture

The project follows a **Modular Feature-First** architecture (Slices):

- **`lib/core/`**: Shared theme (GGSans), common widgets, and global utilities.
- **`lib/data/`**: Global models (Freezed), cross-cutting repositories, and API clients.
- **`lib/features/`**: Feature-specific slices (e.g., `auth`, `server`, `voice`):
    - `application/`: Business logic, state notifiers, and providers.
    - `presentation/`: High-fidelity UI widgets and screen layouts.

## 🏁 Getting Started

### Prerequisites
- Flutter SDK (v3.22+)
- Android Studio (Jellyfish+) / Xcode (15+)
- [Doppler CLI](https://docs.doppler.com/docs/cli) (Production-ready secret management)

### Installation
1. Clone the repository and navigate to the mobile folder:
   ```bash
   cd mobile
   ```
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Run code generation:
   ```bash
   flutter pub run build_runner build --delete-conflicting-outputs
   ```
4. Launch with Doppler:
   ```bash
   doppler run -- ./flutter-start.sh
   ```

## 📊 Project Tracking
- [Full Status Report](MOBILE_STATUS.md) - View the migration progress from React Native.
- [Implementation Roadmap](IMPLEMENTATION_ROADMAP.md) - Future feature milestones.

---
© 2024 Flicko Contributors. Licensed under MIT.
