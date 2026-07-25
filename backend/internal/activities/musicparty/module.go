package musicparty

import (
	"context"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/services"
	centrifugoSvc "github.com/flicko-org/flicko-backend/internal/services/centrifugo"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

// Hub holds references to the Music Party module's internal layers.
type Hub struct {
	repo  Repository
	svc   Service
	cache *RedisCache
}

// Initialize wires up the Music Party module: repo, cache, service, handler,
// and registers all REST routes under /api/v1/mp/...
func Initialize(
	ctx context.Context,
	logger *zap.Logger,
	db *pgxpool.Pool,
	c cache.CacheLayer,
	lk services.LiveKitService,
	r *mux.Router,
	pub centrifugoSvc.Publisher,
) (*Hub, error) {
	logger.Info("initializing music party module")

	// Create layers
	repo := NewRepository(db)
	redisCache := NewRedisCache(c)
	svc := NewService(repo, redisCache, lk, pub, logger)
	handler := NewHandler(svc, logger)

	// Route registration — sub-router under /mp
	mpRouter := r.PathPrefix("/mp").Subrouter()

	// Sessions
	mpRouter.HandleFunc("/sessions", handler.HandleCreateSession).Methods("POST")
	mpRouter.HandleFunc("/sessions/{id}", handler.HandleGetSession).Methods("GET")
	mpRouter.HandleFunc("/sessions/{id}", handler.HandleUpdateSession).Methods("PATCH")
	mpRouter.HandleFunc("/sessions/{id}", handler.HandleEndSession).Methods("DELETE")

	// Participants
	mpRouter.HandleFunc("/sessions/{id}/join", handler.HandleJoinSession).Methods("POST")
	mpRouter.HandleFunc("/sessions/{id}/leave", handler.HandleLeaveSession).Methods("POST")

	// Queue
	mpRouter.HandleFunc("/sessions/{id}/queue", handler.HandleAddToQueue).Methods("POST")
	mpRouter.HandleFunc("/sessions/{id}/queue", handler.HandleGetQueue).Methods("GET")
	mpRouter.HandleFunc("/sessions/{id}/queue/{itemId}", handler.HandleReorderQueueItem).Methods("PATCH")
	mpRouter.HandleFunc("/sessions/{id}/queue/{itemId}", handler.HandleRemoveQueueItem).Methods("DELETE")

	// Playback Control
	mpRouter.HandleFunc("/sessions/{id}/play", handler.HandlePlay).Methods("POST")
	mpRouter.HandleFunc("/sessions/{id}/skip", handler.HandleSkip).Methods("POST")
	mpRouter.HandleFunc("/sessions/{id}/dj", handler.HandleHandoffDJ).Methods("POST")

	// Anchor (sync)
	mpRouter.HandleFunc("/sessions/{id}/anchor", handler.HandlePushAnchor).Methods("POST")
	mpRouter.HandleFunc("/sessions/{id}/anchor", handler.HandleGetAnchor).Methods("GET")

	// Vibes (reactions + skip-vote)
	mpRouter.HandleFunc("/sessions/{id}/vibe", handler.HandleAddVibe).Methods("POST")

	logger.Info("music party module initialized successfully",
		zap.Int("routes", 16),
	)

	return &Hub{
		repo:  repo,
		svc:   svc,
		cache: redisCache,
	}, nil
}
