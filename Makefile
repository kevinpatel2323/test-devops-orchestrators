# Makefile for Swap Optimizer Orchestrator Docker operations

# Variables
DOCKER_COMPOSE = docker-compose
DOCKER = docker
PROJECT_NAME = swap-optimizer
PROD_IMAGE = $(PROJECT_NAME):production
DEV_IMAGE = $(PROJECT_NAME):development

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[0;33m
NC = \033[0m # No Color

.PHONY: help
help: ## Show this help message
	@echo "$(GREEN)Swap Optimizer Orchestrator - Docker Commands$(NC)"
	@echo ""
	@echo "Available commands:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(YELLOW)%-20s$(NC) %s\n", $$1, $$2}'
	@echo ""
	@echo "$(GREEN)Quick Start:$(NC)"
	@echo "  make build          # Build Docker images"
	@echo "  make up             # Start production container"
	@echo "  make dev            # Start development container"
	@echo "  make logs           # View logs"

# Build commands
.PHONY: build
build: ## Build production Docker image
	@echo "$(GREEN)Building production Docker image...$(NC)"
	$(DOCKER_COMPOSE) build orchestrator

.PHONY: build-dev
build-dev: ## Build development Docker image
	@echo "$(GREEN)Building development Docker image...$(NC)"
	$(DOCKER_COMPOSE) build orchestrator-dev

.PHONY: build-all
build-all: ## Build all Docker images
	@echo "$(GREEN)Building all Docker images...$(NC)"
	$(DOCKER_COMPOSE) build

.PHONY: build-no-cache
build-no-cache: ## Build without cache
	@echo "$(GREEN)Building without cache...$(NC)"
	$(DOCKER_COMPOSE) build --no-cache

# Run commands
.PHONY: up
up: ## Start production container in background
	@echo "$(GREEN)Starting production container...$(NC)"
	$(DOCKER_COMPOSE) up -d orchestrator
	@echo "$(GREEN)Production container started!$(NC)"
	@echo "Access the application at: http://localhost:3000"
	@echo "Health check: http://localhost:3000/healthz"
	@echo "Readiness: http://localhost:3000/readyz"

.PHONY: up-build
up-build: ## Build and start production container
	@echo "$(GREEN)Building and starting production container...$(NC)"
	$(DOCKER_COMPOSE) up -d --build orchestrator

.PHONY: dev
dev: ## Start development container with live reload
	@echo "$(GREEN)Starting development container...$(NC)"
	$(DOCKER_COMPOSE) --profile dev up orchestrator-dev

.PHONY: dev-build
dev-build: ## Build and start development container
	@echo "$(GREEN)Building and starting development container...$(NC)"
	$(DOCKER_COMPOSE) --profile dev up --build orchestrator-dev

.PHONY: down
down: ## Stop and remove containers
	@echo "$(YELLOW)Stopping containers...$(NC)"
	$(DOCKER_COMPOSE) down

.PHONY: down-all
down-all: ## Stop and remove containers, networks, volumes
	@echo "$(RED)Stopping and removing everything...$(NC)"
	$(DOCKER_COMPOSE) down -v

# Monitoring commands
.PHONY: monitoring
monitoring: ## Start monitoring stack (Prometheus, Grafana, Loki)
	@echo "$(GREEN)Starting monitoring stack...$(NC)"
	$(DOCKER_COMPOSE) --profile monitoring up -d
	@echo "$(GREEN)Monitoring stack started!$(NC)"
	@echo "Prometheus: http://localhost:9090"
	@echo "Grafana: http://localhost:3002 (admin/admin)"
	@echo "Loki: http://localhost:3100"

.PHONY: monitoring-down
monitoring-down: ## Stop monitoring stack
	@echo "$(YELLOW)Stopping monitoring stack...$(NC)"
	$(DOCKER_COMPOSE) --profile monitoring down

# Log commands
.PHONY: logs
logs: ## Show container logs
	$(DOCKER_COMPOSE) logs -f orchestrator

.PHONY: logs-dev
logs-dev: ## Show development container logs
	$(DOCKER_COMPOSE) logs -f orchestrator-dev

.PHONY: logs-tail
logs-tail: ## Show last 100 lines of logs
	$(DOCKER_COMPOSE) logs --tail=100 orchestrator

# Shell commands
.PHONY: shell
shell: ## Open shell in production container
	@echo "$(GREEN)Opening shell in production container...$(NC)"
	$(DOCKER_COMPOSE) exec orchestrator /bin/sh

.PHONY: shell-dev
shell-dev: ## Open shell in development container
	@echo "$(GREEN)Opening shell in development container...$(NC)"
	$(DOCKER_COMPOSE) exec orchestrator-dev /bin/bash

.PHONY: shell-root
shell-root: ## Open root shell in production container
	@echo "$(YELLOW)Opening root shell in production container...$(NC)"
	$(DOCKER_COMPOSE) exec -u root orchestrator /bin/sh

# Health check commands
.PHONY: health
health: ## Check application health
	@echo "$(GREEN)Checking application health...$(NC)"
	@curl -s http://localhost:3000/healthz | jq '.' || echo "$(RED)Health check failed$(NC)"

.PHONY: ready
ready: ## Check application readiness
	@echo "$(GREEN)Checking application readiness...$(NC)"
	@curl -s http://localhost:3000/readyz | jq '.' || echo "$(RED)Readiness check failed$(NC)"

# Utility commands
.PHONY: ps
ps: ## List running containers
	$(DOCKER_COMPOSE) ps

.PHONY: stats
stats: ## Show container resource usage
	$(DOCKER) stats --no-stream $$($(DOCKER_COMPOSE) ps -q)

.PHONY: clean
clean: ## Clean up stopped containers and unused images
	@echo "$(YELLOW)Cleaning up Docker resources...$(NC)"
	$(DOCKER) system prune -f

.PHONY: clean-all
clean-all: ## Deep clean including volumes
	@echo "$(RED)Deep cleaning Docker resources...$(NC)"
	$(DOCKER) system prune -af --volumes

.PHONY: restart
restart: ## Restart containers
	@echo "$(YELLOW)Restarting containers...$(NC)"
	$(DOCKER_COMPOSE) restart

.PHONY: rebuild
rebuild: down build up ## Complete rebuild and restart
	@echo "$(GREEN)Rebuild complete!$(NC)"

# Testing commands
.PHONY: test
test: ## Run tests in container
	@echo "$(GREEN)Running tests...$(NC)"
	$(DOCKER_COMPOSE) exec orchestrator npm test

.PHONY: test-build
test-build: ## Build and run tests
	@echo "$(GREEN)Building and running tests...$(NC)"
	$(DOCKER_COMPOSE) run --rm orchestrator npm test

# Docker image commands
.PHONY: push
push: ## Push images to registry
	@echo "$(GREEN)Pushing images to registry...$(NC)"
	$(DOCKER) push $(PROD_IMAGE)
	$(DOCKER) push $(DEV_IMAGE)

.PHONY: pull
pull: ## Pull latest images
	@echo "$(GREEN)Pulling latest images...$(NC)"
	$(DOCKER_COMPOSE) pull

# Environment commands
.PHONY: env-create
env-create: ## Create .env file from example
	@if [ ! -f .env ]; then \
		cp .env.example .env; \
		echo "$(GREEN).env file created from .env.example$(NC)"; \
		echo "$(YELLOW)Please update INFURA_URL in .env file$(NC)"; \
	else \
		echo "$(YELLOW).env file already exists$(NC)"; \
	fi

.PHONY: validate
validate: ## Validate docker-compose configuration
	@echo "$(GREEN)Validating docker-compose configuration...$(NC)"
	$(DOCKER_COMPOSE) config

# Quick commands
.PHONY: quick-start
quick-start: env-create build up health ## Quick start for first time setup
	@echo "$(GREEN)Quick start complete!$(NC)"

.PHONY: dev-start
dev-start: env-create build-dev dev ## Quick start for development
	@echo "$(GREEN)Development environment ready!$(NC)"

# Default target
.DEFAULT_GOAL := help
