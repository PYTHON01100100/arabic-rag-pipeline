# Docker Setup - Arabic RAG Pipeline

Complete Docker containerization setup for multi-developer environments and cloud deployment.

## 📋 What's Included

This setup includes everything needed to run the Arabic RAG Pipeline consistently across:
- **Local Development** - Docker Compose for team members
- **EC2** - Direct deployment on AWS EC2 instances
- **ECS** - AWS container orchestration
- **Kubernetes** - Any K8s cluster (EKS, GKE, self-hosted)

## 📦 Files Created

| File | Purpose |
|------|---------|
| `Dockerfile` | Production-grade multi-stage build |
| `docker-compose.yml` | Local development environment |
| `.dockerignore` | Optimize build context |
| `docker-entrypoint.sh` | Container initialization script |
| `k8s-deployment.yaml` | Kubernetes deployment manifests |
| `k8s-ingress.yaml` | Kubernetes ingress & network policies |
| `ecs-task-definition.json` | AWS ECS task definition |
| `.env.example` | Environment variables template |
| `DOCKER_DEPLOYMENT.md` | Comprehensive deployment guide |
| `deploy.sh` | Interactive deployment helper script |
| `DOCKER_SETUP.md` | This file |

## 🚀 Quick Start (5 minutes)

### 1️⃣ Prerequisites
```bash
# Install Docker & Docker Compose
# - Windows/Mac: Docker Desktop (includes Docker Compose)
# - Linux: docker.io + docker-compose

# Verify installation
docker --version
docker compose version
```

### 2️⃣ Get API Key
- Visit: https://aistudio.google.com/apikey
- Get a free Gemini API key

### 3️⃣ Setup Environment
```bash
# Copy environment template
cp .env.example .env

# Edit .env and add your GEMINI_API_KEY
nano .env  # or use your favorite editor
```

### 4️⃣ Start Development
```bash
# Start all services
docker compose up -d

# Wait 30 seconds for startup
sleep 30

# Open browser
open http://localhost:8501
# or visit: http://localhost:8501
```

### 5️⃣ Stop When Done
```bash
# Stop all containers (data persists)
docker compose down

# Stop and remove all data
docker compose down -v
```

## 📊 Container Architecture

```
┌─────────────────────────────────────────────────┐
│ Docker Compose (Local Development)              │
├─────────────────────────────────────────────────┤
│ ┌──────────────────────────────────────────┐   │
│ │ rag-pipeline Container                   │   │
│ ├──────────────────────────────────────────┤   │
│ │ • Python 3.12                            │   │
│ │ • Streamlit (port 8501)                  │   │
│ │ • ChromaDB (persistent)                  │   │
│ │ • Sentence Transformers                  │   │
│ │ • Tesseract OCR + Arabic lang pack       │   │
│ └──────────────────────────────────────────┘   │
│         ↓                    ↓                   │
│    ┌─────────────┐      ┌──────────────┐       │
│    │ chroma_db_  │      │ Environment  │       │
│    │ data volume │      │ Variables    │       │
│    │ (persists)  │      │ (.env file)  │       │
│    └─────────────┘      └──────────────┘       │
└─────────────────────────────────────────────────┘
```

## 🏗️ Dockerfile Highlights

### Multi-Stage Build
- **Builder Stage**: Compiles all dependencies into wheels
- **Runtime Stage**: Minimal image with only runtime deps
- **Result**: ~1.2GB (instead of 2.5GB+ single-stage)

### Security Features
- ✅ Non-root user (UID 1000: `appuser`)
- ✅ Read-only filesystem where applicable
- ✅ Dropped unnecessary capabilities
- ✅ No hardcoded secrets

### Production Ready
- ✅ Health checks configured
- ✅ Graceful shutdown (preStop hooks)
- ✅ Structured logging
- ✅ Resource limits

## 🔧 Common Commands

### Docker Compose (Local)
```bash
# Start services
docker compose up -d

# View logs
docker compose logs -f rag-pipeline

# Restart service
docker compose restart

# Stop without removing data
docker compose stop

# Stop and remove everything
docker compose down

# Remove volumes too (⚠️ deletes data)
docker compose down -v

# Interactive shell
docker compose exec rag-pipeline bash
```

### Docker (Manual)
```bash
# Build image
docker build -t rag-pipeline:1.0.0 .

# Run container
docker run -p 8501:8501 -e GEMINI_API_KEY=xxx -v chroma_db:/app/streamlit_chroma_db rag-pipeline:1.0.0

# View running containers
docker ps

# View all containers
docker ps -a

# View logs
docker logs -f container_id

# Stop container
docker stop container_id
```

## ☁️ Cloud Deployment

### EC2 Quick Deploy
```bash
# Use interactive deployment helper
bash deploy.sh
# Select option 3 (EC2 Quick Deploy)

# OR manual deployment:
# 1. Launch Ubuntu 22.04 EC2 instance
# 2. Install Docker: curl https://get.docker.com | sh
# 3. Clone repo and run: docker-compose up -d
```

### Kubernetes Deploy
```bash
# Deploy to any K8s cluster
kubectl apply -f k8s-deployment.yaml

# Check status
kubectl get pods -n rag-pipeline -w

# View logs
kubectl logs -f deployment/rag-pipeline -n rag-pipeline

# Access service
kubectl port-forward -n rag-pipeline svc/rag-pipeline-service 8501:80
# Visit: http://localhost:8501
```

### ECS Deploy
```bash
# 1. Build and push image to ECR
docker build -t rag-pipeline:latest .
docker tag rag-pipeline:latest ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/rag-pipeline:latest
docker push ACCOUNT_ID.dkr.ecr.REGION.amazonaws.com/rag-pipeline:latest

# 2. Create task definition
aws ecs register-task-definition --cli-input-json file://ecs-task-definition.json

# 3. Create/update service
aws ecs create-service --cluster rag-pipeline-cluster --service-name rag-pipeline-service ...
```

## 📈 Scaling & Performance

### Local Development
- Suitable for 1-3 developers
- Auto hot-reload on code changes
- Data persists between restarts

### Production Deployment

**Horizontal Scaling (Kubernetes)**
```bash
# Scale to 3 replicas
kubectl scale deployment rag-pipeline --replicas=3 -n rag-pipeline

# Enable auto-scaling
kubectl apply -f k8s-deployment.yaml  # Includes HPA (1-3 replicas)
```

**Resource Allocation**
```yaml
# Requests (guaranteed)
- CPU: 500m (0.5 core)
- Memory: 1Gi

# Limits (maximum)
- CPU: 2000m (2 cores)
- Memory: 2Gi
```

## 🔐 Security Best Practices

### ✅ Do's
- Use `.env` for secrets locally (NOT in git)
- Use K8s Secrets for production
- Enable network policies in K8s
- Use HTTPS/TLS in production
- Regular image updates
- Run as non-root user (done automatically)

### ❌ Don'ts
- Commit `.env` file to git
- Use latest tag in production
- Disable health checks
- Run containers as root
- Skip security scanning
- Expose unnecessary ports

## 📝 Environment Variables

Required:
```env
GEMINI_API_KEY=your-key-here
```

Optional (defaults provided):
```env
STREAMLIT_SERVER_PORT=8501
STREAMLIT_SERVER_ADDRESS=0.0.0.0
STREAMLIT_SERVER_HEADLESS=true
PYTHONUNBUFFERED=1
```

See `.env.example` for complete list.

## 🐛 Troubleshooting

### Container won't start
```bash
# Check logs
docker compose logs rag-pipeline

# Debug interactively
docker compose run --rm rag-pipeline bash
```

### Out of memory
```bash
# Check current limits
docker stats

# Increase in docker-compose.yml
# Increase in Docker Desktop preferences (Mac/Windows)
```

### Can't access web UI
```bash
# Check if port 8501 is exposed
docker port rag-pipeline

# Verify firewall/security groups allow 8501
netstat -tlnp | grep 8501  # Linux
netstat -tlnp | grep LISTEN  # Windows (as admin)
```

### ChromaDB data lost
```bash
# Check volumes
docker volume ls | grep chroma

# Inspect volume location
docker volume inspect chroma_db_data

# Restore from backup if available
```

## 📚 Additional Resources

- [DOCKER_DEPLOYMENT.md](DOCKER_DEPLOYMENT.md) - Detailed deployment guide
- [Streamlit Docs](https://docs.streamlit.io/)
- [ChromaDB Docs](https://docs.trychroma.com/)
- [Docker Docs](https://docs.docker.com/)
- [Kubernetes Docs](https://kubernetes.io/docs/)

## 🎯 Next Steps

1. **Local Development**: Run `docker-compose up -d`
2. **Testing**: Verify app at http://localhost:8501
3. **Customize**: Edit docker-compose.yml as needed
4. **Share**: Commit Docker files to git (not .env!)
5. **Deploy**: Use deploy.sh or follow cloud guides

## 💬 Support

For issues:
1. Check troubleshooting section above
2. Review logs: `docker compose logs -f`
3. Check environment: `.env` file is present and valid
4. Verify API key: https://aistudio.google.com/apikey
5. See DOCKER_DEPLOYMENT.md for more help

---

**Made easy for teams. Built for scale.** 🚀
