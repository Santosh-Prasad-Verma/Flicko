// Package main wires all dependencies and starts the mail gateway server.
// No business logic lives here — only component initialization, routing,
// and graceful shutdown orchestration.
package main

import (
	"context"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/go-chi/chi/v5"
	chimiddleware "github.com/go-chi/chi/v5/middleware"
	"github.com/go-chi/httprate"

	"github.com/flicko-org/mail-gateway/internal/config"
	"github.com/flicko-org/mail-gateway/internal/handler"
	"github.com/flicko-org/mail-gateway/internal/mailer"
	"github.com/flicko-org/mail-gateway/internal/queue"
	"github.com/flicko-org/mail-gateway/internal/templates"
)

func main() {
	// ===== 1. LOAD CONFIGURATION =====
	cfg := config.Load()

	// ===== 2. SETUP STRUCTURED LOGGING =====
	setupLogger(cfg)

	slog.Info("starting Flicko Mail Gateway",
		"port", cfg.Port,
		"env", cfg.AppEnv,
		"app_name", cfg.AppName,
		"workers", cfg.WorkerPool,
		"queue_size", cfg.QueueSize,
	)

	// ===== 3. INITIALIZE TEMPLATE RENDERER =====
	renderer, err := templates.NewRenderer("templates")
	if err != nil {
		slog.Error("failed to initialize template renderer", "error", err)
		os.Exit(1)
	}

	// ===== 4. INITIALIZE MAILER =====
	var emailMailer mailer.Mailer
	if cfg.IsDevelopment() && os.Getenv("USE_MOCK_MAILER") == "true" {
		slog.Warn("using MockMailer — emails will NOT be sent (development mode)")
		emailMailer = mailer.NewMockMailer()
	} else {
		emailMailer = mailer.NewSMTPMailer(
			cfg.SMTPHost,
			cfg.SMTPPort,
			cfg.SMTPUsername,
			cfg.SMTPPassword,
			cfg.SMTPFrom,
			renderer,
		)
	}

	// ===== 5. INITIALIZE EMAIL QUEUE =====
	emailQueue := queue.NewEmailQueue(cfg.QueueSize)

	// ===== 6. INITIALIZE WORKER POOL =====
	workerPool := queue.NewWorkerPool(emailQueue, emailMailer, cfg.WorkerPool, cfg.MaxRetries)
	workerPool.Start()

	// ===== 7. INITIALIZE HANDLERS =====
	hookHandler := handler.NewHookHandler(cfg, emailQueue)
	healthHandler := handler.NewHealthHandler(emailQueue, cfg.WorkerPool)
	sendHandler := handler.NewSendHandler(cfg, emailQueue)

	// ===== 8. SETUP CHI ROUTER WITH MIDDLEWARE =====
	r := chi.NewRouter()

	// Global middleware stack: RequestID → RealIP → Logger → Recoverer
	r.Use(chimiddleware.RequestID)
	r.Use(chimiddleware.RealIP)
	r.Use(chimiddleware.Logger)
	r.Use(chimiddleware.Recoverer)

	// Routes
	r.Get("/health", healthHandler.HandleHealth)

	// Welcome email endpoint — frontend calls this after successful signup/login
	// Protected by x-api-key header (set SEND_API_KEY in .env)
	r.Post("/send", sendHandler.HandleSend)

	// Webhook endpoint with rate limiting: 60 req/min per IP
	r.Group(func(r chi.Router) {
		r.Use(httprate.LimitByIP(60, time.Minute))
		r.Post("/hooks/email", hookHandler.HandleEmail)
	})

	// ===== 9. CREATE HTTP SERVER =====
	server := &http.Server{
		Addr:         ":" + cfg.Port,
		Handler:      r,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 10 * time.Second,
		IdleTimeout:  120 * time.Second,
	}

	// ===== 10. GRACEFUL SHUTDOWN =====
	// Listen for OS signals in a separate goroutine
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)

	// Start the server in a goroutine
	go func() {
		slog.Info("HTTP server listening",
			"addr", server.Addr,
			"health", fmt.Sprintf("http://localhost:%s/health", cfg.Port),
			"webhook", fmt.Sprintf("http://localhost:%s/hooks/email", cfg.Port),
		)
		if err := server.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			slog.Error("HTTP server error", "error", err)
			os.Exit(1)
		}
	}()

	// Block until we receive a shutdown signal
	sig := <-quit
	slog.Info("shutdown signal received", "signal", sig.String())

	// Create shutdown context with 10-second timeout
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()

	// Step 1: Stop accepting new HTTP requests
	slog.Info("shutting down HTTP server...")
	if err := server.Shutdown(ctx); err != nil {
		slog.Error("HTTP server shutdown error", "error", err)
	}

	// Step 2: Close the queue (no new jobs accepted)
	slog.Info("closing email queue...")
	emailQueue.Close()

	// Step 3: Wait for workers to drain remaining jobs
	slog.Info("waiting for workers to finish...")
	workerPool.Stop()

	slog.Info("Flicko Mail Gateway stopped gracefully ✅")
}

// setupLogger configures the global slog logger based on config settings.
func setupLogger(cfg *config.Config) {
	var level slog.Level
	switch cfg.LogLevel {
	case "debug":
		level = slog.LevelDebug
	case "warn":
		level = slog.LevelWarn
	case "error":
		level = slog.LevelError
	default:
		level = slog.LevelInfo
	}

	var h slog.Handler
	opts := &slog.HandlerOptions{Level: level}

	if cfg.LogFormat == "text" {
		h = slog.NewTextHandler(os.Stdout, opts)
	} else {
		h = slog.NewJSONHandler(os.Stdout, opts)
	}

	slog.SetDefault(slog.New(h))
}
