# Zustand Stores

> **Reading time:** ~5 minutes · **Audience:** Mobile Developers · **Last Updated:** 2026-04-11

This document is a targeted deep dive into how Zustand is implemented on the frontend. For the conceptual differences between Zustand and React Query, see the [State Management Architecture](../architecture/state-management.md) document.

---

## The Root Problem with Context

In early iterations of Flicko, React Context was used to distribute WebSocket events. This caused massive performance issues: whenever the Context provider updated its state (e.g., to add a single keystroke typing indicator), every single component consuming that Context re-rendered, dropping the UI framerate to 10 FPS.

**Zustand solves this** by existing *outside* the React lifecycle tree. Components selectively subscribe to exactly the slice of data they need.

---

## Best Practices

### 1. Selective Subscription
Never import the entire store state. Always select exactly what you need.

❌ **Bad:** Causes re-renders whenever ANYTHING in the store changes.
```typescript
const store = useMessageStore();
return <Text>{store.messages.length}</Text>
```

✅ **Good:** Only re-renders if `messages.length` specifically changes.
```typescript
const count = useMessageStore(state => state.messages.length);
return <Text>{count}</Text>
```

### 2. Store Separation
Instead of one massive `globalStore`, Flicko uses 22 domain-specific stores. 
If an action touches multiple domains, the stores import each other's getter functions `useVoiceStore.getState()` directly, avoiding circular React dependencies.

---

## Key Stores Index

Here are the highest-impact stores you will interact with.

### `appStateStore.ts`
The highest-level UI state.
- Tracks `activeServerId` and `activeChannelId`.
- Tracks `sidebarOpen` boolean.
- Tracks current UI theme override (System vs AMOled Dark).

### `messageStore.ts`
The highest-throughput store.
- Maintains the optimistic UI buffer array of `Message` objects.
- Functions: `addMessage`, `updateMessageSuccess`, `markMessageError`, `clearBuffer`.
- Automatically wipes itself and relies on React Query cache when the channel changes.

### `voiceStore.ts`
The adapter for WebRTC state.
- Tracks `isMuted`, `isDeafened`.
- Integrates with LiveKit hook callbacks to align our RBAC permissions with LiveKit's literal publish statuses.

### `authStore.ts`
The security layer.
- Retains the decoded JWT payload (Username, User UUID).
- Wrapped in the `persist` middleware configured to write seamlessly to `expo-secure-store` to keep the user logged in across app restarts.
