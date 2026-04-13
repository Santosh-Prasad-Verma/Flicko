# Testing Overview

> **Reading time:** ~4 minutes · **Audience:** Everyone · **Last Updated:** 2026-04-11

To ensure extreme reliability—especially given our small core team—Flicko utilizes an automated testing pyramid. We write tests to catch regressions before CI/CD ever allows them to merge to `main`.

---

## The Testing Pyramid

1. **Unit Tests (Fast, High Volume)**
   Test specific functions and Go handlers in isolation using mock dependencies.
2. **Integration Tests (Medium, Critical Paths)**
   Test the interaction between the Go backend and a real (Dockerized) PostgreSQL database to ensure SQL queries and transactions execute flawlessly.
3. **End-to-End (E2E) Tests (Slow, Simulates User)**
   Test the React Native mobile UI workflows using Detox to ensure the entire system works together.
4. **Load & Stress Tests (On-Demand)**
   Simulates 50,000 users connecting WebSockets simultaneously to verify memory limits.

---

## Continuous Integration

Every layer of this pyramid runs automatically via GitHub Actions:
- **Pull Request:** Runs Unit and Integration tests. Does not allow merge until coverage is validated.
- **Pre-Release:** Runs the slow Mobile E2E UI automation suite.

Dive into the specific testing layers:
- [Go Unit Testing Strategy](unit-testing.md) (Golang details & mocks)
- [Postgres Integration Testing](integration-testing.md) (TestContainers & assertions)
- [Mobile UI End-to-End](mobile-e2e.md) (Detox configuration)
- [Load & Stress Testing](load-testing.md) (K6 metrics)
