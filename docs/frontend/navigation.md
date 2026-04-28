# Navigation Architecture (GoRouter)

> **Reading time:** ~7 minutes · **Audience:** Mobile Developers · **Last Updated:** 2026-04-24

Flicko handles all mobile routing via **GoRouter**, a declarative routing package for Flutter that allows for type-safe parameter passing, deep linking, and nested navigation shells.

---

## Routing Hierarchy

The application routing is defined centrally in `lib/core/router/app_router.dart`. It uses a combination of top-level routes and nested `ShellRoute`s to manage the app's complex UI state.

### 1. The Main Shell (`ShellRoute`)
Most post-login screens are wrapped in a `MainNavigationShell`. This shell handles the persistent sidebar (for server/channel navigation) and the bottom navigation tabs (Chat, Friends, Notifications, Profile).

**Key Responsibilities:**
- Managing the transition between the Sidebar and the active Content view.
- Handling global gestures for opening/closing the server list.
- Maintaining the state of the bottom navigation bar.

### 2. Auth Routes
The `/login`, `/register`, and `/forgot-password` routes exist outside the main shell. They are standard `GoRoute` entries that render full-screen without any persistent navigation bars.

### 3. Feature Routes
Features like Servers, Channels, and Profiles have nested routes:
- `/server/:sid/channel/:cid`: The primary chat interface.
- `/profile/:uid`: Public user profiles.
- `/settings`: The user settings hub with its own internal sub-routes.

---

## Redirection & Protection

Routing is protected by a `redirect` handler that listens to the `AuthNotifier` provider.

```dart
// Simplified Redirect Logic
redirect: (context, state) {
  final authState = ref.read(authProvider);
  final loggingIn = state.matchedLocation == '/login';

  if (authState is Unauthenticated && !loggingIn) {
    return '/login';
  }
  if (authState is Authenticated && loggingIn) {
    return '/'; // Go to home if already logged in
  }
  return null;
}
```

---

## Deep Linking

Flicko supports native deep links and universal links.

**Scheme:** `flicko://`
**Hosts:** `flicko.app`, `join.flicko.app`

When a link like `https://flicko.app/server/join/[code]` is clicked:
1. The OS redirects the intent to the Flicko app.
2. GoRouter matches the location `/server/join/:code`.
3. The `JoinServerScreen` is pushed to the stack, extracting the `code` parameter from the URL.

---

## Modals & Dialogs

While GoRouter handles high-level screen transitions, contextual overlays (like member profile sheets or server options) are often handled via Flutter's `showModalBottomSheet` or `showDialog`.

However, some "major" modals (like the User Settings Hub) are mapped to routes to allow them to be deep-linked or shared. These are implemented using custom `Page` builders in the router configuration to provide specific transitions (e.g., sliding up from the bottom).

---

## Best Practices

1. **Use Named Routes:** Always use `context.goNamed('route_name')` instead of hardcoding strings to prevent broken links if the path structure changes.
2. **Minimize Rebuilds:** Ensure the `GoRouter` instance is provided via a Riverpod provider to ensure it only rebuilds when the auth state changes.
3. **Parameter Safety:** Use the `state.pathParameters` and `state.uri.queryParameters` to extract data from the route path in a structured way.

---

*Last Updated: 2026-04-24 | Version: 2.0.0 (GoRouter) | Maintained by: Flicko Team*

