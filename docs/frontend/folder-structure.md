# Mobile Folder Structure

> **Reading time:** ~5 minutes · **Audience:** Mobile Developers · **Last Updated:** 2026-04-11

The `mobile` application is structured using a feature-first approach, combined with the standard Flutter project structure. 

---

## Root Structure

```text
mobile/
├── assets/               # Local binary files (Fonts, icons, JSON tokens)
├── lib/
│   ├── core/             # Global cross-cutting concerns
│   │   ├── constants/    # Environment config, static keys
│   │   ├── network/      # Dio API client, WebSocket handlers
│   │   ├── theme/        # AppTheme with Light/Dark mode tokens
│   │   └── utils/        # Shared helpers (date parsing, etc.)
│   │
│   ├── data/             # Infrastructure Layer
│   │   ├── models/       # Freezed data models (JSON serialization)
│   │   ├── providers/    # Global Riverpod provider definitions
│   │   └── repositories/ # Repositories for DB/Storage/API ops
│   │
│   ├── features/         # Feature-first domain modules
│   │   ├── auth/         # Login, Register, Password Recovery
│   │   ├── chat/         # Real-time messages, bubbles, composer
│   │   ├── server/       # Servers, Channels, and Members
│   │   └── voice/        # LiveKit WebRTC integration
│   │
│   ├── main.dart         # Entry point & ProviderScope setup
│   └── router.dart       # Central GoRouter routing table
```

---

## Architectural Rules

1. **No Logic in Widgets:** Presentation widgets must only consume state from Riverpod providers. Any business logic belongs in `Notifer` or `Repository` classes.
2. **Feature Encapsulation:** A feature folder should contain its own widgets, state providers, and models if they are unique to that domain.
3. **Repository Pattern:** All data source interaction (REST, WS, DB) must go through a Repository class, never directly called from a UI widget.

---

See [Navigation](navigation.md) to understand how screens within the `app/` directory link together.
