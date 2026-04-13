# Contributing to Flicko

Thank you for your interest in contributing to Flicko! This guide covers everything you need to know to contribute effectively to the project, from setting up your development environment to submitting a polished pull request. Flicko is a complex, multi-service platform — the guide is organized so you can focus on the area most relevant to your contribution.

> **Reading time:** ~20 minutes for the full guide. Skip to the section relevant to your contribution type using the table of contents below.

---

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Environment Setup](#development-environment-setup)
- [Project Architecture Overview](#project-architecture-overview)
- [How to Add a New API Endpoint](#how-to-add-a-new-api-endpoint)
- [How to Add a New Bot Command](#how-to-add-a-new-bot-command)
- [How to Create a Database Migration](#how-to-create-a-database-migration)
- [How to Add a New Zustand Store](#how-to-add-a-new-zustand-store)
- [How to Add a New Mobile Screen](#how-to-add-a-new-mobile-screen)
- [Go Code Style Guide](#go-code-style-guide)
- [TypeScript/React Native Code Style Guide](#typescriptreact-native-code-style-guide)
- [Commit Conventions](#commit-conventions)
- [Pull Request Process](#pull-request-process)
- [Testing Requirements](#testing-requirements)
- [Documentation Requirements](#documentation-requirements)
- [Common Pitfalls](#common-pitfalls)
- [Getting Help](#getting-help)

---

## Code of Conduct

All contributors must follow our [Code of Conduct](CODE_OF_CONDUCT.md). We are committed to providing a welcoming and inclusive experience for everyone. Please read it before contributing — we enforce it actively.

---

## Getting Started

Before making any contribution, familiarize yourself with the project structure and architecture. Flicko consists of three Go microservices (`ws-gateway`, `msg-service`, `backend`), a React Native mobile app, and shared TypeScript code. Understanding which service owns which functionality is essential for placing your changes correctly.

```bash
# 1. Fork the repository on GitHub
# 2. Clone your fork
git clone https://github.com/YOUR_USERNAME/Flicko.git
cd Flicko

# 3. Add upstream remote
git remote add upstream https://github.com/Santosh-Prasad-Verma/Flicko.git

# 4. Install root dependencies (Husky pre-commit hooks, Prettier, lint-staged)
npm install

# 5. Create a feature branch from main
git checkout -b feature/your-feature-name
```

The `npm install` at the root level is critical — it sets up Husky pre-commit hooks that automatically run Prettier on staged TypeScript/JSON/YAML/Markdown files and `gofmt` on Go files. If you skip this step, your commits may fail CI formatting checks.

---

## Development Environment Setup

Flicko's 3-service architecture requires a specific setup. Follow these steps carefully to ensure all services can communicate correctly during local development.

### Prerequisites

| Tool | Minimum Version | Verification Command | Purpose in Flicko |
|------|----------------|---------------------|-------------------|
| **Go** | 1.22+ | `go version` | All 3 backend services |
| **Node.js** | 18.0+ | `node --version` | Mobile app, shared packages |
| **npm** | 9.0+ | `npm --version` | Dependency management |
| **Docker** | 24.0+ | `docker --version` | Production deployment testing |
| **Git** | 2.30+ | `git --version` | Version control |

### Setting Up Backend Services

Each of the three Go services has its own `go.mod` (or uses the shared `go.work` workspace). Here's how to set up and run each one:

```bash
# msg-service — REST API (runs on port 8081)
cd services/msg-service
go mod download
go run ./cmd/server

# ws-gateway — WebSocket Gateway (runs on port 8080)
cd services/ws-gateway
go mod download
go run ./cmd/gateway

# backend — Bot Framework (runs on port 8080)
cd backend
go mod download
go run ./cmd/server
```

The Go workspace file (`services/go.work`) links the three service modules together, allowing shared package imports without publishing to a module registry. When you modify code in `services/shared/`, all services that import those packages will pick up the changes on the next build.

### Setting Up the Mobile App

The React Native app uses Expo SDK 54 with file-based routing. The development server connects to your local backend services via environment variables.

```bash
cd mobile
npm install

# Configure the API URL to point to your local backend
cp .env.example .env
# Edit .env and set:
# EXPO_PUBLIC_API_URL=http://<YOUR_LOCAL_IP>:8081
# EXPO_PUBLIC_WS_URL=ws://<YOUR_LOCAL_IP>:8080/ws

# Start the Expo development server
npx expo start
```

> **Important:** Use your machine's local network IP (e.g., `192.168.1.x`), not `localhost`, because the mobile app runs in a simulator/device on a different network interface. You can find your IP with `ifconfig | grep "inet "` on macOS or `hostname -I` on Linux.

### Environment Configuration

All environment variables are documented in [`docs/getting-started/configuration.md`](getting-started/configuration.md). For local development, the critical ones are:

```env
# Database — Supabase project credentials
DATABASE_URL=postgresql://postgres.XXXXX:PASSWORD@HOST:6543/postgres
SUPABASE_URL=https://XXXXX.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJhbGci...

# Redis — Upstash credentials
REDIS_URL=rediss://default:TOKEN@HOST:6379

# Auth
JWT_SECRET=your-development-secret-minimum-32-chars

# Media
CLOUDINARY_CLOUD_NAME=your_cloud
CLOUDINARY_API_KEY=123456789
CLOUDINARY_API_SECRET=your_secret
```

---

## Project Architecture Overview

Understanding where to place your changes is the most important decision you'll make as a contributor. Here's the service ownership map:

```mermaid
graph LR
    subgraph MSG["msg-service (REST API)"]
        A1[Message CRUD]
        A2[Channel Management]
        A3[Server APIs]
        A4[User APIs]
        A5[Media Upload Signing]
    end

    subgraph WS["ws-gateway (WebSocket)"]
        B1[Message Delivery]
        B2[Typing Indicators]
        B3[Presence Updates]
        B4[Voice State]
    end

    subgraph BE["backend (Bot Framework)"]
        C1[8 Built-in Bots]
        C2[Slash Commands]
        C3[AutoMod Engine]
        C4[Event Bus]
    end

    subgraph SHARED["shared/ (TypeScript)"]
        D1[51 API Services]
        D2[22 Zustand Stores]
        D3[Type Definitions]
        D4[Utilities]
    end
```

**Decision tree for where to add code:**

1. **Adding a new REST endpoint?** → `services/msg-service/` (or `backend/` if bot-related)
2. **Adding a real-time event?** → `services/ws-gateway/` for delivery, `services/shared/protocol/` for the opcode
3. **Adding a bot command?** → `backend/internal/bots/` for the handler, `backend/internal/commands/` for routing
4. **Adding a new database table?** → `supabase/migrations/` for the SQL, `backend/internal/models/` for the Go struct
5. **Adding a mobile screen?** → `mobile/app/` for the route, `mobile/components/` for UI components
6. **Adding API client code?** → `shared/services/` for the service, `shared/stores/` for state management
7. **Adding shared Go code?** → `services/shared/` for utilities used by multiple services

---

## How to Add a New API Endpoint

Adding a new REST endpoint follows the handler → service → repository pattern used throughout `msg-service`. Here's the complete process with actual Flicko code patterns:

### Step 1: Define the Route

Routes are registered in the main server setup. Find the router group for your domain and add the new endpoint:

```go
// services/msg-service/cmd/server/main.go (or route registration file)
// Follow the existing pattern for organizing routes by resource

// Protected routes (require JWT authentication)
protectedRouter := r.PathPrefix("/api/v1").Subrouter()
protectedRouter.Use(middleware.Auth(jwtSecret, supabaseURL, supabaseKey))

// Your new endpoint
protectedRouter.HandleFunc("/api/v1/your-resource", handlers.CreateYourResource).Methods("POST")
protectedRouter.HandleFunc("/api/v1/your-resource/{id}", handlers.GetYourResource).Methods("GET")
```

### Step 2: Create the Handler

Handlers are thin — they parse the request, call the service, and format the response. Never put business logic in handlers.

```go
// backend/internal/handlers/your_resource.go (new file)
package handlers

import (
    "encoding/json"
    "net/http"

    "github.com/Santosh-Prasad-Verma/Flicko/backend/internal/services"
)

type YourResourceHandler struct {
    service *services.YourResourceService
}

func NewYourResourceHandler(service *services.YourResourceService) *YourResourceHandler {
    return &YourResourceHandler{service: service}
}

// CreateYourResource handles POST /api/v1/your-resource
// It validates the request body, calls the service layer, and returns
// the newly created resource as JSON. Returns 400 for invalid input,
// 401 for unauthorized access, 500 for internal errors.
func (h *YourResourceHandler) CreateYourResource(w http.ResponseWriter, r *http.Request) {
    var req CreateYourResourceRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        http.Error(w, `{"error":"Invalid request body"}`, http.StatusBadRequest)
        return
    }

    userID := r.Context().Value("user_id").(string)

    resource, err := h.service.Create(r.Context(), userID, req)
    if err != nil {
        // Use the standard error response pattern
        handleError(w, err)
        return
    }

    w.Header().Set("Content-Type", "application/json")
    w.WriteHeader(http.StatusCreated)
    json.NewEncoder(w).Encode(resource)
}
```

### Step 3: Create the Service

Services contain all business logic — validation, authorization checks, database operations.

```go
// backend/internal/services/your_resource_service.go (new file)
package services

import (
    "context"
    "database/sql"
    "fmt"

    "go.uber.org/zap"
)

type YourResourceService struct {
    db     *sql.DB
    logger *zap.Logger
}

func NewYourResourceService(db *sql.DB, logger *zap.Logger) *YourResourceService {
    return &YourResourceService{db: db, logger: logger}
}

// Create inserts a new resource into the database after validating the input
// and checking the user's permissions. It returns the created resource with
// its generated ID and timestamps. The function uses a transaction to ensure
// atomicity when multiple tables need to be updated together.
func (s *YourResourceService) Create(ctx context.Context, userID string, req CreateYourResourceRequest) (*YourResource, error) {
    s.logger.Info("creating resource",
        zap.String("user_id", userID),
        zap.String("name", req.Name),
    )

    var resource YourResource
    err := s.db.QueryRowContext(ctx,
        `INSERT INTO your_resources (name, owner_id, created_at)
         VALUES ($1, $2, NOW())
         RETURNING id, name, owner_id, created_at`,
        req.Name, userID,
    ).Scan(&resource.ID, &resource.Name, &resource.OwnerID, &resource.CreatedAt)

    if err != nil {
        s.logger.Error("failed to create resource", zap.Error(err))
        return nil, fmt.Errorf("create resource: %w", err)
    }

    return &resource, nil
}
```

### Step 4: Create the Model

```go
// backend/internal/models/your_resource.go (new file)
package models

import "time"

// YourResource represents a [description] in the Flicko platform.
// It is stored in the your_resources database table and is owned by
// a single user, identified by OwnerID.
type YourResource struct {
    ID        string    `json:"id" db:"id"`
    Name      string    `json:"name" db:"name"`
    OwnerID   string    `json:"owner_id" db:"owner_id"`
    CreatedAt time.Time `json:"created_at" db:"created_at"`
}
```

### Step 5: Add the Frontend Service

```typescript
// shared/services/yourResourceService.ts (new file)
import { supabase } from './supabase';

export interface YourResource {
  id: string;
  name: string;
  owner_id: string;
  created_at: string;
}

interface CreateYourResourceRequest {
  name: string;
}

/**
 * Creates a new resource via the msg-service REST API.
 * Automatically includes the JWT auth token in the Authorization header
 * via the Supabase client's fetch wrapper. Returns the created resource
 * with server-generated ID and timestamp.
 */
export async function createYourResource(
  req: CreateYourResourceRequest
): Promise<YourResource> {
  const { data: { session } } = await supabase.auth.getSession();
  if (!session) throw new Error('Not authenticated');

  const response = await fetch(`${API_URL}/api/v1/your-resource`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${session.access_token}`,
    },
    body: JSON.stringify(req),
  });

  if (!response.ok) {
    const error = await response.json();
    throw new Error(error.error || 'Failed to create resource');
  }

  return response.json();
}
```

---

## How to Add a New Bot Command

The bot system uses a registry pattern where each bot subscribes to events and handles slash commands. Here's how to add a new command to an existing bot:

### Step 1: Define the Command

Add your command to the bot's command list in its file under `backend/internal/bots/`:

```go
// backend/internal/bots/moderation.go (existing file — add to Commands slice)
func (b *ModerationBot) Commands() []commands.Command {
    return []commands.Command{
        // ... existing commands ...
        {
            Name:        "your-command",
            Description: "What this command does in one sentence",
            Usage:       "/your-command <required_arg> [optional_arg]",
            Permission:  models.PermissionModerate, // Required permission
            Handler:     b.handleYourCommand,
        },
    }
}
```

### Step 2: Implement the Handler

```go
// Handler receives the parsed command context including the invoking user,
// the channel it was invoked in, and the parsed arguments. It should return
// a response that will be sent as a bot message in the same channel.
func (b *ModerationBot) handleYourCommand(ctx *commands.Context) (*commands.Response, error) {
    if len(ctx.Args) < 1 {
        return &commands.Response{
            Content: "❌ Usage: `/your-command <required_arg>`",
            Ephemeral: true, // Only visible to the invoker
        }, nil
    }

    targetArg := ctx.Args[0]

    // Perform your action using injected services
    err := b.services.YourService.DoAction(ctx.Context, ctx.ServerID, targetArg)
    if err != nil {
        b.logger.Error("your-command failed",
            zap.String("server_id", ctx.ServerID),
            zap.Error(err),
        )
        return nil, fmt.Errorf("your-command: %w", err)
    }

    return &commands.Response{
        Content: fmt.Sprintf("✅ Successfully performed action on %s", targetArg),
    }, nil
}
```

### Step 3: Register in Command Router

The command router in `backend/internal/commands/router.go` (197 lines) automatically discovers commands from registered bots, so no manual registration is needed — just restart the service.

---

## How to Create a Database Migration

Flicko uses Supabase migrations (stored in `supabase/migrations/`) for the primary schema and backend-local migrations (in `backend/migrations/`) for service-specific tables.

### Naming Convention

All Supabase migration files follow this pattern:

```
YYYYMMDDHHMMSS_descriptive_name.sql
```

For example:
```
20260411120000_add_server_analytics_table.sql
```

### Creating a New Migration

```bash
# Using Supabase CLI (recommended)
cd supabase
npx supabase migration new add_your_feature_table

# This creates: supabase/migrations/YYYYMMDDHHMMSS_add_your_feature_table.sql
```

### Migration Template

Every migration should follow this pattern used throughout the existing 65 migrations:

```sql
-- Migration: Add your_feature table
-- Description: Creates the your_feature table for [purpose].
--              Referenced by [which service/feature].

-- Create the table
CREATE TABLE IF NOT EXISTS public.your_feature (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    name TEXT NOT NULL CHECK (char_length(name) BETWEEN 1 AND 100),
    enabled BOOLEAN NOT NULL DEFAULT true,
    config JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Index for common lookups
CREATE INDEX IF NOT EXISTS idx_your_feature_server_id
    ON public.your_feature(server_id);

-- Enable Row-Level Security
ALTER TABLE public.your_feature ENABLE ROW LEVEL SECURITY;

-- RLS Policy: Server members can view
CREATE POLICY "Server members can view your_feature"
    ON public.your_feature
    FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.members
            WHERE members.server_id = your_feature.server_id
            AND members.user_id = auth.uid()
        )
    );

-- RLS Policy: Only admins can modify
CREATE POLICY "Admins can modify your_feature"
    ON public.your_feature
    FOR ALL
    USING (
        EXISTS (
            SELECT 1 FROM public.members m
            JOIN public.member_roles mr ON mr.member_id = m.id
            JOIN public.roles r ON r.id = mr.role_id
            WHERE m.server_id = your_feature.server_id
            AND m.user_id = auth.uid()
            AND (r.permissions & 8) = 8  -- MANAGE_SERVER permission bit
        )
    );
```

---

## How to Add a New Zustand Store

The 22 existing stores follow a consistent pattern. Here's how to add a new one that fits the existing architecture:

```typescript
// shared/stores/yourFeatureStore.ts (new file)
import { create } from 'zustand';

/**
 * YourFeatureStore manages the state for [feature description].
 *
 * This store follows the same pattern as all 22 existing stores:
 * - TypeScript interface defining the state shape
 * - Zustand create() with combined state and actions
 * - Async actions that call service functions
 * - Loading and error state tracking
 */

interface YourFeatureState {
  // Data
  items: YourFeatureItem[];
  selectedItemId: string | null;

  // UI state
  isLoading: boolean;
  error: string | null;

  // Actions
  fetchItems: (serverId: string) => Promise<void>;
  createItem: (serverId: string, data: CreateItemData) => Promise<void>;
  deleteItem: (itemId: string) => Promise<void>;
  setSelectedItem: (itemId: string | null) => void;
  clearError: () => void;
}

export const useYourFeatureStore = create<YourFeatureState>((set, get) => ({
  // Initial state
  items: [],
  selectedItemId: null,
  isLoading: false,
  error: null,

  // Async action: fetch items for a server
  fetchItems: async (serverId: string) => {
    set({ isLoading: true, error: null });
    try {
      const items = await yourFeatureService.getItems(serverId);
      set({ items, isLoading: false });
    } catch (err) {
      set({ error: (err as Error).message, isLoading: false });
    }
  },

  // Sync action: set selected item
  setSelectedItem: (itemId: string | null) => {
    set({ selectedItemId: itemId });
  },

  clearError: () => set({ error: null }),
}));
```

---

## How to Add a New Mobile Screen

Flicko uses Expo Router's file-based routing. Adding a new screen is as simple as creating a new `.tsx` file in the correct directory:

```typescript
// mobile/app/your-feature.tsx (creates route: /your-feature)
import React, { useEffect } from 'react';
import { View, Text, StyleSheet, FlatList, ActivityIndicator } from 'react-native';
import { useYourFeatureStore } from '@shared/stores/yourFeatureStore';
import { useTheme } from '@/hooks/useTheme';
import { spacing, typography } from '@/constants/Colors';

/**
 * YourFeatureScreen displays [description].
 *
 * Route: /your-feature
 * Auth: Required (protected by AuthGate provider)
 * Data: Loaded from yourFeatureStore via Zustand
 */
export default function YourFeatureScreen() {
  const { colors } = useTheme();
  const { items, isLoading, error, fetchItems } = useYourFeatureStore();

  useEffect(() => {
    fetchItems('current-server-id');
  }, []);

  if (isLoading) {
    return (
      <View style={[styles.center, { backgroundColor: colors.bgPrimary }]}>
        <ActivityIndicator color={colors.accentPrimary} />
      </View>
    );
  }

  return (
    <View style={[styles.container, { backgroundColor: colors.bgPrimary }]}>
      <Text style={[styles.title, { color: colors.textPrimary }]}>
        Your Feature
      </Text>
      <FlatList
        data={items}
        keyExtractor={(item) => item.id}
        renderItem={({ item }) => (
          <View style={[styles.card, { backgroundColor: colors.cardBg }]}>
            <Text style={{ color: colors.textPrimary }}>{item.name}</Text>
          </View>
        )}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: spacing.lg },
  center: { flex: 1, justifyContent: 'center', alignItems: 'center' },
  title: { ...typography.headingL, marginBottom: spacing.lg },
  card: { padding: spacing.md, borderRadius: 8, marginBottom: spacing.sm },
});
```

---

## Go Code Style Guide

The Go codebase follows these conventions, derived from the actual patterns found across all 95+ service files:

### Naming

```go
// Package names: single lowercase word, no underscores
package services     // ✅
package userServices // ❌

// Exported types: PascalCase with descriptive names
type ServerService struct {}          // ✅
type SrvSvc struct {}                 // ❌

// Functions: verb-first naming
func CreateServer() {}               // ✅
func ServerCreate() {}               // ❌

// Variables: camelCase
var serverCount int                   // ✅
var server_count int                  // ❌
```

### Dependency Injection Pattern

Every service in Flicko uses constructor injection — no global state:

```go
// Constructor injection pattern used across all 95 service files
type AutoModService struct {
    db     *sql.DB
    redis  *redis.Client
    logger *zap.Logger
}

func NewAutoModService(db *sql.DB, redis *redis.Client, logger *zap.Logger) *AutoModService {
    return &AutoModService{
        db:     db,
        redis:  redis,
        logger: logger,
    }
}
```

### Error Handling

```go
// Always wrap errors with context
result, err := s.db.QueryRowContext(ctx, query, args...)
if err != nil {
    return nil, fmt.Errorf("get server by id: %w", err)
}

// Use structured logging for errors
s.logger.Error("failed to create message",
    zap.String("channel_id", channelID),
    zap.String("user_id", userID),
    zap.Error(err),
)
```

### Formatting

```bash
# gofmt is enforced by Husky pre-commit hooks
gofmt -w .

# Run before committing
go vet ./...
```

---

## TypeScript/React Native Code Style Guide

### Component Pattern

All components use functional components with TypeScript interfaces for props:

```typescript
// Functional component with typed props
interface MessageBubbleProps {
  message: Message;
  isOwn: boolean;
  onLongPress?: (message: Message) => void;
}

export function MessageBubble({ message, isOwn, onLongPress }: MessageBubbleProps) {
  const { colors } = useTheme();
  // ...
}
```

### File Naming

```
Components:     PascalCase.tsx    (MessageBubble.tsx)
Screens:        kebab-case.tsx    (flicko-plus.tsx)
Services:       camelCase.ts      (cloudinaryService.ts)
Stores:         camelCase.ts      (authStore.ts)
Types:          camelCase.ts      (types.ts)
Utils:          camelCase.ts      (validation.ts)
Constants:      PascalCase.ts     (Colors.ts)
```

### Import Organization

```typescript
// 1. React/React Native
import React, { useState, useEffect } from 'react';
import { View, Text, StyleSheet } from 'react-native';

// 2. Third-party libraries
import { useRouter } from 'expo-router';

// 3. Shared stores and services
import { useAuthStore } from '@shared/stores/authStore';
import { serverService } from '@shared/services/serverService';

// 4. Local components and hooks
import { Button } from '@/components/ui/Button';
import { useTheme } from '@/hooks/useTheme';

// 5. Constants and types
import { spacing, typography } from '@/constants/Colors';
```

---

## Commit Conventions

All commits must follow the [Conventional Commits](https://www.conventionalcommits.org/) specification. This is enforced by Husky pre-commit hooks and enables automated changelog generation.

| Prefix | Usage | Example |
|--------|-------|---------|
| `feat:` | New feature | `feat: add voice channel muting support` |
| `fix:` | Bug fix | `fix: resolve WebSocket reconnection loop on Android` |
| `docs:` | Documentation only | `docs: add AutoMod filter configuration guide` |
| `refactor:` | Code change without feature/fix | `refactor: extract message validation to shared package` |
| `test:` | Adding/updating tests | `test: add table-driven tests for friend service` |
| `chore:` | Dependencies, CI, tooling | `chore: bump go-redis/v9 to latest` |
| `perf:` | Performance improvement | `perf: add index on messages(channel_id, created_at)` |
| `style:` | Formatting only | `style: run gofmt on middleware package` |
| `ci:` | CI/CD changes | `ci: add Docker build caching to GitHub Actions` |

### Scope (optional)

Use scope to indicate which service or area is affected:

```
feat(ws-gateway): add connection draining before shutdown
fix(msg-service): handle nil pointer in batch flush
feat(mobile): add AMOLED theme toggle to settings
docs(security): document CSRF token validation flow
```

---

## Pull Request Process

### Before Submitting

1. **Run all Go tests:**
   ```bash
   cd backend && go test -v ./...
   cd services/msg-service && go test -v ./...
   cd services/ws-gateway && go test -v ./...
   ```

2. **Run formatting:**
   ```bash
   gofmt -w .                          # Go
   npx prettier --write .              # TypeScript/JSON/YAML
   ```

3. **Check for lint issues:**
   ```bash
   go vet ./...                        # Go
   cd mobile && npx eslint . --ext .ts,.tsx  # TypeScript
   ```

4. **Test your changes in the mobile app** (if applicable)

5. **Update documentation** if your changes affect any documented behavior

### PR Template

```markdown
## Description
[What does this PR do? Why is it needed?]

## Type of Change
- [ ] New feature
- [ ] Bug fix
- [ ] Refactoring
- [ ] Documentation
- [ ] Tests

## Services Affected
- [ ] ws-gateway
- [ ] msg-service
- [ ] backend
- [ ] mobile
- [ ] shared
- [ ] supabase (migrations)
- [ ] infrastructure (Docker, NGINX, monitoring)

## Testing
[How was this tested? Include test commands and results]

## Database Changes
- [ ] No database changes
- [ ] New migration added (file: `XXXXXXXXXX_name.sql`)
- [ ] RLS policies updated

## Checklist
- [ ] Code follows Flicko style guidelines
- [ ] Tests pass locally
- [ ] Documentation updated (if applicable)
- [ ] No hardcoded secrets or credentials
- [ ] Error cases are handled
```

---

## Testing Requirements

Every contribution that adds new functionality must include corresponding tests. The project uses:

- **Go:** Standard `testing` package + `testify` v1.11.1 for assertions. All 42 existing test files use the table-driven test pattern.
- **TypeScript:** Jest v29.7.0 for shared packages and services.

### Minimum Test Requirements

| Change Type | Required Tests |
|-------------|---------------|
| New Go service function | Table-driven unit test in `*_test.go` |
| New API endpoint | Handler test + service test |
| New bot command | Handler test with mock context |
| New database migration | Verify with `go test` that models still scan correctly |
| New mobile screen | Snapshot test (optional but recommended) |
| Bug fix | Regression test covering the fixed bug |

```go
// Example: Table-driven test following Flicko convention
func TestAutoModService_CheckInviteLinks(t *testing.T) {
    tests := []struct {
        name     string
        content  string
        expected bool
    }{
        {"detects discord.gg invite", "join us at discord.gg/abc123", true},
        {"detects invite.gg invite", "check invite.gg/xyz", true},
        {"ignores normal text", "hello world", false},
        {"ignores partial match", "discordgg is not an invite", false},
    }

    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            result := service.ContainsInviteLink(tt.content)
            assert.Equal(t, tt.expected, result)
        })
    }
}
```

---

## Documentation Requirements

When your contribution changes any documented behavior, update the corresponding documentation file in `docs/`. Here's the mapping:

| Change Area | Documentation to Update |
|-------------|----------------------|
| New API endpoint | `docs/api/endpoints/*.md`, `docs/api/api-overview.md` |
| New bot command | `docs/features/bot-system.md` |
| Database schema change | `docs/database/schema.md`, `docs/database/migrations.md` |
| New environment variable | `docs/getting-started/configuration.md` |
| Security change | `docs/security/*.md` |
| New mobile screen | `docs/frontend/pages-routes.md` |
| Docker changes | `docs/deployment/docker.md` |

---

## Common Pitfalls

1. **Don't use `localhost` in mobile app config** — Simulators and physical devices can't resolve `localhost` to the host machine. Use your LAN IP address instead.

2. **Don't forget RLS policies** — Every new table must have Row-Level Security enabled and appropriate policies. Without RLS, Supabase clients will get empty results.

3. **Don't put business logic in handlers** — Keep handlers thin (parse request → call service → format response). All logic belongs in service files.

4. **Don't use global state in Go** — Every dependency is injected via constructors. No `init()` functions, no package-level variables for stateful objects.

5. **Don't hardcode IDs or secrets** — All configuration comes from environment variables. The `config.Load()` function validates required variables at startup.

6. **Don't skip the pre-commit hooks** — Run `npm install` at the root to set up Husky. Commits with incorrect formatting will fail CI.

---

## Getting Help

- **Questions about the codebase:** Open a GitHub Discussion
- **Bug reports:** Open a GitHub Issue with reproduction steps
- **Feature requests:** Open a GitHub Issue with the `enhancement` label
- **Security vulnerabilities:** Email privately — DO NOT open a public issue

---

## Related Documentation

- [Code of Conduct](CODE_OF_CONDUCT.md) — Community standards and expectations for all contributors
- [Getting Started: Installation](getting-started/installation.md) — Detailed setup instructions for the complete development environment
- [Architecture: System Overview](architecture/system-overview.md) — Deep dive into the 3-service architecture and communication patterns
- [Development: Coding Standards](development/coding-standards.md) — Complete coding standards for Go and TypeScript
- [Testing: Overview](testing/overview.md) — Full testing strategy and coverage requirements

## Quick Reference

| Item | Value |
|------|-------|
| **Branching model** | Feature branches off `main` |
| **Commit convention** | Conventional Commits |
| **Go formatter** | `gofmt` (enforced by Husky) |
| **TS formatter** | Prettier (enforced by Husky) |
| **Test framework (Go)** | `testing` + testify v1.11.1 |
| **Test framework (TS)** | Jest v29.7.0 |
| **PR reviewers** | Auto-assigned by CODEOWNERS |

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
