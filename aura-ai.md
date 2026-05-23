# 🧠 Aura AI — Technical Documentation

> **Flicko's Native AI Companion — Powered by Gemini, Built for Cybernetic UX**

---

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [File Structure](#file-structure)
- [Data Models](#data-models)
- [Core Service — AuraNotifier](#core-service--auranotifier)
- [Gemini API Integration](#gemini-api-integration)
- [Native Feature Integrations](#native-feature-integrations)
- [Chat Interface](#chat-interface)
- [Voice Companion](#voice-companion)
- [Dashboard](#dashboard)
- [Sandbox & Image Viewer](#sandbox--image-viewer)
- [Design Language](#design-language)
- [State Management](#state-management)
- [Routing](#routing)
- [Dependencies](#dependencies)
- [Future Roadmap](#future-roadmap)

---

## Overview

**Aura AI** is Flicko's built-in AI assistant, accessible from the Settings screen. It provides:

- **Text-based Chat** — Three specialized modes: Text Writer, Image Generator, Code Tutor
- **Voice Companion** — Full speech-to-text + text-to-speech pipeline with a 3D animated wireframe sphere
- **Native Integrations** — Can control **Sonic Drip** (music player), send **Direct Messages**, and list **Servers** — all through natural language
- **Dual Engine** — Uses **Google Gemini 1.5 Flash API** for live responses, with an intelligent **local fallback engine** for offline/keyless usage

Aura is named to evoke an **ambient, ethereal presence** — an AI that surrounds and enhances the user's experience across the entire Flicko ecosystem.

---

## Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                        Aura AI System                          │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────┐    ┌─────────────────────────────────┐  │
│  │   Presentation   │    │         Data Layer               │  │
│  │                  │    │                                   │  │
│  │  ┌────────────┐  │    │  ┌───────────────────────────┐   │  │
│  │  │ Dashboard  │  │───▶│  │     AuraNotifier          │   │  │
│  │  │ Screen     │  │    │  │  (Riverpod Notifier)      │   │  │
│  │  └────────────┘  │    │  │                           │   │  │
│  │  ┌────────────┐  │    │  │  ┌───────────────────┐    │   │  │
│  │  │ Chat       │  │───▶│  │  │ Local Command     │    │   │  │
│  │  │ Screen     │  │    │  │  │ Parser (Regex)    │    │   │  │
│  │  └────────────┘  │    │  │  └───────────────────┘    │   │  │
│  │  ┌────────────┐  │    │  │  ┌───────────────────┐    │   │  │
│  │  │ Voice      │  │───▶│  │  │ Gemini API Call   │    │   │  │
│  │  │ Screen     │  │    │  │  │ (Function Calling)│    │   │  │
│  │  └────────────┘  │    │  │  └───────────────────┘    │   │  │
│  │  ┌────────────┐  │    │  │  ┌───────────────────┐    │   │  │
│  │  │ Sandbox    │  │    │  │  │ Simulated         │    │   │  │
│  │  │ Screen     │  │    │  │  │ Fallback Engine   │    │   │  │
│  │  └────────────┘  │    │  │  └───────────────────┘    │   │  │
│  │  ┌────────────┐  │    │  └───────────────────────────┘   │  │
│  │  │ Image      │  │    │                                   │  │
│  │  │ Viewer     │  │    │  ┌───────────────────────────┐   │  │
│  │  └────────────┘  │    │  │ Native Tool Executors     │   │  │
│  └──────────────────┘    │  │                           │   │  │
│                          │  │  • MusicService (Sonic)   │   │  │
│                          │  │  • DMRepository (Messages)│   │  │
│                          │  │  • ServersNotifier (List)  │   │  │
│                          │  │  • UserSearchService       │   │  │
│                          │  │  • AuthNotifier            │   │  │
│                          │  └───────────────────────────┘   │  │
│                          └─────────────────────────────────┘  │
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                  Persistence Layer                        │  │
│  │  SharedPreferences (sessions + API key)                   │  │
│  └──────────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────────┘
```

### Message Processing Pipeline

```
User Input
    │
    ▼
┌───────────────────────────┐
│ 1. Local Command Parser   │  ← Regex-based pattern matching
│    (play, message, list)  │
└────────┬──────────────────┘
         │ Match found? → Execute immediately
         │ No match? ↓
┌────────▼──────────────────┐
│ 2. Gemini API Call        │  ← Live API with Function Calling
│    (if API key configured)│
└────────┬──────────────────┘
         │ API success? → Return response / Execute tool
         │ API fails? ↓
┌────────▼──────────────────┐
│ 3. Simulated Fallback     │  ← Category-aware mock responses
│    (Text/Image/Code)      │
└───────────────────────────┘
```

---

## File Structure

```
mobile/lib/features/ai_assistant/
├── data/
│   └── aura_chat_service.dart          # Core service: models, notifier, API, tools
│
└── presentation/
    ├── aura_dashboard_screen.dart       # Main Aura hub with tool cards + history
    ├── aura_chat_screen.dart            # Text chat interface with message bubbles
    ├── aura_voice_screen.dart           # Voice companion with 3D sphere + STT/TTS
    ├── aura_sandbox_screen.dart         # Code sandbox for running Aura-generated code
    └── aura_image_viewer_screen.dart    # Full-screen image viewer for generated images
```

---

## Data Models

### `AuraMessage`

Represents a single message in a conversation.

| Field       | Type       | Description                                |
|-------------|------------|--------------------------------------------|
| `id`        | `String`   | Unique message identifier                  |
| `sender`    | `String`   | `'user'` or `'aura'`                      |
| `text`      | `String`   | Message content (supports markdown)        |
| `timestamp` | `DateTime` | When the message was sent                  |
| `isLiked`   | `bool`     | User feedback — liked                      |
| `isDisliked`| `bool`     | User feedback — disliked                   |
| `imageUrl`  | `String?`  | Optional image URL for Image Generator     |

**Serialization**: `toMap()` / `fromMap()` for SharedPreferences JSON storage.

### `AuraSession`

Represents a full conversation session.

| Field        | Type                | Description                               |
|--------------|---------------------|-------------------------------------------|
| `id`         | `String`            | Unique session identifier                 |
| `category`   | `String`            | `'Text Writer'`, `'Image Generator'`, `'Code Tutor'` |
| `title`      | `String`            | Auto-generated from first user message    |
| `messages`   | `List<AuraMessage>` | Ordered list of conversation messages     |
| `lastActive` | `DateTime`          | Last activity timestamp (for sorting)     |

**Serialization**: `toMap()` / `fromMap()` with recursive message serialization.

---

## Core Service — AuraNotifier

**Class**: `AuraNotifier extends Notifier<List<AuraSession>>`
**Provider**: `auraSessionsProvider`

### Key Methods

| Method | Description |
|--------|-------------|
| `build()` | Initializes state, loads sessions from SharedPreferences |
| `createNewSession(category, {initialPrompt})` | Creates a new session with auto-generated title |
| `sendMessage(sessionId, text)` | Full pipeline: add user message → parse → API → fallback → add response |
| `updateMessageFeedback(sessionId, messageId, {like, dislike})` | Toggle like/dislike on messages |
| `deleteSession(sessionId)` | Remove a session from history |
| `clearHistory()` | Remove all sessions |
| `getApiKey()` / `saveApiKey(key)` | Manage Gemini API key in SharedPreferences |

### API Key Management

- Stored securely in **SharedPreferences** under key `aura_gemini_api_key`
- Users can configure via the **key icon** on the Dashboard header
- When empty, Aura operates in **simulated local mode** with category-aware mock responses

---

## Gemini API Integration

### Endpoint

```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key={API_KEY}
```

### System Prompts (per Category)

| Category         | System Prompt Summary |
|------------------|----------------------|
| **Text Writer**  | Creative writing assistant with markdown formatting |
| **Image Generator** | Image generation assistant, confirms and describes scenes |
| **Code Tutor**   | Elite software engineering tutor with code blocks |

### Function Calling (Tools)

Aura registers **3 function declarations** with the Gemini API:

#### `play_song`
```json
{
  "name": "play_song",
  "description": "Play a specific song or search and play music on Sonic Drip.",
  "parameters": {
    "type": "OBJECT",
    "properties": {
      "query": { "type": "STRING", "description": "The song title or search query." }
    },
    "required": ["query"]
  }
}
```

#### `send_dm`
```json
{
  "name": "send_dm",
  "description": "Send a direct message to a user/friend by name.",
  "parameters": {
    "type": "OBJECT",
    "properties": {
      "recipientUsername": { "type": "STRING", "description": "The username or display name." },
      "message": { "type": "STRING", "description": "The text message to send." }
    },
    "required": ["recipientUsername", "message"]
  }
}
```

#### `list_servers`
```json
{
  "name": "list_servers",
  "description": "List the servers the user is currently joined to.",
  "parameters": { "type": "OBJECT", "properties": {} }
}
```

### Response Handling

When Gemini returns a `functionCall` in the response parts, Aura extracts the function name and arguments and routes them to `_executeTool()` for native execution.

---

## Native Feature Integrations

### 🎵 Sonic Drip (Music Player)

**Provider Dependencies**: `musicServiceProvider`, `musicNotifierProvider`

**Flow**:
1. User says: *"Play Blinding Lights"*
2. Local parser matches `play ` prefix OR Gemini returns `play_song` function call
3. `MusicService.searchMusic(query)` searches for matching tracks
4. First result is added to the queue via `MusicNotifier.addToQueue(track)`
5. Response: `🎵 Started playing **Blinding Lights** by **The Weeknd** on Sonic Drip!`

### 💬 Direct Messages

**Provider Dependencies**: `userSearchServiceProvider`, `dmRepositoryProvider`, `authNotifierProvider`

**Flow**:
1. User says: *"message john: hey what's up?"*
2. Local parser extracts `username=john`, `message=hey what's up?`
3. `UserSearchService.searchUsers("john")` finds matching user
4. `AuthNotifier` provides current user ID for `senderId`
5. `DMRepository.sendMessage()` sends the DM
6. Response: `💬 Direct message sent to **@john**: "hey what's up?"`

### 🌐 Servers

**Provider Dependencies**: `serversNotifierProvider`

**Flow**:
1. User says: *"list my servers"*
2. Local parser matches `list servers` / `show servers` / `my servers`
3. `ServersNotifier.servers` returns the current server list
4. Response: formatted bullet list of server names

### Local Command Patterns (Regex Fallback)

| Pattern Prefix | Action | Example |
|---------------|--------|---------|
| `play ` / `queue ` | Play a song | "play lofi beats" |
| `message ` / `msg ` / `text ` | Send DM | "msg alice: hello!" |
| `list servers` / `show servers` / `my servers` | List servers | "list my servers" |

These execute **instantly** without API calls, even when offline.

---

## Chat Interface

**File**: `aura_chat_screen.dart` (673 lines, 21KB)

### Features

- **Real-time message bubbles** with sender differentiation (user = right-aligned, Aura = left-aligned)
- **Typing indicator** — animated pulsing dots while Aura processes
- **Message actions**:
  - 👍 Like / 👎 Dislike feedback
  - 📋 Copy to clipboard
  - 🔊 TTS playback (simulated word-by-word highlight)
  - 🖥️ Open in Sandbox (for code blocks)
  - 🖼️ Open in Image Viewer
- **Code block rendering** with syntax highlighting appearance
- **Image display** with tap-to-fullscreen viewer
- **Auto-scroll** to bottom on new messages

### Design Elements

- **Background**: Pure black (`#050505`) with subtle magenta radial glow
- **User bubbles**: Gradient pink-to-purple with white text
- **Aura bubbles**: Dark grey card (`#141418`) with white text and subtle border
- **Input field**: Bottom-anchored with glassmorphic styling
- **Animations**: `flutter_animate` for fade-in and slide transitions

---

## Voice Companion

**File**: `aura_voice_screen.dart` (730 lines, 24KB)

### State Machine

```
AuraVoiceState.idle → AuraVoiceState.listening → AuraVoiceState.thinking → AuraVoiceState.speaking → idle
```

| State      | Visual | Duration | Sphere Behavior |
|------------|--------|----------|-----------------|
| **Idle**   | Subtle magenta glow | Until tap | Slow rotation, minimal deformation |
| **Listening** | Pulsing pink aura | ~4 seconds | Fast rotation, amplitude-reactive deformation |
| **Thinking** | Purple glow | API call duration | Very fast rotation, compressed grid |
| **Speaking** | Cyan-green word highlights | TTS duration | Moderate rotation, sinusoidal wiggles |

### 3D Wireframe Sphere (`AuraMeshPainter`)

A **custom `CustomPainter`** that renders a fully 3D projected wireframe sphere:

- **Geometry**: Latitude/longitude grid with configurable density (6-16 latitudes × 12-32 longitudes)
- **3D Projection**: Perspective projection with `cameraDistance = 300.0`
- **Rotation**: Dual-axis rotation (X + Y) animated by `AnimationController`
- **Deformation**: Organic trigonometric noise waves (`sin * cos` patterns) modulated by voice amplitude
- **Colors**: Sweep gradient from magenta (`#FF007F`) → purple (`#8B00FF`), switches to purple → cyan for thinking state
- **Boundary Ring**: Outer SweepGradient circle at 1.1× radius

### Audio Pipeline

| Component | Package | Purpose |
|-----------|---------|---------|
| Microphone Recording | `record` | Real-time amplitude capture for sphere animation |
| Speech-to-Text | `speech_to_text` | Convert spoken words to text input |
| Text-to-Speech | `flutter_tts` | Speak Aura's response aloud |
| Permission Handling | `permission_handler` | Microphone access |

### Quick Prompt Selector

Pre-configured topics that auto-fill when speech recognition returns empty:
1. "Instagram Trends" — Top 5 Instagram marketing trends
2. "Healthy Diet" — Basic healthy eating principles
3. "Glassmorphic Widget" — Flutter code for a glass card

---

## Dashboard

**File**: `aura_dashboard_screen.dart` (570 lines, 20KB)

### Layout

```
┌─────────────────────────────────────┐
│  ← AURA AI COMPANION            🔑 │  ← Header + API Key
├─────────────────────────────────────┤
│  Create, explore,                   │
│  be inspired                        │  ← Hero title (Epilogue 38px)
├─────────────────────────────────────┤
│  🔍 Search queries or topics...     │  ← Search bar
├─────────────────────────────────────┤
│  ┌──────┐ ┌──────┐ ┌──────┐       │
│  │ AI   │ │ AI   │ │ AI   │       │  ← Quick Tool Cards
│  │ text │ │image │ │ code │       │     (horizontal scroll)
│  │writer│ │gen   │ │tutor │       │
│  └──────┘ └──────┘ └──────┘       │
├─────────────────────────────────────┤
│  History              Clear all     │
│  ┌─────────────────────────────┐   │
│  │ 📝 How to use Visual Studio │   │  ← Dismissible session cards
│  │    Code Tutor · 2h ago     →│   │
│  └─────────────────────────────┘   │
│  ┌─────────────────────────────┐   │
│  │ ✍️ Healthy eating tips       │   │
│  │    Text Writer · 5h ago    →│   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
            🎤 TALK TO AURA            ← FAB (gradient, animated scale)
```

### Features

- **Session search** — Real-time filtering by title or category
- **Tool cards** — Quick-launch cards for each AI mode
- **History list** — Swipe-to-delete (Dismissible), tap to resume
- **API Key dialog** — Secure input for Gemini API key configuration
- **Voice FAB** — Floating action button linking to Voice Companion

---

## Sandbox & Image Viewer

### Aura Sandbox (`aura_sandbox_screen.dart` — 10.5KB)

- Displays Aura-generated code in a formatted, copyable view
- Split-screen code viewer with syntax highlighting appearance
- Copy-to-clipboard functionality

### Aura Image Viewer (`aura_image_viewer_screen.dart` — 8.7KB)

- Full-screen image viewer for AI-generated images
- Pinch-to-zoom and pan gestures
- Share/download options

---

## Design Language

### Color Palette

| Token | Hex | Usage |
|-------|-----|-------|
| `_bgBlack` | `#000000` / `#050505` | Screen backgrounds |
| `_cardGrey` | `#111115` / `#141418` | Card surfaces |
| `_borderGrey` | `#222228` / `#24242A` | Card borders |
| `_accentPink` | `#FF007F` | Primary accent, user bubbles, action elements |
| `_accentPurple` | `#8B00FF` | Secondary accent, Image Generator mode |
| `_accentCyan` | `#00FFCC` | Code Tutor mode, speaking state |
| `_textWhite` | `#FBF9FA` | Primary text |
| `_textMuted` | `#8E8E93` | Secondary/metadata text |

### Typography

| Font | Usage |
|------|-------|
| **Epilogue** | Hero titles (38px, weight 900) |
| **Space Grotesk** | Section headers, card labels, UI text |
| **Space Mono** | Timestamps, metadata, code blocks |

### Animations

- **flutter_animate**: Fade-in, slide-in for screen elements
- **AnimationController**: 10-second loop for 3D sphere rotation
- **AnimatedSwitcher**: Smooth text transitions in voice subtitle
- **Scale animation**: Mic button pulse during listening state
- **Radial gradient**: Dynamic opacity based on voice state

---

## State Management

```dart
// Main state provider
final auraSessionsProvider = NotifierProvider<AuraNotifier, List<AuraSession>>(AuraNotifier.new);
```

- **Architecture**: Riverpod `Notifier` pattern
- **Persistence**: Automatic save/load via `SharedPreferences` (key: `flicko_aura_sessions`)
- **Cross-reads**: Uses `ref.read()` to access Music, DM, Server, Auth providers for native tool execution
- **Sorting**: Sessions sorted by `lastActive` descending (most recent first)
- **Pre-populated data**: First launch includes 4 mock sessions demonstrating different modes

---

## Routing

| Path | Screen | Parameters |
|------|--------|------------|
| `/profile/settings/aura` | `AuraDashboardScreen` | — |
| `/profile/settings/aura/chat` | `AuraChatScreen` | `?category=...&sessionId=...` |
| `/profile/settings/aura/voice` | `AuraVoiceScreen` | — |

Managed via **GoRouter** navigation with `context.push()` / `context.pop()`.

---

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `flutter_riverpod` | — | State management |
| `dio` | — | HTTP client for Gemini API |
| `shared_preferences` | — | Local persistence |
| `google_fonts` | — | Typography (Epilogue, Space Grotesk, Space Mono) |
| `flutter_animate` | — | Declarative animations |
| `speech_to_text` | — | Voice recognition |
| `flutter_tts` | — | Text-to-speech synthesis |
| `record` | — | Microphone audio recording |
| `permission_handler` | — | Runtime permission requests |
| `path_provider` | — | Temp directory for audio files |

---

## Future Roadmap

### Phase 1 — Enhanced Intelligence 🧠

- [ ] **Multi-turn conversation context** — Send full conversation history to Gemini for contextual responses
- [ ] **Streaming responses** — Use Gemini's SSE streaming for real-time character-by-character output
- [ ] **Model upgrade** — Migrate from `gemini-1.5-flash` to `gemini-2.0-flash` for improved quality
- [ ] **Custom system prompts** — Allow users to configure Aura's personality and behavior

### Phase 2 — Expanded Integrations 🔌

- [ ] **Profile management** — Change username, avatar, status through voice commands
- [ ] **Channel messaging** — Send messages to server channels, not just DMs
- [ ] **Music queue management** — Skip, pause, view queue, shuffle via Aura
- [ ] **Notification control** — Mute/unmute channels, mark as read via commands
- [ ] **Theme switching** — Apply store themes through Aura commands

### Phase 3 — Advanced Voice 🎙️

- [ ] **Wake word detection** — "Hey Aura" always-on listening
- [ ] **Multi-language support** — STT/TTS in 10+ languages
- [ ] **Voice personality modes** — Different TTS voices (calm, energetic, professional)
- [ ] **Real-time audio streaming** — Use Gemini's Multimodal Live API for true voice-to-voice
- [ ] **Ambient mode** — Background listening with contextual suggestions

### Phase 4 — Visual AI 🎨

- [ ] **Real image generation** — Connect to Imagen or DALL-E for actual image creation
- [ ] **Image analysis** — Camera/gallery input with Gemini Vision for image understanding
- [ ] **Code execution sandbox** — Actually run Dart/Python code in an isolated environment
- [ ] **Screen context awareness** — Aura can see and discuss the current screen

### Phase 5 — Social Intelligence 🤝

- [ ] **Conversation summarization** — "What did I miss in #general?"
- [ ] **Smart replies** — AI-suggested quick responses in DM conversations
- [ ] **Meeting scheduler** — Coordinate voice channel meetups with friends
- [ ] **Content moderation assistant** — Help server admins moderate content

### Phase 6 — Personalization 🎯

- [ ] **Learning from feedback** — Use like/dislike data to improve responses
- [ ] **Usage analytics** — Track most-used features and optimize accordingly
- [ ] **Custom tool plugins** — Developer API for third-party tool integrations
- [ ] **Aura memory** — Long-term user preference storage across sessions

---

*Documentation last updated: May 2026*
*Aura AI v1.0 — Flicko Platform*
