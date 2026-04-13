package handler

import (
	"time"

	"github.com/go-chi/chi/v5"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/middleware"
	"github.com/flicko-org/flicko/services/shared/auth"
	"github.com/flicko-org/flicko/services/shared/ratelimit"
	flickoredis "github.com/flicko-org/flicko/services/shared/redis"
)

// RouterDeps holds all dependencies needed to build the chi router.
type RouterDeps struct {
	Message *MessageHandler
	Channel *ChannelHandler
	Guild   *GuildHandler
	Upload  *UploadHandler
	Health  *HealthHandler
	Poll    *PollHandler
	Search  *SearchHandler
	Voice   *VoiceHandler

	KeySet      *auth.KeySet
	RateLimiter *ratelimit.Composite
	Idempotency *flickoredis.IdempotencyStore

	IdempotencyTTL time.Duration
	Log            *zap.Logger
}

// NewRouter builds the chi router with all routes and middleware.
//
// Middleware chain (outer → inner):
//
//	RequestID → Logger → Recovery → CORS → Auth (skip /healthz) → RateLimit
//
// Idempotency is applied per-route on POST endpoints.
func NewRouter(deps RouterDeps) *chi.Mux {
	r := chi.NewRouter()

	// ── Global middleware ────────────────────────────────────
	r.Use(middleware.RequestID)
	r.Use(middleware.Logger(deps.Log))
	r.Use(middleware.Recovery(deps.Log))
	r.Use(middleware.CORS(middleware.DefaultCORSConfig()))

	// ── Public routes (no auth) ─────────────────────────────
	r.Get("/healthz", deps.Health.Healthz)

	// ── Authenticated routes ────────────────────────────────
	r.Group(func(r chi.Router) {
		r.Use(auth.AuthMiddleware(deps.KeySet))

		// Default: 50 req/sec per user (general API tier).
		rlGeneral := middleware.DefaultRateLimitConfig()
		r.Use(middleware.RateLimit(deps.RateLimiter, rlGeneral, deps.Log))

		idempotencyMW := middleware.Idempotency(
			deps.Idempotency.Client(),
			middleware.IdempotencyConfig{TTL: deps.IdempotencyTTL},
			deps.Log,
		)

		// Per-route tiers layered on top of the general tier.
		msgRL := middleware.RateLimit(deps.RateLimiter, middleware.MessageCreateRateLimitConfig(), deps.Log)
		uploadRL := middleware.RateLimit(deps.RateLimiter, middleware.UploadRateLimitConfig(), deps.Log)
		guildJoinRL := middleware.RateLimit(deps.RateLimiter, middleware.GuildJoinRateLimitConfig(), deps.Log)

		// ── Messages ────────────────────────────────────
		r.Route("/v1/channels/{channelID}", func(r chi.Router) {
			r.With(idempotencyMW, msgRL).Post("/messages", deps.Message.CreateMessage)
			r.Get("/messages", deps.Message.GetMessages)

			// ── Search ──────────────────────────────────
			if deps.Search != nil {
				r.Get("/messages/search", deps.Search.Search)
			}

			// ── Uploads ─────────────────────────────────
			r.With(idempotencyMW, uploadRL).Post("/upload/presign", deps.Upload.Presign)

			// ── Polls ───────────────────────────────────
			if deps.Poll != nil {
				r.With(idempotencyMW).Post("/polls", deps.Poll.CreatePoll)
			}

			// ── Channel CRUD ────────────────────────────
			r.Patch("/", deps.Channel.UpdateChannel)
			r.Delete("/", deps.Channel.DeleteChannel)
		})

		r.Route("/v1/messages/{messageID}", func(r chi.Router) {
			r.Patch("/", deps.Message.EditMessage)
			r.Delete("/", deps.Message.DeleteMessage)
		})

		// ── Polls ───────────────────────────────────────
		if deps.Poll != nil {
			r.Route("/v1/polls/{pollID}", func(r chi.Router) {
				r.Get("/", deps.Poll.GetPoll)
				r.With(idempotencyMW).Post("/vote", deps.Poll.Vote)
				r.Delete("/vote", deps.Poll.Unvote)
				r.Post("/end", deps.Poll.EndPoll)
			})
		}

		// ── Voice ───────────────────────────────────────
		if deps.Voice != nil {
			r.Post("/v1/voice/token", deps.Voice.GenerateToken)
		}

		// ── Guilds + Channels + Members ─────────────────
		r.With(idempotencyMW).Post("/v1/guilds", deps.Guild.CreateGuild)
		r.Get("/v1/guilds/{guildID}", deps.Guild.GetGuild)
		r.Get("/v1/users/@me/guilds", deps.Guild.GetMyGuilds)

		r.Route("/v1/guilds/{guildID}", func(r chi.Router) {
			r.With(idempotencyMW).Post("/channels", deps.Channel.CreateChannel)
			r.Get("/channels", deps.Channel.ListChannels)

			r.With(idempotencyMW, guildJoinRL).Post("/members", deps.Guild.JoinGuild)
			r.Delete("/members/{userID}", deps.Guild.LeaveGuild)
			r.Get("/members", deps.Guild.ListMembers)
		})
	})

	return r
}
