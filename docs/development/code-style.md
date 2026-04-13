# Code Style & Guidelines

> **Reading time:** ~5 minutes · **Audience:** Everyone · **Last Updated:** 2026-04-11

To prevent "bike-shedding" PR comments about spacing and variable casing, Flicko mandates strict, automated formatting rules. If a guideline isn't covered here, follow the standard idiomatic rules for the respective language.

---

## 1. Backend (Go)

The Go ecosystem has established definitive formatting rules. We follow them without exception.

### Automated Formatting
Never submit a PR without running `gofmt`. Your editor (VSCode/GoLand) should be configured to run this on save.
```bash
gofmt -w .
```

### Naming Conventions
- **Interfaces:** Single-method interfaces should be suffixed with "er" (e.g., `Reader`, `MessageSender`).
- **Structs:** MixedCaps. Do not use underscores (`UserRepository` not `User_Repository`).
- **Packages:** lower_case, single word, no underscores (e.g., `middleware`, not `middle_ware`).
- **Exported vs Unexported:** Only export variables, structs, or functions (by Capitalizing the first letter) if they explicitly need to be used outside that package. Hide internal states aggressively.

### Error Handling
Go does not use `try/catch`. 
Never discard an error with the `_` blank identifier unless you thoroughly justify it in a comment.

**❌ Bad:**
```go
user, _ := repo.GetUser(id) // Ignoring DB connection errors leads to silent panics
```

**✅ Good:**
```go
user, err := repo.GetUser(id)
if err != nil {
    return nil, fmt.Errorf("failed to fetch user %d: %w", id, err)
}
```

---

## 2. Frontend (TypeScript/React)

The mobile repository is guarded by strict `eslint` and `prettier` configurations.

### Automated Formatting
Run the linter before pushing:
```bash
cd mobile
npm run lint
npm run format
```

### Component Structure
- Function components exclusively. No Class-based components.
- React components must be exported using `export default`.
- Extract complex `StyleSheet` blocks to the absolute bottom of the file (outside the component function) so they don't pollute the render lifecycle readability.

### Type Safety (No `any`)
Do not use TypeScript's `any` type unless you are interacting with a deeply untyped legacy 3rd-party library. 
If defining an incoming WebSocket payload, create a rigorous interface:

**❌ Bad:**
```typescript
const handleEvent = (data: any) => { ... }
```

**✅ Good:**
```typescript
interface WSMessageCreateEvent {
  message_id: string;
  channel_id: string;
  author: User;
  content: string;
}
const handleEvent = (data: WSMessageCreateEvent) => { ... }
```

### Imports Grouping
Sort your imports to keep the header clean:
1. React / Native core modules
2. Third-party `node_modules` (e.g., `zustand`, `axios`)
3. Absolute project imports (e.g., `@/components`, `@/shared`)
4. Relative local imports (e.g., `./styles`)
