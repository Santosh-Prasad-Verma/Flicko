# Dockerfile

# Build Stage
FROM golang:1.24-alpine AS builder
RUN apk upgrade --no-cache
WORKDIR /app

# Enable CGO_ENABLED=0 for fully static compiled binary
ENV CGO_ENABLED=0
ENV GOOS=linux
ENV GOARCH=amd64
ENV GOTOOLCHAIN=auto

# Copy go mod and download dependencies
COPY go.mod go.sum ./
RUN go mod download

# Copy source
COPY . .

# Build the binary — MED-008: strip debug info for smaller image
RUN go build -trimpath -ldflags="-s -w" -o flicko-backend ./cmd/server/main.go

# Final runtime image — MED-008: Pin alpine version for reproducible builds
FROM alpine:3.22
WORKDIR /app

# Install CA certs for outbound TLS (Azure, Appwrite) + timezone data
RUN apk upgrade --no-cache \
    && apk add --no-cache ca-certificates tzdata wget

# Add a non-root user
RUN addgroup -S appgroup && adduser -S appuser -G appgroup

# Copy the static binary from builder
COPY --from=builder /app/flicko-backend .

# Expose HTTP and WebSocket ports
EXPOSE 8080 8081

# Use non-root user
USER appuser

# Health check (basic connection check on HTTP port)
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/health || exit 1

ENTRYPOINT ["./flicko-backend"]
