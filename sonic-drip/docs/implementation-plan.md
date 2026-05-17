# Sonic Drip — Implementation Plan

> **Spotify Integration for Flicko** — Step-by-Step Implementation Guide
> 
> Version 1.0 — Complete Budget & Timeline

---

## Table of Contents

1. [Budget Breakdown](#budget-breakdown)
2. [Team Requirements](#team-requirements)
3. [Timeline Overview](#timeline-overview)
4. [Phase 1: Foundation](#phase-1-foundation---weeks-1-4)
5. [Phase 2: Core Features](#phase-2-core-features---weeks-5-8)
6. [Phase 3: Social Features](#phase-3-social-features---weeks-9-12)
7. [Phase 4: Scale & Reliability](#phase-4-scale--reliability---weeks-13-16)
8. [Phase 5: Production Launch](#phase-5-production-launch---weeks-17-18)
9. [Resource Allocation](#resource-allocation)
10. [Risk Mitigation](#risk-mitigation)

---

## Budget Breakdown

### One-Time Development Costs

| Category | Item | Cost (USD) |
|----------|------|------------|
| **Personnel** | Backend Developer (4 months @ $8K/mo) | $32,000 |
| | Mobile Developer (4 months @ $8K/mo) | $32,000 |
| | DevOps Engineer (2 months @ $7K/mo) | $14,000 |
| | QA Engineer (2 months @ $5K/mo) | $10,000 |
| | Security Audit (one-time) | $15,000 |
| **Infrastructure Setup** | Kubernetes cluster setup | $2,000 |
| | CI/CD pipeline configuration | $1,500 |
| | Monitoring stack setup | $1,000 |
| | Security tooling (Vault, etc.) | $1,500 |
| **Legal & Compliance** | Legal consultation (Spotify ToS) | $5,000 |
| | Privacy policy update | $1,000 |
| | Terms of service update | $1,000 |
| **Third-Party Services** | CAPTCHA solver account credits | $500 |
| | Proxy service setup | $500 |
| **Testing** | Load testing tools | $1,000 |
| | Device testing lab | $2,000 |
| **Contingency** | 15% buffer | $14,000 |
| **TOTAL ONE-TIME** | | **$133,500** |

### Monthly Operating Costs (100K DAU)

| Category | Item | Monthly Cost (USD) |
|----------|------|-------------------|
| **Infrastructure** | Kubernetes cluster (EKS/GKE) | $13,740 |
| | PostgreSQL (RDS) | $1,150 |
| | Redis Cluster (ElastiCache) | $1,850 |
| | Cloudflare Pro + R2 | $170 |
| **External Services** | CAPTCHA solver (Capsolver) | $200 |
| | Residential proxies | $500 |
| | Monitoring (Datadog) | $900 |
| **Security** | HashiCorp Vault Cloud | $200 |
| **CDN & Storage** | Album art caching | $150 |
| **TOTAL MONTHLY** | | **$18,860** |

### First Year Total Budget

| Category | Cost (USD) |
|----------|------------|
| One-time development | $133,500 |
| Monthly operating (12 months) | $226,320 |
| **TOTAL FIRST YEAR** | **$359,820** |

### Cost Scaling Projections

| DAU | Monthly Infrastructure | Monthly External Services | Total Monthly | Cost per DAU |
|-----|------------------------|--------------------------|---------------|--------------|
| 100K | $16,910 | $1,600 | $18,510 | $0.185 |
| 500K | $52,000 | $4,000 | $56,000 | $0.112 |
| 1M | $95,000 | $8,000 | $103,000 | $0.103 |
| 5M | $320,000 | $25,000 | $345,000 | $0.069 |

---

## Team Requirements

### Core Team (4 Months)

| Role | Skills | Time Commitment |
|------|--------|-----------------|
| **Backend Developer** | Go, Python, Redis, PostgreSQL, gRPC | Full-time (4 months) |
| **Mobile Developer** | Flutter, Riverpod, WebSocket, Dio | Full-time (4 months) |
| **DevOps Engineer** | Kubernetes, Terraform, ArgoCD, Istio | Part-time (2 months) |
| **QA Engineer** | Automated testing, Load testing | Part-time (2 months) |

### Supporting Roles

| Role | Involvement | Responsibilities |
|------|-------------|------------------|
| **Product Manager** | 20% | Requirements, prioritization, stakeholder comms |
| **Security Engineer** | 10% | Code review, security audit, penetration testing |
| **Tech Lead** | 30% | Architecture decisions, code review, mentorship |

---

## Timeline Overview

```
Week 1-4:   Phase 1 - Foundation (Infrastructure & Auth)
Week 5-8:   Phase 2 - Core Features (Search & Playback)
Week 9-12:  Phase 3 - Social Features (Sharing & Listen Along)
Week 13-16: Phase 4 - Scale & Reliability (Testing & Hardening)
Week 17-18: Phase 5 - Production Launch (Deploy & Monitor)
```

---

## Phase 1: Foundation - Weeks 1-4

### Week 1: Infrastructure Setup

#### Day 1-2: Development Environment

**Tasks:**
- [ ] Set up Kubernetes development cluster (minikube/kind)
- [ ] Configure CI/CD pipeline (GitHub Actions)
- [ ] Set up development namespaces and secrets
- [ ] Configure local Redis and PostgreSQL instances

**Files to Create:**
```
services/spotapi-service/
├── Dockerfile
├── docker-compose.yml
├── requirements.txt
└── pyproject.toml

backend/
├── internal/handlers/music/
│   ├── search_handler.go
│   ├── player_handler.go
│   └── session_handler.go
└── migrations/
    └── 071_music_schema.up.sql
```

**Deliverables:**
- Working Kubernetes dev environment
- Docker images for SpotAPI service
- CI/CD pipeline building and testing

**Budget Impact:** $500 (CI/CD runners, Docker Hub)

---

#### Day 3-4: Database Schema

**Tasks:**
- [ ] Create PostgreSQL migration for music tables
- [ ] Set up partitioning strategy
- [ ] Configure PgBouncer connection pooling
- [ ] Create Redis key schema

**SQL Migration:**
```sql
-- backend/migrations/071_music_schema.up.sql

-- Spotify sessions (partitioned)
CREATE TABLE spotify_sessions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id),
    encrypted_session BYTEA NOT NULL,
    device_id       TEXT,
    status          TEXT DEFAULT 'active',
    created_at      TIMESTAMPTZ DEFAULT now(),
    updated_at      TIMESTAMPTZ DEFAULT now(),
    expires_at      TIMESTAMPTZ
) PARTITION BY HASH (user_id);

-- Create 16 partitions
DO $$
BEGIN
    FOR i IN 0..15 LOOP
        EXECUTE format(
            'CREATE TABLE spotify_sessions_p%s PARTITION OF spotify_sessions 
             FOR VALUES WITH (MODULUS 16, REMAINDER %s)',
            i, i
        );
    END LOOP;
END$$;

-- Music events (monthly partitions)
CREATE TABLE music_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL,
    event_type      TEXT NOT NULL,
    track_id        TEXT,
    playlist_id     TEXT,
    metadata        JSONB,
    created_at      TIMESTAMPTZ DEFAULT now()
) PARTITION BY RANGE (created_at);

-- Shared playlists
CREATE TABLE shared_playlists (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    playlist_id     TEXT NOT NULL,
    playlist_name   TEXT,
    spotify_url     TEXT NOT NULL,
    track_count     INTEGER DEFAULT 0,
    shared_by       UUID NOT NULL REFERENCES users(id),
    channel_id      UUID REFERENCES channels(id),
    created_at      TIMESTAMPTZ DEFAULT now()
);

-- Indexes
CREATE INDEX idx_spotify_sessions_user ON spotify_sessions (user_id);
CREATE INDEX idx_music_events_user_time ON music_events (user_id, created_at DESC);
```

**Deliverables:**
- Database schema deployed
- Partitioning configured
- Indexes created

---

#### Day 5-7: SpotAPI Python Service Base

**Tasks:**
- [ ] Create FastAPI application structure
- [ ] Implement health check endpoint
- [ ] Configure logging and error handling
- [ ] Set up dependency injection

**Code to Create:**

```python
# services/spotapi-service/app/main.py

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.routers import auth, player, search, playlist
from app.config import settings
from app.utils.logger import setup_logging

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    setup_logging()
    yield
    # Shutdown

app = FastAPI(
    title="Flicko SpotAPI Service",
    version="1.0.0",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/auth", tags=["Authentication"])
app.include_router(player.router, prefix="/player", tags=["Player"])
app.include_router(search.router, prefix="/search", tags=["Search"])
app.include_router(playlist.router, prefix="/playlist", tags=["Playlist"])

@app.get("/health")
async def health_check():
    return {"status": "healthy", "service": "spotapi"}
```

**Deliverables:**
- Running SpotAPI service
- Health check endpoint working
- Docker image published

---

### Week 2: Authentication & Session Management

#### Day 1-3: Spotify Login Flow

**Tasks:**
- [ ] Implement Login class wrapper for SpotAPI
- [ ] Configure CAPTCHA solver integration
- [ ] Create session encryption/decryption utilities
- [ ] Build credential storage service

**Code to Create:**

```python
# services/spotapi-service/app/services/auth_service.py

from spotapi import Login, Config
from spotapi.solvers import Capsolver
from cryptography.fernet import Fernet
import json

class SpotifyAuthService:
    def __init__(self, encryption_key: bytes, capsolver_key: str):
        self.cipher = Fernet(encryption_key)
        self.capsolver_key = capsolver_key
    
    async def login(
        self, 
        email: str, 
        password: str,
        proxy: str | None = None
    ) -> dict:
        """Authenticate with Spotify and return session."""
        config = Config(
            solver=Capsolver(self.capsolver_key, proxy=proxy),
        )
        
        login = Login(config, password, email=email)
        login.login()
        
        # Extract session cookies
        cookies = login.client.session.cookies.get_dict()
        
        return {
            "cookies": cookies,
            "user_info": await self._get_user_info(login),
        }
    
    def encrypt_session(self, session: dict) -> bytes:
        """Encrypt session for storage."""
        json_data = json.dumps(session).encode()
        return self.cipher.encrypt(json_data)
    
    def decrypt_session(self, encrypted: bytes) -> dict:
        """Decrypt session from storage."""
        json_data = self.cipher.decrypt(encrypted)
        return json.loads(json_data)
    
    async def _get_user_info(self, login: Login) -> dict:
        """Get user profile info."""
        # Implementation to fetch user details
        pass
```

**Deliverables:**
- Working Spotify login flow
- Session encryption implemented
- CAPTCHA solving integrated

---

#### Day 4-5: Go Backend Session Handler

**Tasks:**
- [ ] Create session handler in Go backend
- [ ] Implement gRPC client for SpotAPI service
- [ ] Build session storage in Redis
- [ ] Create session refresh logic

**Code to Create:**

```go
// backend/internal/handlers/music/session_handler.go

package music

import (
	"context"
	"encoding/json"
	"net/http"
	"time"

	"github.com/flicko-org/flicko-backend/internal/services/encryption"
	"github.com/redis/go-redis/v9"
)

type SessionHandler struct {
	redis      *redis.Client
	spotapi    SpotAPIClient
	encryptor  *encryption.Service
}

type ConnectRequest struct {
	Email    string `json:"email" validate:"required,email"`
	Password string `json:"password" validate:"required,min=8"`
}

type ConnectResponse struct {
	Status   string `json:"status"`
	UserInfo struct {
		Username    string `json:"username"`
		DisplayName string `json:"display_name"`
		Product     string `json:"product"`
	} `json:"user_info"`
}

// Connect handles Spotify account connection
func (h *SessionHandler) Connect(w http.ResponseWriter, r *http.Request) {
	var req ConnectRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		respondError(w, http.StatusBadRequest, "invalid request")
		return
	}

	userID := auth.UserIDFromContext(r.Context())

	// Call SpotAPI service to login
	session, err := h.spotapi.Login(r.Context(), req.Email, req.Password)
	if err != nil {
		respondError(w, http.StatusUnauthorized, err.Error())
		return
	}

	// Encrypt session
	encrypted, err := h.encryptor.Encrypt(session.Cookies)
	if err != nil {
		respondError(w, http.StatusInternalServerError, "encryption failed")
		return
	}

	// Store in Redis
	key := fmt.Sprintf("spotify:session:%s", userID)
	if err := h.redis.Set(r.Context(), key, encrypted, 24*time.Hour).Err(); err != nil {
		respondError(w, http.StatusInternalServerError, "storage failed")
		return
	}

	// Store in PostgreSQL for persistence
	if err := h.storeSession(userID, encrypted); err != nil {
		respondError(w, http.StatusInternalServerError, "persistence failed")
		return
	}

	respondJSON(w, http.StatusOK, ConnectResponse{
		Status:   "connected",
		UserInfo: session.UserInfo,
	})
}
```

**Deliverables:**
- Go backend calling SpotAPI
- Session stored in Redis
- Session persisted to PostgreSQL

---

#### Day 6-7: Flutter Authentication UI

**Tasks:**
- [ ] Create Spotify connect screen
- [ ] Build form validation
- [ ] Implement secure credential input
- [ ] Add loading states and error handling

**Code to Create:**

```dart
// mobile/lib/features/voice/presentation/spotify_connect_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile/core/constants/flicko_colors.dart';
import '../application/spotify_auth_notifier.dart';

class SpotifyConnectScreen extends ConsumerStatefulWidget {
  const SpotifyConnectScreen({super.key});

  @override
  ConsumerState<SpotifyConnectScreen> createState() => _SpotifyConnectScreenState();
}

class _SpotifyConnectScreenState extends ConsumerState<SpotifyConnectScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(spotifyAuthProvider.notifier).connect(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(spotifyAuthProvider);

    return Scaffold(
      backgroundColor: const Color(FlickoColors.bgPrimary),
      appBar: AppBar(
        backgroundColor: const Color(FlickoColors.bgPrimary),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(FlickoColors.textPrimary)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'CONNECT SPOTIFY',
          style: GoogleFonts.epilogue(
            color: const Color(FlickoColors.textPrimary),
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Logo
              Container(
                height: 80,
                width: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954), // Spotify green
                  borderRadius: BorderRadius.circular(40),
                ),
                child: const Icon(
                  Icons.music_note,
                  color: Colors.white,
                  size: 48,
                ),
              ),
              const SizedBox(height: 32),

              // Email field
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                decoration: InputDecoration(
                  labelText: 'Email',
                  labelStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                  filled: true,
                  fillColor: const Color(FlickoColors.bgSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Password field
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                style: GoogleFonts.inter(color: const Color(FlickoColors.textPrimary)),
                decoration: InputDecoration(
                  labelText: 'Password',
                  labelStyle: GoogleFonts.inter(color: const Color(FlickoColors.textMuted)),
                  filled: true,
                  fillColor: const Color(FlickoColors.bgSecondary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: const Color(FlickoColors.textMuted),
                    ),
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your password';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Connect button
              ElevatedButton(
                onPressed: state.isLoading ? null : _connect,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1DB954),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: state.isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'CONNECT SPOTIFY',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
              const SizedBox(height: 16),

              // Error message
              if (state.hasError)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(FlickoColors.danger).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    state.error.toString(),
                    style: GoogleFonts.inter(
                      color: const Color(FlickoColors.danger),
                      fontSize: 13,
                    ),
                  ),
                ),

              const SizedBox(height: 32),

              // Info text
              Text(
                'Your Spotify credentials are encrypted and stored securely. '
                'We use SpotAPI to enable playback without Premium.',
                style: GoogleFonts.inter(
                  color: const Color(FlickoColors.textMuted),
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

**Deliverables:**
- Working Flutter connect screen
- Form validation complete
- Loading states implemented

---

### Week 3: Search & Discovery

#### Day 1-3: Search Service Implementation

**Tasks:**
- [ ] Implement song search via SpotAPI
- [ ] Add caching for search results
- [ ] Build pagination for large result sets
- [ ] Create search history tracking

**Code to Create:**

```python
# services/spotapi-service/app/routers/search.py

from fastapi import APIRouter, Depends, Query
from typing import Optional
from spotapi import Song

from app.services.cache import CacheService

router = APIRouter()

@router.get("/songs")
async def search_songs(
    q: str = Query(..., min_length=1, max_length=100),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0),
    cache: CacheService = Depends()
):
    """Search for songs in Spotify catalog."""
    cache_key = f"search:songs:{hash(q)}:{limit}:{offset}"
    
    # Check cache
    cached = await cache.get(cache_key)
    if cached:
        return cached
    
    # Perform search
    song = Song()
    results = song.query_songs(q, limit=limit, offset=offset)
    
    # Transform response
    tracks = []
    for item in results.get("data", {}).get("searchV2", {}).get("tracksV2", {}).get("items", []):
        track_data = item.get("item", {}).get("data", {})
        tracks.append({
            "id": track_data.get("id"),
            "name": track_data.get("name"),
            "artist": ", ".join([a.get("name") for a in track_data.get("artists", [])]),
            "album": track_data.get("album", {}).get("name"),
            "duration_ms": track_data.get("duration_ms"),
            "image_url": track_data.get("album", {}).get("images", [{}])[0].get("url"),
            "uri": track_data.get("uri"),
        })
    
    response = {
        "tracks": tracks,
        "total": results.get("data", {}).get("searchV2", {}).get("tracksV2", {}).get("totalCount", 0),
        "offset": offset,
        "limit": limit,
    }
    
    # Cache for 10 minutes
    await cache.set(cache_key, response, ttl=600)
    
    return response
```

**Deliverables:**
- Working search endpoint
- Redis caching implemented
- Paginated results

---

#### Day 4-5: Flutter Search UI

**Tasks:**
- [ ] Create search sheet component
- [ ] Build search results list
- [ ] Add loading states
- [ ] Implement debounced search

**Deliverables:**
- Working search UI
- Debounced input
- Cached results display

---

#### Day 6-7: Integration Testing

**Tasks:**
- [ ] Write integration tests for auth flow
- [ ] Write tests for search flow
- [ ] Set up test fixtures
- [ ] Configure CI test pipeline

**Deliverables:**
- Test coverage > 70%
- CI running tests on PR

---

### Week 4: Playback Control Foundation

#### Day 1-3: Player Service

**Tasks:**
- [ ] Implement Player class wrapper
- [ ] Add device discovery
- [ ] Create playback state tracking
- [ ] Build queue management

**Code to Create:**

```python
# services/spotapi-service/app/services/player_service.py

from spotapi import Player, Login
from typing import Optional
import json

class SpotifyPlayerService:
    def __init__(self, login: Login):
        self.player = Player(login)
    
    async def get_devices(self) -> list[dict]:
        """Get available playback devices."""
        devices = self.player.device_ids.devices
        return [
            {
                "id": device.id,
                "name": device.name,
                "type": device.device_type,
                "is_active": device.is_active,
                "volume": device.volume / 65535.0,
            }
            for device in devices.values()
        ]
    
    async def play(self, track_id: str, device_id: Optional[str] = None):
        """Add track to queue and skip to it."""
        self.player.add_to_queue(track_id)
        self.player.skip_next()
    
    async def pause(self):
        """Pause playback."""
        self.player.pause()
    
    async def resume(self):
        """Resume playback."""
        self.player.resume()
    
    async def skip_next(self):
        """Skip to next track."""
        self.player.skip_next()
    
    async def skip_prev(self):
        """Skip to previous track."""
        self.player.skip_prev()
    
    async def seek(self, position_ms: int):
        """Seek to position in current track."""
        self.player.seek_to(position_ms)
    
    async def set_volume(self, volume: float):
        """Set playback volume (0.0 to 1.0)."""
        self.player.set_volume(volume)
    
    async def get_state(self) -> dict:
        """Get current playback state."""
        state = self.player.state
        return {
            "is_playing": not state.is_paused,
            "position_ms": state.position,
            "track": {
                "id": state.track.id if state.track else None,
                "name": state.track.name if state.track else None,
                "artist": state.track.artist_name if state.track else None,
                "duration_ms": state.track.duration if state.track else 0,
            },
        }
```

**Deliverables:**
- Complete player API
- Device management
- State tracking

---

#### Day 4-5: Go Backend Player Handler

**Tasks:**
- [ ] Create player handler endpoints
- [ ] Implement rate limiting
- [ ] Add request validation
- [ ] Build error handling

**Deliverables:**
- Player endpoints working
- Rate limiting configured
- Error responses standardized

---

#### Day 6-7: Flutter Playback UI

**Tasks:**
- [ ] Update Sonic Drip screen with controls
- [ ] Add play/pause/skip buttons
- [ ] Implement seek bar
- [ ] Add volume control

**Deliverables:**
- Working playback controls
- Real-time state updates
- Volume slider

---

## Phase 2: Core Features - Weeks 5-8

### Week 5: Playlist Management

#### Tasks:
- [ ] Create playlist CRUD endpoints
- [ ] Implement add/remove tracks
- [ ] Build playlist listing
- [ ] Add playlist metadata caching

**Deliverables:**
- Full playlist management
- Redis caching
- Flutter playlist UI

---

### Week 6: Now Playing & State Sync

#### Tasks:
- [ ] Implement WebSocket state sync
- [ ] Build Centrifugo integration
- [ ] Create real-time playback updates
- [ ] Add presence indicators

**Deliverables:**
- Real-time state sync
- Now playing widget
- Presence system

---

### Week 7: Device Management

#### Tasks:
- [ ] Build device listing UI
- [ ] Implement device transfer
- [ ] Add device health checks
- [ ] Create fallback device selection

**Deliverables:**
- Device selection UI
- Transfer functionality
- Health monitoring

---

### Week 8: Testing & Bug Fixes

#### Tasks:
- [ ] Comprehensive testing
- [ ] Performance optimization
- [ ] Bug triage and fixes
- [ ] Documentation updates

**Deliverables:**
- All features tested
- Performance baseline
- Bug-free foundation

---

## Phase 3: Social Features - Weeks 9-12

### Week 9: Playlist Sharing

#### Tasks:
- [ ] Build share to channel endpoint
- [ ] Create embed generation
- [ ] Implement share UI
- [ ] Add link previews

**Deliverables:**
- Share functionality
- Rich embeds
- Link previews

---

### Week 10: Listen Along Foundation

#### Tasks:**
- [ ] Design session model
- [ ] Implement host/join logic
- [ ] Build session state management
- [ ] Create presence tracking

**Deliverables:**
- Session management
- Host controls
- Participant tracking

---

### Week 11: Listen Along UI

#### Tasks:
- [ ] Create Listen Along screen
- [ ] Build participant list
- [ ] Implement chat integration
- [ ] Add invite functionality

**Deliverables:**
- Complete Listen Along UI
- Invite system
- Chat integration

---

### Week 12: Listen Along Sync

#### Tasks:
- [ ] Implement real-time sync via Centrifugo
- [ ] Build queue management for hosts
- [ ] Add skip voting
- [ ] Create session persistence

**Deliverables:**
- Real-time sync working
- Voting system
- Session recovery

---

## Phase 4: Scale & Reliability - Weeks 13-16

### Week 13: Circuit Breakers & Fallbacks

#### Tasks:
- [ ] Implement circuit breakers
- [ ] Build graceful degradation
- [ ] Add fallback to deep links
- [ ] Create error recovery

**Deliverables:**
- Circuit breakers active
- Graceful degradation
- Fallback mechanisms

---

### Week 14: Monitoring & Observability

#### Tasks:
- [ ] Set up Prometheus metrics
- [ ] Create Grafana dashboards
- [ ] Configure alerting
- [ ] Build log aggregation

**Deliverables:**
- Complete observability stack
- Alert rules configured
- Dashboards live

---

### Week 15: Load Testing & Optimization

#### Tasks:
- [ ] Run load tests (100K RPS target)
- [ ] Identify bottlenecks
- [ ] Optimize slow paths
- [ ] Tune connection pools

**Deliverables:**
- Load test results
- Performance report
- Optimizations applied

---

### Week 16: Security Hardening

#### Tasks:
- [ ] Security audit review
- [ ] Penetration testing
- [ ] Fix vulnerabilities
- [ ] Update dependencies

**Deliverables:**
- Security audit passed
- Vulnerabilities fixed
- Dependencies updated

---

## Phase 5: Production Launch - Weeks 17-18

### Week 17: Staging Deployment

#### Tasks:
- [ ] Deploy to staging environment
- [ ] Run full regression tests
- [ ] Verify monitoring
- [ ] Test failover scenarios

**Deliverables:**
- Staging deployment complete
- Tests passing
- Monitoring verified

---

### Week 18: Production Launch

#### Day 1-2: Canary Deployment

- [ ] Deploy to 1% of users
- [ ] Monitor error rates
- [ ] Check performance metrics
- [ ] Gather user feedback

#### Day 3-4: Gradual Rollout

- [ ] Increase to 10% of users
- [ ] Continue monitoring
- [ ] Address any issues
- [ ] Increase to 50%

#### Day 5-7: Full Launch

- [ ] Roll out to 100% of users
- [ ] Announce feature
- [ ] Monitor closely
- [ ] Document lessons learned

**Deliverables:**
- Feature live to all users
- Documentation complete
- Post-launch report

---

## Resource Allocation

### Sprint Schedule

```
Week 1-2:  Sprint 1 - Infrastructure & Auth (Backend focus)
Week 3-4:  Sprint 2 - Search & Playback (Full team)
Week 5-6:  Sprint 3 - Playlist & State (Full team)
Week 7-8:  Sprint 4 - Testing & Polish (Full team)
Week 9-10: Sprint 5 - Sharing & Listen Along (Full team)
Week 11-12: Sprint 6 - Listen Along Complete (Full team)
Week 13-14: Sprint 7 - Reliability (DevOps + Backend)
Week 15-16: Sprint 8 - Hardening (Full team)
Week 17-18: Sprint 9 - Launch (Full team)
```

### Weekly Checkpoints

| Week | Demo Day | Stakeholder Review | Key Milestone |
|------|----------|-------------------|---------------|
| 2 | ✅ | Auth flow working | Foundation complete |
| 4 | ✅ | Search & playback | Core features |
| 6 | ✅ | Playlist management | Feature complete |
| 8 | ✅ | All features tested | Ready for social |
| 10 | ✅ | Sharing working | Social features |
| 12 | ✅ | Listen Along | Feature complete |
| 14 | ✅ | Monitoring live | Reliability |
| 16 | ✅ | Security passed | Launch ready |
| 18 | ✅ | Production live | Complete |

---

## Risk Mitigation

### Technical Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Spotify API changes | Medium | High | Contract tests, feature flags, fallbacks |
| CAPTCHA solver failure | Medium | Medium | Multi-provider setup, cookie import |
| Session expiration | High | Medium | Proactive refresh, auto-relogin |
| WebSocket instability | Medium | Medium | Backoff, history recovery |
| Performance issues | Low | High | Load testing, optimization |

### Schedule Risks

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| Scope creep | High | Medium | Strict sprint goals |
| Resource availability | Medium | High | Buffer in timeline |
| Third-party delays | Low | Medium | Early integration testing |

---

## Success Criteria

### Phase 1 Success
- [ ] User can connect Spotify account
- [ ] Session persists for 24 hours
- [ ] Search returns results in < 200ms

### Phase 2 Success
- [ ] Playback controls work reliably
- [ ] State syncs in real-time
- [ ] Device management functional

### Phase 3 Success
- [ ] Sharing to channels works
- [ ] Listen Along functional
- [ ] No data loss on reconnection

### Phase 4 Success
- [ ] System handles 100K RPS
- [ ] Error rate < 0.1%
- [ ] P99 latency < 200ms

### Launch Success
- [ ] Feature used by 10K users in first week
- [ ] No critical bugs
- [ ] User satisfaction > 4.0/5.0

---

## Post-Launch

### Week 19-20: Monitoring & Iteration

- Monitor key metrics
- Address user feedback
- Plan v2 features
- Optimize based on usage patterns

### Future Enhancements (Post-MVP)

- Spotify Web API integration (Premium users)
- YouTube Music integration
- Apple Music integration
- Collaborative playlists
- Music recommendations
- Listening statistics

---

*Implementation Plan Version 1.0 | Created: 2026-05-17*
