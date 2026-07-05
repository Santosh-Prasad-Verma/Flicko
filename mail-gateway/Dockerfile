# ══════════════════════════════════════════
# Flicko Mail Gateway — Multi-stage Dockerfile
# ══════════════════════════════════════════
# Stage 1: Build the Go binary
# Stage 2: Run in minimal Alpine container
# ══════════════════════════════════════════

# ── Build stage ──
FROM golang:1.24-alpine AS builder

WORKDIR /app

# Install git (needed for some Go module downloads)
RUN apk add --no-cache git

# Copy dependency files first (better layer caching)
COPY go.mod go.sum ./
RUN go mod download

# Copy source code
COPY . .

# Build the binary with optimizations
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
    go build -ldflags="-s -w" -o server ./cmd/server

# ── Runtime stage ──
FROM alpine:3.22

# Install CA certificates (required for TLS/SMTP connections)
RUN apk upgrade --no-cache \
    && apk add --no-cache ca-certificates tzdata

WORKDIR /app

# Copy binary from builder
COPY --from=builder /app/server .

# Copy email templates
COPY --from=builder /app/templates/ ./templates/

# Create non-root user for security
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
RUN chown -R appuser:appgroup /app
USER appuser

# Expose the server port
EXPOSE 8080

# Health check using dynamic port
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
    CMD wget -qO- http://localhost:${PORT:-8080}/health || exit 1

# Run the server
CMD ["./server"]
