package musicparty

import (
	"context"
	"fmt"
	"math"
	"time"

	"github.com/flicko-org/flicko-backend/internal/services"
	centrifugoSvc "github.com/flicko-org/flicko-backend/internal/services/centrifugo"
	"github.com/google/uuid"
	"go.uber.org/zap"
)

// Service defines the business logic interface for Music Party.
type Service interface {
	// Sessions
	CreateSession(ctx context.Context, req *CreateSessionRequest, djUserID uuid.UUID) (*MPSession, error)
	GetSession(ctx context.Context, id string) (*MPSession, error)
	UpdateSession(ctx context.Context, id string, req *UpdateSessionRequest, userID uuid.UUID) (*MPSession, error)
	EndSession(ctx context.Context, id string, userID uuid.UUID) error

	// Participants
	JoinSession(ctx context.Context, id string, userID uuid.UUID, req *JoinRequest) (*JoinSessionResponse, error)
	LeaveSession(ctx context.Context, id string, userID uuid.UUID) error

	// Queue
	AddToQueue(ctx context.Context, sessionID string, req *AddQueueItemRequest, userID uuid.UUID) (*MPQueueItem, error)
	GetQueue(ctx context.Context, sessionID string) ([]*MPQueueItem, error)
	ReorderQueueItem(ctx context.Context, sessionID string, itemID string, req *ReorderQueueItemRequest, userID uuid.UUID) error
	RemoveQueueItem(ctx context.Context, sessionID string, itemID string, userID uuid.UUID) error

	// Playback Control
	Play(ctx context.Context, sessionID string, userID uuid.UUID) (*MPSession, error)
	Skip(ctx context.Context, sessionID string, req *SkipRequest, userID uuid.UUID) (*MPSession, error)
	HandoffDJ(ctx context.Context, sessionID string, req *HandoffDJRequest, userID uuid.UUID) (*MPSession, error)

	// Anchor
	PushAnchor(ctx context.Context, sessionID string, req *PushAnchorRequest, userID uuid.UUID) error
	GetAnchor(ctx context.Context, sessionID string) (*AnchorState, error)

	// Vibes
	AddVibe(ctx context.Context, sessionID string, req *VibeRequest, userID uuid.UUID) (*SkipVoteStatus, error)
}

// mpService implements Service.
type mpService struct {
	repo       Repository
	cache      *RedisCache
	acsService services.AzureACSService
	publisher  centrifugoSvc.Publisher
	logger     *zap.Logger
}

// NewService creates a new Music Party service.
func NewService(
	repo Repository,
	cache *RedisCache,
	acs services.AzureACSService,
	pub centrifugoSvc.Publisher,
	logger *zap.Logger,
) Service {
	return &mpService{
		repo:       repo,
		cache:      cache,
		acsService: acs,
		publisher:  pub,
		logger:     logger.Named("service.musicparty"),
	}
}

// ── Sessions ───────────────────────────────────────────────────

func (s *mpService) CreateSession(ctx context.Context, req *CreateSessionRequest, djUserID uuid.UUID) (*MPSession, error) {
	roomID, err := uuid.Parse(req.RoomID)
	if err != nil {
		return nil, fmt.Errorf("invalid room_id: %w", err)
	}

	// Check for existing active session in the room
	existing, err := s.repo.GetActiveSessionByRoom(ctx, roomID)
	if err != nil {
		return nil, err
	}
	if existing != nil {
		return nil, fmt.Errorf("an active music party session already exists in this room")
	}

	// Build settings with defaults
	settings := MPSettings{
		VoteSkipThreshold: 0.5,
		MaxListeners:      25,
		AllowDupes:        true,
	}
	if req.Settings != nil {
		if req.Settings.VoteSkipThreshold != nil {
			settings.VoteSkipThreshold = *req.Settings.VoteSkipThreshold
		}
		if req.Settings.MaxListeners != nil {
			settings.MaxListeners = *req.Settings.MaxListeners
		}
		if req.Settings.AllowDupes != nil {
			settings.AllowDupes = *req.Settings.AllowDupes
		}
	}

	rotationMode := RotationManual
	if req.RotationMode != "" {
		rotationMode = RotationMode(req.RotationMode)
	}

	now := time.Now()
	session := &MPSession{
		ID:               fmt.Sprintf("mp_%s", uuid.New().String()[:12]),
		RoomID:           roomID,
		DJUserID:         djUserID,
		RotationMode:     rotationMode,
		State:            StateReady,
		CurrentPositionMS: 0,
		AnchorWallMS:     0,
		Seq:              0,
		Settings:         settings,
		CreatedAt:        now,
		UpdatedAt:        now,
		LastActiveAt:     now,
	}

	if err := s.repo.CreateSession(ctx, session); err != nil {
		return nil, err
	}

	// Add creator as DJ participant
	djParticipant := &MPParticipant{
		SessionID: session.ID,
		UserID:    djUserID,
		Role:      RoleDJ,
		JoinedAt:  now,
	}
	if err := s.repo.AddParticipant(ctx, djParticipant); err != nil {
		s.logger.Error("failed to add DJ participant", zap.Error(err))
	}

	// Write to Redis
	if err := s.cache.SetSessionState(ctx, session); err != nil {
		s.logger.Warn("failed to cache session state", zap.Error(err))
	}
	if err := s.cache.SetCurrentDJ(ctx, session.ID, djUserID.String()); err != nil {
		s.logger.Warn("failed to cache DJ", zap.Error(err))
	}
	if err := s.cache.AddRoomSession(ctx, roomID.String(), session.ID); err != nil {
		s.logger.Warn("failed to track room session", zap.Error(err))
	}

	// Broadcast via Centrifugo
	s.broadcastEvent(ctx, roomID.String(), "session_created", session)

	return session, nil
}

func (s *mpService) GetSession(ctx context.Context, id string) (*MPSession, error) {
	// Try cache first
	session, err := s.cache.GetSessionState(ctx, id)
	if err == nil && session != nil {
		return session, nil
	}

	// Fallback to DB
	session, err = s.repo.GetSession(ctx, id)
	if err != nil {
		return nil, err
	}

	// Write-back to cache
	if cacheErr := s.cache.SetSessionState(ctx, session); cacheErr != nil {
		s.logger.Warn("failed to write session to cache", zap.Error(cacheErr))
	}

	return session, nil
}

func (s *mpService) UpdateSession(ctx context.Context, id string, req *UpdateSessionRequest, userID uuid.UUID) (*MPSession, error) {
	session, err := s.GetSession(ctx, id)
	if err != nil {
		return nil, err
	}

	// Only the DJ can update settings
	if session.DJUserID != userID {
		return nil, fmt.Errorf("only the DJ can update session settings")
	}

	if req.RotationMode != nil {
		session.RotationMode = RotationMode(*req.RotationMode)
	}
	if req.VoteSkipThreshold != nil {
		session.Settings.VoteSkipThreshold = *req.VoteSkipThreshold
	}
	if req.MaxListeners != nil {
		session.Settings.MaxListeners = *req.MaxListeners
	}

	if err := s.repo.UpdateSession(ctx, session); err != nil {
		return nil, err
	}

	if cacheErr := s.cache.SetSessionState(ctx, session); cacheErr != nil {
		s.logger.Warn("failed to update session cache", zap.Error(cacheErr))
	}

	s.broadcastEvent(ctx, session.RoomID.String(), "session_updated", session)
	return session, nil
}

func (s *mpService) EndSession(ctx context.Context, id string, userID uuid.UUID) error {
	session, err := s.GetSession(ctx, id)
	if err != nil {
		return err
	}

	if session.DJUserID != userID {
		return fmt.Errorf("only the DJ can end the session")
	}

	if err := s.repo.EndSession(ctx, id); err != nil {
		return err
	}

	// Clean up Redis
	if cleanErr := s.cache.CleanupSession(ctx, id); cleanErr != nil {
		s.logger.Warn("failed to clean up session cache", zap.Error(cleanErr))
	}
	_ = s.cache.RemoveRoomSession(ctx, session.RoomID.String(), id)

	s.broadcastEvent(ctx, session.RoomID.String(), "session_ended", map[string]string{"session_id": id})
	return nil
}

// ── Participants ───────────────────────────────────────────────

func (s *mpService) JoinSession(ctx context.Context, id string, userID uuid.UUID, req *JoinRequest) (*JoinSessionResponse, error) {
	session, err := s.GetSession(ctx, id)
	if err != nil {
		return nil, err
	}

	if session.State == StateEnded {
		return nil, fmt.Errorf("session has ended")
	}

	// Check listener count
	count, err := s.repo.CountActiveListeners(ctx, id)
	if err != nil {
		return nil, err
	}
	if count >= session.Settings.MaxListeners {
		return nil, fmt.Errorf("session is full (%d/%d listeners)", count, session.Settings.MaxListeners)
	}

	// Determine role
	role := RoleListener
	if session.DJUserID == userID {
		role = RoleDJ
	}

	tier := TierNone
	if req.SpotifyTier != "" {
		tier = SpotifyTier(req.SpotifyTier)
	}

	participant := &MPParticipant{
		SessionID:   id,
		UserID:      userID,
		Role:        role,
		SpotifyTier: &tier,
		JoinedAt:    time.Now(),
	}

	if err := s.repo.AddParticipant(ctx, participant); err != nil {
		return nil, err
	}

	// Get queue
	queue, err := s.repo.GetQueueItems(ctx, id)
	if err != nil {
		s.logger.Warn("failed to fetch queue for join response", zap.Error(err))
	}

	// Get anchor
	anchor, _ := s.cache.GetAnchorState(ctx, id)

	// Mint Azure ACS voice token
	tokenResp, err := s.acsService.IssueToken(ctx, []string{"voip", "chat"})
	token := ""
	if err == nil && tokenResp != nil {
		token = tokenResp.Token
	} else if err != nil {
		s.logger.Warn("failed to generate azure acs token for music party", zap.Error(err))
		token = fmt.Sprintf("acs_token_mp_%s_%s", id, userID.String())
	}

	s.broadcastEvent(ctx, session.RoomID.String(), "participant_joined", map[string]interface{}{
		"session_id": id,
		"user_id":    userID.String(),
		"role":       string(role),
	})

	return &JoinSessionResponse{
		Session:      session,
		Queue:        queue,
		Anchor:       anchor,
		VoiceToken:   token,
		LiveKitToken: token,
	}, nil
}

func (s *mpService) LeaveSession(ctx context.Context, id string, userID uuid.UUID) error {
	session, err := s.GetSession(ctx, id)
	if err != nil {
		return err
	}

	if err := s.repo.RemoveParticipant(ctx, id, userID); err != nil {
		return err
	}

	s.broadcastEvent(ctx, session.RoomID.String(), "participant_left", map[string]interface{}{
		"session_id": id,
		"user_id":    userID.String(),
	})

	// If the DJ left, trigger rotation
	if session.DJUserID == userID {
		s.logger.Info("DJ left, triggering rotation", zap.String("session_id", id))
		if err := s.rotateDJ(ctx, session); err != nil {
			s.logger.Error("failed to rotate DJ after leave", zap.Error(err))
		}
	}

	return nil
}

// ── Queue ──────────────────────────────────────────────────────

func (s *mpService) AddToQueue(ctx context.Context, sessionID string, req *AddQueueItemRequest, userID uuid.UUID) (*MPQueueItem, error) {
	// Rate limit check
	allowed, err := s.cache.CheckQueueAddRateLimit(ctx, userID.String())
	if err != nil {
		s.logger.Warn("rate limit check failed", zap.Error(err))
	}
	if !allowed {
		return nil, fmt.Errorf("rate limited: too many queue additions")
	}

	session, err := s.GetSession(ctx, sessionID)
	if err != nil {
		return nil, err
	}
	if session.State == StateEnded {
		return nil, fmt.Errorf("session has ended")
	}

	// Verify user is a participant
	participant, err := s.repo.GetParticipant(ctx, sessionID, userID)
	if err != nil {
		return nil, err
	}
	if participant == nil {
		return nil, fmt.Errorf("must be a session participant to add tracks")
	}

	now := time.Now()
	item := &MPQueueItem{
		ID:            fmt.Sprintf("qi_%s", uuid.New().String()[:12]),
		SessionID:     sessionID,
		SpotifyURI:    req.SpotifyURI,
		Title:         req.Title,
		Artist:        req.Artist,
		DurationMS:    req.DurationMS,
		AlbumArtURL:   req.AlbumArtURL,
		PreviewURL:    req.PreviewURL,
		AddedByUserID: userID,
		Position:      float64(now.UnixMilli()),
		State:         QueueStateQueued,
		CreatedAt:     now,
	}

	if err := s.repo.AddQueueItem(ctx, item); err != nil {
		return nil, err
	}

	s.broadcastEvent(ctx, session.RoomID.String(), "queue_updated", map[string]interface{}{
		"session_id": sessionID,
		"action":     "added",
		"item":       item,
	})

	return item, nil
}

func (s *mpService) GetQueue(ctx context.Context, sessionID string) ([]*MPQueueItem, error) {
	return s.repo.GetQueueItems(ctx, sessionID)
}

func (s *mpService) ReorderQueueItem(ctx context.Context, sessionID string, itemID string, req *ReorderQueueItemRequest, userID uuid.UUID) error {
	session, err := s.GetSession(ctx, sessionID)
	if err != nil {
		return err
	}

	// Only DJ can reorder
	if session.DJUserID != userID {
		return fmt.Errorf("only the DJ can reorder the queue")
	}

	item, err := s.repo.GetQueueItem(ctx, itemID)
	if err != nil {
		return err
	}
	if item == nil {
		return fmt.Errorf("queue item not found")
	}

	item.Position = req.Position
	if err := s.repo.UpdateQueueItem(ctx, item); err != nil {
		return err
	}

	s.broadcastEvent(ctx, session.RoomID.String(), "queue_updated", map[string]interface{}{
		"session_id": sessionID,
		"action":     "reordered",
	})

	return nil
}

func (s *mpService) RemoveQueueItem(ctx context.Context, sessionID string, itemID string, userID uuid.UUID) error {
	session, err := s.GetSession(ctx, sessionID)
	if err != nil {
		return err
	}

	item, err := s.repo.GetQueueItem(ctx, itemID)
	if err != nil {
		return err
	}
	if item == nil {
		return fmt.Errorf("queue item not found")
	}

	// DJ or the person who added it can remove
	if session.DJUserID != userID && item.AddedByUserID != userID {
		return fmt.Errorf("only the DJ or the person who added the track can remove it")
	}

	if err := s.repo.RemoveQueueItem(ctx, itemID); err != nil {
		return err
	}

	s.broadcastEvent(ctx, session.RoomID.String(), "queue_updated", map[string]interface{}{
		"session_id": sessionID,
		"action":     "removed",
		"item_id":    itemID,
	})

	return nil
}

// ── Playback Control ───────────────────────────────────────────

func (s *mpService) Play(ctx context.Context, sessionID string, userID uuid.UUID) (*MPSession, error) {
	session, err := s.GetSession(ctx, sessionID)
	if err != nil {
		return nil, err
	}

	if session.DJUserID != userID {
		return nil, fmt.Errorf("only the DJ can control playback")
	}

	// Get next queued track if no current track
	if session.CurrentTrackURI == nil || *session.CurrentTrackURI == "" {
		next, err := s.repo.GetNextQueueItem(ctx, sessionID)
		if err != nil {
			return nil, err
		}
		if next == nil {
			return nil, fmt.Errorf("queue is empty")
		}

		// Mark as playing
		now := time.Now()
		next.State = QueueStatePlaying
		next.PlayedAt = &now
		if err := s.repo.UpdateQueueItem(ctx, next); err != nil {
			return nil, err
		}

		session.CurrentTrackURI = &next.SpotifyURI
		session.CurrentPositionMS = 0
		session.CurrentStartedAt = &now
	}

	session.State = StatePlaying
	session.Seq++
	now := time.Now()
	session.AnchorWallMS = now.UnixMilli()

	if err := s.repo.UpdateSession(ctx, session); err != nil {
		return nil, err
	}

	if cacheErr := s.cache.SetSessionState(ctx, session); cacheErr != nil {
		s.logger.Warn("failed to update session cache", zap.Error(cacheErr))
	}

	// Push anchor to cache
	anchor := &AnchorState{
		TrackURI:    *session.CurrentTrackURI,
		PositionMS:  session.CurrentPositionMS,
		Playing:     true,
		WallClockMS: session.AnchorWallMS,
		Seq:         session.Seq,
		DJID:        session.DJUserID.String(),
	}
	_ = s.cache.SetAnchorState(ctx, sessionID, anchor)

	s.broadcastEvent(ctx, session.RoomID.String(), "playback_started", session)
	return session, nil
}

func (s *mpService) Skip(ctx context.Context, sessionID string, req *SkipRequest, userID uuid.UUID) (*MPSession, error) {
	session, err := s.GetSession(ctx, sessionID)
	if err != nil {
		return nil, err
	}

	// DJ or vote-skip can skip
	if req.Reason != "vote" && session.DJUserID != userID {
		return nil, fmt.Errorf("only the DJ can skip tracks")
	}

	// Mark current track as skipped
	if session.CurrentTrackURI != nil {
		items, err := s.repo.GetQueueItems(ctx, sessionID)
		if err == nil {
			for _, item := range items {
				if item.State == QueueStatePlaying {
					now := time.Now()
					item.State = QueueStateSkipped
					item.EndedAt = &now
					_ = s.repo.UpdateQueueItem(ctx, item)
					break
				}
			}
		}
	}

	// Advance to next track
	next, err := s.repo.GetNextQueueItem(ctx, sessionID)
	if err != nil {
		return nil, err
	}

	if next != nil {
		now := time.Now()
		next.State = QueueStatePlaying
		next.PlayedAt = &now
		_ = s.repo.UpdateQueueItem(ctx, next)

		session.CurrentTrackURI = &next.SpotifyURI
		session.CurrentPositionMS = 0
		session.CurrentStartedAt = &now
		session.AnchorWallMS = now.UnixMilli()
	} else {
		session.CurrentTrackURI = nil
		session.CurrentPositionMS = 0
		session.State = StatePaused
	}

	session.Seq++
	if err := s.repo.UpdateSession(ctx, session); err != nil {
		return nil, err
	}

	_ = s.cache.SetSessionState(ctx, session)

	// Handle DJ rotation on track end
	if req.Reason == "ended" && session.RotationMode != RotationManual {
		if err := s.rotateDJ(ctx, session); err != nil {
			s.logger.Error("failed to rotate DJ", zap.Error(err))
		}
	}

	s.broadcastEvent(ctx, session.RoomID.String(), "track_skipped", map[string]interface{}{
		"session_id": sessionID,
		"reason":     req.Reason,
		"session":    session,
	})

	return session, nil
}

func (s *mpService) HandoffDJ(ctx context.Context, sessionID string, req *HandoffDJRequest, userID uuid.UUID) (*MPSession, error) {
	session, err := s.GetSession(ctx, sessionID)
	if err != nil {
		return nil, err
	}

	if session.DJUserID != userID {
		return nil, fmt.Errorf("only the current DJ can hand off")
	}

	newDJID, err := uuid.Parse(req.ToUserID)
	if err != nil {
		return nil, fmt.Errorf("invalid to_user_id: %w", err)
	}

	// Verify target is a participant
	target, err := s.repo.GetParticipant(ctx, sessionID, newDJID)
	if err != nil {
		return nil, err
	}
	if target == nil {
		return nil, fmt.Errorf("target user is not a session participant")
	}

	// Update roles
	session.DJUserID = newDJID
	session.Seq++

	if err := s.repo.UpdateSession(ctx, session); err != nil {
		return nil, err
	}

	_ = s.cache.SetSessionState(ctx, session)
	_ = s.cache.SetCurrentDJ(ctx, sessionID, newDJID.String())

	s.broadcastEvent(ctx, session.RoomID.String(), "dj_changed", map[string]interface{}{
		"session_id": sessionID,
		"new_dj_id":  newDJID.String(),
	})

	// Notify the new DJ via private channel
	s.publishToUser(ctx, newDJID.String(), "you_are_dj", map[string]string{
		"session_id": sessionID,
	})

	return session, nil
}

// ── Anchor ─────────────────────────────────────────────────────

func (s *mpService) PushAnchor(ctx context.Context, sessionID string, req *PushAnchorRequest, userID uuid.UUID) error {
	session, err := s.GetSession(ctx, sessionID)
	if err != nil {
		return err
	}

	if session.DJUserID != userID {
		return fmt.Errorf("only the DJ can push anchors")
	}

	now := time.Now()
	session.CurrentTrackURI = &req.TrackURI
	session.CurrentPositionMS = req.PositionMS
	session.AnchorWallMS = now.UnixMilli()
	session.Seq++

	if req.Playing {
		session.State = StatePlaying
	} else {
		session.State = StatePaused
	}

	// Update DB (debounced — only write every 10 anchor pushes)
	if session.Seq%10 == 0 {
		if err := s.repo.UpdateSession(ctx, session); err != nil {
			s.logger.Warn("failed to persist anchor to DB", zap.Error(err))
		}
	}

	// Always update Redis (hot state)
	anchor := &AnchorState{
		TrackURI:    req.TrackURI,
		PositionMS:  req.PositionMS,
		Playing:     req.Playing,
		WallClockMS: now.UnixMilli(),
		Seq:         session.Seq,
		DJID:        userID.String(),
	}
	_ = s.cache.SetAnchorState(ctx, sessionID, anchor)
	_ = s.cache.SetSessionState(ctx, session)

	return nil
}

func (s *mpService) GetAnchor(ctx context.Context, sessionID string) (*AnchorState, error) {
	anchor, err := s.cache.GetAnchorState(ctx, sessionID)
	if err == nil && anchor != nil {
		return anchor, nil
	}

	// Fallback: reconstruct from session
	session, err := s.repo.GetSession(ctx, sessionID)
	if err != nil {
		return nil, err
	}

	trackURI := ""
	if session.CurrentTrackURI != nil {
		trackURI = *session.CurrentTrackURI
	}

	return &AnchorState{
		TrackURI:    trackURI,
		PositionMS:  session.CurrentPositionMS,
		Playing:     session.State == StatePlaying,
		WallClockMS: session.AnchorWallMS,
		Seq:         session.Seq,
		DJID:        session.DJUserID.String(),
	}, nil
}

// ── Vibes ──────────────────────────────────────────────────────

func (s *mpService) AddVibe(ctx context.Context, sessionID string, req *VibeRequest, userID uuid.UUID) (*SkipVoteStatus, error) {
	session, err := s.GetSession(ctx, sessionID)
	if err != nil {
		return nil, err
	}

	// Verify user is a participant
	participant, err := s.repo.GetParticipant(ctx, sessionID, userID)
	if err != nil {
		return nil, err
	}
	if participant == nil {
		return nil, fmt.Errorf("must be a session participant")
	}

	vibe := &MPVibe{
		SessionID:   sessionID,
		QueueItemID: &req.QueueItemID,
		UserID:      userID,
		Kind:        VibeKind(req.Kind),
		CreatedAt:   time.Now(),
	}

	if err := s.repo.AddVibe(ctx, vibe); err != nil {
		return nil, err
	}

	s.broadcastEvent(ctx, session.RoomID.String(), "vibe_added", map[string]interface{}{
		"session_id": sessionID,
		"user_id":    userID.String(),
		"kind":       req.Kind,
	})

	// Handle skip-vote logic
	if VibeKind(req.Kind) == VibeSkipVote && session.CurrentTrackURI != nil {
		return s.processSkipVote(ctx, session, req.QueueItemID, userID)
	}

	return nil, nil
}

// ── DJ Rotation ────────────────────────────────────────────────

func (s *mpService) rotateDJ(ctx context.Context, session *MPSession) error {
	// Acquire rotation lock
	acquired, err := s.cache.AcquireRotationLock(ctx, session.ID)
	if err != nil || !acquired {
		return fmt.Errorf("rotation already in progress")
	}

	participants, err := s.repo.GetActiveParticipants(ctx, session.ID)
	if err != nil {
		return err
	}

	if len(participants) == 0 {
		// No participants — end session
		return s.EndSession(ctx, session.ID, session.DJUserID)
	}

	switch session.RotationMode {
	case RotationRoundRobin:
		return s.rotateRoundRobin(ctx, session, participants)
	case RotationListenerVote:
		// For listener_vote, use round-robin as fallback (vote modal on client side)
		return s.rotateRoundRobin(ctx, session, participants)
	default:
		// Manual — no rotation; pause and surface modal
		session.State = StatePaused
		_ = s.repo.UpdateSession(ctx, session)
		_ = s.cache.SetSessionState(ctx, session)
		s.broadcastEvent(ctx, session.RoomID.String(), "dj_left_manual", map[string]string{
			"session_id": session.ID,
		})
		return nil
	}
}

func (s *mpService) rotateRoundRobin(ctx context.Context, session *MPSession, participants []*MPParticipant) error {
	// Find current DJ index, then pick next
	currentDJIdx := -1
	for i, p := range participants {
		if p.UserID == session.DJUserID {
			currentDJIdx = i
			break
		}
	}

	// Pick next participant (wrap around)
	nextIdx := (currentDJIdx + 1) % len(participants)
	if participants[nextIdx].UserID == session.DJUserID && len(participants) > 1 {
		nextIdx = (nextIdx + 1) % len(participants)
	}

	newDJ := participants[nextIdx]
	session.DJUserID = newDJ.UserID
	session.Seq++

	if err := s.repo.UpdateSession(ctx, session); err != nil {
		return err
	}

	_ = s.cache.SetSessionState(ctx, session)
	_ = s.cache.SetCurrentDJ(ctx, session.ID, newDJ.UserID.String())

	s.broadcastEvent(ctx, session.RoomID.String(), "dj_changed", map[string]interface{}{
		"session_id": session.ID,
		"new_dj_id":  newDJ.UserID.String(),
		"mode":       "round_robin",
	})

	s.publishToUser(ctx, newDJ.UserID.String(), "you_are_dj", map[string]string{
		"session_id": session.ID,
	})

	return nil
}

func (s *mpService) processSkipVote(ctx context.Context, session *MPSession, queueItemID string, userID uuid.UUID) (*SkipVoteStatus, error) {
	trackURI := ""
	if session.CurrentTrackURI != nil {
		trackURI = *session.CurrentTrackURI
	}

	// Check if user already voted
	voted, err := s.cache.HasUserVotedSkip(ctx, session.ID, trackURI, userID.String())
	if err != nil {
		return nil, err
	}
	if voted {
		return nil, fmt.Errorf("you already voted to skip this track")
	}

	// Add vote
	_ = s.cache.AddSkipVoter(ctx, session.ID, trackURI, userID.String())
	votes, err := s.cache.IncrSkipVote(ctx, session.ID, trackURI)
	if err != nil {
		return nil, err
	}

	// Count active listeners for threshold
	listenerCount, err := s.repo.CountActiveListeners(ctx, session.ID)
	if err != nil {
		return nil, err
	}

	threshold := session.Settings.VoteSkipThreshold
	needed := int(math.Ceil(float64(listenerCount) * threshold))
	reached := int(votes) >= needed

	status := &SkipVoteStatus{
		CurrentVotes: int(votes),
		Threshold:    threshold,
		TotalVoters:  listenerCount,
		Reached:      reached,
	}

	if reached {
		s.logger.Info("skip vote threshold reached", zap.String("session_id", session.ID))
		_, _ = s.Skip(ctx, session.ID, &SkipRequest{Reason: "vote"}, session.DJUserID)
	}

	return status, nil
}

// ── Broadcasting ───────────────────────────────────────────────

func (s *mpService) broadcastEvent(ctx context.Context, roomID string, eventType string, payload interface{}) {
	channel := fmt.Sprintf("room:%s:mp", roomID)
	data := map[string]interface{}{
		"event":   eventType,
		"payload": payload,
	}
	if err := s.publisher.Publish(ctx, channel, data); err != nil {
		s.logger.Warn("failed to publish centrifugo event",
			zap.String("channel", channel),
			zap.String("event", eventType),
			zap.Error(err),
		)
	}
}

func (s *mpService) publishToUser(ctx context.Context, userID string, eventType string, payload interface{}) {
	channel := fmt.Sprintf("user:%s:mp", userID)
	data := map[string]interface{}{
		"event":   eventType,
		"payload": payload,
	}
	if err := s.publisher.Publish(ctx, channel, data); err != nil {
		s.logger.Warn("failed to publish user event",
			zap.String("channel", channel),
			zap.Error(err),
		)
	}
}
