# Navigation Architecture

> **Reading time:** ~7 minutes · **Audience:** Mobile Developers · **Last Updated:** 2026-04-11

Flicko handles routing via **Expo Router (v3)**, which uses the filesystem to dictate application paths. This enables deep linking out of the box and natively mapped URLs for web equivalents.

---

## App Layouts

Our routing hierarchy is protected by nested `_layout.tsx` files.

### 1. The Root Layout (`app/_layout.tsx`)
This is the absolute top of the app tree.
**Responsibilities:**
- Initializes TanStack QueryClient.
- Connects the main WebSocket (via `useWebSocket` hook).
- Initializes LiveKit libraries.
- Checks the `authStore`: Automatically redirects users to `/(auth)/login` if no valid JWT is present, or `/(tabs)/chat` if they are authenticated.

### 2. The Auth Layout (`app/(auth)/_layout.tsx`)
A minimal `Stack` navigator.
Contains the Login, Register, and Forgot Password screens. Does not render any tabs or sidebars.

### 3. The Tabs Layout (`app/(tabs)/_layout.tsx`)
The main post-login UI. Rendered as a native Bottom Tab navigator on iOS/Android.

---

## The Two-Pane Concept (Sidebar + Chat)

Flicko relies heavily on a fluid sidebar for navigating servers, identical to the Discord mobile app UX.

**How it works:**
The Sidebar is NOT a dedicated screen in the navigation stack. It is a persistent UI layer rendered *above* the Chat tab, controlled by `appStateStore`.

```typescript
// Opening the sidebar
const toggleSidebar = useAppStateStore(s => s.toggleSidebar);

// Used by custom gesture recognizers 
<PanGestureHandler onGestureEvent={onSwipeRight}>
  <ChatScreen />
</PanGestureHandler>
```
When a user taps a channel in the Sidebar, it does not push a new screen to the navigation stack. It merely updates `appStateStore.activeChannelId`. The `<Chat />` screen responds reactively to this ID change by re-subscribing its queries and wiping its message buffer. This provides a lightning-fast channel switching experience (no screen transition animations).

---

## Deep Linking

Expo Router allows handling complex invite links natively.

**Scheme:** `flicko://`
**Universal Link:** `https://flicko.app/`

When a user taps `https://flicko.app/join/xyz`, the OS opens Flicko.
1. Expo Router catches the path `/join/[code]`.
2. The `app/join/[code].tsx` screen mounts.
3. The component extracts `code` from the URL parameters using `useLocalSearchParams()`.
4. The screen fetches the invite metadata and renders the "Accept Invite" modal.

---

## Modals & Presentation

Certain interactions require temporary contextual screens, rather than standard push navigation.

If a user needs to see a member's profile, we render a bottom sheet. Expo Router defines these using the `presentation: 'modal'` option inside `_layout.tsx`.

```tsx
<Stack>
  <Stack.Screen name="(tabs)" options={{ headerShown: false }} />
  <Stack.Screen 
    name="modals/profile" 
    options={{ presentation: 'formSheet', headerShown: false }} 
  />
</Stack>
```
When navigating to `/modals/profile`, iOS will render a native sliding sheet that the user can dismiss by swiping down, preserving the underlying chat view state completely.
