# Quick Reference Card

Fast lookup for common commands and configurations.

## 🎯 Common Commands

### Docker Compose
```bash
# Start everything
docker compose up -d

# View logs
docker compose logs -f rag-pipeline

# Stop everything (keep data)
docker compose down

# Stop and delete data
docker compose down -v

# Restart
docker compose restart rag-pipeline

# Shell access
docker compose exec rag-pipeline bash

# Show running containers
docker compose ps

# View resource usage
docker stats
```

### Make Commands
```bash
make help           # Show all commands
make up             # Start services
make down           # Stop services
make logs           # View logs
make restart        # Restart
make shell          # Open shell
make build          # Build image
make clean          # Remove everything
make health         # Check health
```

### Kubernetes
```bash
# Deploy
kubectl apply -f k8s-deployment.yaml

# Check status
kubectl get pods -n rag-pipeline
kubectl rollout status deployment/rag-pipeline -n rag-pipeline

# View logs
kubectl logs -f deployment/rag-pipeline -n rag-pipeline

# Port forward
kubectl port-forward svc/rag-pipeline-service 8501:80 -n rag-pipeline

# Scale
kubectl scale deployment rag-pipeline --replicas=3 -n rag-pipeline

# Get service IP
kubectl get svc -n rag-pipeline
```

### Ollama
```bash
# Start Ollama service
docker compose --profile ollama up -d

# List models
docker compose exec ollama ollama ls

# Download model
docker compose exec ollama ollama pull mistral

# Remove model
docker compose exec ollama ollama rm mistral

# Check status
curl http://localhost:11434/api/tags
```

### vLLM
```bash
# Start vLLM (needs GPU)
docker compose --profile vllm up -d

# Check GPU usage
nvidia-smi

# View model loading progress
docker compose logs -f vllm

# Check API status
curl http://localhost:8000/v1/models
```

---

## 🔧 Configuration Cheat Sheet

### .env File Template

```env
# ============================================================================
# LLM Provider Selection
# ============================================================================
LLM_PROVIDER=auto  # or: gemini, ollama, vllm

# ============================================================================
# Gemini Configuration
# ============================================================================
GEMINI_API_KEY=sk-...
GEMINI_MODEL=gemini-2.0-flash

# ============================================================================
# Ollama Configuration
# ============================================================================
OLLAMA_BASE_URL=http://ollama:11434
OLLAMA_MODEL=mistral
OLLAMA_TEMPERATURE=0.7

# ============================================================================
# vLLM Configuration
# ============================================================================
VLLM_BASE_URL=http://vllm:8000/v1
VLLM_API_KEY=not-needed
VLLM_MODEL=meta-llama/Llama-2-7b-chat-hf
VLLM_MAX_TOKENS=2048
VLLM_TEMPERATURE=0.7

# ============================================================================
# Streamlit Settings
# ============================================================================
STREAMLIT_SERVER_PORT=8501
STREAMLIT_SERVER_ADDRESS=0.0.0.0
STREAMLIT_SERVER_HEADLESS=true
```

---

## 🚀 Deployment Checklist

### Before Going Live
- [ ] Test locally: `docker compose up -d`
- [ ] Upload test PDF
- [ ] Ask test question
- [ ] Verify responses
- [ ] Check logs: `docker compose logs`
- [ ] Document setup

### For Cloud Deployment
- [ ] Choose platform (EC2/ECS/K8s)
- [ ] Configure security groups
- [ ] Set up load balancer (if needed)
- [ ] Configure monitoring
- [ ] Plan backup strategy
- [ ] Document architecture

### For Production
- [ ] Use specific image tags (not `:latest`)
- [ ] Enable HTTPS/TLS
- [ ] Set up log aggregation
- [ ] Configure alerts
- [ ] Plan disaster recovery
- [ ] Document runbooks

---

## 📊 Provider Selection Matrix

**Choose Based On:**

| If You Want | Choose | Why |
|------------|--------|-----|
| Easiest setup | Gemini | 30 seconds, no hardware |
| Best Arabic | Gemini | Excellent multilingual support |
| Zero cost | Ollama | Free software, no API |
| Privacy/offline | Ollama or vLLM | All processing local |
| Speed | vLLM | GPU acceleration |
| Production ready | vLLM or Gemini | Mature, scalable |
| Managed service | Gemini | No ops needed |
| Self-hosted | Ollama or vLLM | Full control |

---

## 🔌 Port Mapping

| Service | Port | URL | Access |
|---------|------|-----|--------|
| Streamlit | 8501 | http://localhost:8501 | Web UI |
| Ollama | 11434 | http://localhost:11434/api | Local only |
| vLLM | 8000 | http://localhost:8000/v1 | Local only |
| Prometheus | 9090 | http://localhost:9090 | Monitoring |

---

## 🆘 Troubleshooting Quick Fixes

### "Can't connect to http://localhost:8501"
```bash
# Check if running
docker compose ps

# Check logs
docker compose logs rag-pipeline

# Restart
docker compose restart
```

### "Provider not available"
```bash
# Check Gemini API key
grep GEMINI_API_KEY .env

# Check Ollama
curl http://localhost:11434/api/tags

# Check vLLM
curl http://localhost:8000/v1/models

# View provider detection
docker compose logs | grep "مزود"
```

### "Out of memory"
```bash
# Check Docker memory
docker stats

# For macOS/Windows: Docker Desktop → Preferences → Resources

# For Linux: Update docker-compose limits
# Edit docker-compose.yml, increase memory in deploy section
```

### "Model failed to download"
```bash
# For Ollama
docker compose exec ollama ollama pull mistral

# Check disk space
docker system df

# Clean up
docker system prune -a
```

---

## 📈 Performance Metrics

### Response Times
- **Gemini**: 1-2 seconds
- **Ollama (CPU)**: 15-30 seconds
- **vLLM (GPU)**: 2-3 seconds

### Memory Usage
- **Main app**: 1-2 GB
- **Ollama**: 8-16 GB
- **vLLM**: 8-16 GB

### Disk Usage
- **Docker image**: 1.2 GB
- **Ollama model**: 4-13 GB
- **ChromaDB data**: Grows with PDFs

---

## 🔐 Security Checklist

- [ ] API keys in .env (not committed to git)
- [ ] .env added to .gitignore
- [ ] Using non-root user in container
- [ ] Health checks enabled
- [ ] Firewall configured for ports
- [ ] HTTPS/TLS for production
- [ ] Secrets in AWS Secrets Manager (production)
- [ ] Network policies configured (K8s)

---

## 📚 Documentation Map

| Task | Document |
|------|----------|
| First time setup | LLM_QUICK_START.md |
| Understand project | SESSION_SUMMARY.md |
| Deploy to production | LLM_DEPLOYMENT.md |
| Compare providers | LLM_PROVIDERS.md |
| Docker details | DOCKER_DEPLOYMENT.md |
| Troubleshoot | LLM_PROVIDERS.md § Troubleshooting |
| Provider specs | LLM_PROVIDERS.md |
| All files listed | FILE_INVENTORY.md |

---

## 🎯 Setup Time Estimates

| Scenario | Time | Difficulty |
|----------|------|-----------|
| Gemini local | 5 min | Easy |
| Ollama local | 15 min | Medium |
| vLLM local | 20 min | Medium |
| EC2 deployment | 30 min | Medium |
| ECS deployment | 1 hour | Hard |
| Kubernetes | 2 hours | Hard |

---

## 💰 Cost Estimates (Monthly)

| Option | Cost | Details |
|--------|------|---------|
| Gemini only | $5-20 | API usage based |
| Ollama only | $0 | Server hardware only |
| vLLM on AWS | $400 | g4dn.xlarge GPU instance |
| Kubernetes | $500+ | Depends on cluster |

---

## 🚀 First 5 Minutes

```bash
# 1. Get into project folder
cd claude

# 2. Copy environment template
cp .env.example .env

# 3. For Gemini only (edit and add key)
nano .env
# Add: GEMINI_API_KEY=sk-...

# 4. Start
docker compose up -d

# 5. Open browser
# http://localhost:8501
```

---

## 📱 Common URLs

| Service | URL | Purpose |
|---------|-----|---------|
| App | http://localhost:8501 | Main interface |
| Ollama API | http://localhost:11434 | Local LLM |
| vLLM API | http://localhost:8000/v1 | Local LLM |
| Prometheus | http://localhost:9090 | Metrics |

---

## 🔄 Provider Switching

```bash
# 1. Update .env
echo "LLM_PROVIDER=ollama" > .env

# 2. Restart
docker compose restart rag-pipeline

# 3. Done! No rebuilds needed
```

---

## 🐛 Debug Commands

```bash
# Full logs with timestamps
docker compose logs --timestamps rag-pipeline

# Last 100 lines
docker compose logs --tail 100

# Follow new logs
docker compose logs -f

# Check environment variables
docker compose exec rag-pipeline env | grep -i llm

# Health check
docker exec rag-pipeline curl http://localhost:8501/_stcore/health

# Docker resource usage
docker stats

# Network inspection
docker network ls
docker network inspect claude_rag-network
```

---

## 📋 Version Information

Check what you're running:

```bash
# Docker version
docker --version

# Docker Compose version
docker compose version

# Python in container
docker compose exec rag-pipeline python --version

# Installed packages
docker compose exec rag-pipeline pip list | grep -E "(streamlit|torch|vllm|ollama)"
```

---

**Print this page or bookmark for quick reference!**
