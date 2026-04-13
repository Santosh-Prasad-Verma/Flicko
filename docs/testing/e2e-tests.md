# End-to-End Tests

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Current Status
E2E testing is minimal. The current testing strategy relies on:
1. Go unit tests for backend logic
2. Docker health checks for service availability
3. Manual testing for UI flows

## Recommended E2E Setup
For comprehensive E2E testing, consider:
- **Detox** — React Native E2E testing framework
- **Maestro** — Mobile UI testing with YAML flows
- **k6** — Load testing for WebSocket and REST APIs

## Related Docs
- [Testing Overview](overview.md)
