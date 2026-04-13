# Mobile Folder Structure

> **Reading time:** ~5 minutes · **Audience:** Mobile Developers · **Last Updated:** 2026-04-11

The `@mobile` application is structured using Expo Router's file-based routing combined with domain-driven component separation. 

---

## Root Structure

```text
mobile/
├── app/                  # File-based Navigation Router
│   ├── (auth)/           # Authentication layout and screens
│   ├── (tabs)/           # Main bottom-tab layout
│   │   ├── chat/         # Active chat screen (WebSockets map here)
│   │   ├── dms/          # Direct messages list
│   │   ├── search/       # Global search interface
│   │   └── settings/     # User preferences & profile
│   └── _layout.tsx       # Root wrapper (Providers, Auth checks)
│
├── components/           # Reusable UI Architecture
│   ├── ui/               # Dumb components (Buttons, Inputs, Spinners)
│   ├── chat/             # Chat domain (MessageBubble, Composer, Reactions)
│   ├── mod/              # Moderation domain (ReportModal, BanSheet)
│   └── server/           # Server domain (ChannelList, MemberList)
│
├── constants/            # Project-wide static maps
│   ├── Colors.ts         # Centralized Light/Dark theme hex codes
│   └── Config.ts         # Static limits (Max file size, regex)
│
├── hooks/                # React Hooks
│   ├── useWebSocket.ts   # The massive central event dispatcher
│   ├── useAuthQueue.ts   # Axios interceptors for 401 retries
│   └── useKeyboard.ts    # iOS keyboard height adjustments
│
├── shared/               # Non-React utilities
│   ├── stores/           # The 22 Zustand stores (e.g., authStore.ts)
│   ├── api/              # Axios wrappers and query definitions
│   └── utils/            # Time formatters, UUID generators
│
└── assets/               # Local binary files (Fonts, the flicko icon)
```

---

## Architectural Rules

1. **No Deep Nesting:** The `components/` directory should never be nested more than one domain level deep. Do not create `components/chat/input/buttons/Send.tsx`. Keep it flat.
2. **"Dumb" UI Components:** Files in `components/ui` must NOT `import { useStore }` or make API calls. They accept props and emit generic `onPress` events. They are purely presentational.
3. **File Routing Brackets:** Folders in `app/` surrounded by parentheses `(tabs)` are logical groupings used by Expo Router. They do not affect the physical URL/Path structure of deep links.

---

See [Navigation](navigation.md) to understand how screens within the `app/` directory link together.
