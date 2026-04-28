# Flicko - Development Guidelines

## Code Quality Standards

### Go Backend Standards

#### File Organization
- **Package naming**: Use lowercase, single-word package names (e.g., `auth`, `bots`, `middleware`)
- **File naming**: Use snake_case for filenames (e.g., `auth_test.go`, `moderation.go`, `idempotency_test.go`)
- **Test files**: Always suffix test files with `_test.go` and use separate test packages (e.g., `package auth_test`)

#### Code Formatting
- **Indentation**: Use tabs (Go standard)
- **Line length**: No strict limit, but keep lines readable (typically < 120 chars)
- **Imports**: Group imports in 3 sections: stdlib, external, internal (separated by blank lines)
```go
import (
    "context"
    "fmt"
    "time"

    "github.com/golang-jwt/jwt/v5"
    "go.uber.org/zap"

    "github.com/flicko-org/flicko-backend/internal/commands"
)
```

#### Naming Conventions
- **Exported functions**: PascalCase (e.g., `GenerateKeyPair`, `ValidateToken`)
- **Unexported functions**: camelCase (e.g., `checkModPermission`, `logAudit`)
- **Constants**: PascalCase for exported, camelCase for unexported (e.g., `AccessTokenTTL`, `validULID`)
- **Interfaces**: Noun or adjective (e.g., `Bot`, `Cmdable`)
- **Receivers**: Use short, consistent names (1-2 letters, e.g., `b *ModerationBot`)

#### Documentation
- **Package comments**: Document package purpose at the top of main file
- **Function comments**: Document all exported functions with complete sentences
- **Inline comments**: Use `//` for single-line, avoid block comments except for large sections
- **Section separators**: Use ASCII art separators for logical sections
```go
// ── Command Handlers ────────────────────────────────────────────────────────
```

### TypeScript/React Native Standards

#### File Organization
- **Component files**: PascalCase (e.g., `AdvancedMessageSearch.tsx`)
- **Utility files**: camelCase (e.g., `searchService.ts`)
- **Type definitions**: Use `interface` for object shapes, `type` for unions/aliases

#### Code Formatting
- **Indentation**: 2 spaces
- **Line length**: Soft limit at 100 characters
- **Semicolons**: Required
- **Quotes**: Single quotes for strings, double quotes for JSX attributes
- **Trailing commas**: Always use in multi-line objects/arrays

#### Naming Conventions
- **Components**: PascalCase (e.g., `FilterChip`, `SearchResultCard`)
- **Props interfaces**: ComponentName + "Props" (e.g., `AdvancedMessageSearchProps`)
- **Hooks**: camelCase with "use" prefix (e.g., `useTheme`, `useCallback`)
- **Constants**: SCREAMING_SNAKE_CASE (e.g., `FILTER_OPTIONS`, `MINIMUM_TOUCH_TARGET`)
- **Event handlers**: "handle" prefix (e.g., `handleAddFilter`, `handleJump`)

#### Documentation
- **JSDoc comments**: Use for complex functions and components
- **Inline comments**: Explain "why" not "what"
- **Section separators**: Use ASCII art for major sections
```typescript
// ── Types ─────────────────────────────────────────────────────────────────
```

## Architectural Patterns

### Go Backend Patterns

#### 1. Context-First Design
Always pass `context.Context` as the first parameter to functions that perform I/O:
```go
func (b *ModerationBot) handleKick(ctx commands.CommandContext) (*commands.CommandResponse, error) {
    reqCtx, cancel := context.WithTimeout(ctx.Ctx, 30*time.Second)
    defer cancel()
    // ... use reqCtx for all I/O operations
}
```

#### 2. Error Handling
- Return errors, don't panic (except in truly exceptional cases)
- Wrap errors with context using `fmt.Errorf("operation failed: %w", err)`
- Log errors at the boundary (handlers, not deep in business logic)
- Use sentinel errors for expected error conditions (e.g., `ErrExpiredToken`)

#### 3. Structured Logging
Use Zap for structured logging with consistent field names:
```go
b.logger.Info("punishment expired",
    zap.String("type", pType),
    zap.String("user", userID),
    zap.String("server", serverID),
)
```

#### 4. Test Helpers
Create helper functions with `t.Helper()` to improve test failure messages:
```go
func generateTestKeys(t *testing.T) (ed25519.PublicKey, ed25519.PrivateKey) {
    t.Helper()
    pub, priv, err := auth.GenerateKeyPair()
    if err != nil {
        t.Fatalf("GenerateKeyPair() error = %v", err)
    }
    return pub, priv
}
```

#### 5. Table-Driven Tests
Use table-driven tests for multiple test cases:
```go
tests := []struct {
    name   string
    header string
}{
    {"no Bearer prefix", "Token abc123"},
    {"empty Bearer", "Bearer "},
    {"Bearer only", "Bearer"},
}

for _, tt := range tests {
    t.Run(tt.name, func(t *testing.T) {
        // test logic
    })
}
```

#### 6. Middleware Pattern
Chain middleware functions for HTTP handlers:
```go
handler := auth.AuthMiddleware(keySet)(
    auth.RequireRole("admin")(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // handler logic
    })),
)
```

#### 7. Bot Registry Pattern
Use a registry for extensible bot systems:
```go
registry := bots.NewRegistry(db, redis, logger)
registry.Register(bots.NewModerationBot(services))
registry.Register(bots.NewAutoModBot(services))
registry.StartAll()
```

### React Native Patterns

#### 1. Memoization
Use `memo` for components and `useMemo`/`useCallback` for expensive computations:
```typescript
const FilterChip = memo(function FilterChip({ filter, onRemove }) {
    // component logic
});

const handleJump = useCallback((message: SearchResultMessage) => {
    // handler logic
}, []);
```

#### 2. Animated Components
Use `react-native-reanimated` for smooth animations:
```typescript
<Animated.View
    entering={FadeIn.duration(150)}
    exiting={FadeOut.duration(100)}
    layout={Layout.springify()}
>
    {/* content */}
</Animated.View>
```

#### 3. Theme Integration
Always use theme colors from `useTheme` hook:
```typescript
const { themeColors } = useTheme();

<View style={[styles.container, { backgroundColor: themeColors.bgPrimary }]}>
```

#### 4. Debounced Search
Use `useEffect` with cleanup for debounced operations:
```typescript
useEffect(() => {
    if (searchTimeoutRef.current) {
        clearTimeout(searchTimeoutRef.current);
    }

    searchTimeoutRef.current = setTimeout(() => {
        performSearch(query.trim(), filters);
    }, 400);

    return () => {
        if (searchTimeoutRef.current) clearTimeout(searchTimeoutRef.current);
    };
}, [query, filters]);
```

#### 5. Accessibility
Always provide accessibility props:
```typescript
<Pressable
    onPress={handlePress}
    hitSlop={8}
    style={styles.button}
    accessibilityRole="button"
    accessibilityLabel="Add filter"
>
```

## Common Code Idioms

### Go Idioms

#### 1. Defer for Cleanup
Always use `defer` for cleanup operations:
```go
reqCtx, cancel := context.WithTimeout(ctx.Ctx, 30*time.Second)
defer cancel()
```

#### 2. Early Returns
Use early returns to reduce nesting:
```go
if err := b.checkModPermission(reqCtx, ctx.ServerID, ctx.UserID); err != nil {
    return &commands.CommandResponse{Content: "❌ Permission denied", Ephemeral: true}, nil
}
// continue with main logic
```

#### 3. Zero Values
Leverage Go's zero values for initialization:
```go
var count int  // automatically 0
var username string  // automatically ""
```

#### 4. Atomic Operations
Use `sync/atomic` for concurrent counters:
```go
var calls atomic.Int32
calls.Add(1)
if c := calls.Load(); c != 1 {
    t.Fatalf("expected 1 call, got %d", c)
}
```

#### 5. String Building
Use `strings.Builder` for efficient string concatenation:
```go
var sb strings.Builder
sb.WriteString("prefix")
sb.WriteString(value)
return sb.String()
```

### TypeScript/React Native Idioms

#### 1. Optional Chaining
Use optional chaining for safe property access:
```typescript
const author = Array.isArray(row.author) ? row.author[0] : row.author;
const username = author?.username || 'unknown';
```

#### 2. Nullish Coalescing
Use `??` for default values (not `||`):
```typescript
const limit = limitFloat ?? 10;
```

#### 3. Type Guards
Use type guards for runtime type checking:
```typescript
if (typeof targetID === 'string') {
    // targetID is string here
}
```

#### 4. Destructuring
Use destructuring for cleaner code:
```typescript
const { themeColors } = useTheme();
const { item } = props;
```

#### 5. Spread Operators
Use spread for immutable updates:
```typescript
setFilters((prev) => [...prev, newFilter]);
```

## Internal API Usage Patterns

### Database Access (Go)

#### 1. Query with Context
Always pass context to database operations:
```go
err := b.ctx.DB.QueryRow(reqCtx,
    `SELECT COUNT(*) FROM warnings WHERE server_id = $1 AND user_id = $2`,
    ctx.ServerID, targetID).Scan(&count)
```

#### 2. Parameterized Queries
Always use parameterized queries to prevent SQL injection:
```go
_, err := b.ctx.DB.Exec(reqCtx,
    `INSERT INTO warnings (server_id, user_id, moderator_id, reason) VALUES ($1, $2, $3, $4)`,
    ctx.ServerID, targetID, ctx.UserID, reason)
```

#### 3. Row Iteration
Always close rows and check for errors:
```go
rows, err := b.ctx.DB.Query(reqCtx, query, args...)
if err != nil {
    return nil, fmt.Errorf("query failed: %w", err)
}
defer rows.Close()

for rows.Next() {
    // scan logic
}
```

### Event Bus (Go)

#### 1. Publishing Events
Use structured event data:
```go
b.ctx.EventBus.Publish(events.Event{
    Type:     events.MemberKick,
    ServerID: ctx.ServerID,
    UserID:   targetID,
    Data:     map[string]interface{}{"moderator_id": ctx.UserID, "reason": reason},
})
```

#### 2. Subscribing to Events
Subscribe with unique handler IDs:
```go
bctx.EventBus.Subscribe(events.CommandInvoke, "mod-commands", b.router.HandleEvent)
bctx.EventBus.Subscribe(events.TickerMinute, "mod-punishment-expiry", b.checkExpiredPunishments)
```

### Supabase Client (TypeScript)

#### 1. Query Building
Chain query methods for complex queries:
```typescript
let dbQuery = supabase
    .from('messages')
    .select(`id, content, created_at, author:profiles!author_id(id, username)`, { count: 'exact' })
    .order('created_at', { ascending: false })
    .range(offset, offset + 24);
```

#### 2. Error Handling
Always check for errors:
```typescript
const { data, count, error } = await dbQuery;
if (error) throw error;
```

## Frequently Used Annotations

### Go Annotations

#### 1. Build Tags
Use build tags for conditional compilation:
```go
//go:build integration
// +build integration
```

#### 2. Generate Directives
Use `go:generate` for code generation:
```go
//go:generate mockgen -source=interface.go -destination=mock_interface.go
```

#### 3. Struct Tags
Use struct tags for JSON/DB mapping:
```go
type User struct {
    ID       string `json:"id" db:"id"`
    Username string `json:"username" db:"username"`
}
```

### TypeScript Annotations

#### 1. JSDoc Comments
Document complex types and functions:
```typescript
/**
 * Advanced Message Search
 *
 * Discord-style message search with filter chips (from, mentions, has,
 * before, after, in, pinned) and paginated result display with
 * "Jump to message" functionality.
 *
 * Requirements: Search UI Feature
 */
```

#### 2. Type Assertions
Use type assertions sparingly:
```typescript
const opt = FILTER_OPTIONS.find(o => o.type === type) as FilterOption;
```

#### 3. Generic Constraints
Use generic constraints for type safety:
```typescript
function getValue<T extends string | number>(value: T): T {
    return value;
}
```

## Testing Standards

### Go Testing

#### 1. Test Naming
- Test functions: `TestFunctionName`
- Subtests: Use `t.Run(name, func(t *testing.T) {})`
- Benchmark functions: `BenchmarkFunctionName`

#### 2. Test Organization
Group tests by functionality with section comments:
```go
// ============================================================
//  jwt.go — token generation + validation tests
// ============================================================
```

#### 3. Test Fixtures
Use `t.TempDir()` for temporary directories:
```go
dir := t.TempDir()
privPath := filepath.Join(dir, "private.pem")
```

#### 4. Test Cleanup
Use `t.Cleanup()` for cleanup operations:
```go
rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
t.Cleanup(func() { _ = rdb.Close() })
```

### TypeScript Testing

#### 1. Test Structure
Use describe/it blocks for organization:
```typescript
describe('AdvancedMessageSearch', () => {
    it('should render search input', () => {
        // test logic
    });
});
```

#### 2. Mocking
Use jest mocks for external dependencies:
```typescript
jest.mock('../../services/supabase', () => ({
    supabase: mockSupabase,
}));
```

## Performance Optimization

### Go Performance

#### 1. Avoid Allocations
Reuse buffers and slices:
```go
buf := make([]byte, 0, 1024)  // pre-allocate capacity
```

#### 2. Use Sync.Pool
Pool expensive objects:
```go
var bufferPool = sync.Pool{
    New: func() interface{} {
        return new(bytes.Buffer)
    },
}
```

#### 3. Batch Operations
Batch database operations:
```go
// Insert multiple rows in single transaction
tx, _ := db.Begin(ctx)
for _, item := range items {
    tx.Exec(ctx, query, item)
}
tx.Commit(ctx)
```

### React Native Performance

#### 1. FlatList Optimization
Use `keyExtractor` and `getItemLayout`:
```typescript
<FlatList
    data={results}
    keyExtractor={(item) => item.id}
    getItemLayout={(data, index) => ({
        length: ITEM_HEIGHT,
        offset: ITEM_HEIGHT * index,
        index,
    })}
/>
```

#### 2. Image Optimization
Use `cached_network_image` for image caching:
```typescript
<CachedImage
    source={{ uri: imageUrl }}
    style={styles.image}
    resizeMode="cover"
/>
```

## Security Best Practices

### Input Validation
- Always validate user input at API boundaries
- Use parameterized queries for database operations
- Sanitize HTML/markdown content before rendering

### Authentication
- Use short-lived access tokens (15 minutes)
- Implement refresh token rotation
- Validate JWT signatures with public key

### Authorization
- Check permissions at both application and database layers
- Use Row-Level Security (RLS) policies in PostgreSQL
- Implement least-privilege principle

### Error Handling
- Never expose internal error details to clients
- Log errors with context but redact sensitive data
- Return generic error messages to users
