# Frontend Overview

> **Reading time:** ~5 minutes · **Audience:** Mobile/Frontend Developers · **Last Updated:** 2026-04-11

Flicko’s frontend is a cross-platform mobile application built using React Native and the Expo framework. It is responsible for delivering the real-time, 60fps chat experience that users expect from modern platforms.

---

## Technology Stack

Our choices prioritize developer velocity cross-platform consistency:

- **Framework:** React Native + Expo (Managed Workflow)
- **Language:** TypeScript (Strict Mode)
- **UI & Styling:** StyleSheet API with highly customized design tokens
- **Navigation:** Expo Router (File-based routing)
- **State Management:** 
  - `Zustand` (Global UI and WebSocket State)
  - `@tanstack/react-query` (Server Cache + Offline logic)
- **Media:** `@livekit/react-native` for WebRTC, `expo-image` for high-performance lazy loading
- **Storage:** `expo-secure-store` for Auth Tokens, `AsyncStorage` for preferences.

---

## Design Philosophy

1. **Optimistic Updates First:** The user should never wait for an HTTP request to finish to see their chat message appear. The app must feel instantaneous.
2. **Platform Agnostic UI:** Unlike some apps that heavily branch for iOS vs Android, Flicko maintains a unified custom brand language (colors, fonts, gestures) that looks identical on both platforms.
3. **Always Connected:** The frontend must smoothly handle spotty 4G connections, gracefully queuing messages and reconnecting WebSockets in the background.

---

## Directory Context

The entire mobile application lives inside the `/mobile` directory of the monorepo. It operates completely independently of the Go backend, connecting only via the public API URLs.

```bash
Flicko/
└── mobile/
    ├── app/          # Navigation screens (Expo Router)
    ├── components/   # Reusable UI elements
    ├── constants/    # Theme colors, config maps
    ├── hooks/        # Custom React hooks
    └── shared/       # Zustand stores & util functions
```

Explore the frontend documentation:
- [Folder Structure](folder-structure.md)
- [State Management & Zustand Stores](zustand-stores.md)
- [Performance & Optimization](performance.md)
