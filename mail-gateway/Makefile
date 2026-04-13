# ══════════════════════════════════════════
# Flicko Mail Gateway — Makefile
# ══════════════════════════════════════════

.PHONY: run build test lint clean docker-build docker-run fmt vet tidy

# ── Development ──

# Run the server locally
run:
	@echo "🚀 Starting Flicko Mail Gateway..."
	go run cmd/server/main.go

# Build the binary
build:
	@echo "📦 Building..."
	CGO_ENABLED=0 go build -ldflags="-s -w" -o bin/server ./cmd/server
	@echo "✅ Binary: bin/server"

# Run tests
test:
	@echo "🧪 Running tests..."
	go test ./... -v -race -cover

# Run short tests only (no integration tests)
test-unit:
	@echo "🧪 Running unit tests..."
	go test ./tests/... -v -race -cover -short

# Format code
fmt:
	@echo "🎨 Formatting..."
	go fmt ./...

# Vet for issues
vet:
	@echo "🔍 Vetting..."
	go vet ./...

# Tidy modules
tidy:
	@echo "📦 Tidying modules..."
	go mod tidy

# Lint (requires golangci-lint)
lint:
	@echo "🔍 Linting..."
	golangci-lint run ./...

# Clean build artifacts
clean:
	@echo "🧹 Cleaning..."
	rm -rf bin/
	@echo "✅ Clean"

# ── Docker ──

# Build Docker image
docker-build:
	@echo "🐳 Building Docker image..."
	docker build -t flicko-mail-gateway:latest .

# Run Docker container
docker-run:
	@echo "🐳 Running Docker container..."
	docker run -p 8080:8080 --env-file .env flicko-mail-gateway:latest

# ── Quick checks ──

# Run all validations
check: fmt vet test
	@echo "✅ All checks passed"
