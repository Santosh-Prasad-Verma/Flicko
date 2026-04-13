# Component Architecture

> **Reading time:** ~8 minutes · **Audience:** Mobile Developers · **Last Updated:** 2026-04-11

Because a chat interface renders hundreds of items simultaneously (messages, avatars, server icons), UI components in Flicko must be ruthlessly optimized. 

---

## 1. The Separation of "Dumb" and "Smart"

We enforce a strict separation of presentational (Dumb) and logical (Smart) components.

### Dumb Components (`components/ui/`)
- Example: `BaseButton.tsx`, `Avatar.tsx`, `Badge.tsx`.
- They take data via `props` and emit actions via `onPress`.
- They are completely unaware of the network, the database, or Zustand. 
- They utilize React's `memo()` wrapper to prevent re-renders unless their explicit props change.

### Smart Components (`components/chat/`)
- Example: `MessageFeed.tsx`, `Composer.tsx`.
- They connect to Zustand (`useMessageStore`) and TanStack Query (`useQuery`).
- They pass down the localized data to the Dumb components for rendering.

---

## 2. The Message Bubble

The `MessageBubble.tsx` is the most demanding component in the app. It must render Markdown, attachments, avatars, timestamps, and reaction rows.

**Optimization Rules:**
- **Calculated Heights:** Wherever possible, we define fixed heights or explicitly styled aspect ratios for attachments so the `FlatList` doesn't flutter when images load.
- **Expo Image:** We exclusively use `expo-image` instead of React Native's standard `<Image>`. It utilizes a C++ core memory cache and supports aggressive off-thread decoding, crucial for loading 50 avatars instantly scrolling up.
- **Props Equality:** We explicitly define a custom `areEqual` function for `memo(MessageBubble, areEqual)` to ensure the bubble ONLY re-renders if the message `content` changed or its nested `reactions` array length changed.

---

## 3. FlashList replace FlatList

React Native's core `<FlatList>` performs poorly past 100 complex items. Flicko uses Shopify's `@shopify/flash-list`.

**Implementation details:**
Inside `MessageFeed.tsx`:
```tsx
import { FlashList } from '@shopify/flash-list';

<FlashList
  data={messages}
  renderItem={({ item }) => <MessageBubble message={item} />}
  estimatedItemSize={80} // CRITICAL for performance
  inverted={true}        // Messages grow from the bottom up
  keyExtractor={(item) => item.id}
/>
```

The `estimatedItemSize` allows `FlashList` to pre-calculate layout windows before the native bridge draws them, eliminating blank screen flickering when scrolling rapidly through chat history.

---

## 4. The Composer (Keyboard Handling)

The chat input box (`Composer.tsx`) must anchor itself perfectly above the iOS / Android software keyboards. 

Relying on standard `<KeyboardAvoidingView>` is insufficient because it often stutters during animation.
Instead, we use `react-native-keyboard-controller`.

```tsx
import { useKeyboardAnimation } from 'react-native-keyboard-controller';

const { height } = useKeyboardAnimation();
// We bind the `height` animated value directly to a Reanimated style,
// forcing the Composer view to move at the exact 120Hz refresh rate of the keyboard.
```

This ensures the user's text area never disappears behind the keyboard during the pop-up transition.

---

## Styling Paradigm

Flicko relies on standard `StyleSheet.create` combined with a design token system mapping to `constants/Colors.ts`. We do NOT use Tailwind/NativeWind, as the runtime string parsing of utility classes introduces unacceptable GC (Garbage Collection) pauses on lower-end Android devices when rendering 50 messages per frame.
