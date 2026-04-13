# Test Coverage

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Current Coverage

### Go Backend
- **42 test files** covering the service layer
- Highest coverage: `automod_service_test.go` (5.7 KB), `friend_service_test.go` (3.9 KB)
- All tests use table-driven pattern with `testify` assertions

### Generate Coverage Report
```bash
cd backend
go test -coverprofile=coverage.out ./...
go tool cover -func=coverage.out    # Summary
go tool cover -html=coverage.out    # HTML report
```

### Coverage Goals
| Layer | Target | Status |
|-------|--------|--------|
| Services | 70%+ | In progress |
| Middleware | 60%+ | Partial |
| Handlers | 50%+ | Minimal |
| Shared utils | 80%+ | Good |

---

## Related Docs
- [Testing Overview](overview.md)
- [Unit Tests](unit-tests.md)
