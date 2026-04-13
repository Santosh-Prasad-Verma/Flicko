# Local Setup & Execution

> **Reading time:** ~8 minutes · **Audience:** Everyone · **Last Updated:** 2026-04-11

Running Flicko locally requires spinning up the database, the three separate Go services, and the React Native frontend simultaneously. 

---

## 1. Booting the Datastore (Supabase Local)

Do not connect your local development environment to the public production Supabase instance. You will corrupt live data.

Instead, utilize the Supabase CLI to spin up a Dockerized PostgreSQL instance matching production 1-to-1.

```bash
cd backend
npx supabase start
```

This command will:
1. Pull the Supabase Postgres, Kong, and GoTrue containers.
2. Form alliances on your localhost (`5432`).
3. Automatically apply every SQL file sequentially from `supabase/migrations/` to construct the schema.
4. Output the local `DATABASE_URL` and `JWT_SECRET` keys directly to your terminal.

## 2. Booting the Go Backend (Hot-Reload)

While you *could* run `go run ./cmd/...`, compiling three binaries manually every time you save a `.go` file is tedious. 

We use **Air** for live-reloads. The monorepo has three pre-configured `.air.toml` files.

Open three separate terminal tabs (or a tmux pane) in the root directory:

**Tab 1 (Monolith API):**
```bash
air -c ./cmd/api/.air.toml
# Binds to :8080
```

**Tab 2 (WebSockets):**
```bash
air -c ./cmd/ws-gateway/.air.toml
# Binds to :8081
```

**Tab 3 (Message Batcher):**
```bash
air -c ./cmd/msg-service/.air.toml
# Binds to :8082
```

*(Note: Ensure your root `.env` file contains the local Database URLs provided by the `supabase start` output rather than production keys!)*

## 3. Booting the Mobile App

With all 3 Go services active, we compile the Expo app.

1. Navigate to the frontend directory:
   ```bash
   cd mobile
   ```
2. Install dependencies (skip if done previously):
   ```bash
   npm ci
   ```
3. Start the Expo Metro Bundler:
   ```bash
   npx expo start
   ```

**Connecting Devices:**
- **iOS Simulator:** Press `i` in the terminal to boot Xcode simulator.
- **Android Emulator:** Press `a` in the terminal.
- **Physical Device:** Install the "Expo Go" app from the iOS/Google app store, and scan the massive QR code displayed in the terminal with your phone's camera. Ensure your phone is on the exact same WiFi network as your development laptop.

---

## Modifying URLs for Mobile

**Crucial Step:** When testing on an iOS Simulator or Physical iPhone via Wi-Fi, the React Native app cannot resolve `localhost` mapping back to your laptop. It will look for `localhost` within the iPhone itself and fail.

Inside `mobile/constants/Config.ts`, ensure you change the API bindings to your laptop's explicit local IPv4 address during development.

**Windows/Linux (ifconfig / ipconfig):**
`192.168.1.55`

**Mac:**
System Settings -> Wi-Fi -> Details -> IP Address

```typescript
// Config.ts
export const DEV_API_URL = "http://192.168.1.55:8080/api/v1";
export const DEV_WS_URL = "ws://192.168.1.55:8081/api/v1/ws";
export const DEV_MSG_URL = "http://192.168.1.55:8082/api/v1";
```
