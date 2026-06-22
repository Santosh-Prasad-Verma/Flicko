package watchtogether

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
	"github.com/stretchr/testify/assert"
)

type mockRepository struct {
	sessions     map[string]*WTSession
	participants map[string][]*WTParticipant
}

func newMockRepository() *mockRepository {
	return &mockRepository{
		sessions:     make(map[string]*WTSession),
		participants: make(map[string][]*WTParticipant),
	}
}

func (m *mockRepository) CreateSession(ctx context.Context, s *WTSession) error {
	m.sessions[s.ID] = s
	return nil
}

func (m *mockRepository) GetSession(ctx context.Context, id string) (*WTSession, error) {
	s, ok := m.sessions[id]
	if !ok {
		return nil, errors.New("not found")
	}
	return s, nil
}

func (m *mockRepository) UpdateSession(ctx context.Context, s *WTSession) error {
	m.sessions[s.ID] = s
	return nil
}

func (m *mockRepository) GetActiveSessionForRoom(ctx context.Context, roomID uuid.UUID) (*WTSession, error) {
	for _, s := range m.sessions {
		if s.RoomID == roomID && s.State != StateEnded {
			return s, nil
		}
	}
	return nil, nil
}

func (m *mockRepository) AddParticipant(ctx context.Context, p *WTParticipant) error {
	m.participants[p.SessionID] = append(m.participants[p.SessionID], p)
	return nil
}

func (m *mockRepository) GetParticipants(ctx context.Context, sessionID string) ([]*WTParticipant, error) {
	return m.participants[sessionID], nil
}

func (m *mockRepository) MarkParticipantLeft(ctx context.Context, sessionID string, userID uuid.UUID) error {
	list := m.participants[sessionID]
	for _, p := range list {
		if p.UserID == userID {
			now := time.Now()
			p.LeftAt = &now
		}
	}
	return nil
}

func (m *mockRepository) GetOldestActiveParticipant(ctx context.Context, sessionID string) (*WTParticipant, error) {
	var oldest *WTParticipant
	for _, p := range m.participants[sessionID] {
		if p.LeftAt == nil {
			if oldest == nil || p.JoinedAt.Before(oldest.JoinedAt) {
				oldest = p
			}
		}
	}
	if oldest == nil {
		return nil, errors.New("no active participants")
	}
	return oldest, nil
}

func (m *mockRepository) GetPublicLobbies(ctx context.Context) ([]*WTSession, error) {
	var lobbies []*WTSession
	for _, s := range m.sessions {
		if s.IsPublic && s.State != StateEnded {
			lobbies = append(lobbies, s)
		}
	}
	return lobbies, nil
}

type mockLiveKit struct{}

func (m *mockLiveKit) GenerateToken(roomName string, participantName string, participantIdentity string, canPublish bool, canPublishData bool) (string, error) {
	return "mocked-livekit-token", nil
}

type mockPublisher struct{}

func (m *mockPublisher) Publish(ctx context.Context, channel string, data any) error {
	return nil
}

type mockCacheLayer struct {
	data  map[string]string
	zsets map[string][]float64
}

func newMockCacheLayer() *mockCacheLayer {
	return &mockCacheLayer{
		data:  make(map[string]string),
		zsets: make(map[string][]float64),
	}
}

func (m *mockCacheLayer) Get(ctx context.Context, key string) (string, error) {
	return m.data[key], nil
}

func (m *mockCacheLayer) Set(ctx context.Context, key string, value string, expiration time.Duration) error {
	m.data[key] = value
	return nil
}

func (m *mockCacheLayer) Delete(ctx context.Context, key string) error {
	delete(m.data, key)
	delete(m.zsets, key)
	return nil
}

func (m *mockCacheLayer) DeletePattern(ctx context.Context, pattern string) error {
	return nil
}

func (m *mockCacheLayer) GetJSON(ctx context.Context, key string, dest interface{}) error {
	val, ok := m.data[key]
	if !ok {
		return errors.New("key not found")
	}
	return json.Unmarshal([]byte(val), dest)
}

func (m *mockCacheLayer) SetJSON(ctx context.Context, key string, value interface{}, expiration time.Duration) error {
	b, err := json.Marshal(value)
	if err != nil {
		return err
	}
	m.data[key] = string(b)
	return nil
}

func (m *mockCacheLayer) Exists(ctx context.Context, key string) (bool, error) {
	_, ok := m.data[key]
	return ok, nil
}

func (m *mockCacheLayer) Publish(ctx context.Context, channel string, message interface{}) error {
	return nil
}

func (m *mockCacheLayer) Subscribe(ctx context.Context, channel string) *redis.PubSub {
	return nil
}

func (m *mockCacheLayer) Close() error {
	return nil
}

func (m *mockCacheLayer) Ping(ctx context.Context) error {
	return nil
}

func (m *mockCacheLayer) GetRedisClient() redis.Cmdable {
	return nil
}

func (m *mockCacheLayer) ZAdd(ctx context.Context, key string, score float64, member string) error {
	m.zsets[key] = append(m.zsets[key], score)
	return nil
}

func (m *mockCacheLayer) ZCard(ctx context.Context, key string) (int64, error) {
	return int64(len(m.zsets[key])), nil
}

func (m *mockCacheLayer) ZRemRangeByScore(ctx context.Context, key, min, max string) error {
	var minVal float64
	fmt.Sscanf(min, "%f", &minVal)
	var newScores []float64
	for _, s := range m.zsets[key] {
		if s >= minVal {
			newScores = append(newScores, s)
		}
	}
	m.zsets[key] = newScores
	return nil
}

func (m *mockCacheLayer) ZRangeFirst(ctx context.Context, key string) (int64, error) {
	return 0, nil
}

func (m *mockCacheLayer) Expire(ctx context.Context, key string, expiration time.Duration) error {
	return nil
}


func TestService_CreateSession(t *testing.T) {
	repo := newMockRepository()
	cache := NewRedisCache(nil) // we won't hit caching directly in this basic test or we mock it
	lk := &mockLiveKit{}
	pub := &mockPublisher{}

	svc := NewService(repo, cache, lk, pub, nil)

	req := &CreateSessionRequest{
		RoomID: uuid.New().String(),
		Media: MediaInput{
			Kind:  MediaKindYouTube,
			URL:   "https://youtu.be/dQw4w9WgXcQ",
			Title: "Test Video",
		},
		Settings: WTSettings{
			MaxViewers: 12,
		},
	}

	hostID := uuid.New()
	session, err := svc.CreateSession(context.Background(), req, hostID)
	if err != nil {
		t.Fatalf("unexpected error creating session: %v", err)
	}

	if session.HostUserID != hostID {
		t.Errorf("expected host ID %v, got %v", hostID, session.HostUserID)
	}

	if session.State != StateDraft {
		t.Errorf("expected initial state 'draft', got %s", session.State)
	}
}

func TestService_JoinSession(t *testing.T) {
	repo := newMockRepository()
	cache := NewRedisCache(nil)
	lk := &mockLiveKit{}
	pub := &mockPublisher{}

	svc := NewService(repo, cache, lk, pub, nil)

	roomID := uuid.New()
	sessionID := "wt_test"
	hostID := uuid.New()

	session := &WTSession{
		ID:         sessionID,
		RoomID:     roomID,
		HostUserID: hostID,
		MediaKind:  MediaKindYouTube,
		MediaURL:   "https://youtu.be/dQw4w9WgXcQ",
		Settings:   WTSettings{MaxViewers: 12},
		State:      StateDraft,
	}

	_ = repo.CreateSession(context.Background(), session)

	// Join as viewer
	viewerID := uuid.New()
	resp, err := svc.JoinSession(context.Background(), sessionID, viewerID, "Viewer_1")
	if err != nil {
		t.Fatalf("unexpected error joining session: %v", err)
	}

	if resp.LiveKitToken != "mocked-livekit-token" {
		t.Errorf("expected livekit token 'mocked-livekit-token', got %s", resp.LiveKitToken)
	}
}

func TestService_UpdateAnchor(t *testing.T) {
	repo := newMockRepository()
	cache := NewRedisCache(nil)
	lk := &mockLiveKit{}
	pub := &mockPublisher{}

	svc := NewService(repo, cache, lk, pub, nil)

	sessionID := "wt_test"
	hostID := uuid.New()

	session := &WTSession{
		ID:         sessionID,
		RoomID:     uuid.New(),
		HostUserID: hostID,
		MediaKind:  MediaKindYouTube,
		MediaURL:   "https://youtu.be/dQw4w9WgXcQ",
		Settings:   WTSettings{MaxViewers: 12},
		State:      StateDraft,
	}

	_ = repo.CreateSession(context.Background(), session)

	req := &PushAnchorRequest{
		PositionMS: 5000,
		Playing:    true,
		Rate:       1.0,
	}

	err := svc.UpdateSessionAnchor(context.Background(), sessionID, hostID, req)
	if err != nil {
		t.Fatalf("unexpected error updating anchor: %v", err)
	}

	updated, _ := repo.GetSession(context.Background(), sessionID)
	if updated.AnchorPositionMS != 5000 {
		t.Errorf("expected anchor position 5000, got %d", updated.AnchorPositionMS)
	}

	if updated.State != StateReady {
		t.Errorf("expected state to transition to 'ready', got %s", updated.State)
	}
}

func TestService_UpdateAnchor_RateLimiting(t *testing.T) {
	repo := newMockRepository()
	cacheLayer := newMockCacheLayer()
	cache := NewRedisCache(cacheLayer)
	lk := &mockLiveKit{}
	pub := &mockPublisher{}

	svc := NewService(repo, cache, lk, pub, nil)

	sessionID := "wt_rate_limit_test"
	hostID := uuid.New()

	session := &WTSession{
		ID:         sessionID,
		RoomID:     uuid.New(),
		HostUserID: hostID,
		MediaKind:  MediaKindYouTube,
		MediaURL:   "https://youtu.be/dQw4w9WgXcQ",
		Settings:   WTSettings{MaxViewers: 12},
		State:      StateDraft,
	}

	_ = repo.CreateSession(context.Background(), session)

	req := &PushAnchorRequest{
		PositionMS: 5000,
		Playing:    true,
		Rate:       1.0,
	}

	// First 60 requests should pass
	for i := 0; i < 60; i++ {
		err := svc.UpdateSessionAnchor(context.Background(), sessionID, hostID, req)
		assert.NoError(t, err)
	}

	// 61st request should be rate limited
	err := svc.UpdateSessionAnchor(context.Background(), sessionID, hostID, req)
	assert.ErrorIs(t, err, ErrAnchorRateLimitExceeded)
}

func TestService_GetSessionAnchor(t *testing.T) {
	repo := newMockRepository()
	cache := NewRedisCache(nil)
	lk := &mockLiveKit{}
	pub := &mockPublisher{}

	svc := NewService(repo, cache, lk, pub, nil)

	sessionID := "wt_anchor_test"
	hostID := uuid.New()

	session := &WTSession{
		ID:               sessionID,
		RoomID:           uuid.New(),
		HostUserID:       hostID,
		MediaKind:        MediaKindYouTube,
		MediaURL:         "https://youtu.be/dQw4w9WgXcQ",
		Settings:         WTSettings{MaxViewers: 12},
		State:            StatePlaying,
		AnchorPositionMS: 25000,
		AnchorPlaying:    true,
		AnchorRate:       1.0,
		AnchorWallMS:     1234567890,
		Seq:              12,
	}

	_ = repo.CreateSession(context.Background(), session)

	anchor, err := svc.GetSessionAnchor(context.Background(), sessionID)
	assert.NoError(t, err)
	assert.NotNil(t, anchor)
	assert.Equal(t, 25000, anchor.PositionMS)
	assert.True(t, anchor.Playing)
	assert.Equal(t, 1.0, anchor.Rate)
	assert.Equal(t, int64(1234567890), anchor.WallClockMS)
	assert.Equal(t, 12, anchor.Seq)
}

func TestService_CreateStandaloneSession(t *testing.T) {
	repo := newMockRepository()
	cache := NewRedisCache(nil)
	lk := &mockLiveKit{}
	pub := &mockPublisher{}

	svc := NewService(repo, cache, lk, pub, nil)

	req := &CreateSessionRequest{
		RoomID: "", // empty room ID triggers standalone session
		Media: MediaInput{
			Kind:  MediaKindYouTube,
			URL:   "https://youtu.be/dQw4w9WgXcQ",
			Title: "Test Video",
		},
		Settings: WTSettings{
			MaxViewers: 12,
		},
		IsPublic:  true,
		LobbyName: "My Public Lobby",
	}

	hostID := uuid.New()
	session, err := svc.CreateSession(context.Background(), req, hostID)
	if err != nil {
		t.Fatalf("unexpected error creating standalone session: %v", err)
	}

	assert.True(t, session.IsStandalone)
	assert.Equal(t, uuid.Nil, session.RoomID)
	assert.True(t, session.IsPublic)
	assert.Equal(t, "My Public Lobby", *session.LobbyName)
}

func TestService_ListPublicLobbies(t *testing.T) {
	repo := newMockRepository()
	cache := NewRedisCache(nil)
	lk := &mockLiveKit{}
	pub := &mockPublisher{}

	svc := NewService(repo, cache, lk, pub, nil)

	// Create a public session
	s1 := &WTSession{
		ID:           "wt_public",
		RoomID:       uuid.Nil,
		HostUserID:   uuid.New(),
		MediaKind:    MediaKindYouTube,
		MediaURL:     "https://youtu.be/dQw4w9WgXcQ",
		State:        StateReady,
		IsStandalone: true,
		IsPublic:     true,
	}
	_ = repo.CreateSession(context.Background(), s1)

	// Create a private session
	s2 := &WTSession{
		ID:           "wt_private",
		RoomID:       uuid.Nil,
		HostUserID:   uuid.New(),
		MediaKind:    MediaKindYouTube,
		MediaURL:     "https://youtu.be/dQw4w9WgXcQ",
		State:        StateReady,
		IsStandalone: true,
		IsPublic:     false,
	}
	_ = repo.CreateSession(context.Background(), s2)

	lobbies, err := svc.ListPublicLobbies(context.Background())
	assert.NoError(t, err)
	assert.Len(t, lobbies, 1)
	assert.Equal(t, "wt_public", lobbies[0].ID)
}

