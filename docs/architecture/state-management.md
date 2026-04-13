# State Management Architecture

> **Reading time:** ~15 minutes · **Audience:** Mobile Developers · **Last Updated:** 2026-04-11

This document explains the frontend state management architecture in Flicko's React Native application. It details how we combine Zustand (for global UI/WebSocket state) and React Query (for server state caching) to create a highly responsive, optimistic UI that seamlessly synchronizes real-time data.

---

## Table of Contents

- [Core Philosophy](#core-philosophy)
- [Zustand vs. React Query](#zustand-vs-react-query)
- [Zustand Store Architecture](#zustand-store-architecture)
- [WebSocket State Synchronization](#websocket-state-synchronization)
- [Optimistic UI Updates](#optimistic-ui-updates)
- [Persistence Strategy](#persistence-strategy)
- [Example: The Message Flow](#example-the-message-flow)

---

## Core Philosophy

Flicko's frontend state management follows three rules:

1. **Local State is King for UX:** Interactions (typing, changing channels, opening modals) must never block on a network request. All UI state is held locally and changes synchronously.
2. **Server State is Cached:** Entity data (user profiles, channel lists) is cached heavily. We show stale data while revalidating in the background.
3. **WebSocket Overrides Cache:** Real-time events delivered via WebSocket instantly mutate the local state directly, bypassing standard React Query invalidation delays.

---

## Zustand vs. React Query

We divide our state into two distinct categories, handled by two different libraries:

### React Query (Server State)
Used for data fetched via standard REST API calls. 
**Responsibilities:** fetching, caching, deduplication, automatic retries, background refetching (stale-while-revalidate), and pagination.
**Where to find it:** Inside `mobile/components/` and `mobile/app/` (e.g., `useQuery`, `useInfiniteQuery`).
**Primary Entities:** Server lists, members lists, older message history, search results.

### Zustand (Global UI & Real-Time State)
Used for everything that isn't a REST data fetch. We have 22 dedicated stores.
**Responsibilities:** 
1. **App State:** Current active server/channel, theme preferences, modals.
2. **WebSocket Streams:** Typing indicators, online presence, active voice channel participants.
3. **Optimistic Cache:** The local buffer for messages flowing over WebSockets.
**Where to find it:** `shared/stores/`

---

## Zustand Store Architecture

Zustand stores in `shared/stores/` are domain-separated to prevent unnecessary re-renders. We aggressively avoid monolithic top-level stores.

### The 22 Stores (Key Highlights)

| Store | Responsibility | Persistence |
|-------|----------------|-------------|
| `authStore` | JWT tokens, login session, current user identity | Encrypted (SecureStore) |
| `appStateStore` | Active server ID, active channel ID, sidebar status | Async Storage (Mem) |
| `messageStore` | Active channel message buffer, sending status, optimistic UI | Memory Only |
| `presenceStore` | Map of `userId` -> `status` (online, idle), typing state | Memory Only |
| `voiceStore` | LiveKit session state, active speaker, mute/deafen status | Memory Only |
| `uploadStore` | Cross-screen file upload progress | Memory Only |
| `themeStore` | Light/Dark/AMOLED user preference | Async Storage |

### Defining a Store (Best Practices)

```typescript
import { create } from 'zustand';

interface PresenceState {
  // 1. Data state
  onlineUsers: Record<string, 'online' | 'idle' | 'dnd'>;
  typingUsers: Record<string, { username: string; timestamp: number }>;
  
  // 2. Immutability functions (actions)
  setUserStatus: (userId: string, status: 'online' | 'idle' | 'dnd') => void;
  setTyping: (channelId: string, userId: string, username: string) => void;
  clearTypingIntervals: () => void;
}

export const usePresenceStore = create<PresenceState>((set) => ({
  onlineUsers: {},
  typingUsers: {},
  
  setUserStatus: (userId, status) => 
    set((state) => ({ 
      onlineUsers: { ...state.onlineUsers, [userId]: status } 
    })),
    
  setTyping: (channelId, userId, username) => {
    // Implementation drops typing indicator after 5 seconds
    // ...
  },
  // ...
}));
```

---

## WebSocket State Synchronization

When the `ws-gateway` delivers an event, it bypasses React Query and updates Zustand stores directly. This gives the app its real-time "Discord-like" feel.

The central router for this is the `useWebSocket` hook (`mobile/hooks/useWebSocket.ts`):

```typescript
// Simplified WebSocket Dispatcher
useEffect(() => {
  ws.onmessage = (event) => {
    const payload = JSON.parse(event.data);
    
    switch (payload.type) {
      case 'MESSAGE_CREATE':
        // Update local buffer immediately
        useMessageStore.getState().addMessage(payload.data);
        break;
        
      case 'PRESENCE_UPDATE':
        usePresenceStore.getState().setUserStatus(payload.data.user_id, payload.data.status);
        break;
        
      case 'VOICE_STATE_UPDATE':
        useVoiceStore.getState().updateParticipant(payload.data);
        break;
        
      case 'CHANNEL_DELETE':
        // Edge case: Sometimes we must invalidate React Query
        queryClient.invalidateQueries({ queryKey: ['channels', payload.data.server_id] });
        break;
    }
  };
}, []);
```

---

## Optimistic UI Updates

When a user performs a local action (e.g., sends a message), we do not wait for the server response (or the subsequent WebSocket echo) to update the UI.

**The Optimistic Pipeline:**
1. User taps "Send".
2. Create a temporary message object with a local `uuid` and `status: 'sending'`.
3. Push immediately to `messageStore` (UI renders it instantly in gray).
4. Fire the REST API request.
5. On success: Replace the temporary object with the server-acknowledged object. Update status to `sent`.
6. On failure: Update status to `error`. UI shows a red retry icon.

```typescript
const sendMessage = async (content: string) => {
  const tempId = uuidv4();
  const tempMessage = { id: tempId, content, status: 'sending', /* ... */ };
  
  // 1. Optimistic Update
  addMessage(tempMessage);
  
  try {
    // 2. Network Request
    const realMessage = await api.post(`/channels/${channelId}/messages`, { content });
    
    // 3. Confirm Update
    replaceMessage(tempId, realMessage);
  } catch (error) {
    // 4. Mark as Failed
    markMessageError(tempId);
  }
};
```

*(Note: Our WebSocket dispatcher includes logic to ignore the `MESSAGE_CREATE` echo it receives via Redis if the message originated from the current device, preventing duplicates).*

---

## Persistence Strategy

To ensure fast app launches and seamless offline recovery, specific data is persisted.

**1. Secure Storage (`expo-secure-store`)**
Used exclusively by `authStore.ts` for sensitive JWT tokens. Encrypted by the mobile OS Keychain/Keystore.

**2. Async Storage (`@react-native-async-storage/async-storage`)**
Used for non-sensitive user preferences (`themeStore`, `appStateStore`) via Zustand's `persist` middleware.

**3. React Query Offline Cache (`@tanstack/react-query-persist-client`)**
The React Query cache is persisted to Async Storage. When the app launches offline, it instantly renders the last viewed channels and servers from cache while attempting background refetches.

---

## Related Documentation

- [Frontend: Overview](../frontend/overview.md) — The complete React Native architecture
- [Architecture: Data Flow](data-flow.md) — Sequence diagrams showing network/state boundaries
- [Features: Real-Time Messaging](../features/real-time-messaging.md) — How the message UI components consume these stores

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
