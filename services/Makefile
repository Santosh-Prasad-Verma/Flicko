# ============================================================
# Flicko Services — Monorepo Makefile
# ============================================================
#
# Usage:
#   make build          Build all service binaries
#   make test           Run all tests with race detector
#   make vet            Run go vet across all modules
#   make lint           Alias for vet (add staticcheck later)
#   make clean          Remove build artefacts
#   make docker-build   Build production Docker images
#   make help           Show this help
# ============================================================

SHELL   := /bin/bash -o pipefail
GO      := go
GOFLAGS := -trimpath -ldflags="-s -w"

# Service modules
SERVICES := ws-gateway msg-service
MODULES  := shared $(SERVICES)

# Output directory
BIN := ../bin

.PHONY: all build test vet lint clean docker-build help $(SERVICES)

## ── Default ──────────────────────────────────────────────
all: vet test build

## ── Build ────────────────────────────────────────────────
build: $(SERVICES) ## Build all service binaries

ws-gateway:
	@echo "→ building ws-gateway"
	@mkdir -p $(BIN)
	cd ws-gateway && $(GO) build $(GOFLAGS) -o ../$(BIN)/ws-gateway ./cmd/gateway

msg-service:
	@echo "→ building msg-service"
	@mkdir -p $(BIN)
	cd msg-service && $(GO) build $(GOFLAGS) -o ../$(BIN)/msg-service ./cmd/server

## ── Test ─────────────────────────────────────────────────
test: ## Run all tests with race detector
	@for mod in $(MODULES); do \
		echo "→ testing $$mod"; \
		cd $$mod && $(GO) test -race -count=1 ./... && cd ..; \
	done

## ── Vet / Lint ───────────────────────────────────────────
vet: ## Run go vet on all modules
	@for mod in $(MODULES); do \
		echo "→ vetting $$mod"; \
		cd $$mod && $(GO) vet ./... && cd ..; \
	done

lint: vet ## Alias (replace with staticcheck / golangci-lint later)

## ── Clean ────────────────────────────────────────────────
clean: ## Remove build artefacts
	rm -rf $(BIN)

## ── Docker ───────────────────────────────────────────────
docker-build: ## Build production Docker images
	docker build -f ws-gateway/Dockerfile.prod -t flicko/ws-gateway ..
	docker build -f msg-service/Dockerfile.prod -t flicko/msg-service ..

## ── Help ─────────────────────────────────────────────────
help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}'
