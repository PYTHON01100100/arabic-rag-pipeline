.PHONY: help build up down logs clean restart test deploy push

# Colors
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m # No Color

COMPOSE := docker compose
DOCKER := docker

help:
	@echo "$(GREEN)Arabic RAG Pipeline - Docker Commands$(NC)"
	@echo ""
	@echo "$(YELLOW)Development:$(NC)"
	@echo "  make up              - Start development environment"
	@echo "  make down            - Stop containers (keep data)"
	@echo "  make down-clean      - Stop containers (delete all data)"
	@echo "  make logs            - View container logs (tail -f)"
	@echo "  make restart         - Restart containers"
	@echo "  make shell           - Open shell in container"
	@echo ""
	@echo "$(YELLOW)Building:$(NC)"
	@echo "  make build           - Build Docker image locally"
	@echo "  make build-prod      - Build optimized production image"
	@echo ""
	@echo "$(YELLOW)Deployment:$(NC)"
	@echo "  make deploy          - Interactive deployment helper"
	@echo "  make push            - Push image to registry"
	@echo "  make k8s-deploy      - Deploy to Kubernetes"
	@echo ""
	@echo "$(YELLOW)Maintenance:$(NC)"
	@echo "  make clean           - Remove containers & images"
	@echo "  make test            - Test Docker image"
	@echo "  make health          - Check container health"
	@echo ""

# Development targets
up:
	@echo "$(GREEN)Starting development environment...$(NC)"
	@if [ ! -f .env ]; then cp .env.example .env; echo "Created .env from template"; fi
	$(COMPOSE) up -d
	@echo "$(GREEN)✓ Service starting at http://localhost:8501$(NC)"

down:
	@echo "$(GREEN)Stopping containers...$(NC)"
	$(COMPOSE) down
	@echo "$(GREEN)✓ Stopped (data persisted)$(NC)"

down-clean:
	@echo "$(YELLOW)⚠ Removing containers and data...$(NC)"
	$(COMPOSE) down -v
	@echo "$(GREEN)✓ Cleaned up$(NC)"

logs:
	$(COMPOSE) logs -f rag-pipeline

restart:
	@echo "$(GREEN)Restarting services...$(NC)"
	$(COMPOSE) restart
	@echo "$(GREEN)✓ Restarted$(NC)"

shell:
	@echo "$(GREEN)Opening shell in container...$(NC)"
	$(COMPOSE) exec rag-pipeline bash

health:
	@echo "$(GREEN)Checking container health...$(NC)"
	@$(DOCKER) compose ps
	@echo ""
	@curl -s http://localhost:8501/_stcore/health > /dev/null && echo "$(GREEN)✓ Service is healthy$(NC)" || echo "$(YELLOW)✗ Service not responding$(NC)"

# Build targets
build:
	@echo "$(GREEN)Building Docker image...$(NC)"
	$(DOCKER) build -t rag-pipeline:latest .
	@echo "$(GREEN)✓ Build complete: rag-pipeline:latest$(NC)"

build-prod:
	@echo "$(GREEN)Building optimized production image...$(NC)"
	$(DOCKER) build \
		--build-arg BUILDKIT_INLINE_CACHE=1 \
		-t rag-pipeline:$(shell git rev-parse --short HEAD) \
		-t rag-pipeline:latest \
		.
	@echo "$(GREEN)✓ Production build complete$(NC)"

# Testing
test: build
	@echo "$(GREEN)Testing Docker image...$(NC)"
	@$(DOCKER) run --rm -it \
		-e GEMINI_API_KEY=test \
		-p 8501:8501 \
		rag-pipeline:latest \
		streamlit run rag_pipeline.py --logger.level=info & \
		TEST_PID=$$!; \
		sleep 10; \
		if curl -s http://localhost:8501/_stcore/health > /dev/null; then \
			echo "$(GREEN)✓ Container health check passed$(NC)"; \
			kill $$TEST_PID 2>/dev/null || true; \
		else \
			echo "$(YELLOW)✗ Health check failed$(NC)"; \
			kill $$TEST_PID 2>/dev/null || true; \
		fi

# Deployment targets
deploy:
	@bash deploy.sh

push:
	@echo "$(YELLOW)Enter image name (e.g., docker.io/username/rag-pipeline):$(NC)"
	@read REGISTRY; \
	echo "$(GREEN)Tagging image for $$REGISTRY...$(NC)"; \
	$(DOCKER) tag rag-pipeline:latest $$REGISTRY:latest; \
	echo "$(GREEN)Pushing to registry...$(NC)"; \
	$(DOCKER) push $$REGISTRY:latest; \
	echo "$(GREEN)✓ Push complete$(NC)"

k8s-deploy:
	@echo "$(GREEN)Deploying to Kubernetes...$(NC)"
	@echo "$(YELLOW)Ensure you've updated the image URI in k8s-deployment.yaml$(NC)"
	kubectl apply -f k8s-deployment.yaml
	@echo "$(GREEN)✓ Deployment submitted$(NC)"
	@echo "Check status with: kubectl rollout status deployment/rag-pipeline -n rag-pipeline"

# Maintenance targets
clean:
	@echo "$(YELLOW)⚠ Removing all containers and images...$(NC)"
	$(COMPOSE) down -v
	$(DOCKER) rmi rag-pipeline:latest 2>/dev/null || true
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

# Development helpers
env:
	@if [ ! -f .env ]; then \
		echo "$(GREEN)Creating .env from template...$(NC)"; \
		cp .env.example .env; \
		echo "$(YELLOW)⚠ Please edit .env and add your GEMINI_API_KEY$(NC)"; \
	else \
		echo "$(GREEN).env already exists$(NC)"; \
	fi

validate:
	@echo "$(GREEN)Validating Docker setup...$(NC)"
	@docker --version && echo "$(GREEN)✓ Docker OK$(NC)" || echo "$(YELLOW)✗ Docker not found$(NC)"
	@docker compose version && echo "$(GREEN)✓ Docker Compose OK$(NC)" || echo "$(YELLOW)✗ Docker Compose not found$(NC)"
	@[ -f .env ] && echo "$(GREEN)✓ .env file exists$(NC)" || echo "$(YELLOW)✗ .env file missing$(NC)"
	@grep -q "GEMINI_API_KEY" .env && echo "$(GREEN)✓ GEMINI_API_KEY set$(NC)" || echo "$(YELLOW)✗ GEMINI_API_KEY missing$(NC)"

# Info targets
status:
	@echo "$(GREEN)Docker Compose Status:$(NC)"
	$(COMPOSE) ps
	@echo ""
	@echo "$(GREEN)Volume Status:$(NC)"
	$(DOCKER) volume ls | grep rag-pipeline || echo "No volumes found"

version:
	@echo "$(GREEN)Component Versions:$(NC)"
	@$(DOCKER) --version
	@$(DOCKER) compose version
	@echo "Python: $$(python --version 2>&1)"
	@echo "Git commit: $$(git rev-parse --short HEAD 2>/dev/null || echo 'N/A')"

docs:
	@echo "$(GREEN)Documentation:$(NC)"
	@echo "  Quick Start: DOCKER_SETUP.md"
	@echo "  Deployment: DOCKER_DEPLOYMENT.md"
	@echo "  Summary: DOCKER_SUMMARY.md"
	@echo ""
	@echo "Opening DOCKER_SETUP.md..."
	@cat DOCKER_SETUP.md | head -50

# Default target
.DEFAULT_GOAL := help
