# LLM Providers - Quick Start Guide

Three options to run the Arabic RAG Pipeline. Choose based on your needs.

## 🎯 Decision Matrix

| Need | Provider | Command |
|------|----------|---------|
| ⚡ Fastest setup | **Gemini** | `docker compose up` |
| 🎮 Free & private | **Ollama** | `docker compose --profile ollama up` |
| 🚀 Production speed | **vLLM** | `docker compose --profile vllm up` |

---

## 1️⃣ Google Gemini (30 seconds)

Best if you want the easiest setup.

```bash
# Get key from https://aistudio.google.com/apikey

# Setup
echo "GEMINI_API_KEY=sk-..." > .env
echo "LLM_PROVIDER=gemini" >> .env

# Run
docker compose up -d

# Access: http://localhost:8501
```

✅ Works immediately  
❌ Requires API key (paid after free tier)  
💵 Cost: Free → ~$0.0005 per request

---

## 2️⃣ Ollama (5 minutes)

Best if you want free and private.

```bash
# Start Ollama service
docker compose --profile ollama up -d

# Wait 30 seconds, then download model
sleep 30
docker compose exec ollama ollama pull mistral

# Configure
echo "LLM_PROVIDER=ollama" > .env
echo "OLLAMA_MODEL=mistral" >> .env

# Start app
docker compose up -d rag-pipeline

# Access: http://localhost:8501
```

✅ Free  
✅ Private (no internet needed)  
❌ Slow (15-30 seconds per response)  
💵 Cost: One-time hardware (~$100+)

---

## 3️⃣ vLLM (10 minutes)

Best if you have a GPU and want maximum speed.

```bash
# Prerequisites: NVIDIA GPU + Docker GPU support

# Configure
cat > .env << 'EOF'
LLM_PROVIDER=vllm
VLLM_MODEL=meta-llama/Llama-2-7b-chat-hf
EOF

# Start (takes 3-5 minutes to load model)
docker compose --profile vllm up -d

# Monitor
docker compose logs -f vllm

# Start app
docker compose up -d

# Access: http://localhost:8501
```

✅ Very fast (2-5s per response)  
✅ Free software  
❌ Requires NVIDIA GPU  
💵 Cost: GPU instance (~$400/month)

---

## Switching Between Providers

```bash
# Update .env
echo "LLM_PROVIDER=ollama" > .env

# Restart
docker compose restart rag-pipeline

# Done! No code changes needed
```

---

## Check Which Provider Is Running

```bash
# View logs
docker compose logs rag-pipeline | grep -i "مزود"

# Should show something like:
# ✅ مزود LLM: Ollama
```

---

## Installation By Platform

### Linux (Recommended)

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER

# Clone repo
git clone <repo>
cd arabic-rag-pipeline-main

# Choose a provider (see above)
docker compose up -d
```

### macOS

```bash
# Install Docker Desktop
# https://www.docker.com/products/docker-desktop

# Clone repo
git clone <repo>
cd arabic-rag-pipeline-main

# Run
docker compose up -d
```

### Windows

```bash
# Install Docker Desktop
# https://www.docker.com/products/docker-desktop

# Open PowerShell
git clone <repo>
cd arabic-rag-pipeline-main

# Run
docker compose up -d
```

---

## Troubleshooting

### "Can't access http://localhost:8501"

```bash
# Check if running
docker compose ps

# View logs
docker compose logs rag-pipeline

# Restart
docker compose restart
```

### "Model failed to load"

```bash
# For Ollama
docker compose exec ollama ollama pull mistral

# For vLLM
docker compose logs vllm  # Shows loading progress
```

### "Out of memory"

```bash
# Decrease model size or increase Docker memory
# macOS/Windows: Docker Desktop → Preferences → Resources
# Linux: Update docker-compose memory limits

# For vLLM use smaller model
VLLM_MODEL=mistral-7b  # Instead of 13b
```

### "Provider not available"

```bash
# Check all available providers
docker compose logs rag-pipeline | head -20

# Should show which providers were detected
```

---

## Cost Comparison (Monthly)

**Gemini**
- Free tier: 60 req/min
- Production: ~$5-20/month

**Ollama**
- One-time: $100-500 hardware
- Monthly: $0 (just electricity)

**vLLM**
- GPU instance: $400/month (AWS g4dn)
- Best performance

---

## FAQ

**Q: Which should I use?**  
A: Start with Gemini for testing, Ollama for privacy, vLLM for production.

**Q: Can I switch later?**  
A: Yes! Just update .env and restart. Data persists.

**Q: Does it work offline?**  
A: Only Ollama and vLLM work offline. Gemini needs internet.

**Q: How fast is each?**  
A: Gemini (3s), vLLM (2s), Ollama (15-30s)

**Q: Do I lose data if I switch?**  
A: No, ChromaDB persists regardless of LLM provider.

---

## Next Steps

1. **Choose your provider** (see options above)
2. **Run docker compose up** (or with --profile flag)
3. **Open http://localhost:8501**
4. **Upload some PDFs and start asking questions!**

For more details, see:
- `LLM_PROVIDERS.md` - Detailed provider guide
- `LLM_DEPLOYMENT.md` - Production deployment
- `DOCKER_SETUP.md` - Overall Docker setup
