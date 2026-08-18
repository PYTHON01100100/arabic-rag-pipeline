# LLM Providers Guide - Arabic RAG Pipeline

Switch between Google Gemini API, Ollama, and vLLM for different production scenarios.

## Quick Comparison

| Provider | Cost | Speed | Setup | Arabic Support | GPU Required |
|----------|------|-------|-------|---|---|
| **Google Gemini** | Paid (free tier) | Fast | Easy (API key) | ✅ Excellent | ❌ No |
| **Ollama** | Free | Slow | Medium | ⚠️ Limited | ❌ No |
| **vLLM** | Free | Very Fast | Hard | ✅ Good | ✅ Yes |

## 1. Google Gemini (Easiest - Recommended for Testing)

### Setup

1. Get API key (free): https://aistudio.google.com/apikey

2. Add to `.env`:
```env
LLM_PROVIDER=gemini
GEMINI_API_KEY=sk-xxx...
GEMINI_MODEL=gemini-2.0-flash
```

3. Start:
```bash
docker compose up -d
```

### Pros
- ✅ Easiest to setup
- ✅ Excellent Arabic support
- ✅ Fast responses
- ✅ No GPU needed

### Cons
- ❌ Requires API key (paid after free tier)
- ❌ Depends on internet connection
- ❌ API rate limits

### Cost
- Free tier: 60 requests/minute
- Paid: ~$0.0005 per 1K input tokens

---

## 2. Ollama (Free Local - Best for Privacy)

### Prerequisites
- Install Ollama: https://ollama.ai
- Minimum 7GB RAM (for llama2)
- No GPU needed (but slow)

### Setup

1. Start Ollama server (separate terminal):
```bash
# macOS/Linux
ollama serve

# Windows (if installed)
ollama serve
```

2. Download Arabic-capable model:
```bash
ollama pull llama2  # English (8GB)
# OR for Arabic-first models:
ollama pull mistral  # Better Arabic (4.1GB)
```

3. Update `.env`:
```env
LLM_PROVIDER=ollama
OLLAMA_BASE_URL=http://localhost:11434
OLLAMA_MODEL=llama2
OLLAMA_TEMPERATURE=0.7
```

4. Start application:
```bash
docker compose up -d
```

### Docker Compose (All-in-One)

Use the included Ollama service:

```bash
# Start with Ollama
docker compose --profile ollama up -d

# Wait for Ollama to be ready (30 seconds)
sleep 30

# Download model
docker compose exec ollama ollama pull llama2

# Now start the RAG pipeline
docker compose up -d rag-pipeline
```

### Pros
- ✅ Free
- ✅ Local (no internet needed)
- ✅ Private (no data sent to servers)
- ✅ Can work offline

### Cons
- ❌ Slow (15-30s per response without GPU)
- ❌ Limited Arabic models
- ❌ High memory usage
- ⚠️ Quality lower than Gemini/Claude

### Available Arabic Models

```bash
# English (good fallback)
ollama pull llama2       # 4B, 7B, 13B versions

# Better multilingual/Arabic
ollama pull mistral      # Better Arabic
ollama pull neural-chat  # Also good

# Pull specific size
ollama pull mistral:7b   # Specify size
```

### Example Usage

```bash
# Terminal 1: Start Ollama
ollama serve

# Terminal 2: Download model
ollama pull mistral

# Terminal 3: Setup application
cd arabic-rag-pipeline-main
cp .env.example .env
# Edit .env to set OLLAMA_MODEL=mistral
docker compose up -d

# Access: http://localhost:8501
```

### Troubleshooting

```bash
# Check Ollama status
curl http://localhost:11434/api/tags

# Pull specific model
ollama pull mistral

# Remove model to free space
ollama rm mistral

# Check memory usage
ollama ps

# Clear stuck processes
killall ollama
```

---

## 3. vLLM (Fast Local - Production Recommended)

### Prerequisites
- **NVIDIA GPU** with CUDA (8GB+ VRAM recommended)
- GPU drivers installed
- Docker with GPU support (`nvidia-docker`)

### Setup

#### Option A: Docker (Recommended)

```bash
# 1. Enable GPU support in docker-compose
# Edit docker-compose.yml, uncomment GPU section under vllm service

# 2. Start vLLM service
docker compose --profile vllm up -d

# 3. Wait for model to load (2-5 minutes)
docker compose logs -f vllm

# 4. Configure RAG pipeline
cat >> .env << 'EOF'
LLM_PROVIDER=vllm
VLLM_BASE_URL=http://localhost:8000/v1
VLLM_MODEL=meta-llama/Llama-2-7b-chat-hf
EOF

# 5. Start application
docker compose up -d
```

#### Option B: Manual (Advanced)

```bash
# Install vLLM
pip install vllm

# Start server
python -m vllm.entrypoints.openai.api_server \
  --model meta-llama/Llama-2-7b-chat-hf \
  --dtype float16 \
  --gpu-memory-utilization 0.8

# In another terminal:
docker compose up -d rag-pipeline
```

### Configuration

```env
# .env
LLM_PROVIDER=vllm
VLLM_BASE_URL=http://localhost:8000/v1
VLLM_API_KEY=not-needed
VLLM_MODEL=meta-llama/Llama-2-7b-chat-hf
VLLM_MAX_TOKENS=2048
VLLM_TEMPERATURE=0.7
```

### Available Models (HuggingFace)

```bash
# Llama 2 (most popular)
meta-llama/Llama-2-7b-chat-hf      # 7B (fastest)
meta-llama/Llama-2-13b-chat-hf     # 13B (better quality)
meta-llama/Llama-2-70b-chat-hf     # 70B (best, needs 80GB+)

# Mistral (better Arabic)
mistralai/Mistral-7B-Instruct-v0.1

# Other options
NousResearch/Nous-Hermes-2-7b
teknium/OpenHermes-2.5-Mistral-7B
```

### Pros
- ✅ Very fast (2-5s per response with GPU)
- ✅ Free (open source)
- ✅ Local and private
- ✅ Supports batch processing
- ✅ Production-grade

### Cons
- ❌ Requires NVIDIA GPU
- ❌ Complex setup
- ❌ High VRAM usage
- ❌ Limited Arabic quality

### Performance Benchmarks

With NVIDIA A100 GPU:
- 7B model: ~20 tokens/sec (2-3s for 50 tokens)
- 13B model: ~10 tokens/sec (4-5s for 50 tokens)
- 70B model: ~2-3 tokens/sec (15-20s for 50 tokens)

### GPU Memory Requirements

| Model | GPU Memory | Recommended GPU |
|-------|-----------|-----------------|
| 7B | 16GB | RTX 3080, RTX 4060 Ti |
| 13B | 24GB | RTX 3090, RTX 4090 |
| 70B | 80GB | A100, H100 |

### Troubleshooting

```bash
# Check CUDA setup
nvidia-smi

# Verify docker-gpu
docker run --rm --gpus all nvidia/cuda:11.8.0-runtime-ubuntu22.04 nvidia-smi

# Check vLLM logs
docker compose logs -f vllm

# Memory issues? Reduce token limit or batch size
# Edit docker-compose.yml VLLM_MAX_TOKENS
```

---

## Auto-Detection (Recommended)

The pipeline automatically selects the best available provider:

```env
LLM_PROVIDER=auto  # Default: tries vLLM > Ollama > Gemini
```

Priority order:
1. vLLM (if running)
2. Ollama (if running)
3. Google Gemini (if API key present)

### Example Auto-Detection Flow

```bash
# .env with all configured
LLM_PROVIDER=auto
GEMINI_API_KEY=sk-xxx...
OLLAMA_BASE_URL=http://localhost:11434
VLLM_BASE_URL=http://localhost:8000/v1

# Startup order:
# 1. Check if vLLM is running on :8000/v1/models ← uses this
# 2. Check if Ollama is running on :11434/api/tags
# 3. Check if GEMINI_API_KEY is set
```

---

## Production Deployment Guide

### For AWS/Cloud Deployment

#### Using Ollama (Cheapest)
```bash
# EC2: t3.large (2 vCPU, 8GB RAM, $0.10/hour)
docker compose --profile ollama up -d
```

#### Using vLLM (Fastest, Needs GPU)
```bash
# EC2: g4dn.xlarge (NVIDIA T4 GPU, $0.526/hour)
# Supports 6-7B models easily

docker compose --profile vllm up -d
```

#### Using Gemini (No Infrastructure)
```bash
# Just set API key, no hardware costs
LLM_PROVIDER=gemini
```

### For Kubernetes

```yaml
# Configure based on provider

# 1. Gemini (simplest)
env:
  - name: LLM_PROVIDER
    value: "gemini"
  - name: GEMINI_API_KEY
    valueFrom:
      secretKeyRef:
        name: llm-secrets
        key: gemini-key

# 2. Ollama (add sidecar)
containers:
  - name: ollama
    image: ollama/ollama:latest
    ports:
      - containerPort: 11434
  - name: rag-pipeline
    env:
      - name: LLM_PROVIDER
        value: "ollama"
      - name: OLLAMA_BASE_URL
        value: "http://localhost:11434"

# 3. vLLM (with GPU)
containers:
  - name: vllm
    image: vllm/vllm-openai:latest
    resources:
      requests:
        nvidia.com/gpu: 1
```

---

## Cost Comparison

### Monthly Costs (Assuming 10,000 requests/month)

**Google Gemini API**
- Estimate: $5-15/month
- Per request: $0.0005-0.0015

**Ollama (Self-Hosted)**
- EC2 t3.large: ~$70/month
- Electricity: ~$10/month
- **Total: $80/month** (but no API costs)

**vLLM (Self-Hosted with GPU)**
- EC2 g4dn.xlarge: ~$380/month
- Electricity: ~$20/month
- **Total: $400/month** (but very fast, production-grade)

---

## Switching Providers at Runtime

### Step 1: Update `.env`
```bash
# Was using Gemini
LLM_PROVIDER=gemini

# Switch to Ollama
LLM_PROVIDER=ollama
OLLAMA_MODEL=mistral
```

### Step 2: Restart Application
```bash
docker compose restart rag-pipeline
```

### Step 3: Application Detects Provider
- Sidebar shows current provider
- No code changes needed
- Data persists (ChromaDB unchanged)

---

## Custom Models

### Add Your Own Model

For Ollama:
```bash
# Create Modelfile
cat > Modelfile << 'EOF'
FROM mistral
SYSTEM """أنت مساعد أكاديمي عربي متخصص."""
EOF

# Create custom model
ollama create my-arabic-model -f Modelfile

# Use it
LLM_PROVIDER=ollama
OLLAMA_MODEL=my-arabic-model
```

For vLLM:
```bash
# Use any HuggingFace model
VLLM_MODEL=NousResearch/Nous-Hermes-2-Mixtral-8x7B-DPO
```

---

## Troubleshooting

### Provider Not Found
```bash
# Verify provider is running
curl http://localhost:11434/api/tags      # Ollama
curl http://localhost:8000/v1/models      # vLLM
curl https://generativelanguage.googleapis.com/v1beta/models  # Gemini

# Check logs
docker compose logs rag-pipeline
```

### API Key Invalid
```bash
# Gemini: Verify key at https://aistudio.google.com/apikey
# Check it's in .env
grep GEMINI_API_KEY .env

# Restart
docker compose restart rag-pipeline
```

### Slow Responses
```bash
# Ollama: Use mistral instead of llama2 (faster)
# vLLM: Ensure GPU is being used (nvidia-smi)
# Gemini: Check internet connection
```

### Memory Issues
```bash
# Ollama: Close other applications, increase Docker memory
# vLLM: Reduce model size (7b instead of 13b)
# Check usage: docker stats
```

---

## Recommendations

### For Development/Testing
→ **Google Gemini** (easiest)

### For Privacy/Offline
→ **Ollama** (free, simple)

### For Production/Performance
→ **vLLM** (fast, scalable) or **Gemini** (managed)

### For Cost-Sensitive
→ **Ollama** (one-time hardware cost)

### For Teams/Enterprise
→ **vLLM on Kubernetes** (scalable) or **Gemini API** (managed)

---

## Support

- Ollama Issues: https://github.com/ollama/ollama/issues
- vLLM Issues: https://github.com/vllm-project/vllm/issues
- Gemini Issues: https://ai.google.dev/
- This Project: See DOCKER_DEPLOYMENT.md
