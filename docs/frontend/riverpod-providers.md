# Riverpod Providers

> **Reading time:** ~8 minutes · **Audience:** Mobile Developers · **Last Updated:** 2026-04-24

This document details the inventory of Riverpod providers used in the Flicko mobile application. For the conceptual architecture and why we chose Riverpod, see the [State Management Architecture](../architecture/state-management.md) document.

---

## Best Practices

### 1. Selective Listening
To avoid unnecessary widget rebuilds, use `.select` to listen only to the specific piece of state needed.

```dart
// ❌ Bad: Rebuilds if ANY auth state changes (even unrelated fields)
final user = ref.watch(authProvider);

// ✅ Good: Only rebuilds if the username specifically changes
final username = ref.watch(authProvider.select((state) => state.username));
```

### 2. Auto-Dispose by Default
Always use `.autoDispose` for providers that are tied to a specific screen or temporary logic to prevent memory leaks.

```dart
final chatMessagesProvider = FutureProvider.autoDispose.family<List<Message>, String>((ref, channelId) {
  return ref.read(messageRepositoryProvider).getMessages(channelId);
});
```

### 3. Provider Composition
Providers should depend on other providers (e.g., a `Repository` provider depending on an `Auth` provider for tokens).

---

## Key Providers Index

### Auth & User Support
- **`authProvider` (`AsyncNotifierProvider`):** Manages user login, registration, and logout logic. Persists JWT to secure storage.
- **`userProfileProvider` (`FutureProvider`):** Fetches detailed profile information for a specific user ID.

### Server & Channel Management
- **`serverListProvider` (`AsyncNotifierProvider`):** Maintains the list of servers the user is a member of.
- **`currentServerProvider` (`StateProvider`):** Tracks the active server ID the user is currently viewing.
- **`channelListProvider` (`FutureProvider`):** Fetches channels for the current server.

### Real-Time Messaging
- **`messagesProvider` (`AsyncNotifierProvider`):** The highest-throughput provider. Manages the message buffer for the active channel, including optimistic updates.
- **`typingIndicatorProvider` (`StreamProvider`):** Listens to WebSocket events to show "who is typing" in the current channel.

### Voice & Video
- **`voiceStateProvider` (`NotifierProvider`):** Tracks local mute/deafen status and WebRTC connection status for the active voice channel.
- **`voiceParticipantsProvider` (`StreamProvider`):** Tracks active speakers and participants in a voice room.

### App Utility
- **`themeProvider` (`NotifierProvider`):** Manages Light/Dark/AMOLED theme modes.
- **`connectivityProvider` (`StreamProvider`):** Monitors network status to show offline banners and trigger reconnections.

---

## Debugging Providers

Use the **Riverpod Graph** or the **Flutter DevTools** to inspect provider state in real-time. In debug mode, we also log provider transitions:

```dart
// In lib/main.dart
ProviderScope(
  observers: [LoggerProviderObserver()],
  child: FlickoApp(),
)
```

---

*Last Updated: 2026-04-24 | Version: 1.0.0 | Maintained by: Flicko Team*
