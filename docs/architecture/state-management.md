# State Management Architecture (Riverpod)

> **Reading time:** ~15 minutes · **Audience:** Mobile Developers · **Last Updated:** 2026-04-24

This document explains the mobile state management architecture in Flicko's Flutter application. It details how we use **Riverpod** to handle local state, server data caching, and real-time WebSocket synchronization in a reactive, testable, and high-performance manner.

---

## Table of Contents

- [Core Philosophy](#core-philosophy)
- [Why Riverpod?](#why-riverpod)
- [Provider Categories](#provider-categories)
- [Real-Time Synchronization](#real-time-synchronization)
- [Optimistic UI Patterns](#optimistic-ui-patterns)
- [Persistence & Secure Storage](#persistence--secure-storage)
- [Example: Message Dispatch Flow](#example-message-dispatch-flow)

---

## Core Philosophy

Flicko's mobile state management follows three primary rules:

1. **Reactive UI:** The UI is a direct function of the state. When state changes, only the specific widgets listening to that slice of state re-render.
2. **Aggressive Caching:** We use providers to cache server responses. Stale data is shown immediately while background refreshes (revalidation) occur via `AsyncValue`.
3. **One-Way Data Flow:** Actions (methods in Notifiers) trigger state updates, which then flow down to the UI. The UI never mutates state directly.

---

## Why Riverpod?

Riverpod is chosen as the primary state management solution for Flicko due to its robust features that align with production-grade application requirements:

- **Compile-time Safety:** Providers are inherently type-safe and verified at compile-time.
- **Provider Composition:** Providers can easily depend on each other without circular dependency issues.
- **Async Handling:** Built-in support for `AsyncValue` (loading, error, data) eliminates boilerplate in widgets.
- **Testability:** Mocking providers for unit and widget tests is straightforward and robust.

---

## Provider Categories

We group providers based on their lifecycle and frequency of updates.

### 1. Data Providers (Server State)
These handle data fetched from our Go microservices.
- **Types:** `FutureProvider`, `AsyncNotifierProvider`.
- **Responsibilities:** API calls, data transformation, caching logic.
- **Primary Entities:** Server lists, channel history, user profiles.

### 2. Logic Providers (UI State)
These handle ephemeral state that doesn't necessarily persist to the server.
- **Types:** `StateProvider`, `NotifierProvider`.
- **Responsibilities:** Navigation state, sidebar status, modal visibility, search queries.

### 3. Stream Providers (Real-Time State)
These integrate directly with our WebSocket gateway.
- **Types:** `StreamProvider`.
- **Responsibilities:** Listens to the WebSocket stream and emits updates for typing indicators, online status, and instant message arrivals.

---

## Real-Time Synchronization

When a message arrives via the `ws-gateway`, we use Riverpod to update our local data cache without requiring a full REST API refetch.

```dart
// Example of a Message Stream Provider
final messageStreamProvider = StreamProvider.autoDispose<Message>((ref) {
  final socketService = ref.watch(webSocketServiceProvider);
  return socketService.messagesStream;
});

// Listener in the Message List Notifier
ref.listen(messageStreamProvider, (previous, next) {
  next.whenData((message) {
    if (message.channelId == currentChannelId) {
      state = state.copyWith(
        messages: [message, ...state.messages],
      );
    }
  });
});
```

---

## Optimistic UI Patterns

Optimistic updates are critical for a "fast" feel. When a user sends a message, it appears in the UI instantly, even before the server acknowledges it.

**The Workflow:**
1. **Trigger:** User taps "Send".
2. **Local Add:** The `AsyncNotifier` adds a temporary message with a `uuid` and `status = sending`.
3. **Network Call:** The API call is made in the background.
4. **Resync:** 
   - **On Success:** The temporary message is replaced with the official server version.
   - **On Error:** The message is marked with `status = error`, and a retry option is presented.

---

## Persistence & Secure Storage

To ensure seamless app restarts, certain providers are persisted.

- **Storage Service:** We use `shared_preferences` and `flutter_secure_storage`.
- **Auth Persistence:** `AuthNotifier` persists the JWT token to secure storage.
- **Theme Persistence:** User theme preferences (Dark, Light, AMOLED) are saved to shared preferences and loaded at app startup.

---

## Related Documentation

- [Frontend Overview](../frontend/overview.md) — The Flutter architecture summary
- [Folder Structure](folder-structure.md) — How providers are organized within features
- [Tech Stack](tech-stack.md) — Detailed list of dependencies

---

*Last Updated: 2026-04-24 | Version: 2.0.0 (Flutter/Riverpod) | Maintained by: Flicko Team*
ko Team*
