# Complete Guide - Arabic RAG Pipeline

Master guide combining everything you need to know about this project.

## 📖 Table of Contents

1. [What This Is](#what-this-is)
2. [What's Included](#whats-included)
3. [Quick Start](#quick-start)
4. [How It Works](#how-it-works)
5. [LLM Providers](#llm-providers)
6. [Deployment](#deployment)
7. [Operations](#operations)
8. [Troubleshooting](#troubleshooting)
9. [Reference](#reference)

---

## What This Is

**Arabic RAG Pipeline** (Lecture-Saver 3000) is a production-ready Retrieval-Augmented Generation application that:

- ✅ Accepts PDF uploads (lectures, documents)
- ✅ Indexes PDFs into a vector database
- ✅ Answers questions about uploaded content in Arabic
- ✅ Provides citations showing which documents the answers came from
- ✅ Maintains conversation history for follow-up questions
- ✅ Runs in Docker (Windows, Mac, Linux)
- ✅ Supports three LLM backends (Gemini, Ollama, vLLM)

**Perfect for**: Educational institutions, research teams, document-heavy workflows

---

## What's Included

### Application Code
- `rag_pipeline.py` - Main Streamlit application
- `llm_providers.py` - LLM provider abstraction (Gemini, Ollama, vLLM)

### Infrastructure
- `Dockerfile` - Container image (multi-stage, optimized)
- `docker-compose.yml` - Local development
- `docker-compose.prod.yml` - Production configuration
- `k8s-deployment.yaml` - Kubernetes manifests
- `ecs-task-definition.json` - AWS ECS configuration

### Automation Scripts
- `setup-first-time.sh` - Interactive first-time setup
- `health-check.sh` - Diagnose issues
- `backup-restore.sh` - Backup/restore data
- `deploy.sh` - Multi-environment deployment
- `Makefile` - Convenient commands

### Documentation (10 files, ~13,000 words)
- Quick starts, deployment guides, provider specs, troubleshooting

---

## Quick Start

### For Impatient People (5 minutes)

```bash
# 1. Choose your LLM provider:
# Option A: Google Gemini (easiest)
# Option B: Ollama (free)
# Option C: vLLM (fastest, needs GPU)

# 2. Setup (pick one option):

# Option A: Gemini
cp .env.example .env
# Edit .env, add GEMINI_API_KEY from https://aistudio.google.com/apikey
docker compose up -d

# Option B: Ollama
docker compose --profile ollama up -d
docker compose exec ollama ollama pull mistral
docker compose up -d

# Option C: vLLM (GPU required)
docker compose --profile vllm up -d
docker compose logs -f vllm  # Wait 3-5 min

# 3. Access
# Open: http://localhost:8501
```

### For Careful People (30 minutes)

1. Read [START_HERE.md](START_HERE.md)
2. Read [LLM_QUICK_START.md](LLM_QUICK_START.md)
3. Run `bash setup-first-time.sh`
4. Follow instructions

### For Thorough People (2 hours)

1. Read [SESSION_SUMMARY.md](SESSION_SUMMARY.md)
2. Read [LLM_PROVIDERS.md](LLM_PROVIDERS.md)
3. Read [DOCKER_SETUP.md](DOCKER_SETUP.md)
4. Run setup scripts
5. Test locally
6. Plan deployment

---

## How It Works

### Data Flow

```
User Uploads PDF
    ↓
1. PDF Extraction (pypdf + OCR fallback)
    ↓
2. Text Chunking (recursive, with overlap)
    ↓
3. Embedding & Indexing (ChromaDB + multilingual embeddings)
    ↓
4. User Asks Question
    ↓
5. Embedding Retrieval (find top 15 similar chunks)
    ↓
6. Cross-Encoder Reranking (rank by relevance)
    ↓
7. LLM Generation (using Gemini/Ollama/vLLM)
    ↓
8. Citation Processing (map answers to sources)
    ↓
Response with Citations
```

### Technology Stack

| Component | Technology | Purpose |
|-----------|-----------|---------|
| UI | Streamlit | Web interface (Arabic RTL) |
| Vector DB | ChromaDB | Persistent storage + similarity search |
| Embeddings | Sentence Transformers | Multilingual text embeddings |
| Reranker | Cross-Encoder | Improve retrieval quality |
| LLM | Gemini/Ollama/vLLM | Answer generation |
| PDF | pypdf + Tesseract | Extract text (handles OCR) |
| Container | Docker | Deployment anywhere |

### Architecture

```
┌─────────────────────────────────────────┐
│  Streamlit Web UI (port 8501)          │
│  - RTL Arabic interface                 │
│  - PDF upload sidebar                   │
│  - Chat interface                       │
└────────────┬────────────────────────────┘
             │
┌────────────▼────────────────────────────┐
│  RAG Pipeline Module                    │
│  - PDF extraction & chunking            │
│  - Embedding retrieval                  │
│  - Cross-encoder reranking              │
│  - Citation processing                  │
└────────────┬────────────────────────────┘
             │
        ┌────┴────┬──────────┬──────────┐
        │          │          │          │
    ┌───▼───┐  ┌──▼──┐  ┌───▼────┐ ┌──▼──┐
    │Gemini │  │Ollama  │  │vLLM  │ │    │
    │ API   │  │ Local  │  │ GPU  │ │    │
    └───────┘  └────────┘  └──────┘ └────┘
```

---

## LLM Providers

### Quick Comparison

| Aspect | Gemini | Ollama | vLLM |
|--------|--------|--------|------|
| **Setup Time** | 30 sec | 5 min | 10 min |
| **Cost** | $5-20/mo | $0/mo | $400/mo |
| **Speed** | 1-2s | 15-30s | 2-3s |
| **GPU** | ❌ | ❌ | ✅ |
| **Offline** | ❌ | ✅ | ✅ |
| **Arabic** | ✅✅✅ | ⚠️ | ✅ |
| **Best For** | Teams | Privacy | Production |

### Detailed Comparison

**Google Gemini**
- Easiest to start
- Excellent Arabic support
- Cloud-based (needs internet)
- Small free tier, then pay per use
- No infrastructure needed
- Best for quick testing & evaluation

**Ollama**
- Completely free
- Local processing (private)
- No API key needed
- Works offline
- Slow on CPU (15-30 seconds)
- Limited Arabic models
- Best for privacy-conscious workflows

**vLLM**
- Very fast (2-3 seconds)
- Requires NVIDIA GPU
- Complex setup
- Free software, GPU cost
- High throughput support
- Production-grade quality
- Best for high-volume use

### Switching Providers

```bash
# Update .env
echo "LLM_PROVIDER=ollama" > .env

# Restart (no rebuild needed!)
docker compose restart rag-pipeline

# Application automatically detects new provider
```

---

## Deployment

### Local (Docker Compose)

```bash
docker compose up -d
# Access: http://localhost:8501
```
- Development & testing
- Single developer
- Perfect for learning

### EC2 (AWS)

```bash
# t3.medium instance
curl https://get.docker.com | sh
git clone <repo>
docker compose up -d
```
- $40-70/month
- Manual scaling
- Good for small workloads

### ECS (AWS)

```bash
# Use ecs-task-definition.json
aws ecs register-task-definition --cli-input-json file://ecs-task-definition.json
aws ecs create-service ...
```
- Managed service
- Auto-scaling
- Load balancing

### Kubernetes

```bash
kubectl apply -f k8s-deployment.yaml
```
- Any cloud (AWS, GCP, Azure, on-premise)
- Auto-scaling
- Highest reliability
- Most complex

---

## Operations

### Common Tasks

#### Start services
```bash
docker compose up -d          # Start all
make up                       # Using Makefile
```

#### View logs
```bash
docker compose logs -f        # All services
docker compose logs -f rag-pipeline  # Specific service
make logs                     # Using Makefile
```

#### Restart
```bash
docker compose restart        # All services
docker compose restart rag-pipeline  # Specific service
make restart                  # Using Makefile
```

#### Stop (keep data)
```bash
docker compose down
make down
```

#### Stop and delete everything
```bash
docker compose down -v
make clean
```

#### Switch LLM provider
```bash
echo "LLM_PROVIDER=ollama" >> .env
docker compose restart rag-pipeline
```

#### Backup data
```bash
bash backup-restore.sh        # Choose backup option
```

#### Restore from backup
```bash
bash backup-restore.sh        # Choose restore option
```

#### Check health
```bash
bash health-check.sh
make health
```

### Monitoring

#### Resource usage
```bash
docker stats                  # Real-time metrics
docker compose ps             # Container status
```

#### Application health
```bash
curl http://localhost:8501/_stcore/health
```

#### Logs analysis
```bash
docker compose logs | grep ERROR
docker compose logs | grep WARNING
```

---

## Troubleshooting

### "Can't connect to localhost:8501"

**Check if running:**
```bash
docker compose ps
# Should show rag-pipeline as running
```

**Check logs:**
```bash
docker compose logs rag-pipeline
# Look for startup errors
```

**Restart:**
```bash
docker compose restart
```

### "Provider not available"

**For Gemini:**
```bash
grep GEMINI_API_KEY .env
# Should show a key starting with sk-
```

**For Ollama:**
```bash
curl http://localhost:11434/api/tags
# Should return JSON with model info
```

**For vLLM:**
```bash
curl http://localhost:8000/v1/models
# Should return JSON with model info
```

### "Out of memory"

**Check Docker memory:**
```bash
docker stats
```

**Fix (Mac/Windows):**
- Docker Desktop → Preferences → Resources
- Increase allocated memory

**Fix (Linux):**
- Edit `docker-compose.yml`
- Add memory limit under deploy section
- Restart

### "Model failed to download"

**For Ollama:**
```bash
docker compose exec ollama ollama pull mistral
```

**For vLLM:**
- Check GPU memory: `nvidia-smi`
- Try smaller model
- Check internet connection

### "Disk full"

**Check usage:**
```bash
docker system df
du -sh streamlit_chroma_db/
```

**Clean up:**
```bash
docker system prune -a
docker volume prune
```

---

## Reference

### Documentation Map

| Need | Document | Words |
|------|----------|-------|
| Overview | SESSION_SUMMARY.md | 4,000 |
| Entry point | START_HERE.md | 1,500 |
| Quick start | LLM_QUICK_START.md | 1,500 |
| Docker | DOCKER_SETUP.md | 2,000 |
| Deployment | DOCKER_DEPLOYMENT.md | 3,000 |
| Providers | LLM_PROVIDERS.md | 3,500 |
| Production | LLM_DEPLOYMENT.md | 3,000 |
| Implementation | LLM_CHANGELOG.md | 2,500 |
| Files | FILE_INVENTORY.md | 1,500 |
| Commands | QUICK_REFERENCE.md | 1,500 |
| This guide | COMPLETE_GUIDE.md | 3,000 |

### Script Reference

| Script | Purpose | Time |
|--------|---------|------|
| setup-first-time.sh | Interactive setup | 5 min |
| health-check.sh | Diagnose issues | 1 min |
| backup-restore.sh | Backup/restore data | 5 min |
| deploy.sh | Deploy to cloud | 30 min |
| Makefile | Quick commands | - |

### Key Files

| File | Purpose |
|------|---------|
| rag_pipeline.py | Main application |
| llm_providers.py | LLM abstraction |
| Dockerfile | Container image |
| docker-compose.yml | Local development |
| docker-compose.prod.yml | Production setup |
| k8s-deployment.yaml | Kubernetes |
| .env.example | Configuration template |

### Common Commands

```bash
# Development
docker compose up -d              # Start
docker compose logs -f            # View logs
docker compose restart            # Restart
docker compose down               # Stop

# Using Makefile
make up                          # Start
make logs                        # View logs
make restart                     # Restart
make down                        # Stop
make help                        # Show all

# Maintenance
bash health-check.sh             # Check health
bash backup-restore.sh           # Backup/restore
docker stats                     # Monitor resources

# Provider management
echo "LLM_PROVIDER=ollama" >> .env
docker compose restart rag-pipeline

# Cleanup
docker compose down -v           # Remove all
docker system prune -a           # Clean docker
```

### Ports

| Service | Port | URL |
|---------|------|-----|
| Streamlit | 8501 | http://localhost:8501 |
| Ollama | 11434 | http://localhost:11434 |
| vLLM | 8000 | http://localhost:8000/v1 |

### Environment Variables

**Core**:
```env
LLM_PROVIDER=auto              # auto, gemini, ollama, vllm
```

**Gemini**:
```env
GEMINI_API_KEY=sk-...
GEMINI_MODEL=gemini-2.0-flash
```

**Ollama**:
```env
OLLAMA_BASE_URL=http://ollama:11434
OLLAMA_MODEL=mistral
```

**vLLM**:
```env
VLLM_BASE_URL=http://vllm:8000/v1
VLLM_MODEL=meta-llama/Llama-2-7b-chat-hf
```

---

## Tips & Tricks

### Local Development
- Use `make` for quick commands
- Keep `.env` file locally (don't commit)
- Each developer creates own `.env`
- Data persists in Docker volumes

### Production Deployment
- Use specific image tags (not `:latest`)
- Enable HTTPS/TLS
- Use AWS Secrets Manager for API keys
- Set up monitoring
- Plan backup strategy

### Performance
- Use vLLM for production (GPU)
- Use Gemini for teams (managed)
- Use Ollama for privacy (local)

### Scaling
- Kubernetes for multi-server
- Load balancer for traffic distribution
- Horizontal Pod Autoscaling in K8s
- ECS for AWS-only deployments

### Cost Optimization
- Free tier: Gemini (free tier limited)
- Low cost: Ollama (one-time hardware)
- Production: vLLM (GPU cost) or Gemini API

---

## Getting Help

1. **Not working?** → Run `bash health-check.sh`
2. **Stuck on setup?** → Read `LLM_QUICK_START.md`
3. **Need deployment help?** → Read `LLM_DEPLOYMENT.md`
4. **Want to understand code?** → Read `LLM_CHANGELOG.md`
5. **Need a command?** → See `QUICK_REFERENCE.md`

---

## File Organization

Keep organized with this folder structure:
```
claude/
├── 📄 Application files (rag_pipeline.py, etc.)
├── 🐳 Docker files (Dockerfile, docker-compose.yml, etc.)
├── 🚀 Scripts (setup-first-time.sh, deploy.sh, etc.)
├── 📚 Documentation (*.md files)
├── ⚙️ Config (.env.example, Makefile, etc.)
└── 📦 Data directories (streamlit_chroma_db/, backups/, etc.)
```

---

## Next Steps

### First Time
1. Read [START_HERE.md](START_HERE.md)
2. Choose LLM provider
3. Run setup script or follow [LLM_QUICK_START.md](LLM_QUICK_START.md)
4. Start using at http://localhost:8501

### For Production
1. Read [LLM_DEPLOYMENT.md](LLM_DEPLOYMENT.md)
2. Choose deployment platform
3. Follow platform-specific guide
4. Set up monitoring
5. Plan backup/recovery

### For Teams
1. Share [START_HERE.md](START_HERE.md)
2. Each developer follows setup
3. Share `.env.example` (not `.env`)
4. Each creates own `.env` with API key
5. Data persists in volumes

---

## Summary

**What you have**: Production-ready RAG pipeline with multi-provider LLM support

**What you can do**: Upload PDFs, index them, ask questions, get citations

**Where to start**: [START_HERE.md](START_HERE.md)

**How long**: 5-30 minutes to first working system

**How scalable**: From laptop to Kubernetes clusters

**How much it costs**: Free (Ollama) to $400/month (vLLM with GPU)

---

**Questions? Check the documentation files above or run the diagnostic scripts!**

**Ready to start? Open [START_HERE.md](START_HERE.md) now!**

---

**Version**: 1.0  
**Status**: ✅ Production Ready  
**Last Updated**: 2026-08-18
