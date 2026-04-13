# Shared Stores

This directory contains Zustand state management stores that are shared between the web and mobile applications.

## Cross-Platform Persistence

All stores that require persistence use a platform-agnostic storage adapter located in `shared/lib/storage.ts`. This adapter automatically detects the platform and uses:

- **Web**: `localStorage`
- **React Native**: `AsyncStorage` (from `@react-native-async-storage/async-storage`)

### Usage Example

```typescript
import { create } from 'zustand';
import { persist, createJSONStorage } from 'zustand/middleware';
import { createZustandStorage } from '../lib/storage';

interface MyStore {
  value: string;
  setValue: (value: string) => void;
}

export const useMyStore = create<MyStore>()(
  persist(
    (set) => ({
      value: '',
      setValue: (value) => set({ value }),
    }),
    {
      name: 'my-store-key',
      storage: createJSONStorage(() => createZustandStorage()),
    }
  )
);
```

## Available Stores

### authStore.ts
Manages authentication state including user profile and session. Only persists user data (not session tokens for security).

### settingsStore.ts
Manages user preferences including theme, language, font size, notifications, and accessibility settings.

### notificationStore.ts
Manages in-app toast notifications and unread message counts per channel.

### voiceStore.ts
Manages voice/video call state including active channel, mute/deafen status, and participants.

### draftStore.ts
Manages message drafts with automatic cleanup of drafts older than 7 days.

### modalStore.ts
Manages modal dialog state and props for all application modals.

### uiStore.ts
Manages UI navigation state including active server, channel, and sidebar collapse states.

### contextMenuStore.ts
Manages context menu state, position, and menu items.

## Web-Specific Integration

For web applications, auth initialization is handled by `src/services/authInit.service.ts`, which:
- Initializes Supabase auth state
- Syncs with the auth store
- Handles auth state changes
- Provides sign in/up/out methods

## Mobile-Specific Integration

For mobile applications, stores work out of the box with AsyncStorage. The mobile app should:
1. Install `@react-native-async-storage/async-storage`
2. Import stores from `@shared/stores`
3. Use the same store hooks as the web app

## Notes

- All stores are type-safe with TypeScript
- Stores automatically handle platform differences
- No code changes needed when switching between web and mobile
- Storage operations are async but Zustand handles this transparently
