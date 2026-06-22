package watchtogether

import (
	"context"

	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/services"
	centrifugoSvc "github.com/flicko-org/flicko-backend/internal/services/centrifugo"
	"go.uber.org/zap"
)

type Hub struct {
	repo  Repository
	svc   Service
	cache *RedisCache
}

func Initialize(
	ctx context.Context,
	logger *zap.Logger,
	db *pgxpool.Pool,
	c cache.CacheLayer,
	lk services.LiveKitService,
	r *mux.Router,
	pub centrifugoSvc.Publisher,
) (*Hub, error) {
	logger.Info("initializing watch together module")

	// Create layers
	repo := NewRepository(db)
	redisCache := NewRedisCache(c)
	svc := NewService(repo, redisCache, lk, pub, logger)
	handler := NewHandler(svc, logger)

	// Route registration
	// Routes are registered relative to the parent protected subrouter.
	// E.g., /api/v1/wt/sessions
	wtRouter := r.PathPrefix("/wt").Subrouter()

	wtRouter.HandleFunc("/sessions", handler.HandleCreate).Methods("POST")
	wtRouter.HandleFunc("/sessions/{id}", handler.HandleGet).Methods("GET")
	wtRouter.HandleFunc("/sessions/{id}", handler.HandleEnd).Methods("DELETE")
	wtRouter.HandleFunc("/sessions/{id}/join", handler.HandleJoin).Methods("POST")
	wtRouter.HandleFunc("/sessions/{id}/leave", handler.HandleLeave).Methods("POST")
	wtRouter.HandleFunc("/sessions/{id}/host", handler.HandleTransferHost).Methods("POST")
	wtRouter.HandleFunc("/sessions/{id}/anchor", handler.HandleUpdateAnchor).Methods("POST")
	wtRouter.HandleFunc("/sessions/{id}/anchor", handler.HandleGetAnchor).Methods("GET")
	wtRouter.HandleFunc("/lobbies", handler.HandleListLobbies).Methods("GET")

	logger.Info("watch together module initialized successfully")

	return &Hub{
		repo:  repo,
		svc:   svc,
		cache: redisCache,
	}, nil
}
