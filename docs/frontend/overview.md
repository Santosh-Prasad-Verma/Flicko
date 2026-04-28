# Frontend Overview

> **Reading time:** ~5 minutes · **Audience:** Mobile Developers · **Last Updated:** 2026-04-24

Flicko’s frontend is a premium, cross-platform mobile application built using **Flutter 3.22+**. It is designed for maximum performance, aiming for a consistent 120fps experience on supported devices while delivering real-time features like messaging, voice chat, and collaborative tools.

---

## Technology Stack

Our stack is chosen for performance, type safety, and developer expressiveness:

- **Framework:** [Flutter](https://flutter.dev/) (3.22.x)
- **Language:** [Dart](https://dart.dev/) (3.4+)
- **State Management:** [Riverpod](https://riverpod.dev/) (Provider-based, reactive)
- **Navigation:** [GoRouter](https://pub.dev/packages/go_router) (Declarative, parameter-safe routing)
- **Networking:** [Dio](https://pub.dev/packages/dio) for REST, [Websocket Manager](https://pub.dev/packages/web_socket_channel) for Real-time
- **Voice/Video:** [LiveKit Flutter SDK](https://livekit.io/)
- **Storage:** [Supabase Storage](https://supabase.com/storage) for binaries, [Cloudinary](https://cloudinary.com/) for media CDN
- **Local Persistence:** `flutter_secure_storage` (Auth) and `shared_preferences` (Settings)

---

## Design Philosophy

1. **Native Performance:** We leverage Flutter's Impeller rendering engine to ensure buttery-smooth animations and transitions.
2. **Feature-First Architecture:** Code is organized by feature (Auth, Servers, Messages) rather than by layer (Models, Views, Controllers), making it easier to scale and maintain.
3. **Reactive by Default:** The entire application follows a reactive pattern using Riverpod. UI widgets automatically rebuild when their dependent providers emit new state.
4. **Resilient Connectivity:** The app is built to handle network transitions gracefully, with built-in retry logic and optimistic UI state management.

---

## Directory structure

The mobile source code lives in the `/mobile` directory.

```bash
mobile/
├── lib/
│   ├── core/           # Global config, constants, network, and theme
│   ├── data/           # Repositories and base API clients
│   ├── features/       # Feature-specific logic (Presentation & Application)
│   │   ├── auth/
│   │   ├── server/
│   │   ├── messages/
│   │   └── voice/
│   └── main.dart       # Application entry point
└── assets/             # Images, fonts, and design tokens
```

---

## Next Steps

Explore the detailed frontend documentation:
- [Folder Structure](folder-structure.md)
- [Riverpod Providers](riverpod-providers.md)
- [Navigation & Routing](navigation.md)
- [Styling & Design Tokens](styling-guide.md)

