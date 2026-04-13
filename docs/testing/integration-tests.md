# Integration Tests

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Overview
Integration tests verify the interaction between services (database queries, Redis pub/sub, Cloudinary signing).

### Mail Gateway Integration Tests
Location: `mail-gateway/tests/`

Tests the complete email delivery pipeline:
- Template rendering
- Queue processing
- SMTP delivery (with mock server)

### Health Check Integration
The health endpoints serve as runtime integration tests:
```bash
curl http://localhost:8080/api/v1/healthz/ready
# Returns 200 if both PostgreSQL and Redis are connected
```

---

## Related Docs
- [Testing Overview](overview.md)
- [Unit Tests](unit-tests.md)
