# Frontend State Management

> **Reading time:** ~3 minutes · **Audience:** Frontend Developers · **Last Updated:** 2026-04-24

Flicko uses **Riverpod** as its central state management and data caching solution. It replaces the legacy combination of Riverpod and React Query used in earlier versions.

## Core Features

- **Standardized Data Fetching:** We use `FutureProvider` and `AsyncNotifier` to handle API requests and state management in a single, type-safe interface.
- **Real-Time Integration:** `StreamProvider` is used to map WebSocket events directly into the UI state.
- **Optimistic Updates:** Implementing low-latency UI updates during network operations to ensure a highly responsive user experience.
- **Testing ready:** All dependencies are injected via providers, making it trivial to mock the backend for widget and integration tests.

## Key Resources

- **Detailed Architecture:** [Architecture: State Management](../architecture/state-management.md)
- **Provider Inventory:** [Riverpod Providers Index](riverpod-providers.md)

---

*Last Updated: 2026-04-24 | Version: 2.0.0 | Maintained by: Flicko Team*

