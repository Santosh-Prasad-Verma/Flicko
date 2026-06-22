package watchtogether

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/flicko-org/flicko-backend/internal/services"
	centrifugoSvc "github.com/flicko-org/flicko-backend/internal/services/centrifugo"
	"go.uber.org/zap"
)

var ErrAnchorRateLimitExceeded = errors.New("rate limit exceeded: 60 anchors per minute")

type Service interface {
	CreateSession(ctx context.Context, req *CreateSessionRequest, hostUserID uuid.UUID) (*WTSession, error)
	GetSession(ctx context.Context, id string) (*WTSession, error)
	JoinSession(ctx context.Context, id string, userID uuid.UUID, userName string) (*JoinSessionResponse, error)
	LeaveSession(ctx context.Context, id string, userID uuid.UUID) error
	EndSession(ctx context.Context, id string, userID uuid.UUID) error
	TransferHost(ctx context.Context, id string, currentHostID uuid.UUID, toUserID uuid.UUID) error
	UpdateSessionAnchor(ctx context.Context, id string, hostUserID uuid.UUID, req *PushAnchorRequest) error
	GetSessionAnchor(ctx context.Context, id string) (*WTSessionAnchor, error)
	ListPublicLobbies(ctx context.Context) ([]*WTSession, error)
}

type wtService struct {
	repo       Repository
	cache      *RedisCache
	livekit    services.LiveKitService
	publisher  centrifugoSvc.Publisher
	logger     *zap.Logger
}

func NewService(
	repo Repository,
	cache *RedisCache,
	lk services.LiveKitService,
	pub centrifugoSvc.Publisher,
	logger *zap.Logger,
) Service {
	if logger == nil {
		logger = zap.NewNop()
	}
	return &wtService{
		repo:      repo,
		cache:     cache,
		livekit:   lk,
		publisher: pub,
		logger:    logger.Named("service.watchtogether"),
	}
}

func (s *wtService) CreateSession(ctx context.Context, req *CreateSessionRequest, hostUserID uuid.UUID) (*WTSession, error) {
	var roomUUID uuid.UUID
	var isStandalone bool
	if req.RoomID == "" {
		isStandalone = true
		roomUUID = uuid.Nil
	} else {
		var err error
		roomUUID, err = uuid.Parse(req.RoomID)
		if err != nil {
			return nil, errors.New("invalid room id")
		}

		// Verify if there is already an active session for the room
		active, err := s.repo.GetActiveSessionForRoom(ctx, roomUUID)
		if err != nil {
			return nil, fmt.Errorf("failed to check existing sessions: %w", err)
		}
		if active != nil {
			return nil, errors.New("an active session already exists in this voice room")
		}
	}

	sessionID := fmt.Sprintf("wt_%s", uuid.New().String())

	// Default settings mapping
	settings := req.Settings
	if settings.MaxViewers <= 0 {
		settings.MaxViewers = 12
	}

	title := req.Media.Title
	var lobbyName *string
	if req.LobbyName != "" {
		lobbyName = &req.LobbyName
	}

	wt := &WTSession{
		ID:               sessionID,
		RoomID:           roomUUID,
		HostUserID:       hostUserID,
		MediaKind:        req.Media.Kind,
		MediaURL:         req.Media.URL,
		MediaTitle:       &title,
		Settings:         settings,
		State:            StateDraft,
		AnchorPositionMS: 0,
		AnchorPlaying:    false,
		AnchorRate:       1.0,
		AnchorWallMS:     time.Now().UnixMilli(),
		Seq:              0,
		IsStandalone:     isStandalone,
		IsPublic:         req.IsPublic,
		LobbyName:        lobbyName,
		CreatedAt:        time.Now(),
		UpdatedAt:        time.Now(),
		LastActiveAt:     time.Now(),
	}

	// Persist to Postgres
	if err := s.repo.CreateSession(ctx, wt); err != nil {
		return nil, fmt.Errorf("failed to save session to database: %w", err)
	}

	// Add host as first participant
	p := &WTParticipant{
		SessionID: wt.ID,
		UserID:    hostUserID,
		Role:      "host",
		JoinedAt:  time.Now(),
	}
	if err := s.repo.AddParticipant(ctx, p); err != nil {
		s.logger.Warn("failed to save host participant", zap.Error(err))
	}

	// Set in Redis
	if err := s.cache.SetSessionState(ctx, wt); err != nil {
		s.logger.Warn("failed to write session to cache", zap.Error(err))
	}

	// Broadcast session start to Centrifugo room channel (if channel-based)
	if !wt.IsStandalone {
		s.broadcastEvent(ctx, wt.RoomID.String(), "session_created", wt)
	}

	return wt, nil
}

func (s *wtService) GetSession(ctx context.Context, id string) (*WTSession, error) {
	// Try cache first
	wt, err := s.cache.GetSessionState(ctx, id)
	if err == nil && wt != nil {
		return wt, nil
	}

	// Fallback to database
	wt, err = s.repo.GetSession(ctx, id)
	if err != nil {
		return nil, err
	}

	// Write back to cache
	_ = s.cache.SetSessionState(ctx, wt)

	return wt, nil
}

func (s *wtService) JoinSession(ctx context.Context, id string, userID uuid.UUID, userName string) (*JoinSessionResponse, error) {
	wt, err := s.GetSession(ctx, id)
	if err != nil {
		return nil, err
	}

	if wt.State == StateEnded {
		return nil, errors.New("session has already ended")
	}

	// Fetch active participants to verify capacity
	participants, err := s.repo.GetParticipants(ctx, id)
	if err != nil {
		return nil, fmt.Errorf("failed to retrieve participants: %w", err)
	}

	if len(participants) >= wt.Settings.MaxViewers {
		return nil, errors.New("session has reached maximum capacity")
	}

	role := "viewer"
	if wt.HostUserID == userID {
		role = "host"
	}

	p := &WTParticipant{
		SessionID: id,
		UserID:    userID,
		Role:      role,
		JoinedAt:  time.Now(),
	}
	if err := s.repo.AddParticipant(ctx, p); err != nil {
		return nil, fmt.Errorf("failed to register participant: %w", err)
	}

	// Generate LiveKit token
	// Participant name uses userName, identity uses userID
	token, err := s.livekit.GenerateToken(
		wt.ID, 
		userName, 
		userID.String(), 
		false, // canPublish (no video/audio publishing)
		true,  // canPublishData (required to send reactions / commands)
	)
	if err != nil {
		return nil, fmt.Errorf("failed to mint livekit token: %w", err)
	}

	return &JoinSessionResponse{
		Session:      wt,
		LiveKitToken: token,
	}, nil
}

func (s *wtService) LeaveSession(ctx context.Context, id string, userID uuid.UUID) error {
	wt, err := s.GetSession(ctx, id)
	if err != nil {
		return err
	}

	if err := s.repo.MarkParticipantLeft(ctx, id, userID); err != nil {
		return err
	}

	// If the user leaving is the host, trigger an election or transfer host
	if wt.HostUserID == userID && wt.State != StateEnded {
		s.logger.Info("host left session; triggering host election", zap.String("session_id", id))
		
		// Find oldest active participant
		nextHost, err := s.repo.GetOldestActiveParticipant(ctx, id)
		if err == nil && nextHost != nil {
			wt.HostUserID = nextHost.UserID
			wt.UpdatedAt = time.Now()
			if dbErr := s.repo.UpdateSession(ctx, wt); dbErr == nil {
				_ = s.cache.SetSessionState(ctx, wt)
				s.broadcastEvent(ctx, wt.RoomID.String(), "host_changed", map[string]string{
					"session_id":   id,
					"new_host_id":  nextHost.UserID.String(),
				})
			}
		} else {
			// No participants left, end the session
			s.logger.Info("no active participants left; ending session", zap.String("session_id", id))
			return s.EndSession(ctx, id, userID)
		}
	}

	return nil
}

func (s *wtService) EndSession(ctx context.Context, id string, userID uuid.UUID) error {
	wt, err := s.GetSession(ctx, id)
	if err != nil {
		return err
	}

	// Only host or system can end the session
	if wt.HostUserID != userID && userID != uuid.Nil {
		return errors.New("unauthorized to end this session")
	}

	wt.State = StateEnded
	now := time.Now()
	wt.EndedAt = &now
	wt.UpdatedAt = now

	// Update Postgres
	if err := s.repo.UpdateSession(ctx, wt); err != nil {
		return fmt.Errorf("failed to update session db: %w", err)
	}

	// Delete from cache
	_ = s.cache.DeleteSessionState(ctx, id)

	// Broadcast session end
	s.broadcastEvent(ctx, wt.RoomID.String(), "session_ended", map[string]string{
		"session_id": id,
	})

	return nil
}

func (s *wtService) TransferHost(ctx context.Context, id string, currentHostID uuid.UUID, toUserID uuid.UUID) error {
	wt, err := s.GetSession(ctx, id)
	if err != nil {
		return err
	}

	if wt.HostUserID != currentHostID {
		return errors.New("only the host can transfer hosting privileges")
	}

	wt.HostUserID = toUserID
	wt.UpdatedAt = time.Now()

	// Update Postgres
	if err := s.repo.UpdateSession(ctx, wt); err != nil {
		return fmt.Errorf("failed to update session db: %w", err)
	}

	// Update cache
	_ = s.cache.SetSessionState(ctx, wt)

	// Broadcast host change
	s.broadcastEvent(ctx, wt.RoomID.String(), "host_changed", map[string]string{
		"session_id":   id,
		"new_host_id":  toUserID.String(),
	})

	return nil
}

func (s *wtService) UpdateSessionAnchor(ctx context.Context, id string, hostUserID uuid.UUID, req *PushAnchorRequest) error {
	wt, err := s.GetSession(ctx, id)
	if err != nil {
		return err
	}

	if wt.HostUserID != hostUserID {
		return errors.New("only the host can push synchronization anchors")
	}

	// Rate limit: 60 anchors per minute per host
	limitKey := fmt.Sprintf("wt:limit:anchor:%s", hostUserID.String())
	limited, err := s.cache.CheckRateLimit(ctx, limitKey, 60, 1*time.Minute)
	if err != nil {
		s.logger.Warn("failed to check rate limit", zap.Error(err))
	} else if limited {
		return ErrAnchorRateLimitExceeded
	}

	wt.AnchorPositionMS = req.PositionMS
	wt.AnchorPlaying = req.Playing
	wt.AnchorRate = req.Rate
	wt.AnchorWallMS = time.Now().UnixMilli()
	wt.Seq = wt.Seq + 1
	wt.UpdatedAt = time.Now()
	wt.LastActiveAt = time.Now()

	if wt.State == StateDraft {
		wt.State = StateReady
	}

	// Update Postgres
	if err := s.repo.UpdateSession(ctx, wt); err != nil {
		return fmt.Errorf("failed to save anchor to database: %w", err)
	}

	// Update Cache
	_ = s.cache.SetSessionState(ctx, wt)

	return nil
}

func (s *wtService) GetSessionAnchor(ctx context.Context, id string) (*WTSessionAnchor, error) {
	wt, err := s.GetSession(ctx, id)
	if err != nil {
		return nil, err
	}

	if wt.State == StateEnded {
		return nil, errors.New("session has ended")
	}

	return &WTSessionAnchor{
		PositionMS:  wt.AnchorPositionMS,
		Playing:     wt.AnchorPlaying,
		Rate:        wt.AnchorRate,
		WallClockMS: wt.AnchorWallMS,
		Seq:         wt.Seq,
	}, nil
}

func (s *wtService) ListPublicLobbies(ctx context.Context) ([]*WTSession, error) {
	return s.repo.GetPublicLobbies(ctx)
}

func (s *wtService) broadcastEvent(ctx context.Context, roomID string, eventType string, payload interface{}) {
	channel := fmt.Sprintf("room:%s:wt", roomID)
	data := map[string]interface{}{
		"event":   eventType,
		"payload": payload,
	}
	if err := s.publisher.Publish(ctx, channel, data); err != nil {
		s.logger.Warn("failed to publish centrifugo event", zap.String("channel", channel), zap.Error(err))
	}
}
