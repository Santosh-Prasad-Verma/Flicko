# Development: Git Workflow

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Branching Strategy

### Main Branch
- `main` — Production-ready code. All pushes trigger CI/CD.

### Feature Branches
```
feature/voice-channel-muting
fix/websocket-reconnect-race
refactor/extract-permission-service
docs/api-endpoint-docs
test/automod-filter-coverage
```

### Workflow
1. Create feature branch from `main`
2. Make changes, commit with conventional commit messages
3. Push branch and open Pull Request
4. Wait for CI checks + code review
5. Merge to `main` (squash merge preferred)

## Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add voice channel muting support
fix: resolve WebSocket reconnect race condition
docs: update API endpoint documentation
refactor: extract permission service from auth middleware
test: add unit tests for automod filter service
chore: update Go dependencies to latest patch versions
```

## Pre-Commit Hooks

**Husky** runs on every commit:
1. `lint-staged` processes staged files:
   - `.ts/.tsx` → Prettier + ESLint
   - `.go` → gofmt
   - `.json/.yaml/.md` → Prettier
2. Commit is rejected if any formatter/linter fails

---

## Related Docs
- [Coding Standards](coding-standards.md)
- [CI/CD](../deployment/ci-cd.md)
