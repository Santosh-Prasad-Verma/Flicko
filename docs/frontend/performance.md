# Performance Optimizations

> **Reading time:** ~6 minutes · **Audience:** Mobile Developers · **Last Updated:** 2026-04-11

To deliver a premium 60fps React Native experience equivalent to native iOS/Android chat apps, Flicko employs several aggressive optimization strategies.

---

## 1. Hermes Engine

We enforce the usage of the Hermes JavaScript Engine, purposefully built by Meta for React Native.

**Benefits realized in Flicko:**
- **Ahead-of-Time (AOT) Compilation:** The JavaScript bundle is precompiled into Hermes bytecode during the Expo build step. This results in incredibly fast app launch times (TTI) compared to JIT engines like V8.
- **Garbage Collection:** Hermes utilizes an optimized GC tailored for mobile memory limits, preventing the dreaded "micro-stutters" when rendering hundreds of chat messages during rapid scrolling.

## 2. Reanimated 3 (UI Thread Processing)

Standard React Native animations require constantly crossing the "Bridge" — passing numbers between the JS Thread and the Native UI Thread. This causes lag if the JS thread is busy parsing incoming WebSocket JSON.

For all gestures (e.g., swiping the sidebar, dragging to reorder channels), Flicko relies on `react-native-reanimated`.

```typescript
import { useSharedValue, useAnimatedStyle, withSpring } from 'react-native-reanimated';

const offset = useSharedValue(0);

// This style executes 100% on the native UI thread
const animatedStyles = useAnimatedStyle(() => {
  return {
    transform: [{ translateX: offset.value }],
  };
});
```
This guarantees 60fps animations regardless of heavy background network activity.

## 3. Query Deduplication

When a user taps "Server A", the app needs to load Channels, Roles, and Members. 
If we used naive `useEffect` fetch blocks, the `<Sidebar />`, the `<Header />`, and the `<ChatFeed />` might all try to fetch the Server Metadata simultaneously, resulting in 3 identical REST calls.

We utilize `@tanstack/react-query` to establish an absolute query cache. If 5 components request `['server', 'A']` within the same tick, React Query deduplicates them, fires a single HTTP GET, and distributes the response to all 5 components simultaneously.

## 4. Off-Thread Image Decoding

See [Component Architecture](components.md) for details on our usage of `expo-image`. It decodes JPEGs and Avifs down to raw pixels on a background thread before injecting them into the GPU, entirely preventing the JS thread from blocking during scroll.

## 5. Heavy Component Memoization

React's default behavior is to cascade renders. If `MessageFeed` updates (because a new message arrived), React attempts to re-render all 50 existing messages on the screen.

Every `MessageBubble` is wrapped in `React.memo()`. We provide a custom comparator:
```typescript
const arePropsEqual = (prevProps, nextProps) => {
  return prevProps.message.id === nextProps.message.id &&
         prevProps.message.edited_at === nextProps.message.edited_at &&
         prevProps.message.reactions.length === nextProps.message.reactions.length;
}
export default React.memo(MessageBubble, arePropsEqual);
```
This mathematically stops the React reconciliation engine from diffing the component tree for 49 unchanged messages.
