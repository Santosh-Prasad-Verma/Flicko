# Frontend State Management
> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Architecture: Zustand + React Query

### Zustand Stores (22 stores)
Location: `shared/stores/`

All stores use Zustand's hook-based API:
```typescript
const { user, setUser } = useAuthStore();
```

Key stores (with file sizes indicating complexity):
- `messageStore.ts` (13 KB) — Message cache, optimistic updates
- `voiceStore.ts` (12 KB) — Voice channel state
- `serverManagementStore.ts` (10 KB) — Server CRUD
- `readStateStore.ts` (8 KB) — Unread tracking
- `settingsStore.ts` (7 KB) — User preferences
- `uploadStore.ts` (7 KB) — File upload progress
- `authStore.ts` (6 KB) — Auth state, session

### React Query
File: `mobile/services/queryClient.ts`

Used for:
- Server state caching
- Background data refetching
- Optimistic updates on mutations
- Automatic retry on failure
