# Flicko - Technology Stack

## Programming Languages

### Go 1.25.7
**Usage**: Backend services (ws-gateway, msg-service, backend monolith, mail-gateway)  
**Rationale**: High performance, excellent concurrency, strong standard library

**Key Dependencies**:
```go
// HTTP & Routing
github.com/gorilla/mux v1.8.1              // HTTP router
github.com/gorilla/websocket v1.5          // WebSocket implementation

// Database
github.com/jackc/pgx/v5 v5.8.0             // PostgreSQL driver with connection pooling

// Redis
github.com/redis/go-redis/v9 v9.18.0       // Redis client with TLS support

// Authentication
github.com/golang-jwt/jwt/v5 v5.3.1        // JWT token creation and validation

// Logging
go.uber.org/zap v1.27.0                    // Structured JSON logging (zero-allocation)

// Utilities
github.com/google/uuid v1.6.0              // UUID generation
golang.org/x/crypto v0.48.0                // Cryptographic functions
golang.org/x/time v0.14.0                  // Rate limiting utilities
```

### Dart 3.4+ / Flutter 3.22+
**Usage**: Mobile application (iOS + Android)  
**Rationale**: Cross-platform, native performance, rich UI framework

**Key Dependencies**:
```yaml
# State Management & DI
flutter_riverpod: ^3.3.1                   # Reactive state management
freezed_annotation: ^3.1.0                 # Immutable data classes
json_annotation: ^4.8.1                    # JSON serialization

# Navigation
go_router: ^17.2.2                         # Declarative routing

# Backend & Services
supabase_flutter: ^2.5.0                   # Supabase client (auth, database)
livekit_client: ^2.0.0                     # WebRTC voice/video
flutter_stripe: ^12.6.0                    # Stripe payment integration
appwrite: ^23.1.0                          # Media storage client

# Networking
dio: ^5.4.3+1                              # HTTP client
web_socket_channel: ^3.0.3                 # WebSocket client

# Local Storage
shared_preferences: ^2.2.3                 # Key-value storage
flutter_secure_storage: ^10.0.0            # Encrypted storage

# Media & Notifications
firebase_messaging: ^16.2.0                # Push notifications
flutter_local_notifications: ^21.0.0       # Local notifications
image_picker: ^1.1.1                       # Image selection
camera: ^0.12.0+1                          # Camera access
video_player: ^2.8.6                       # Video playback
just_audio: ^0.10.5                        # Audio playback
record: ^6.2.0                             # Audio recording

# UI & Design
google_fonts: ^8.0.2                       # Custom fonts
flutter_svg: ^2.0.10                       # SVG rendering
flutter_animate: ^4.5.0                    # Animations
cached_network_image: ^3.4.1               # Image caching
```

## Backend Technologies

### Database & Storage

#### Supabase (PostgreSQL 15+)
**Purpose**: Primary database with auth, RLS, Edge Functions  
**Features**:
- Row-Level Security (RLS) policies for authorization
- Connection pooling via Supavisor
- Real-time subscriptions
- Edge Functions (Deno runtime)
- 94 SQL migrations

**Connection**: `pgx/v5` driver with connection pooling

#### Upstash Redis
**Purpose**: Pub/Sub, session cache, rate limiting, DLQ  
**Features**:
- Global replication with TLS
- REST API for serverless environments
- Persistent storage
- Pub/Sub for WebSocket fan-out

**Connection**: `go-redis/v9` with TLS support

#### Appwrite Storage
**Purpose**: Secure media storage (images, videos, attachments)  
**Features**:
- Bucket-level permissions
- Client-side SDK for direct uploads
- CDN integration
- File security with user-level access control

**Connection**: `appwrite` Flutter SDK (v23.1.0)

### Cloud Services

#### LiveKit Cloud
**Purpose**: WebRTC SFU for voice/video channels  
**Features**:
- Global SFU network
- Opus codec for voice
- Adaptive bitrate for video
- Screen sharing support
- Token-based authentication

**Integration**: `livekit_client` Flutter SDK (v2.0.0)

#### Stripe
**Purpose**: Payment processing for Flicko Plus subscription  
**Features**:
- Subscription management
- Webhook integration
- Payment method storage
- Invoice generation

**Integration**: `flutter_stripe` SDK (v12.6.0)

#### Cloudflare
**Purpose**: CDN, WAF, DDoS protection, DNS  
**Features**:
- Unlimited DDoS mitigation
- WAF rules (SQL injection, XSS, bot detection)
- Origin TLS certificates
- Global CDN with edge caching

## Infrastructure & DevOps

### Docker & Container Orchestration

#### Docker 24+
**Purpose**: Container runtime for all services  
**Configuration**:
- Multi-stage builds for minimal image size
- Alpine 3.19 base images (~5 MB)
- Read-only filesystems
- Non-root processes
- Resource limits (CPU, memory)

#### Docker Compose
**Purpose**: Multi-container orchestration  
**Files**:
- `docker-compose.prod.yml`: 9 containers, 3 networks, 455 lines
- `docker-compose.dev.yml`: Development environment
- `docker-compose.zero.yml`: Minimal local setup

**Networks**:
- `flicko_edge`: Internet-facing (NGINX only)
- `flicko_internal`: Services, database, Redis
- `flicko_monitor`: Observability stack

### Reverse Proxy & Load Balancing

#### NGINX 1.25-alpine
**Purpose**: TLS termination, rate limiting, load balancing  
**Configuration**:
- TLS 1.3 with Cloudflare Origin certificates
- 4 rate limiting zones (API, WebSocket, upload, auth)
- WebSocket upgrade support
- Gzip compression
- Request body limit: 25 MB

**Routing**:
- `/ws` → ws-gateway (WebSocket)
- `/api/v1` → msg-service (REST API)
- `/bots` → backend (Bot commands)

### Monitoring & Observability

#### Prometheus
**Purpose**: Metrics collection and time-series database  
**Configuration**:
- 15-second scrape interval
- Retention: 15 days
- Targets: ws-gateway, msg-service, backend, NGINX, Node Exporter

**Metrics**:
- `ws_connections_total`: Active WebSocket connections
- `msg_batch_latency`: Message batch insert latency
- `go_goroutines`: Goroutine count per service
- `http_requests_total`: HTTP request count by endpoint

#### Grafana
**Purpose**: Dashboard visualization and alerting  
**Features**:
- Pre-built dashboards for system overview, WebSocket health, API latency
- Alerting rules for high CPU, memory, error rates
- Integration with Prometheus and Loki

#### Loki
**Purpose**: Log aggregation with LogQL query language  
**Configuration**:
- JSON log parsing
- Label extraction (service, level, request_id)
- Retention: 7 days

**Log Sources**:
- All Go services (structured JSON via Zap)
- NGINX access logs
- Docker container logs

#### Node Exporter
**Purpose**: Host system metrics  
**Metrics**: CPU per core, memory, disk I/O, network, file descriptors

#### NGINX Exporter
**Purpose**: NGINX proxy metrics  
**Metrics**: Requests/sec, status codes, upstream latency

### CI/CD

#### GitHub Actions
**Purpose**: Automated testing and deployment  
**Workflows**:
- `backend-ci.yml`: Go tests, linting, build
- `mobile-cd.yml`: Flutter tests, build APK/IPA
- `vps-deploy.yml`: Deploy to production VPS

#### Husky + lint-staged
**Purpose**: Pre-commit hooks for code quality  
**Configuration**:
```json
{
  "*.{ts,tsx,js,jsx}": ["prettier --write", "eslint --fix"],
  "*.go": ["gofmt -w"],
  "*.{json,md,yml,yaml}": ["prettier --write"]
}
```

### Secrets Management

#### Doppler
**Purpose**: Centralized, encrypted secrets management  
**Features**:
- Environment-specific configs (dev, staging, prod)
- Real-time secret updates
- Service token for VPS deployment
- CLI integration: `doppler run -- <command>`

**Secrets**:
- Supabase URL, anon key, service role key
- Appwrite project ID, endpoint, bucket ID
- LiveKit API key, API secret, URL
- Stripe API key
- JWT public/private keys
- Redis URL
- GIPHY API key

## Build Systems & Tools

### Go Build
**Commands**:
```bash
# Build backend
cd backend && go build -o bin/server ./cmd/server

# Build ws-gateway
cd services/ws-gateway && go build -o ../../bin/ws-gateway ./cmd/gateway

# Build msg-service
cd services/msg-service && go build -o ../../bin/msg-service ./cmd/server

# Run tests
go test -v ./...

# Run with coverage
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out
```

### Flutter Build
**Commands**:
```bash
# Get dependencies
flutter pub get

# Run code generation
flutter pub run build_runner build --delete-conflicting-outputs

# Run app (development)
flutter run

# Build APK (Android)
flutter build apk --release

# Build IPA (iOS)
flutter build ios --release

# Run tests
flutter test --coverage

# Analyze code
flutter analyze
```

### Docker Build
**Commands**:
```bash
# Build production images
docker compose -f docker-compose.prod.yml build

# Start production stack
docker compose -f docker-compose.prod.yml up -d

# View logs
docker compose -f docker-compose.prod.yml logs -f

# Stop stack
docker compose -f docker-compose.prod.yml down
```

## Development Commands

### Backend Development
```bash
# Start backend with Doppler
doppler run -- cd backend && go run ./cmd/server

# Start ws-gateway
doppler run -- cd services/ws-gateway && go run ./cmd/gateway

# Start msg-service
doppler run -- cd services/msg-service && go run ./cmd/server

# Run tests
cd backend && go test -v ./...

# Format code
gofmt -w .
```

### Mobile Development
```bash
# Start Flutter app
cd mobile && flutter run

# Hot reload (in running app)
# Press 'r' in terminal

# Hot restart (in running app)
# Press 'R' in terminal

# Run on specific device
flutter run -d <device-id>

# Run tests
flutter test

# Generate code
flutter pub run build_runner watch
```

### Infrastructure Development
```bash
# Start development stack
docker compose -f docker-compose.dev.yml up -d

# View logs
docker compose logs -f

# Restart service
docker compose restart <service-name>

# Stop stack
docker compose down

# Clean volumes
docker compose down -v
```

## Version Requirements

| Tool | Minimum Version | Check Command |
|------|----------------|---------------|
| Go | 1.25.7 | `go version` |
| Flutter | 3.22.0 | `flutter --version` |
| Dart | 3.4.0 | `dart --version` |
| Docker | 24.0 | `docker --version` |
| Docker Compose | 2.0 | `docker compose version` |
| Git | 2.30 | `git --version` |
| Node.js | 18.0 (for Husky) | `node --version` |
