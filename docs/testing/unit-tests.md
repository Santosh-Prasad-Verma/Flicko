# Unit Tests

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Go Unit Tests

### Location
`backend/internal/services/*_test.go` — 42 test files

### Framework
- **Testing:** Standard `testing` package
- **Assertions:** `github.com/stretchr/testify` v1.11.1
- **Pattern:** Table-driven tests

### Running
```bash
cd backend && go test -v ./internal/services/...
```

### Test Categories
| Category | Files | Key Tests |
|----------|-------|-----------|
| Auth | 3 | Token validation, session management |
| AutoMod | 1 (5.7 KB) | 8 filter types tested |
| Permissions | 2 | Bitfield math, channel overwrites |
| Friends | 1 (3.9 KB) | Request/accept/block lifecycle |
| Warnings | 1 (3.2 KB) | Escalation thresholds |
| Reports | 1 (2.6 KB) | Report submission and moderation |

## TypeScript Unit Tests

### Location
`shared/stores/__tests__/`, `shared/services/__tests__/`

### Framework
- **Jest** v29.7.0
- **React Testing Library** for component tests

### Running
```bash
cd mobile && npx jest
```

---

## Related Docs
- [Testing Overview](overview.md)
- [Integration Tests](integration-tests.md)
