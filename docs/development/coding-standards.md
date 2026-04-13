# Development: Coding Standards

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Go Code Standards

### Formatting
- **Formatter:** `gofmt` (enforced via pre-commit hook)
- **Import ordering:** Standard library, then third-party, then internal
- **Naming:** CamelCase for exported, camelCase for unexported
- **Comments:** All exported functions, types, and methods require doc comments

### Patterns
- **Error handling:** Return `error` values, never panic in service code
- **Dependency injection:** Constructor functions (`NewXxxService(deps...)`)
- **Logging:** `zap` structured logging, never `fmt.Println` in production
- **Context:** Always pass `context.Context` as first parameter
- **Testing:** Table-driven tests with `testify`

### Example
```go
// CreateServer creates a new server and returns it.
// Returns an error if the name is invalid or the owner doesn't exist.
func (s *ServerService) CreateServer(ctx context.Context, ownerID uuid.UUID, name string) (*models.Server, error) {
    if err := validate.ServerName(name); err != nil {
        return nil, fmt.Errorf("validate server name: %w", err)
    }
    // ... implementation
}
```

---

## TypeScript/React Native Standards

### Formatting
- **Formatter:** Prettier (enforced via pre-commit hook)
- **Linter:** ESLint with TypeScript rules
- **Configuration:** `.prettierrc` in project root

### Patterns
- **Components:** Functional components with hooks (no class components except ErrorBoundary)
- **State:** Zustand stores in `shared/stores/`
- **Server state:** React Query (`@tanstack/react-query`)
- **Imports:** Path aliases (`@shared/`, `@stores/`, `@services/`, etc.)
- **Types:** TypeScript strict mode, no `any` without justification

### File Naming
| Type | Convention | Example |
|------|-----------|---------|
| Components | PascalCase | `MessageList.tsx` |
| Screens | camelCase | `login.tsx` |
| Services | camelCase.service | `auth.service.ts` |
| Stores | camelCase + Store | `authStore.ts` |
| Utils | camelCase.utils | `validation.utils.ts` |
| Types | camelCase | `models.ts` |

---

## Related Docs
- [Git Workflow](git-workflow.md) — Branching strategy
- [Dev Environment](dev-environment.md) — Setup
