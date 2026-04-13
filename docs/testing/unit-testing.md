# Unit Testing

> **Reading time:** ~6 minutes · **Audience:** Backend Developers · **Last Updated:** 2026-04-11

The vast majority of tests in Flicko are Go unit tests. They execute in milliseconds and mock out external boundaries (Postgres, Redis, APIs) to purely test algorithmic business logic.

---

## 1. Organizing Tests

We follow idiomatic Go conventions. Tests live in the same directory as the file they are testing, suffixed with `_test.go`.

```text
backend/internal/services/
├── permissions.go
└── permissions_test.go
```

To run all tests in a package:
```bash
go test ./internal/services/...
```

---

## 2. Mocking Dependencies

Because our architecture strictly enforces Dependency Injection, mocking is incredibly easy. We use `gomock` to automatically generate mock implementations of our interfaces.

**Scenario:** Testing a Controller Handler

If `ServerHandler` requires `ServerService`, we don't spin up a database. We inject `MockServerService` which allows us to intercept function calls and return synthetic errors.

```go
func TestCreateServerHandler_InvalidInput(t *testing.T) {
    // 1. Setup Mock Controller
    ctrl := gomock.NewController(t)
    defer ctrl.Finish()

    // 2. Generate Mock
    mockSvc := mocks.NewMockServerService(ctrl)
    
    // We expect the service to NEVER be called because JSON validation should fail first
    mockSvc.EXPECT().Create(gomock.Any(), gomock.Any(), gomock.Any(), gomock.Any()).Times(0)

    // 3. Inject Mock into Handler
    handler := NewServerHandler(mockSvc)

    // 4. Construct Malformed HTTP Request
    reqBody := `{"name": "a"}` // Too short, validator wants min=2
    req, _ := http.NewRequest("POST", "/servers", strings.NewReader(reqBody))
    rr := httptest.NewRecorder()

    // 5. Execute
    handler.Create(rr, req)

    // 6. Assert Result
    assert.Equal(t, http.StatusBadRequest, rr.Code)
}
```

---

## 3. Table-Driven Tests 

For complex algorithms (like the AutoMod regex matcher or the RBAC Permission bitwise calculator), we use Go's Table-Driven Testing pattern.

A table defines `[]struct{ input, expectedOutput }`. A single `for` loop iterates the table, passing the inputs to the function and calling `t.Errorf` on mismatch. This allows us to cover 30 different permutation edge-cases with only 10 lines of test execution code.

---

## 4. Coverage Expectations

We target **80% code coverage** for the `internal/` packages. 
We explicitly do not enforce 100% because mocking out rote mapping structs purely for a green badge results in brittle, unmaintainable test bases. We focus entirely on critical business paths.
